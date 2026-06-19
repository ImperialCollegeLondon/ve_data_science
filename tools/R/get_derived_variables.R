box::use(tools/R/get_data_variables[get_data_variables])

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

get_total_soil_c_per_volume <- function(nc) {
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


get_total_soil_c_per_mass <- function(array) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(array)
  bulk_density <- 
}
