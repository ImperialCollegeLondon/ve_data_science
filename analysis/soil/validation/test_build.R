library(dplyr)
library(arrow)
box::use(tools/R/R/valdb)

# Paths to the VE scenario simulation outputs
zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

# Read the validation database
db_path <- "data/derived/soil/validation/database"
validation_database <- open_dataset(db_path) |> collect()

# Combine the validation database with VE outputs
combined_database <-
  valdb$join_ve_outputs(validation_database, zarr_path, config_path)

# Write the combined database
combined_db_path <- "data/derived/soil/validation/database_combined"
combined_database |>
  group_by(dataset) |>
  write_dataset(combined_db_path, format = "parquet")
