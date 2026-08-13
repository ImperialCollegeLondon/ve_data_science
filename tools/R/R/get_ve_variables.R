#| ---
#| title: Virtual Ecosystem variable retrieval and derivation
#|
#| description: |
#|     Functions for retrieving and computing derived Virtual Ecosystem
#|     variables from Zarr output datasets.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|     - Virtual Ecosystem Zarr output dataset (.zarr)
#|     - Virtual Ecosystem configuration TOML file (.toml)
#|
#| output_files: None (returns R objects)
#|
#| package_dependencies:
#|     - pizzarr
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

get_derived_variables <- function(zarr_path, config_path) {
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
