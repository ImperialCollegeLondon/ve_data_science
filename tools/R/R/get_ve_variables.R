#| ---
#| title: Virtual Ecosystem variable retrieval and derivation
#|
#| description: |
#|     Functions for retrieving and computing derived Virtual Ecosystem
#|     variables from Zarr output datasets, plus a legacy netCDF reader for
#|     backward compatibility.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|     - Virtual Ecosystem Zarr output dataset (.zarr)
#|     - Virtual Ecosystem netCDF dataset (.nc)
#|     - Virtual Ecosystem configuration TOML file (.toml)
#|
#| output_files: None (returns R objects)
#|
#| package_dependencies:
#|     - pizzarr
#|     - tidync
#|     - purrr
#|     - dplyr
#|     - stringr
#|     - toml
#|     - cli
#|
#| usage_notes: |
#|     See individual function documentation below for details and examples.
#| ---

#' Retrieve (non-dimension) state variables from a Zarr dataset
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param group Character string for which Zarr group to retrieve data from.
#'   One of `"outputs"` (default), `"inputs"`, or `"init"`.
#' @param variables Optional character vector of variable names to retrieve.
#'   If `NULL` (default), all non-dimension state variables are retrieved.
#'
#' @returns A named list of arrays for the requested non-dimension state
#'   variables. Names correspond to variable names.
#'
#' @examples
#' \dontrun{
#'   # Retrieve all variables from outputs group
#'   all_vars <- get_data_variables("out/model_state.zarr", group = "outputs")
#'
#'   # Retrieve specific variables from inputs group
#'   subset_vars <- get_data_variables(
#'     "out/model_state.zarr",
#'     group = "inputs",
#'     variables = c("air_temperature", "precipitation")
#'   )
#' }
#'
#' @export

get_data_variables <- function(
  zarr_path,
  group = c("outputs", "inputs", "init"),
  variables = NULL
) {
  # read Zarr variables from VE
  ve_vars <- pizzarr::zarr_open(zarr_path)$get_item(group)

  # retrieve state variables
  vars <- ve_vars$get_store()$listdir(group)
  var_discard <- c(".zattrs", ".zgroup", "number", "spatial_ref")
  vars <- vars[vars %notin% var_discard]

  # use all variables if none specified,
  # otherwise validate requested variables exist
  if (!is.null(variables)) {
    # check that all requested variables are present in the data
    missing_vars <- setdiff(variables, vars)
    if (length(missing_vars) > 0) {
      cli::cli_abort(
        "The following variables are not found: {.val {missing_vars}}"
      )
    }
  } else {
    variables <- vars
  }

  # check that all variables have shape
  var_dims <- purrr::map_int(variables, \(var) {
    ve_vars$get_item(var)$get_ndim()
  })
  if (any(var_dims == 0)) {
    var_zero_dim <- variables[var_dims == 0]
    cli::cli_abort(
      "The following variables have zero dimension: {.val {var_zero_dim}}.
      Did you intend to remove them?"
    )
  }

  # extract each variable's array
  # also put the dimension names back from the attributes
  # for Zarr V2 the dimension-name is a clunky round-about process
  out <- purrr::map(
    variables,
    \(variable) {
      tmp_zarr <- ve_vars$get_item(variable)
      out_array <- tmp_zarr$as.array()
      dimnames_names <-
        tmp_zarr$get_attrs()$to_list()$`_ARRAY_DIMENSIONS` |>
        unlist()
      dimnames <-
        dimnames_names |>
        purrr::map(\(name) {
          ve_vars$get_item(name)$as.array()
        })
      names(dimnames) <- dimnames_names
      dimnames(out_array) <- dimnames
      return(out_array)
    },
    .progress = TRUE
  )

  names(out) <- variables
  return(out)
}


#' Retrieve (non-dimension) state variables from a netCDF file
#'
#' @param tidync A tidync object from tidync(), which reads in data from
#'   a netCDF file.
#' @param variables Optional character vector of variable names to retrieve.
#'   If `NULL` (default), all non-dimension state variables are retrieved.
#'
#' @returns A list of arrays for all non-dimension state variables, including
#'   each of their dimension names. Names correspond to variable names.
#'
#' @examples
#' \dontrun{
#'   # Retrieve all variables
#'   nc <- tidync::tidync("data.nc")
#'   all_vars <- get_data_variables_nc(nc)
#'
#'   # Retrieve specific variables
#'   subset_vars <- get_data_variables_nc(
#'     nc,
#'     variables = c("temp", "precip")
#'   )
#' }
#'
#' @export

get_data_variables_nc <- function(tidync, variables = NULL) {
  # retrieve all non-dimension state variables
  vars <-
    tidync$variable |>
    dplyr::filter(dim_coord == FALSE) |>
    dplyr::pull(name)

  # use all variables if none specified,
  # otherwise validate requested variables exist
  if (!is.null(variables)) {
    # check that all requested variables are present in the data
    missing_vars <- setdiff(variables, vars)
    if (length(missing_vars) > 0) {
      cli::cli_abort(
        "The following variables are not found: {.val {missing_vars}}"
      )
    }
  } else {
    # default to all available variables
    variables <- vars
  }

  # activate each variable and extract its array iteratively
  out <-
    variables |>
    purrr::map(\(var) {
      tidync |>
        tidync::activate(var) |>
        tidync::hyper_array(drop = FALSE) |>
        purrr::pluck(var)
    })
  names(out) <- variables
  return(out)
}

#' Get derived variables
#'
#' Wrapper around \code{get_*()} to compute derived variables from a
#' Virtual Ecosystem Zarr output dataset.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config_path Path to the exported full VE configuration TOML file.
#' @param ... Additional arguments passed to \code{get_data_variables()}.
#' @return A named list with derived variables.
#'
#' @examples
#' \dontrun{
#'   zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
#'   config_path <-
#'     "data/scenarios/maliau/maliau_2/out/ve_full_model_configuration.toml"
#'   get_derived_variables(zarr_path, config_path)
#' }
#'
#' @export

get_derived_variables <- function(zarr_path, config_path, ...) {
  config <- toml::read_toml(config_path)

  # first collect the derived variables that are returned as a single array
  list(
    total_soil_c_per_volume = get_total_soil_c_per_volume(zarr_path),
    total_soil_c_per_mass = get_total_soil_c_per_mass(zarr_path, config),
    total_soil_c_per_area = get_total_soil_c_per_area(zarr_path, config),
    total_soil_n_per_volume = get_total_soil_n_per_volume(zarr_path, config),
    total_soil_n_per_mass = get_total_soil_n_per_mass(zarr_path, config),
    total_soil_n_per_area = get_total_soil_n_per_area(zarr_path, config),
    total_soil_p_per_volume = get_total_soil_p_per_volume(zarr_path, config),
    total_soil_p_per_mass = get_total_soil_p_per_mass(zarr_path, config),
    total_soil_p_per_area = get_total_soil_p_per_area(zarr_path, config)
  ) |>
    # then collect the derived variables that are returned as a list of arrays
    append(
      get_soil_np_pool_microbial(zarr_path, config)
    )
}

#' Compute total soil carbon per volume
#'
#' Sum carbon pools from soil variable arrays.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset. See examples.
#' @return Array of total soil carbon per volume.
#'
#' @export

get_total_soil_c_per_volume <- function(zarr_path) {
  # get the soil C variables
  input_vars <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c(
      "soil_cnp_pool_lmwc",
      "soil_cnp_pool_maom",
      "soil_cnp_pool_necromass",
      "soil_cnp_pool_pom",
      "soil_c_pool_arbuscular_mycorrhiza",
      "soil_c_pool_bacteria",
      "soil_c_pool_ectomycorrhiza",
      "soil_c_pool_saprotrophic_fungi"
    )
  )

  # summation
  with(
    input_vars,
    soil_cnp_pool_lmwc[,, "C"] +
      soil_cnp_pool_maom[,, "C"] +
      soil_cnp_pool_necromass[,, "C"] +
      soil_cnp_pool_pom[,, "C"] +
      soil_c_pool_arbuscular_mycorrhiza +
      soil_c_pool_bacteria +
      soil_c_pool_ectomycorrhiza +
      soil_c_pool_saprotrophic_fungi
  )
}

#' Convert nutrient per volume to mass basis
#'
#' @param volume_basis_data Data in volume basis.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of soil nutrient per mass.

convert_volume_to_mass_basis <- function(volume_basis_data, config) {
  # retrieve bulk density from full configurations, but it won't be exported
  # unless the abiotic model is used. In the case of abiotic_simple, for
  # example, it will return NULL, so we overwrite it manually with a hard-coded
  # default value in VE; this is meant to be temporary and is subjected to
  # discussion
  bulk_density_soil <- config$abiotic$constants$bulk_density_soil
  if (is.null(bulk_density_soil)) {
    bulk_density_soil <- 1175.0
    data_name <- deparse(substitute(volume_basis_data))
    cli::cli_alert_warning(paste0(
      "Soil bulk density is not found in the scenario config file while ",
      "converting {.var {data_name}}. ",
      "Assigning VE default value {.val {bulk_density_soil}}."
    ))
  }

  # convert nutrient per volume to nutrient per mass
  volume_basis_data / bulk_density_soil
}

#' Convert nutrient per volume to area basis
#'
#' @param volume_basis_data Data in volume basis.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of soil nutrient per area.

convert_volume_to_area_basis <- function(volume_basis_data, config) {
  soil_layer_depth <- config$core$constants$microbial_simulation_depth
  volume_basis_data * soil_layer_depth
}


#' Calculate total soil carbon per mass
#'
#' Convert total soil carbon per volume to a mass basis.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil carbon per mass.
#' @export

get_total_soil_c_per_mass <- function(zarr_path, config) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(zarr_path)
  convert_volume_to_mass_basis(total_soil_c_per_volume, config)
}


#' Calculate total soil carbon per area
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil carbon per area.
#' @export

get_total_soil_c_per_area <- function(zarr_path, config) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(zarr_path)
  convert_volume_to_area_basis(total_soil_c_per_volume, config)
}


#' Calculate soil nitrogen and phosphorus in microbial pools
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return List of arrays of nitrogen and phosphorus in the microbial pools.

get_soil_np_pool_microbial <- function(zarr_path, config) {
  # get the soil C in the microbial pools
  soil_c_microbial <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c(
      "soil_c_pool_bacteria",
      "soil_c_pool_arbuscular_mycorrhiza",
      "soil_c_pool_ectomycorrhiza",
      "soil_c_pool_saprotrophic_fungi"
    )
  )

  # get the microbial nutrient stoichiometry
  stoich <-
    config$soil$microbial_group_definition |>
    purrr::map_vec(\(x) {
      as.data.frame(x[c("name", "c_n_ratio", "c_p_ratio")])
    }) |>
    dplyr::mutate(name = paste0("soil_c_pool_", name))
  # make sure that the names of microbial groups match up
  c_n_ratio <- stoich$c_n_ratio[match(names(soil_c_microbial), stoich$name)]
  c_p_ratio <- stoich$c_p_ratio[match(names(soil_c_microbial), stoich$name)]

  # convert soil C to N and P, and rename arrays by their nutrient type
  soil_n_microbial <-
    purrr::map2(soil_c_microbial, c_n_ratio, \(x, y) {
      x / y
    })
  names(soil_n_microbial) <- stringr::str_replace(
    names(soil_n_microbial),
    "_c_",
    "_n_"
  )
  soil_p_microbial <-
    purrr::map2(soil_c_microbial, c_p_ratio, \(x, y) {
      x / y
    })
  names(soil_p_microbial) <- stringr::str_replace(
    names(soil_p_microbial),
    "_c_",
    "_p_"
  )

  # combine N and P outputs
  c(soil_n_microbial, soil_p_microbial)
}


#' Compute total soil nitrogen per volume
#'
#' Sum nitrogen pools from soil variable arrays.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per volume.
#' @export

get_total_soil_n_per_volume <- function(zarr_path, config) {
  # get the soil N variables
  input_vars <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c(
      "soil_cnp_pool_lmwc",
      "soil_cnp_pool_maom",
      "soil_cnp_pool_necromass",
      "soil_cnp_pool_pom",
      "soil_n_pool_ammonium",
      "soil_n_pool_nitrate"
    )
  )

  # convert the microbial C to N
  soil_np_pool_microbial <- get_soil_np_pool_microbial(zarr_path, config)

  # summation
  with(
    input_vars,
    soil_cnp_pool_lmwc[,, "N"] +
      soil_cnp_pool_maom[,, "N"] +
      soil_cnp_pool_necromass[,, "N"] +
      soil_cnp_pool_pom[,, "N"] +
      soil_n_pool_ammonium +
      soil_n_pool_nitrate
  ) +
    with(
      soil_np_pool_microbial,
      soil_n_pool_arbuscular_mycorrhiza +
        soil_n_pool_bacteria +
        soil_n_pool_ectomycorrhiza +
        soil_n_pool_saprotrophic_fungi
    )
}

#' Calculate total soil nitrogen per mass
#'
#' Convert total soil nitrogen per volume to a mass basis.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per mass.
#' @export

get_total_soil_n_per_mass <- function(zarr_path, config) {
  total_soil_n_per_volume <- get_total_soil_n_per_volume(zarr_path, config)
  convert_volume_to_mass_basis(total_soil_n_per_volume, config)
}

#' Calculate total soil nitrogen per area
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per area.
#' @export

get_total_soil_n_per_area <- function(zarr_path, config) {
  total_soil_n_per_volume <- get_total_soil_n_per_volume(zarr_path, config)
  convert_volume_to_area_basis(total_soil_n_per_volume, config)
}

#' Compute total soil phosphorus per volume
#'
#' Sum phosphorus pools from soil variable arrays.
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per volume.
#' @export

get_total_soil_p_per_volume <- function(zarr_path, config) {
  # get the soil P variables
  input_vars <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c(
      "soil_cnp_pool_lmwc",
      "soil_cnp_pool_maom",
      "soil_cnp_pool_necromass",
      "soil_cnp_pool_pom",
      "soil_p_pool_labile",
      "soil_p_pool_primary",
      "soil_p_pool_secondary"
    )
  )

  # convert the microbial C to P
  soil_np_pool_microbial <- get_soil_np_pool_microbial(zarr_path, config)

  # summation
  with(
    input_vars,
    soil_cnp_pool_lmwc[,, "P"] +
      soil_cnp_pool_maom[,, "P"] +
      soil_cnp_pool_necromass[,, "P"] +
      soil_cnp_pool_pom[,, "P"] +
      soil_p_pool_labile +
      soil_p_pool_primary +
      soil_p_pool_secondary
  ) +
    with(
      soil_np_pool_microbial,
      soil_p_pool_arbuscular_mycorrhiza +
        soil_p_pool_bacteria +
        soil_p_pool_ectomycorrhiza +
        soil_p_pool_saprotrophic_fungi
    )
}

#' Calculate total soil phosphorus per mass
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per mass.
#' @export

get_total_soil_p_per_mass <- function(zarr_path, config) {
  total_soil_p_per_volume <- get_total_soil_p_per_volume(zarr_path, config)
  convert_volume_to_mass_basis(total_soil_p_per_volume, config)
}

#' Calculate total soil phosphorus per area
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per area.
#' @export

get_total_soil_p_per_area <- function(zarr_path, config) {
  total_soil_p_per_volume <- get_total_soil_p_per_volume(zarr_path, config)
  convert_volume_to_area_basis(total_soil_p_per_volume, config)
}

#' Calculate soil ammonium pool per mass
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of soil ammonium pool per mass.
#' @export

get_soil_n_pool_ammonium_per_mass <- function(zarr_path, config) {
  soil_n_pool_ammonium_per_volume <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = "soil_n_pool_ammonium"
  )
  convert_volume_to_mass_basis(soil_n_pool_ammonium_per_volume, config)
}

#' Calculate soil nitrate pool per mass
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of soil nitrate pool per mass.
#' @export

get_soil_n_pool_nitrate_per_mass <- function(zarr_path, config) {
  soil_n_pool_nitrate_per_volume <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = "soil_n_pool_nitrate"
  )
  convert_volume_to_mass_basis(soil_n_pool_nitrate_per_volume, config)
}


get_soil_p_pool_labile_per_mass <- function(zarr_path, config) {
  soil_p_pool_labile <- get_data_variables(
    zarr_path,
    group = "outputs",
    variables = "soil_p_pool_labile"
  )
  convert_volume_to_mass_basis(soil_p_pool_labile, config)
}


#' Calculate productivity from VE realised tissue biomass outputs
#'
#' A named realised tissue biomass per individual is multiplied by cohort
#' individuals, aggregated to cell-level biomass, and converted to an annual
#' area-normalised productivity rate between consecutive timesteps.
#'
#' Rows with missing `whole_crown_gpp` are treated as the initial biomass state
#' immediately before the regular `time_index = 0` output. This initial state
#' is aggregated separately rather than added to the regular timestep-0
#' cohorts, so the first returned interval represents the change from the
#' initial state to regular `time_index = 0`. Its duration is inferred from the
#' gap between regular timestep 0 and the next regular timestep.
#'
#' The function retains the productivity rate for every available cell and
#' timestep. When a start and end date are supplied, dates are matched by
#' month and a selected-period mean is calculated for each cell. A separate
#' mean across the entire simulation is always calculated. If either requested
#' month is unavailable, the selected-period mean is returned as `NA`.
#'
#' @param plants_cohort_data Path to a VE `plants_cohort_data.csv` file or a
#'   data frame containing the required columns.
#' @param input_variable Name of the per-individual realised tissue biomass
#'   column. Values must be in kg C, kg N, or kg P.
#' @param output_variable Name for the calculated productivity column.
#' @param cell_area_ha Area represented by each cell in hectares. This must be
#'   supplied explicitly.
#' @param start_date Optional start date for calculating a period mean. Dates
#'   are matched by month.
#' @param end_date Optional end date for calculating a period mean. Dates are
#'   matched by month.
#'
#' @returns A data frame retaining the interval-level change for each cell and
#'   time and `time_index`, with selected-period and full-simulation means
#'   repeated on each cell's rows, plus a `selected_period` label and `units`.
#'   Spatial means across all cells are also repeated on each row for the
#'   selected period and the full simulation.
#'   If either
#'   requested month is unavailable, the selected-period mean is `NA` and the
#'   full-simulation mean remains populated.
#'
#' @export

calculate_ve_realised_tissue_productivity <- function(
  plants_cohort_data,
  input_variable,
  output_variable,
  cell_area_ha,
  start_date = NULL,
  end_date = NULL
) {
  # These columns identify the cohort biomass, individuals, and the
  # timesteps needed to calculate the annual area-normalised change.
  required_columns <- c(
    "cell_id",
    "time",
    "time_index",
    "n_individuals",
    "whole_crown_gpp",
    input_variable
  )

  # Accept either the VE CSV path or data already loaded into a data frame.
  if (is.character(plants_cohort_data) && length(plants_cohort_data) == 1) {
    if (!file.exists(plants_cohort_data)) {
      cli::cli_abort(
        "Plants cohort data file does not exist: {.path {plants_cohort_data}}"
      )
    }
    plants_cohort_data <- utils::read.csv(
      plants_cohort_data,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  # Fail early so malformed input does not produce misleading productivity.
  if (!is.data.frame(plants_cohort_data)) {
    cli::cli_abort("plants_cohort_data must be a CSV path or data frame.")
  }

  missing_columns <- setdiff(required_columns, names(plants_cohort_data))
  if (length(missing_columns) > 0) {
    cli::cli_abort(
      "Missing required columns: {.val {missing_columns}}"
    )
  }

  if (
    !is.numeric(cell_area_ha) ||
      length(cell_area_ha) != 1 ||
      !is.finite(cell_area_ha) ||
      cell_area_ha <= 0
  ) {
    cli::cli_abort("cell_area_ha must be one positive finite number.")
  }

  if (xor(is.null(start_date), is.null(end_date))) {
    cli::cli_abort("start_date and end_date must be supplied together.")
  }

  if (
    !is.null(start_date) &&
      (length(start_date) != 1 ||
        length(end_date) != 1)
  ) {
    cli::cli_abort("start_date and end_date must each contain one date.")
  }

  tissue_element <- toupper(sub(
    ".*_([cCpPnN])_biomass$",
    "\\1",
    input_variable
  ))
  if (!tissue_element %in% c("C", "N", "P")) {
    cli::cli_abort(
      "input_variable must identify a C, N, or P biomass column."
    )
  }
  output_units <- paste0("Mg ", tissue_element, " ha-1 year-1")

  # Convert the source columns to the types used by the calculation.
  cohort_data <- data.frame(
    cell_id = plants_cohort_data$cell_id,
    time = as.Date(plants_cohort_data$time),
    time_index = as.numeric(plants_cohort_data$time_index),
    n_individuals = as.numeric(plants_cohort_data$n_individuals),
    whole_crown_gpp = plants_cohort_data$whole_crown_gpp,
    tissue_biomass = as.numeric(plants_cohort_data[[input_variable]]),
    stringsAsFactors = FALSE
  )

  if (anyNA(cohort_data$time)) {
    cli::cli_abort(
      "The time column contains values that cannot be parsed as dates."
    )
  }

  initial_rows <- is.na(cohort_data$whole_crown_gpp)
  regular_rows <- !initial_rows
  if (!any(initial_rows) || !any(regular_rows)) {
    cli::cli_abort(
      "whole_crown_gpp must identify both initial and regular output rows."
    )
  }

  # Tissue biomass is per individual, so multiply by cohort abundance to get
  # the biomass contributed by each cohort before state aggregation.
  cohort_data$tissue_biomass_kg <-
    cohort_data$tissue_biomass * cohort_data$n_individuals

  initial_biomass <- aggregate(
    tissue_biomass_kg ~ cell_id,
    data = cohort_data[initial_rows, , drop = FALSE],
    FUN = sum,
    na.rm = TRUE
  )
  names(initial_biomass)[2] <- "initial_tissue_biomass_kg"

  # Regular rows are the model states used for all subsequent intervals.
  cell_tissue_biomass <- aggregate(
    tissue_biomass_kg ~ cell_id + time + time_index,
    data = cohort_data[regular_rows, , drop = FALSE],
    FUN = sum,
    na.rm = TRUE
  )

  # Calculate each cell's signed change. The first regular state uses the
  # separately aggregated initial state; later states use regular lags.
  cell_data <- split(cell_tissue_biomass, cell_tissue_biomass$cell_id)
  cell_tissue_biomass <- lapply(cell_data, function(cell_data) {
    cell_data <- cell_data[order(cell_data$time), , drop = FALSE]
    initial_value <- initial_biomass[
      initial_biomass$cell_id == cell_data$cell_id[1],
      "initial_tissue_biomass_kg"
    ]
    if (length(initial_value) != 1) {
      cli::cli_abort(
        "Each regular cell must have exactly one initial biomass value."
      )
    }
    timestep_gap <- as.numeric(diff(cell_data$time)[1])
    if (is.na(timestep_gap) || timestep_gap <= 0) {
      cli::cli_abort(
        "At least two regular timesteps are required to infer the initial interval."
      )
    }
    cell_data$previous_time <- c(
      cell_data$time[1] - timestep_gap,
      head(cell_data$time, -1)
    )
    cell_data$previous_tissue_biomass_kg <- c(
      initial_value,
      head(cell_data$tissue_biomass_kg, -1)
    )
    cell_data$interval_years <- as.numeric(
      cell_data$time - cell_data$previous_time
    ) /
      365.25
    cell_data$annual_area_normalised_change <- (cell_data$tissue_biomass_kg -
      cell_data$previous_tissue_biomass_kg) /
      cell_data$interval_years /
      cell_area_ha /
      1000
    cell_data[
      !is.na(cell_data$previous_time) &
        cell_data$interval_years > 0,
      ,
      drop = FALSE
    ]
  })
  cell_tissue_biomass <- do.call(rbind, cell_tissue_biomass)

  selected_period_data <- NULL
  selected_period_label <- "not_requested"
  if (!is.null(start_date)) {
    start_date <- as.Date(start_date)
    end_date <- as.Date(end_date)
    if (is.na(start_date) || is.na(end_date) || start_date > end_date) {
      cli::cli_abort("start_date and end_date must be valid ordered dates.")
    }

    available_dates <- unique(c(
      cell_tissue_biomass$previous_time,
      cell_tissue_biomass$time
    ))
    available_months <- format(available_dates, "%Y-%m")
    start_month <- format(start_date, "%Y-%m")
    end_month <- format(end_date, "%Y-%m")
    dates_available <- start_month %in%
      available_months &&
      end_month %in% available_months

    if (dates_available) {
      period_data <- cell_tissue_biomass[
        format(cell_tissue_biomass$previous_time, "%Y-%m") >= start_month &
          format(cell_tissue_biomass$time, "%Y-%m") <= end_month,
        ,
        drop = FALSE
      ]
      if (nrow(period_data) > 0) {
        selected_period_data <- period_data
        selected_period_label <- paste(
          start_month,
          end_month,
          sep = " to "
        )
      } else {
        selected_period_label <- "unavailable_period"
      }
    } else {
      selected_period_label <- "unavailable_period"
    }
  }

  simulation_mean <- aggregate(
    annual_area_normalised_change ~ cell_id,
    data = cell_tissue_biomass,
    FUN = mean,
    na.rm = TRUE
  )
  names(simulation_mean)[2] <- paste0(
    output_variable,
    "_simulation_period_mean"
  )
  selected_period_mean <- data.frame(
    cell_id = simulation_mean$cell_id,
    selected_period_mean = NA_real_
  )
  if (!is.null(selected_period_data)) {
    selected_period_mean <- aggregate(
      annual_area_normalised_change ~ cell_id,
      data = selected_period_data,
      FUN = mean,
      na.rm = TRUE
    )
  }
  names(selected_period_mean)[2] <- paste0(
    output_variable,
    "_selected_period_mean"
  )

  spatial_simulation_mean <- mean(
    cell_tissue_biomass$annual_area_normalised_change,
    na.rm = TRUE
  )
  spatial_selected_period_mean <- NA_real_
  if (!is.null(selected_period_data)) {
    spatial_selected_period_mean <- mean(
      selected_period_data$annual_area_normalised_change,
      na.rm = TRUE
    )
  }

  interval_data <- cell_tissue_biomass[,
    c("cell_id", "time", "time_index", "annual_area_normalised_change"),
    drop = FALSE
  ]
  names(interval_data)[4] <- output_variable

  result <- merge(
    interval_data,
    selected_period_mean,
    by = "cell_id",
    all.x = TRUE,
    sort = FALSE
  )
  result <- merge(
    result,
    simulation_mean,
    by = "cell_id",
    all.x = TRUE,
    sort = FALSE
  )
  result$selected_period <- selected_period_label
  result[[paste0(output_variable, "_spatial_selected_period_mean")]] <-
    spatial_selected_period_mean
  result[[paste0(output_variable, "_spatial_simulation_period_mean")]] <-
    spatial_simulation_mean
  result$units <- output_units
  result <- result[,
    c(
      "cell_id",
      "time",
      "time_index",
      output_variable,
      "selected_period",
      paste0(output_variable, "_selected_period_mean"),
      paste0(output_variable, "_simulation_period_mean"),
      paste0(output_variable, "_spatial_selected_period_mean"),
      paste0(output_variable, "_spatial_simulation_period_mean"),
      "units"
    ),
    drop = FALSE
  ]
  result
}
