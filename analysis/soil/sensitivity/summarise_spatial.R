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
