#' Convert netCDF input data from cell_id to xy coordinates
#'
#' Converts a netCDF input data in the Virtual Ecosystem with cell_id
#' coordinates to one with x and y coordinates.
#'
#' @param nc Path and filename to the netCDF file to be converted.
#' @param x Numeric vector of x coordinates.
#' @param y Numeric vector of y coordinates.
#' @param filename Output path to save the converted netCDF.
#' @param return Logical. Whether to return the converted object.
#'
#' @returns An array of converted input data.

cell_id_to_xy <- function(nc, x, y, filename = NULL, return = FALSE) {
  # read netCDF based on cell_id
  in_dat <- tidync(nc)

  # check that x and y has compatible length with cell_id
  n_cell_id <- in_dat$dimension$length[in_dat$dimension$name == "cell_id"]
  stopifnot(
    "The lengths of x and y must multiply to be the length of cell_id" = length(
      x
    ) *
      length(y) ==
      n_cell_id
  )

  # list variables associated with the cell_id dimension
  vars_with_cell_id <-
    in_dat$grid |>
    unnest(variables) |>
    filter(str_detect(grid, "D0"), variable != "cell_id") |>
    pull(variable)

  # convert to xy-based data arrays
  out_dat <-
    lapply(vars_with_cell_id, function(var) {
      array <-
        in_dat |>
        activate(var) |>
        hyper_array()
      array <- array[[1]]
      non_cell_id_dim <- setdiff(names(dimnames(array)), "cell_id")
      non_cell_id_dim_size <- sapply(dimnames(array)[non_cell_id_dim], length)
      xy_dimnames <- list(x = x, y = y)
      nx <- length(x)
      ny <- length(y)
      # separate array restructuring depending on whether the variable has
      # cell_id as the only dimension, or if there are other dimensions
      # (e.g., pft)
      if (length(non_cell_id_dim) > 0) {
        array(
          array,
          c(non_cell_id_dim_size, nx, ny),
          dimnames = c(dimnames(array)[non_cell_id_dim], xy_dimnames)
        )
      } else {
        matrix(array, nx, ny, dimnames = xy_dimnames)
      }
    })
  # put names back to the list of arrays to work with convert_array_to_nc()
  names(out_dat) <- vars_with_cell_id

  # write arrays to netCDF if filename is supplied
  if (!is.null(filename)) {
    convert_array_to_nc(out_dat, filename = filename)
  }

  # return object if requested
  if (return) out_dat
}
