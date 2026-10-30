library(tidyverse)
library(rEDM)

source("tools/R/R/valdb_build.R")
source("tools/R/R/get_ve_variables.R")

ve_data_vars <- build_data_variables_table(variables_derived = NULL) |> names()

outputs <- get_data_variables(
  "data/scenarios/maliau/maliau_2/out/model_data.zarr",
  "outputs"
)

outputs_df <-
  outputs[intersect(names(outputs), ve_data_vars)] |>
  reshape2::melt() |>
  # select a single cell for testing
  filter(cell_id == 0) |>
  unite(
    "var_fullname",
    L1,
    pft,
    element,
    layers,
    groundwater_layers,
    na.rm = TRUE,
    remove = TRUE
  )

# NEED TO LOG-TRANSFORM???
# I will scale them

test_df <-
  outputs_df |>
  filter(str_detect(var_fullname, "soil")) |>
  pivot_wider(names_from = var_fullname, values_from = value) |>
  select(where(~ length(unique(.x)) > 1L)) |>
  mutate(across(-time_index, ~ as.numeric(scale(.x))))

targets <- paste(names(test_df[, -1]), collapse = " ")

rho_E <- EmbedDimension(
  dataFrame = test_df,
  lib = "1 80",
  pred = "81 132",
  columns = targets,
  target = targets,
  showPlot = TRUE
)

smap_test <- SMap(
  dataFrame = test_df,
  lib = "1 100",
  pred = "101 132",
  columns = targets,
  target = targets,
  E = 3,
  embedded = TRUE
)

matplot(smap_test$coefficients[-1, ])
