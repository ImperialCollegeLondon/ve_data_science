#| ---
#| title: Build a combined animal validation database with VE outputs
#|
#| description: |
#|     This R script reads the animal validation database and joins it to
#|     Virtual Ecosystem simulation outputs for downstream validation workflows.
#|
#|     It currently targets the maliau_2 scenario output paths defined in this
#|     script and writes a grouped parquet dataset by source dataset.
#|
#| virtual_ecosystem_module: Animal
#|
#| author: Nicholas Wei Cheng Tan
#|
#| status: final
#|
#| input_files:
#|   - name: database
#|     path: data/derived/animal/validation/
#|     description: |
#|       Animal validation database used as the base table for joining VE outputs.
#|   - name: model_data.zarr
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       VE scenario output Zarr store providing model variables for joining.
#|   - name: compiled_configuration.toml
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       VE compiled configuration used to interpret scenario output metadata.
#|   - name: animal_cohort_data.csv
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       Animal cohort output used to calculate functional-group population density.
#|
#| output_files:
#|   - name: database_combined
#|     path: data/derived/animal/validation
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
library(pizzarr)
reticulate::py_require(c("pandas", "matplotlib"))
source("tools/R/R/valdb.R")
source("tools/R/R/get_ve_variables.R")

# Paths to the VE scenario simulation outputs
scenario_out <- "data/scenarios/maliau/maliau_2/out"
zarr_path <- file.path(scenario_out, "model_data.zarr")
config_path <- file.path(scenario_out, "compiled_configuration.toml")
cohort_data_path <- file.path(scenario_out, "animal_cohort_data.csv")

# Build the validation
db_path <- "data/derived/animal/validation/database"
build_validation_database(
  sources_dir = "data/derived/animal/validation/sources",
  db_path = db_path
)

# Read the validation database
validation_database <- open_dataset(db_path) |> collect()

# Combine the validation database with VE outputs, including FG density
combined_database <- join_ve_outputs(
  validation_database = validation_database,
  zarr_path = zarr_path,
  config_path = config_path,
  cohort_data_path = cohort_data_path
)

# Write the combined database
combined_db_path <- "data/derived/animal/validation/database_combined"
combined_database |>
  group_by(dataset) |>
  write_dataset(combined_db_path, format = "parquet")
