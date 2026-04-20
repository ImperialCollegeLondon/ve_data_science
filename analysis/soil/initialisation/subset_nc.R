#' Subset netCDF data used by the Virtual Ecosystem
#'
#' Subset netCDF input data using latitudinal and longitudinal limits.
#'
#' @param nc Path and filename to the netCDF file to be subsetted.
#' @param ll_x Lower limit of the x or longitudinal dimension.
#' @param ll_y Lower limit of the y or longitudinal dimension.
#' @param ur_x Upper limit of the x or longitudinal dimension.
#' @param ur_y Upper limit of the y or longitudinal dimension.
#' @param ... Additional arguments passed to convert_array_to_nc()
#'
#' @returns A subset netCDF file written to disk as per filename when close.nc is TRUE.

subset_nc <- function(nc, ll_x, ll_y, ur_x, ur_y, ...) {
  # filter data to region of interest
  subset_array(nc, ll_x, ll_y, ur_x, ur_y)

  # convert arrays back to netCDF
  convert_array_to_nc(array = data_subset_array, ...)
}

subset_array <- function(nc, ll_x, ll_y, ur_x, ur_y) {
  # filter data to region of interest
  data_subset <-
    tidync(nc) |>
    hyper_filter(
      x = x > ll_x & x < ur_x,
      y = y > ll_y & y < ur_y
    )

  # a list of non-variables to be excluded
  # these are dimensions
  non_vars <- c(
    "x",
    "y",
    "element",
    "cell_id",
    "pft",
    "time_index",
    "valid_time",
    "expver"
  )
  vars <- setdiff(data_subset$variable$name, non_vars)

  # collect input variables into a list of arrays with named dimensions
  data_subset_array <- vector("list", length(vars))
  names(data_subset_array) <- vars
  for (var in vars) {
    data_subset_array[[var]] <-
      data_subset |>
      activate(var) |>
      hyper_array(drop = FALSE)
    data_subset_array[[var]] <- data_subset_array[[var]][[1]]
  }
}
