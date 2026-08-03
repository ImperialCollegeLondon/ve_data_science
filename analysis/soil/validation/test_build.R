library(tidyverse)
library(reshape2)
library(arrow)
library(pizzarr)
box::use(tools/R/R/get_ve_variables[...])

db_path <- "data/derived/soil/validation/database"

validation_database <-
  open_dataset(db_path) |>
  collect()

vars <- unique(validation_database$var_canonical)


# Read VE outputs
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"
# outputs <- zarr_open(zarr_path)
# outputs_group <- outputs$get_item("outputs")

xy <-
  get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)

time <-
  get_data_variables(
    zarr_path,
    group = "outputs",
    variables = c("timestamp")
  ) |>
  melt() |>
  pivot_wider(names_from = L1, values_from = value)


vars_derived <- get_derived_variables(
  zarr_path,
  config_path,
  group = "outputs",
  variables = vars[-which(vars == "groundwater_storage")]
) |>
  melt() |>
  rename(var_canonical = L1) |>
  left_join(xy) |>
  left_join(time)
