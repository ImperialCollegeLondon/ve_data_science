#| ---
#| title: Retrieve all (non-dimension) state variables from a netCDF data
#|
#| description: |
#|     Retrieve all (non-dimension) state variables from a netCDF data into a
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
#|
#| usage_notes: See function documentation below.
#| ---

#' Retrieve all (non-dimension) state variables from a netCDF data
#'
#' @param tidync A tidync object from tidync::tidync(), which reads in data from
#'   a netCDF file.
#'
#' @returns A list of arrays for all non-dimension state variables, including
#'   each of their dimension names.

get_all_variables <- function(tidync) {
  # retrive all non-dimension state variables
  vars <- tidync$variable |> filter(dim_coord == FALSE) |> pull(name)
  # activate each variable and extract its array iteratively
  out <- vars |>
    map(\(var) {
      tidync |>
        activate(var) |>
        hyper_array(drop = FALSE) |>
        pluck(var)
    })
  names(out) <- vars
  return(out)
}
