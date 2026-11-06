library(tidyverse)
source("tools/R/R/build_config.R")

project_root <- here::here()
grid_definition_path <- file.path(
  project_root,
  "data/derived/site/maliau/maliau_grid_definition.toml"
)
plant_constants_path <- file.path(
  project_root,
  "data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv"
)
config_dir <- file.path(
  project_root,
  "data/sensitivity/soil_litter_inputs/config"
)

required_inputs <- c(grid_definition_path, plant_constants_path)
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs) > 0) {
  stop(sprintf(
    "Required input file(s) do not exist: %s",
    paste(missing_inputs, collapse = ", ")
  ))
}

maliau_core <-
  toml::read_toml(grid_definition_path) |>
  pluck("Scenario", "maliau_2", "core")

variable_groups <- build_variable_groups(
  plants_path = "../data/plant_input_data_maliau_2_mean.nc",
  climate_path = "../data/era5_maliau_10x10_2010_2020_mean.nc",
  elevation_path = "../data/elevation_maliau_10x10_mean.nc",
  soil_path = "$SOIL_LITTER_DATA",
  litter_path = "$SOIL_LITTER_DATA"
)

core_grid <-
  maliau_core$grid |>
  discard_at("grid_type") |>
  list_modify(cell_nx = 1, cell_ny = 1)

plants <- list(
  cohort_data_path = "../data/cohort_data_1_cm_maliau_2.csv",
  pft_definitions_path = "../data/plant_pft_definitions_maliau_2.csv",
  constants = read_csv(plant_constants_path, show_col_types = FALSE) |>
    slice(1) |>
    as.list()
)

animal <- list(
  functional_group_definitions_path = "../data/animal_functional_groups_Maliau_level5.csv",
  cohort_data_export = list(enabled = FALSE)
)

config_lines <- c(
  render_comment("Core settings"),
  render_module("core"),
  render_table("core.grid", core_grid),
  render_table("core.timing", maliau_core$timing),
  render_array_tables(
    "core.data.variable",
    variable_groups$abiotic_simple
  ),
  render_module("abiotic_simple"),
  render_array_tables("core.data.variable", variable_groups$hydrology),
  render_module("hydrology"),
  render_module("animal", animal),
  render_table("animal.cohort_data_export", animal$cohort_data_export),
  render_module("plants", plants),
  render_array_tables("core.data.variable", variable_groups$plants),
  render_table("plants.constants", plants$constants),
  render_module("soil"),
  render_array_tables("core.data.variable", variable_groups$soil),
  render_module("litter"),
  render_array_tables("core.data.variable", variable_groups$litter)
)

build_config(config_lines, config_dir, "config.toml")

if (!file.exists(file.path(config_dir, "config.toml"))) {
  stop("Compiled Virtual Ecosystem config was not created.")
}
