#| ---
#| title: Build a combined validation database with VE outputs
#|
#| description: |
#|     This R script defines a function that reads a validation database and
#|     joins it to Virtual Ecosystem simulation outputs for downstream
#|     validation workflows.
#|
#|     The module and scenario must be supplied explicitly. Standard repository
#|     paths are derived from them, but complete paths can be supplied instead.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai & Nicholas Wei Cheng Tan
#|
#| status: wip
#|
#| input_files:
#|   - name: database
#|     path: data/derived/<module>/validation/
#|     description: |
#|       Validation database used as the base table for joining VE outputs.
#|   - name: model_data.zarr
#|     path: data/scenarios/<scenario_group>/<scenario_name>/out/
#|     description: |
#|       VE scenario output Zarr store providing model variables for joining.
#|   - name: compiled_configuration.toml
#|     path: data/scenarios/<scenario_group>/<scenario_name>/out/
#|     description: |
#|       VE compiled configuration used to interpret scenario output metadata.
#|
#| output_files:
#|   - name: database_combined
#|     path: data/derived/<module>/validation
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
#|     From the repository root, source the script and call the function:
#|       source("analysis/soil/validation/combine_validation_database.R")
#|       combine_validation_database(
#|         module_name = "soil",
#|         scenario_group = "maliau",
#|         scenario_name = "maliau_2"
#|       )
#|
#|     Complete paths can be supplied when data do not use the standard layout:
#|       combine_validation_database(
#|         module_name = "litter",
#|         scenario_group = "maliau",
#|         scenario_name = "maliau_2",
#|         zarr_path = "/path/to/model_data.zarr",
#|         config_path =
#|           "/path/to/compiled_configuration.toml",
#|         db_path = "/path/to/database",
#|         combined_db_path = "/path/to/output"
#|       )
#| ---

library(dplyr)
library(arrow)
box::use(tools/R/R/valdb)

#' Build a combined validation database with VE outputs
#'
#' @param module_name Virtual Ecosystem module name used in validation paths.
#' @param scenario_group Scenario group used in VE output paths.
#' @param scenario_name Scenario name used in VE output paths.
#' @param zarr_path Optional complete path to the VE output Zarr store.
#' @param config_path Optional complete path to the compiled VE configuration.
#' @param db_path Optional complete path to the validation database.
#' @param combined_db_path Optional complete path for the combined database.
#'
#' @returns Invisibly, the path to the combined database.
combine_validation_database <- function(
  module_name,
  scenario_group,
  scenario_name,
  zarr_path = NULL,
  config_path = NULL,
  db_path = NULL,
  combined_db_path = NULL
) {
  validation_root <- here::here(
    "data",
    "derived",
    module_name,
    "validation"
  )
  scenario_out_dir <- here::here(
    "data",
    "scenarios",
    scenario_group,
    scenario_name,
    "out"
  )

  if (is.null(zarr_path)) {
    zarr_path <- file.path(scenario_out_dir, "model_data.zarr")
  }
  if (is.null(config_path)) {
    config_path <- file.path(
      scenario_out_dir,
      "compiled_configuration.toml"
    )
  }
  if (is.null(db_path)) {
    db_path <- file.path(validation_root, "database")
  }
  if (is.null(combined_db_path)) {
    combined_db_path <- file.path(validation_root, "database_combined")
  }

  validation_database <- open_dataset(db_path) |> collect()
  combined_database <- valdb$join_ve_outputs(
    validation_database,
    zarr_path,
    config_path
  )

  combined_database |>
    group_by(dataset) |>
    write_dataset(combined_db_path, format = "parquet")

  invisible(combined_db_path)
}
