#| ---
#| title: Extract continuous state variables into long-format dataframe
#|
#| description: |
#|     Tidy up continuous state variables into a long-format dataframe.
#|     Currently this function is designed with the downstream visualisation
#|     of output from Virtual Ecosystem in mind.
#|
#| VE_module: All
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
#|     - tidyverse
#|     - tidync
#|
#| usage_notes: |
#|    See an example of use case in
#|    analysis/soil/sensitivity/visualise_continuous_data.R
#| ---

#' Extract continuous state variables into long-format dataframe
#'
#' Tidy up continuous state variables into a long-format dataframe. Currently
#' this function is designed with the downstream visualisation of output from
#' Virtual Ecosystem in mind.
#'
#' @param continuous Filename of the merged continuous data file.
#' @param variables A character string of state variables to extract.
#' @param initial Optional. Filename of the initial state data file. If this supplied, then the initial values are added to the tidy output.
#'
#' @returns A long-format dataframe of continuous state variables.

# libraries to add to @Import later
require(tidync)
require(tidyverse)

tidy_continuous_data <- function(continuous, variables, initial = NULL) {
  # load continuous data file
  cont <- tidync(continuous)

  # extract the index of spatial and temporal dimensions
  dims_cont <-
    list(space = "cell_id", time = "time_index") |>
    map(\(dim_name) {
      cont |> hyper_dims() |> filter(name == dim_name) |> pull(id)
    })
  # spatial coordinates to join by cell_id
  coords_cont <-
    cont |>
    activate(paste0("D", dims_cont$space)) |>
    hyper_tibble()
  # temporal coordinates to join by time_index
  time_cont <-
    cont |>
    activate(paste0("D", dims_cont$time)) |>
    hyper_tibble()

  # tidy, long-format version of the continuous data
  tidy_cont <-
    variables |>
    map(\(variable) {
      cont |>
        activate(variable) |>
        hyper_tibble() |>
        pivot_longer(
          cols = all_of(variable),
          names_to = "variable"
        ) |>
        # add spatial and temporal coordinates
        left_join(coords_cont, by = join_by(cell_id)) |>
        left_join(time_cont, by = join_by(time_index))
    }) |>
    list_c() |>
    mutate(time_index = as.numeric(time_index))

  # if initial data is requested, ditto the tidying process above and then
  # merge it with the continuous data;
  # the initial values are assigned a time_index of -1
  if (!is.null(initial)) {
    init <- tidync(initial)
    dims_init <-
      init |> hyper_dims() |> filter(name == "cell_id") |> pull(id)
    coords_init <-
      init |>
      activate(paste0("D", dims_init)) |>
      hyper_tibble() |>
      select(cell_id, x, y)

    tidy_init <-
      variables |>
      map(\(variable) {
        init |>
          activate(variable) |>
          hyper_tibble() |>
          pivot_longer(
            cols = all_of(variable),
            names_to = "variable"
          ) |>
          left_join(coords_init, by = join_by(cell_id))
      }) |>
      list_c() |>
      mutate(timestamp = -1, time_index = -1)

    # merge initial and continuous data
    tidy_cont <- bind_rows(tidy_init, tidy_cont)
  }

  return(tidy_cont)
}
