#' Get derived variables
#'
#' Wrapper around \code{get_*()} to compute derived
#' variables from the input NetCDF object.
#'
#' @param array Data arrays read from \code{tidync::tidync()}. See examples.
#' @return A named list with derived variables.
#'
#' @examples
#' \dontrun{
#'   array <- tidync::tidync(
#'     "data/scenarios/maliau/maliau_2/out/all_continuous_data.nc"
#'   )
#'   get_derived_variables(array)
#' }
#'
#' @export

get_derived_variables <- function(array) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(array)
  return(list(total_soil_c_per_volume = total_soil_c_per_volume))
}

#' Compute total soil carbon per volume
#'
#' Sum carbon pools from soil variables in a NetCDF object.
#'
#' @param array Data arrays read from \code{tidync::tidync()}. See examples.
#' @return Array of total soil carbon per volume.
#'
#' @export

get_total_soil_c_per_volume <- function(array) {
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


configs <- toml::read_toml(
  "data/scenarios/maliau/maliau_2/out/ve_full_model_configuration.toml"
)

get_total_soil_c_per_mass <- function(array, config) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(array)

  # retrieve bulk density from full configurations, but it won't be exported
  # unless the abiotic model is used. In the case of abiotic_simple, for
  # example, it will return NULL, so we overwrite it manually with a hard-coded
  # default value in VE; this is meant to be temporary and is subjected to
  # discussion
  bulk_density_soil <- configs$abiotic$constants$bulk_density_soil
  if (is.null(bulk_density_soil)) {
    bulk_density_soil <- 1175.0
    cli::cli_alert_warning("Soil bulk density is not found in the config file.")
    cli::cli_alert_warning(
      "Assigning it the default value {bulk_density_soil} from VE."
    )
  }

  # convert nutrient per volume to nutrient per mass
  total_soil_c_per_volume / bulk_density_soil
}
