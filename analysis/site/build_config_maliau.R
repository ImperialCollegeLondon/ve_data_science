#| ---
#| title: Build the compiled configuration file for the maliau_2 scenario
#|
#| description: |
#|     This R script uses helper functions from build_config.R to build a
#|     single compiled TOML configuration file for the maliau_2 scenario while
#|     keeping the manual config structure close to the committed version.
#|
#| VE_module: All
#|
#| author:
#|   - name: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Definition file of the Maliau scenarios
#|   - name: plant_constants_maliau_2.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2
#|     description: Plant constants for the Maliau scenario by Arne Scheire
#|
#| output_files:
#|   - name: config_regenerated.toml
#|     path: data/scenarios/maliau/maliau_2/config
#|     description: Regenerated compiled config TOML file for comparison
#|
#| package_dependencies:
#|     - tidyverse
#|     - toml
#|
#| usage_notes:
#| ---

library(tidyverse)
library(toml)
source("tools/R/R/build_config.R")


# Source new values analysed elsewhere -----------------------------------

maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")
maliau_2 <- maliau$Scenario$maliau_2$core

variable_groups <- build_variable_groups(
  plants_path = "../data/plant_input_data_Maliau_10x10.nc",
  climate_path = "../data/era5_maliau_10x10_2010_2020.nc",
  elevation_path = "../data/elevation_maliau_10x10.nc",
  soil_path = "../data/soil_maliau.nc",
  litter_path = "../data/litter_maliau.nc"
)

plants_constants <- read_csv(
  "data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv"
)


# Set up a combined nested list schema -----------------------------------

core <- list(
  grid = maliau_2$grid |> discard_at("grid_type"),
  timing = maliau_2$timing,
  data = list(variable = variable_groups)
)

abiotic <- list()

hydrology <- list()

plants <- list(
  cohort_data_path = "../data/cohort_data_1_cm_maliau_2.csv",
  pft_definitions_path = "../data/plant_pft_definitions_maliau_2.csv",
  community_data_export = list(
    required_data = c("cohorts", "community_canopy", "stem_canopy"),
    cohort_attributes = list(),
    community_canopy_attributes = list(),
    stem_canopy_attributes = list()
  ),
  constants = as.list(plants_constants[1, ])
)
animal <- list(
  functional_group_definitions_path = "../data/animal_functional_groups_Maliau_level3.csv",
  cohort_data_export = list(enabled = TRUE),
  resource_pool_export = list(enabled = TRUE)
)

soil <- list()

litter <- list()


# Build compiled configuration -------------------------------------------

comments <- list(
  core = "# Core settings",
  abiotic = "# Abiotic config settings",
  abiotic_variables = "# Abiotic array variables",
  hydrology = "# Hydrology config settings",
  hydrology_variables = "# Hydrology array variables",
  animal = "# Animal config settings",
  animal_functional_group_definitions_path = c(
    "# Animal functional group definitions file path",
    paste0(
      "# Currently uses Maliau_level3, other levels are also available ",
      "through Globus."
    )
  ),
  plants = "# Plant config settings",
  plants_pft_definitions_path = "# Plant pft definitions file path",
  plants_cohort_data_path = "# Plant cohort data file path",
  plants_community_data_export = "# Plant output data export settings",
  plants_variables = "# Plant array variables",
  plants_constants = "# Plant constants (non-defaults)",
  soil = "# Soil config settings",
  soil_variables = "# Soil array variables",
  litter = "# Litter config settings",
  litter_variables = "# Litter array variables"
)

core_values <- remove_nested_list_fields(core)
animal_values <- remove_nested_list_fields(animal)
plants_values <- remove_nested_list_fields(plants)

lines <- c(
  render_table("core", core_values, comments$core),
  render_table("core.grid", core$grid),
  render_table("core.timing", core$timing),
  render_table("abiotic_simple", abiotic, comments$abiotic),
  render_array_tables(
    "core.data.variable",
    core$data$variable$abiotic_simple,
    comments$abiotic_variables
  ),
  render_table("hydrology", hydrology, comments$hydrology),
  render_array_tables(
    "core.data.variable",
    core$data$variable$hydrology,
    comments$hydrology_variables
  ),
  render_table_with_body_comments(
    "animal",
    animal_values,
    comments$animal,
    comments$animal_functional_group_definitions_path
  ),
  render_table("animal.cohort_data_export", animal$cohort_data_export),
  render_table("animal.resource_pool_export", animal$resource_pool_export),
  render_table_with_body_comments(
    "plants",
    plants_values,
    comments$plants,
    c(
      normalize_comment_lines(comments$plants_pft_definitions_path),
      normalize_comment_lines(comments$plants_cohort_data_path)
    )
  ),
  render_table(
    "plants.community_data_export",
    plants$community_data_export,
    comments$plants_community_data_export
  ),
  render_array_tables(
    "core.data.variable",
    core$data$variable$plants,
    comments$plants_variables
  ),
  render_table(
    "plants.constants",
    plants$constants,
    comments$plants_constants
  ),
  render_table("soil", soil, comments$soil),
  render_array_tables(
    "core.data.variable",
    core$data$variable$soil,
    comments$soil_variables
  ),
  render_table("litter", litter, comments$litter),
  render_array_tables(
    "core.data.variable",
    core$data$variable$litter,
    comments$litter_variables
  )
)

build_config(
  lines = lines,
  path = "data/scenarios/maliau/maliau_2/config",
  file_name = "config_regenerated.toml"
)
