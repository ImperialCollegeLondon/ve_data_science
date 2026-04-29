require(tidync)
require(tidyverse)

tidy_continuous_data <- function(continuous, variables, initial = NULL) {
  cont <- tidync(continuous)
  dims_cont <-
    list(space = "cell_id", time = "time_index") |>
    map(\(dim_name) {
      cont |> hyper_dims() |> filter(name == dim_name) |> pull(id)
    })

  coords_cont <-
    cont |>
    activate(paste0("D", dims_cont$space)) |>
    hyper_tibble()

  time_cont <-
    cont |>
    activate(paste0("D", dims_cont$time)) |>
    hyper_tibble()

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
        left_join(coords_cont, by = join_by(cell_id)) |>
        left_join(time_cont, by = join_by(time_index))
    }) |>
    list_c() |>
    mutate(time_index = as.numeric(time_index))

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

    tidy_cont <- bind_rows(tidy_cont, tidy_init)
  }
  return(tidy_cont)
}
