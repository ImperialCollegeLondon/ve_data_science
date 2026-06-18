#| ---
#| title: Retrieve (non-dimension) state variables from a netCDF data
#|
#| description: |
#|     Retrieve (non-dimension) state variables from a netCDF data into a
#|     list of arrays for all non-dimension state variables, including
#|     each of their dimension names.
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
#|     - tidync
#|     - purrr
#|     - dplyr
#|
#| usage_notes: See function documentation below.
#| ---

#' Retrieve (non-dimension) state variables from a netCDF file
#'
#' @param tidync A tidync object from tidync(), which reads in data from
#'   a netCDF file.
#' @param variables Optional character vector of variable names to retrieve.
#'   If `NULL` (default), all non-dimension state variables are retrieved.
#'
#' @returns A list of arrays for all non-dimension state variables, including
#'   each of their dimension names. Names correspond to variable names.
#'
#' @examples
#' \dontrun{
#'   # Retrieve all variables
#'   nc <- tidync::tidync("data.nc")
#'   all_vars <- get_variables(nc)
#'
#'   # Retrieve specific variables
#'   subset_vars <- get_variables(nc, variables = c("temp", "precip"))
#' }
#'
#' @export

get_variables <- function(tidync, variables = NULL) {
  # retrieve all non-dimension state variables
  vars <-
    tidync$variable |>
    dplyr::filter(dim_coord == FALSE) |>
    dplyr::pull(name)

  # use all variables if none specified,
  # otherwise validate requested variables exist
  if (!is.null(variables)) {
    # check that all requested variables are present in the data
    missing_vars <- setdiff(variables, vars)
    if (length(missing_vars) > 0) {
      cli::cli_abort(
        "The following variables are not found: {.val {missing_vars}}"
      )
    }
  } else {
    # default to all available variables
    variables <- vars
  }

  # activate each variable and extract its array iteratively
  out <-
    variables |>
    purrr::map(\(var) {
      tidync |>
        tidync::activate(var) |>
        tidync::hyper_array(drop = FALSE) |>
        purrr::pluck(var)
    })
  names(out) <- variables
  return(out)
}
