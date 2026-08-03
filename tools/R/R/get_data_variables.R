#| ---
#| title: Retrieve (non-dimension) state variables from a Zarr dataset
#|
#| description: |
#|     Retrieve (non-dimension) state variables from a Virtual Ecosystem Zarr
#|     output dataset into a named list of arrays.
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
#|     - pizzarr
#|     - purrr
#|
#| usage_notes: See function documentation below.
#| ---

#' Retrieve (non-dimension) state variables from a Zarr dataset
#'
#' @param zarr_path Path to a Virtual Ecosystem Zarr output dataset.
#' @param variables Optional character vector of variable names to retrieve.
#'   If `NULL` (default), all non-dimension state variables are retrieved.
#'
#' @returns A named list of arrays for the requested non-dimension state
#'   variables. Names correspond to variable names.
#'
#' @examples
#' \dontrun{
#'   # Retrieve all variables
#'   all_vars <- get_data_variables("out/model_state.zarr")
#'
#'   # Retrieve specific variables
#'   subset_vars <- get_data_variables(
#'     "out/model_state.zarr",
#'     variables = c("air_temperature", "precipitation")
#'   )
#' }
#'
#' @export

get_data_variables <- function(zarr_path, variables = NULL) {
  # read Zarr outputs from VE
  outputs <- pizzarr::zarr_open(zarr_path)$get_item("outputs")

  # retrieve all non-dimension state variables
  vars <- outputs$get_store()$listdir("outputs")
  var_discard <- c(
    ".zattrs",
    ".zgroup",
    "x",
    "y",
    "cell_id",
    "element",
    "layers",
    "number",
    "pft",
    "spatial_ref",
    "time_index",
    "timestamp"
  )
  vars <- vars[vars %notin% var_discard]

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
    variables <- vars
  }

  # check that all variables have shape
  var_dims <- purrr::map_int(variables, \(var) {
    outputs$get_item(var)$get_ndim()
  })
  if (any(var_dims == 0)) {
    var_zero_dim <- variables[var_dims == 0]
    cli::cli_abort(
      "The following variables have zero dimension: {.val {var_zero_dim}}.
      Did you intend to remove them?"
    )
  }

  # extract each variable's array
  out <- purrr::map(
    variables,
    \(variable) {
      outputs$get_item(variable)$as.array()
    },
    .progress = TRUE
  )

  names(out) <- variables
  return(out)
}
