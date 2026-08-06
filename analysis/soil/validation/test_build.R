#| ---
#| title: Build a combined soil validation database with VE outputs
#|
#| description: |
#|     This R script reads the soil validation database and joins it to Virtual
#|     Ecosystem simulation outputs for downstream validation workflows.
#|
#|     It currently targets the maliau_2 scenario output paths defined in this
#|     script and writes a grouped parquet dataset by source dataset.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: database
#|     path: data/derived/soil/validation/
#|     description: |
#|       Soil validation database used as the base table for joining VE outputs.
#|   - name: model_data.zarr
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       VE scenario output Zarr store providing model variables for joining.
#|   - name: compiled_configuration.toml
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       VE compiled configuration used to interpret scenario output metadata.
#|
#| output_files:
#|   - name: database_combined
#|     path: data/derived/soil/validation
#|     description: |
#|       Validation database augmented with VE outputs and written as parquet,
#|       partitioned by dataset.
#|
#| source_files:
#|   - name: valdb.R
#|     path: tools/R/R/
#|     description: |
#|       Provides join_ve_outputs() used to combine validation and VE data.
#|
#| package_dependencies:
#|   - dplyr
#|   - arrow
#|   - box
#|
#| usage_notes: |
#|     Update scenario and database paths when running against other scenarios
#|     or validation databases.
#| ---

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
