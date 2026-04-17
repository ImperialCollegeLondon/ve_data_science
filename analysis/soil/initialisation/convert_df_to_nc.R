#' Convert input dataframe to netCDF used by the Virtual Ecosystem
#'
#' Generate input data in netCDF format for the Virtual Ecosystem from a
#' dataframe object. Currently the function only works specifically for the
#' soil and litter modules due to dimensional differences of other modules'
#' input data.
#'
#' @param data Dataframe containing the input variables.
#' @param filename Filename of the netCDF output.
#' @param x A numeric vector of the x dimension.
#' @param y A numeric vector of the y dimension.
#' @param element A character vector of the element dimension. Currently it
#'   defaults to c("C", "N", "P") and it probably does not make any sense to
#'   modify it.
#' @param variables A character vector of variable names, which need to be the
#'   same as the variable listed in Virtual Ecosystem.
#' @param units A character vector of measurement unit of the variables, needs
#'   to be in the same order and length as `variables`
#' @param description Optional. A character string describing the data. If
#'   this is supplied, it will be used in the description field in the global
#'   attribute of the output netCDF file.
#'
#' @returns A netCDF file written to disk as per filename.
#'
#' @export

convert_df_to_nc <- function(
  data,
  filename,
  x,
  y,
  element = c("C", "N", "P"),
  variables,
  units,
  description = NULL
) {
  # create netCDF file
  ncout <- create.nc(filename, format = "netcdf4")

  # some dimension attributes
  # length of x
  n_x <- length(x)
  # length of y
  n_y <- length(y)
  # length of element
  n_element <- length(element)

  # define dimensions
  dim.def.nc(ncout, "x", n_x)
  dim.def.nc(ncout, "y", n_y)
  dim.def.nc(ncout, "element", n_element)
  var.def.nc(ncout, "x", "NC_FLOAT", "x")
  var.def.nc(ncout, "y", "NC_FLOAT", "y")
  var.def.nc(ncout, "element", "NC_STRING", "element")
  att.put.nc(ncout, "x", "units", "NC_CHAR", "m")
  att.put.nc(ncout, "y", "units", "NC_CHAR", "m")
  var.put.nc(ncout, "x", x)
  var.put.nc(ncout, "y", y)
  var.put.nc(ncout, "element", element)

  # define and put variables
  # raw data from data.frame are converted to array before being put into netCDF
  # note that I am explicitly using rev() to reverse the order of the element
  # dimension here in R so in Python it is ordered in the 'right' way
  for (i in seq_along(variables)) {
    if (str_detect(variables[i], "_cnp")) {
      var.def.nc(ncout, variables[i], "NC_DOUBLE", rev(c("x", "y", "element")))
      triplet_tmp <- do.call(rbind, data[[variables[i]]])
      array_tmp <- array(triplet_tmp, dim = rev(c(n_x, n_y, n_element)))
    } else {
      var.def.nc(ncout, variables[i], "NC_DOUBLE", rev(c("x", "y")))
      array_tmp <- array(data[[variables[i]]], dim = rev(c(n_x, n_y)))
    }
    # put variables into netCDF
    var.put.nc(ncout, variables[i], array_tmp)
    # add units
    # more metadata can be added here
    att.put.nc(ncout, variables[i], "units", "NC_CHAR", units[i])
  }

  # add global attributes; currently only the description field
  if (!is.null(description)) {
    att.put.nc(ncout, "NC_GLOBAL", "description", "NC_CHAR", description)
  }

  # close the file, writing data to disk
  close.nc(ncout)
}
