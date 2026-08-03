library(tidyverse)
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

vars_derived <- get_derived_variables(
  zarr_path,
  config_path,
  group = "outputs",
  variables = vars[-which(vars == "groundwater_storage")]
)
