library(tidyverse)
library(arrow)
library(pizzarr)

db_path <- "data/derived/soil/validation/database"

validation_database <-
  open_dataset(db_path) |>
  collect()

vars <- unique(validation_database$var_canonical)


# Read VE outputs
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
outputs <- zarr_open(zarr_path)
outputs_group <- outputs$get_item("outputs")

map(vars, \(var) {
  outputs_group$get_item(var)
})
