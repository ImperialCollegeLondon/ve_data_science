#| ---
#| title: Convert a list of input arrays to netCDF used by the Virtual Ecosystem
#|
#| description: |
#|     Generate input data in netCDF format for the Virtual Ecosystem from a list
#|     of arrays. In principle this function should work across modules.
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

#' Convert a list of input arrays to netCDF used by the Virtual Ecosystem
#'
#' Generate input data in netCDF format for the Virtual Ecosystem from a list
#' of arrays. In principle this function should work across modules.
#'
#' @param array A *list* of arrays containing the input variables.
#' @param filename Filename of the netCDF output.
#' @param description Optional. A character string describing the data. If
#'   this is supplied, it will be used in the description field in the global
#'   attribute of the output netCDF file.
#' @param close.nc Logical. Whether to close the netCDF connection. Defaults to
#'   TRUE. Set to FALSE to add additional data manually before closing the
#'   connection.
#'
#' @returns A netCDF file written to disk as per filename when close.nc is TRUE.
#'
#' @export

convert_array_to_nc <- function(
  array,
  filename,
  description = NULL,
  close.nc = TRUE
) {
  # create netCDF file
  ncout <- RNetCDF::create.nc(filename, format = "netcdf4")

  # some dimension attributes
  dims <-
    lapply(array, dimnames) |>
    purrr::flatten() |>
    (\(x) split(x, names(x)))() |>
    purrr::map(~ unique(unlist(.x)))

  # define dimensions
  for (d in names(dims)) {
    dim_var <- dims[[d]]
    RNetCDF::dim.def.nc(ncout, d, length(dim_var))
    # auto-guess the type of variable based on whether any of the element is NA
    # when converted to numeric
    if (suppressWarnings(any(is.na(as.numeric(dim_var))))) {
      # String type dimension(s)
      RNetCDF::var.def.nc(ncout, d, "NC_STRING", d)
      RNetCDF::var.put.nc(ncout, d, dim_var)
    } else {
      # Numeric type dimension(s)
      RNetCDF::var.def.nc(ncout, d, "NC_FLOAT", d)
      RNetCDF::var.put.nc(ncout, d, as.numeric(dim_var))
    }
  }

  # define and put variables
  for (var in names(array)) {
    RNetCDF::var.def.nc(ncout, var, "NC_DOUBLE", names(dimnames(array[[var]])))
    RNetCDF::var.put.nc(ncout, var, array[[var]])
  }

  # add global attributes
  if (!is.null(description)) {
    RNetCDF::att.put.nc(
      ncout,
      "NC_GLOBAL",
      "description",
      "NC_CHAR",
      description
    )
  }

  # close the file if requested, writing data to disk
  # otherwise, write object to environment
  if (close.nc) {
    RNetCDF::close.nc(ncout)
  } else {
    ncout
  }
}
