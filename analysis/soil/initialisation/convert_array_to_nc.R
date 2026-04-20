convert_array_to_nc <- function(
  array,
  filename,
  description = NULL,
  close.nc = TRUE
) {
  # create netCDF file
  ncout <- create.nc(filename, format = "netcdf4")

  # some dimension attributes
  dims <-
    lapply(array, dimnames) %>%
    flatten() %>%
    {
      split(., names(.))
    } %>%
    map(~ unique(unlist(.x)))

  # define dimensions
  for (d in names(dims)) {
    dim_var <- dims[[d]]
    dim.def.nc(ncout, d, length(dim_var))
    # auto-guess the type of variable based on whether any of the element is NA
    # when converted to numeric
    if (suppressWarnings(any(is.na(as.numeric(dim_var))))) {
      # String type dimension(s)
      var.def.nc(ncout, d, "NC_STRING", d)
      var.put.nc(ncout, d, dim_var)
    } else {
      # Numeric type dimension(s)
      var.def.nc(ncout, d, "NC_FLOAT", d)
      var.put.nc(ncout, d, as.numeric(dim_var))
    }
  }

  # define and put variables
  for (var in names(array)) {
    var.def.nc(ncout, var, "NC_DOUBLE", names(dimnames(array[[var]])))
    var.put.nc(ncout, var, array[[var]])
  }

  # add global attributes
  if (!is.null(description)) {
    att.put.nc(ncout, "NC_GLOBAL", "description", "NC_CHAR", description)
  }

  # close the file if requested, writing data to disk
  # otherwise, write object to environment
  if (close.nc) {
    close.nc(ncout)
  } else {
    ncout
  }
}
