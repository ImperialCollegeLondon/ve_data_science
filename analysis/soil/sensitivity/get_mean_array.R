get_mean_array <- function(nc, ...) {
  # convert netCDF to array
  # subsetting is optional; if the x and y bounds, or cell_id, are set to the
  # same as the original data, then no subsetting is done
  dat_array <- subset_array(nc, ...)

  # get the mean array for all state variables
  lapply(dat_array, function(var) {
    # collect dimension names and format them for the new mean array
    dim_names <- names(dimnames(var))

    # marginalise over any dimension(s) that are not x, y or cell_id
    dim_to_marginalise <- which(!dim_names %in% c("x", "y", "cell_id"))

    # separate attribute collection when there is vs. is not any dimension
    # to marginalise across
    if (length(dim_to_marginalise) > 0) {
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
    } else {
      # when there is no other dimension to marginalise across, the output
      # should simply be a scalar array
      dimnames_new <- lapply(dimnames(var), function(names) names[1])
      mean_array <- array(mean(var), dim = 1, dimnames = dimnames_new)
    }

    return(mean_array)
  })
}
