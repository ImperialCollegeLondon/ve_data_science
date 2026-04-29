library(tidyverse)
library(tidync)

tidy_continuous_data <- function(nc, variables) {
  cont <- tidync::tidync(nc)
  cont_dims <- cont |> tidync::hyper_dims()
  D_space <- cont_dims |> dplyr::filter(name == "cell_id") |> dplyr::pull(id)
  D_time <- cont_dims |> dplyr::filter(name == "time_index") |> dplyr::pull(id)

  coords <-
    cont |>
    tidync::activate(paste0("D", D_space)) |>
    tidync::hyper_tibble()

  time <-
    cont |>
    tidync::activate(paste0("D", D_time)) |>
    tidync::hyper_tibble()

  variables |>
    purrr::map(\(variable) {
      cont |>
        tidync::activate(variable) |>
        tidync::hyper_tibble() |>
        tidyr::pivot_longer(
          cols = tidyselect::all_of(variable),
          names_to = "variable"
        ) |>
        dplyr::left_join(coords, by = dplyr::join_by(cell_id)) |>
        dplyr::left_join(time, by = dplyr::join_by(time_index))
    }) |>
    purrr::list_c()
}

df_long <-
  tidy_continuous_data(
    "data/scenarios/maliau/maliau_2/out/all_continuous_data.nc",
    c("soil_cnp_pool_pom", "soil_cnp_pool_maom")
  )


init <-
  tidync("data/scenarios/maliau/maliau_2/out/initial_state.nc")

activate(init, "D1") |> hyper_tibble()


ggplot(df_long) +
  facet_grid(variable ~ element, scales = "free_y") +
  geom_line(aes(timestamp, value, group = cell_id), alpha = 0.4)
