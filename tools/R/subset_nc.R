#| ---
#| title: Subset netCDF data used by the Virtual Ecosystem
#|
#| description: |
#|     Subset netCDF input data using latitudinal and longitudinal limits.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|     - RNetCDF
#|     - purrr
#|
#| usage_notes: See function documentation below.
#| ---

#' Subset netCDF data used by the Virtual Ecosystem
#'
#' Subset netCDF input data using latitudinal and longitudinal limits.
#'
#' @param nc Path and filename to the netCDF file to be subsetted.
#' @param ll_x Lower limit of the x or longitudinal dimension.
#' @param ll_y Lower limit of the y or longitudinal dimension.
#' @param ur_x Upper limit of the x or longitudinal dimension.
#' @param ur_y Upper limit of the y or longitudinal dimension.
#' @param cell_id
#' @param ... Additional arguments passed to convert_array_to_nc()
#'
#' @returns A subset netCDF file written to disk as per filename when close.nc is TRUE.

subset_nc <- function(
  nc,
  ll_x = NULL,
  ll_y = NULL,
  ur_x = NULL,
  ur_y = NULL,
  cell_ids = NULL,
  ...
) {
  # filter data to region of interest
  data_subset_array <- subset_array(nc, ll_x, ll_y, ur_x, ur_y, cell_ids)

  # convert arrays back to netCDF
  convert_array_to_nc(array = data_subset_array, ...)
}

subset_array <- function(
  nc,
  ll_x = NULL,
  ll_y = NULL,
  ur_x = NULL,
  ur_y = NULL,
  cell_ids = NULL
) {
  # check that either [ll_x, ll_y, ur_x, ur_y] OR cell_ids is supplied, not both
  stopifnot(
    "Please only specify either [ll_x, ll_y, ur_x, ur_y] OR cell_ids." = (all(c(
      is.null(ll_x),
      is.null(ll_y),
      is.null(ur_x),
      is.null(ur_y)
    )) &&
      !is.null(cell_ids)) ||
      (all(c(
        !is.null(ll_x),
        !is.null(ll_y),
        !is.null(ur_x),
        !is.null(ur_y)
      )) &&
        is.null(cell_ids))
  )

  # filter data to region of interest
  tidync(nc) |>
    hyper_filter(
      x = x > ll_x & x < ur_x,
      y = y > ll_y & y < ur_y
    ) |>
    # Retrieve all variables from the subsetted data
    get_all_variables()
}
