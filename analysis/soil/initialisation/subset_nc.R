subset_nc <- function(nc, ll_x, ll_y, ur_x, ur_y, ...) {
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

  # convert arrays back to netCDF
  convert_array_to_nc(array = data_subset_array, ...)
}
