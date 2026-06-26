#' Get derived variables
#'
#' Wrapper around \code{get_*()} to compute derived
#' variables from the input NetCDF object.
#'
#' @param array Data arrays read from \code{tidync::tidync()}. See examples.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return A named list with derived variables.
#'
#' @examples
#' \dontrun{
#'   array <- tidync::tidync(
#'     "data/scenarios/maliau/maliau_2/out/all_continuous_data.nc"
#'   )
#'   config <- toml::read_toml(
#'     "data/scenarios/maliau/maliau_2/out/ve_full_model_configuration.toml"
#'   )
#'   get_derived_variables(array)
#' }
#'
#' @export

get_derived_variables <- function(array, config) {
  list(
    total_soil_c_per_volume = get_total_soil_c_per_volume(array),
    total_soil_c_per_mass = get_total_soil_c_per_mass(array, config),
    total_soil_c_per_area = get_total_soil_c_per_area(array, config),
    soil_np_pool_microbial = get_soil_np_pool_microbial(array, config),
    total_soil_n_per_volume = get_total_soil_n_per_volume(array, config),
    total_soil_n_per_mass = get_total_soil_n_per_mass(array, config),
    total_soil_n_per_area = get_total_soil_n_per_area(array, config),
    total_soil_p_per_volume = get_total_soil_p_per_volume(array, config),
    total_soil_p_per_mass = get_total_soil_p_per_mass(array, config),
    total_soil_p_per_area = get_total_soil_p_per_area(array, config)
  )
}

#' Compute total soil carbon per volume
#'
#' Sum carbon pools from soil variable arrays.
#'
#' @param array Data arrays read from \code{tidync::tidync()}. See examples.
#' @return Array of total soil carbon per volume.
#'
#' @export

get_total_soil_c_per_volume <- function(array) {
  # get the soil C variables
  input_vars <- get_data_variables(
    array,
    c(
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
    soil_cnp_pool_lmwc["C", , ] +
      soil_cnp_pool_maom["C", , ] +
      soil_cnp_pool_necromass["C", , ] +
      soil_cnp_pool_pom["C", , ] +
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
    cli::cli_alert_warning("Soil bulk density is not found in the config file.")
    cli::cli_alert_warning(
      "Assigning it the default value {bulk_density_soil} from VE."
    )
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
  soil_layer_depth <- config$core$constants$max_depth_of_microbial_activity
  volume_basis_data * soil_layer_depth
}


#' Calculate total soil carbon per mass
#'
#' Convert total soil carbon per volume to a mass basis.
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil carbon per mass.
#' @export

get_total_soil_c_per_mass <- function(array, config) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(array)
  convert_volume_to_mass_basis(total_soil_c_per_volume, config)
}


#' Calculate total soil carbon per area
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil carbon per area.
#' @export

get_total_soil_c_per_area <- function(array, config) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(array)
  convert_volume_to_area_basis(total_soil_c_per_volume, config)
}


#' Calculate soil nitrogen and phosphorus in microbial pools
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return List of arrays of nitrogen and phosphorus in the microbial pools.

get_soil_np_pool_microbial <- function(array, config) {
  # get the soil C in the microbial pools
  soil_c_microbial <- get_data_variables(
    array,
    c(
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
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per volume.
#' @export

get_total_soil_n_per_volume <- function(array, config) {
  # get the soil N variables
  input_vars <- get_data_variables(
    array,
    c(
      "soil_cnp_pool_lmwc",
      "soil_cnp_pool_maom",
      "soil_cnp_pool_necromass",
      "soil_cnp_pool_pom",
      "soil_n_pool_ammonium",
      "soil_n_pool_nitrate"
    )
  )

  # convert the microbial C to N
  soil_np_pool_microbial <- get_soil_np_pool_microbial(array, config)

  # summation
  with(
    input_vars,
    soil_cnp_pool_lmwc["N", , ] +
      soil_cnp_pool_maom["N", , ] +
      soil_cnp_pool_necromass["N", , ] +
      soil_cnp_pool_pom["N", , ] +
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
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per mass.
#' @export

get_total_soil_n_per_mass <- function(array, config) {
  total_soil_n_per_volume <- get_total_soil_n_per_volume(array, config)
  convert_volume_to_mass_basis(total_soil_n_per_volume, config)
}

#' Calculate total soil nitrogen per area
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil nitrogen per area.
#' @export

get_total_soil_n_per_area <- function(array, config) {
  total_soil_n_per_volume <- get_total_soil_n_per_volume(array, config)
  convert_volume_to_area_basis(total_soil_n_per_volume, config)
}

#' Compute total soil phosphorus per volume
#'
#' Sum phosphorus pools from soil variable arrays.
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per volume.
#' @export

get_total_soil_p_per_volume <- function(array, config) {
  # get the soil P variables
  input_vars <- get_data_variables(
    array,
    c(
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
  soil_np_pool_microbial <- get_soil_np_pool_microbial(array, config)

  # summation
  with(
    input_vars,
    soil_cnp_pool_lmwc["P", , ] +
      soil_cnp_pool_maom["P", , ] +
      soil_cnp_pool_necromass["P", , ] +
      soil_cnp_pool_pom["P", , ] +
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
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per mass.
#' @export

get_total_soil_p_per_mass <- function(array, config) {
  total_soil_p_per_volume <- get_total_soil_p_per_volume(array, config)
  convert_volume_to_mass_basis(total_soil_p_per_volume, config)
}

#' Calculate total soil phosphorus per area
#'
#' @param array Data arrays read from \code{tidync::tidync()}.
#' @param config A list of VE configuration read from the exported full
#' configuration TOML file.
#' @return Array of total soil phosphorus per area.
#' @export

get_total_soil_p_per_area <- function(array, config) {
  total_soil_p_per_volume <- get_total_soil_p_per_volume(array, config)
  convert_volume_to_area_basis(total_soil_p_per_volume, config)
}
