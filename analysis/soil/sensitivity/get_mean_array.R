get_mean_array <- function(nc, ll_x, ll_y, ur_x, ur_y) {
  # convert netCDF to array
  # subsetting is optional; if the x and y bounds are set to the same of the
  # original data, then no subsetting is done
  dat_array <- subset_array(nc, ll_x, ll_y, ur_x, ur_y)

  # get the mean array for all state variables
  lapply(dat_array, function(var) {
    # collect dimension names and format them for the new mean array
    dim_names <- names(dimnames(var))

    # marginalise over any dimension(s) that are not x and y
    dim_to_marginalise <- which(!dim_names %in% c("x", "y"))

    dim_new <- dim(var)
    dim_new[-dim_to_marginalise] <- 1

    dimnames_new <- mapply(
      function(x, y) x[y],
      x = dimnames(var),
      y = lapply(dim_new, seq_len)
    )

    # calculate mean and assign the mean array the same dimension as the original
    mean_array <- apply(var, dim_to_marginalise, mean)
    mean_array <- array(mean_array, dim = dim_new, dimnames = dimnames_new)
    mean_array
  })
}
