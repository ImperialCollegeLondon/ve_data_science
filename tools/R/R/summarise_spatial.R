#' Marginalise variable arrays over space
#'
#' Apply a function to spatially aggregate a variable array. In the context of
#' the Virtual Ecosystem, this usually means marginalising a variable over the
#' x and y coordinates, or over cell_id's.
#'
#' @param arrays A list of variable arrays, usually assembled with
#'   get_all_variables()
#' @param FUN The function to be applied, potentially one of the acceptable
#'   function by base::apply()
#'
#' @returns A spatially-aggregated array with the same dimnames as the input
#'   array. The marginalised spatial dimensions are of length one, and they are
#'   arbitrarily assigned the first value of each spatial dimension to be
#'   compatible with convert_array_to_nc() or the data requirement of `ve_run`,
#'   as a quick-and-dirty solution.

summarise_spatial <- function(arrays, FUN) {
  arrays |>
    map(\(var) {
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
        array_summarised <- apply(var, dim_to_marginalise, FUN)
        array_summarised <- array(
          array_summarised,
          dim = dim_new,
          dimnames = dimnames_new
        )
      } else {
        # when there is no other dimension to marginalise across, the output
        # should simply be a scalar array
        dimnames_new <- lapply(dimnames(var), function(names) names[1])
        dim_new <- rep(1, length(dimnames_new))
        array_summarised <- array(
          FUN(var),
          dim = dim_new,
          dimnames = dimnames_new
        )
      }

      return(array_summarised)
    })
}
