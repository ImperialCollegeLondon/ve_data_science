box::use(tools/R/get_data_variables[get_data_variables])

#' Get derived variables
#'
#' Wrapper around \code{get_*()} to compute derived
#' variables from the input NetCDF object.
#'
#' @param nc NetCDF object or path accepted by \code{get_data_variables()}.
#' @return A named list with derived variables.
#'
#' @examples
#' \dontrun{
#'   nc <- tidync::tidync(
#'     "data/scenarios/maliau/maliau_2/out/all_continuous_data.nc"
#'   )
#'   get_derived_variables(nc)
#' }
#'
#' @export

get_derived_variables <- function(nc) {
  total_soil_c_per_volume <- get_total_soil_c_per_volume(nc)
  return(list(total_soil_c_per_volume = total_soil_c_per_volume))
}

#' Compute total soil carbon per volume
#'
#' Sum carbon pools from soil variables in a NetCDF object.
#'
#' @param nc NetCDF object or path accepted by \code{get_data_variables()}.
#' @return Array of total soil carbon per volume.
#'
#' @export

get_total_soil_c_per_volume <- function(nc) {
  input_varnames <- c(
    "soil_cnp_pool_lmwc",
    "soil_cnp_pool_maom",
    "soil_cnp_pool_necromass",
    "soil_cnp_pool_pom",
    "soil_c_pool_arbuscular_mycorrhiza",
    "soil_c_pool_bacteria",
    "soil_c_pool_ectomycorrhiza",
    "soil_c_pool_saprotrophic_fungi"
  )

  input_vars <- get_data_variables(nc, input_varnames)

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
