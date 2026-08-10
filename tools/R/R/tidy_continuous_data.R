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

box::use(tools/R/R/get_ve_variables[...])

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

tidy_continuous_data <- function(path, variables, initial = FALSE) {
  # load continuous data file
  outputs <- get_data_variables(path, group = "outputs", variables)

  # spatial coordinates to join by cell_id
  xy <-
    get_data_variables(path, group = "outputs", variables = c("x", "y")) |>
    reshape2::melt() |>
    pivot_wider(names_from = L1)
  # temporal coordinates to join by time_index
  timestamp <-
    get_data_variables(path, group = "outputs", variables = "timestamp") |>
    reshape2::melt() |>
    pivot_wider(names_from = L1)

  # tidy, long-format version of the continuous data
  tidy_cont <-
    outputs |>
    reshape2::melt() |>
    left_join(xy, by = join_by(cell_id)) |>
    left_join(timestamp, by = join_by(time_index)) |>
    mutate(time_index = as.numeric(time_index))

  # if initial data is requested, ditto the tidying process above and then
  # merge it with the continuous data;
  # the initial values are assigned a time_index of -1
  if (initial) {
    init <- get_data_variables(path, group = "init", variables)

    tidy_init <-
      init |>
      reshape2::melt() |>
      left_join(xy, by = join_by(cell_id)) |>
      mutate(timestamp = -1, time_index = -1)

    # merge initial and continuous data
    tidy_cont <- bind_rows(tidy_init, tidy_cont)
  }

  # finalise output
  tidy_cont |> rename(variable = L1) |> as_tibble()
}
