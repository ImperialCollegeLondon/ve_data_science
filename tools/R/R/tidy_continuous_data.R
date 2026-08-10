#| ---
#| title: Extract continuous state variables into long-format dataframe
#|
#| description: |
#|     Tidy up continuous state variables from a Virtual Ecosystem Zarr output
#|     dataset into a long-format tibble. Spatial (x, y) and temporal
#|     (timestamp) coordinates are joined onto each observation. Optionally,
#|     initial-state values can be prepended with a time_index of -1.
#|     The function is designed for use in downstream visualisation and
#|     sensitivity analysis workflows.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|     - Virtual Ecosystem Zarr output dataset (.zarr), passed via `path`
#|
#| output_files:
#|     - None (returns an R tibble)
#|
#| source_files:
#|     - name: get_ve_variables.R
#|       path: tools/R/R/get_ve_variables.R
#|       description: |
#|           Provides get_data_variables() used to read variables from the
#|           Zarr dataset.
#|
#| package_dependencies:
#|     - dplyr
#|     - tidyr
#|     - reshape2
#|
#| usage_notes: |
#|     See examples of use in:
#|       - analysis/soil/sensitivity/visualise_continuous_data.R
#|       - analysis/animal/continuous_states/small_temporal_variation.qmd
#| ---

box::use(tools/R/R/get_ve_variables[...])

#' Extract continuous state variables into long-format dataframe
#'
#' Reads selected state variables from a Virtual Ecosystem Zarr output dataset
#' and returns them as a long-format tibble with spatial (x, y) and temporal
#' (timestamp) coordinates joined onto each observation. Designed for use in
#' downstream visualisation and sensitivity analysis workflows.
#'
#' @param path Path to a Virtual Ecosystem Zarr output dataset.
#' @param variables Character vector of state variable names to extract.
#' @param initial Logical. If `TRUE`, initial-state values from the `"init"`
#'   group are prepended to the output with `time_index = -1` and
#'   `timestamp = -1`.
#'
#' @returns A long-format tibble with columns `variable`, `value`, `cell_id`,
#'   `x`, `y`, `time_index`, and `timestamp`.

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
