#| ---
#| title: Convert a list of input arrays to netCDF or Zarr for the Virtual Ecosystem
#|
#| description: |
#|     Generate input data in netCDF or Zarr format for the Virtual Ecosystem
#|     from a list of arrays. In principle these functions should work across
#|     modules.
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
#|     - pizzarr
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

#' Convert a list of input arrays to Zarr used by the Virtual Ecosystem
#'
#' Generate input data in Zarr format for the Virtual Ecosystem from a list
#' of arrays.
#'
#' @param array A *list* of arrays containing the input variables.
#' @param filename Path to the Zarr output store.
#' @param description Optional. A character string describing the data. If
#'   supplied, it will be stored as a global attribute named `description`.
#'
#' @returns A Zarr store written to disk as per `filename`.
#'
#' @export
#'
convert_array_to_zarr <- function(
  array,
  filename,
  description = NULL
) {
  # create a Zarr store
  zarr_store <- pizzarr::zarr_create_group(filename, zarr_format = 2L)
  # Note: currently this function stores the variables as outputs only
  #       because it is intended for mock unit tests only;
  #       in the future we will include options for inputs and init
  output_store <- zarr_store$create_group("outputs")

  # some dimension attributes
  dims <-
    lapply(array, dimnames) |>
    purrr::flatten() |>
    (\(x) split(x, names(x)))() |>
    purrr::map(~ unique(unlist(.x)))

  # fill the Zarr store with data variables
  for (var in names(array)) {
    var_store <- output_store$create_dataset(
      var,
      array[[var]],
      shape = dim(array[[var]])
    )
    # store dimension names as attributes
    # for Zarr V2 this is the only option
    dimension_names <- names(dimnames(array[[var]]))
    var_store$get_attrs()$set_item("_ARRAY_DIMENSIONS", dimension_names)
  }

  # fill the Zarr store with dimension variables
  for (i in seq_along(dims)) {
    output_store$create_dataset(
      names(dims)[i],
      dims[[i]],
      shape = length(dims[[i]]),
      dtype = "<U10"
    )
  }

  # add global attributes
  output_store$get_attrs()$set_item("description", description)
}
