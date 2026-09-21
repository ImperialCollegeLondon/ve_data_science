#| ---
#| title: Build the compiled config for the maliau_2 scenario
#|
#| description: |
#|   Build a regenerated compiled TOML configuration file for the
#|   `maliau_2` scenario.
#|
#|   The script assembles module sections and repeated
#|   `[[core.data.variable]]` entries with helper functions from
#|   `tools/R/R/build_config.R`, with the aim of keeping the generated output
#|   close to the committed scenario config while remaining reproducible.
#|
#| virtual_ecosystem_module: All
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau/maliau_grid_definition.toml
#|     description: |
#|       Scenario-specific core grid and timing settings for the Maliau site.
#|   - name: plant_constants_maliau_2.csv
#|     path: data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv
#|     description: |
#|       Plant constants used to populate non-default values in the compiled
#|       plants module config.
#|
#| output_files:
#|   - name: config_regenerated.toml
#|     path: data/scenarios/maliau/maliau_2/config/config_regenerated.toml
#|     description: |
#|       Regenerated compiled configuration written for inspection and
#|       comparison with the committed scenario config.
#|
#| source_files:
#|   - name: build_config.R
#|     path: tools/R/R/build_config.R
#|     description: |
#|       Provides helpers for rendering TOML comments, modules, child tables,
#|       array tables, and the final output file.
#|
#| package_dependencies:
#|   - tidyverse
#|   - toml
#|
#| usage_notes: |
#|   Run this script from the repository root so that the relative paths used
#|   by `source()`, `read_toml()`, `read_csv()`, and the rendered config remain
#|   valid.
#| ---

library(tidyverse)
library(toml)
source("tools/R/R/build_config.R")


# Read scenario inputs ----------------------------------------------------

maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")

# Pull out just the compiled core settings for the maliau_2 scenario.
maliau_2 <- maliau$Scenario$maliau_2$core

# Group repeated core.data.variable entries by the module section that uses them.
variable_groups <- build_variable_groups(
  plants_path = "../data/plant_input_data_Maliau_10x10.nc",
  climate_path = "../data/era5_maliau_10x10_2010_2020.nc",
  elevation_path = "../data/elevation_maliau_10x10.nc",
  soil_path = "../data/soil_maliau.nc",
  litter_path = "../data/litter_maliau.nc"
)

# Read the first row as a named list of plant constant overrides.
plants_constants <- read_csv(
  "data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv"
)


# Assemble module values --------------------------------------------------

core <- list(
  # grid_type is implied by the compiled config and is omitted here.
  grid = maliau_2$grid |> discard_at("grid_type"),
  timing = maliau_2$timing,
  data = list(variable = variable_groups)
)

abiotic_simple <- list()

hydrology <- list()

# These values become the top-level [plants] section and child tables.
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

# Animal settings include both top-level fields and export child tables.
animal <- list(
  functional_group_definitions_path = "../data/animal_functional_groups_Maliau_level3.csv",
  cohort_data_export = list(enabled = TRUE),
  resource_pool_export = list(enabled = TRUE)
)

# These modules use defaults at the top level for this scenario.
soil <- list()

litter <- list()


# Render compiled configuration ------------------------------------------

lines <- c(
  # Compile the core module.
  render_comment("Core settings"),
  render_module("core"),
  render_table("core.grid", core$grid),
  render_table("core.timing", core$timing),

  # Compile the abiotic_simple module.
  # This module has no top-level scalar values in this scenario.
  render_comment("Abiotic simple settings"),
  render_module("abiotic_simple"),
  render_comment("Abiotic simple input variables"),
  render_array_tables(
    "core.data.variable",
    core$data$variable$abiotic_simple
  ),

  # Compile the hydrology module.
  # As above, the scenario-specific content here is in the input variables.
  render_comment("Hydrology settings"),
  render_module("hydrology"),
  render_comment("Hydrology input variables"),
  render_array_tables(
    "core.data.variable",
    core$data$variable$hydrology
  ),

  # Compile the animal module.
  render_comment("Animal settings"),
  render_module(
    "animal",
    values = animal,
    field_comments = list(
      functional_group_definitions_path = c(
        "Animal functional group definitions file path.",
        "This scenario currently uses the Maliau level 3 definitions."
      )
    )
  ),
  # Render child tables separately so the TOML hierarchy stays explicit.
  render_table("animal.cohort_data_export", animal$cohort_data_export),
  render_table("animal.resource_pool_export", animal$resource_pool_export),

  # Compile the plants module.
  render_comment("Plants settings"),
  render_module(
    "plants",
    values = plants,
    field_comments = list(
      pft_definitions_path = "Plant functional type definitions file path.",
      cohort_data_path = "Plant cohort input data file path."
    )
  ),
  render_comment("Plant community data export settings"),
  render_table("plants.community_data_export", plants$community_data_export),
  render_comment("Plants input variables"),
  render_array_tables(
    "core.data.variable",
    core$data$variable$plants
  ),
  # Keep the non-default plant constants in their own child table.
  render_comment("Plant constants with scenario-specific overrides"),
  render_table("plants.constants", plants$constants),

  # Compile the soil module.
  render_comment("Soil settings"),
  render_module("soil"),
  render_comment("Soil input variables"),
  render_array_tables(
    "core.data.variable",
    core$data$variable$soil
  ),

  # Compile the litter module.
  render_comment("Litter settings"),
  render_module("litter"),
  render_comment("Litter input variables"),
  render_array_tables(
    "core.data.variable",
    core$data$variable$litter
  )
)

# Write a regenerated config for side-by-side inspection, not to overwrite the
# committed scenario config.
build_config(
  lines = lines,
  path = "data/scenarios/maliau/maliau_2/config",
  file_name = "config_regenerated.toml"
)
