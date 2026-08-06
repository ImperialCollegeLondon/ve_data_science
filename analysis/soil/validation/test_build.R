library(arrow)
box::use(tools/R/R/get_ve_variables[...])
box::use(tools/R/R/valdb)


# Usage -------------------------------------------------------------------

zarr_path <- "data/scenarios/maliau/maliau_2/out/model_data.zarr"
config_path <- "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"

db_path <- "data/derived/soil/validation/database"
validation_database <- open_dataset(db_path) |> collect()

valdb$join_ve_outputs(validation_database, zarr_path, config_path)
