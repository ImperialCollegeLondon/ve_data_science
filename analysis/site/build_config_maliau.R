#| ---
#| title: Build the configuration files for the maliau_2 scenario
#|
#| description: |
#|     This R script uses a custom function to build the configuration files for
#|     the maliau_2 scenario to improve over the current manual TOML edits.
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
#|   - name: plant_constants_Maliau_10x10.csv
#|     path: data/derived/plant/csv_plant_input_data
#|     description: Plant constants for the Maliau scenario by Arne Scheire
#|
#| output_files:
#|   - name: ve_run.toml
#|     path: data/scenarios/maliau/maliau_2_build_config
#|     description: Built main config TOML file for maliau_2
#|   - name: core_config.toml
#|     path: data/scenarios/maliau/maliau_2_build_config
#|     description: Built core config TOML file for maliau_2
#|   - name: animal_config.toml
#|     path: data/scenarios/maliau/maliau_2_build_config
#|     description: Built animal config TOML file for maliau_2
#|   - name: plants_config.toml
#|     path: data/scenarios/maliau/maliau_2_build_config
#|     description: Built plants config TOML file for maliau_2
#|
#| package_dependencies:
#|     - tidybayes
#|     - toml
#|
#| usage_notes:
#| ---

library(tidyverse)
library(toml)
source("tools/build_config.R")
source("tools/collect_data_paths.R")


# Source new values analysed elsewhere -----------------------------------

# new values for core.grid
maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")
maliau_2 <- maliau$Scenario$maliau_2$core

# input data paths for core.data.variable
data_paths <- collect_data_paths(
  plants = "../data/plant_input_data_Maliau_10x10.nc",
  climate = "../data/era5_maliau_10x10_2010_2020.nc",
  elevation = "../data/elevation_maliau_10x10.nc",
  soil = "../data/soil_maliau.nc",
  litter = "../data/litter_maliau.nc"
)

# new values for plants.constants
plants_contants <-
  read.csv(
    "data/derived/plant/csv_plant_input_data/plant_constants_Maliau_10x10.csv"
  )


# Set up a list of new values --------------------------------------------
# These new values reflect the Maliau scenarios

# core config
core <- list(
  grid = maliau_2$grid,
  timing = list(
    start_date = "2010-01-01",
    update_interval = "1 month",
    run_length = "11 years"
  ),
  data_output_options = list(
    save_initial_state = TRUE
  ),
  data = list(
    variable = data_paths
  )
)

# plants config
plants <- list(
  cohort_data_path = "../data/plant_cohort_data_Maliau_10x10.csv",
  pft_definitions_path = "../data/plant_pft_definitions_Maliau_10x10.csv",
  community_data_export = list(
    required_data = list(
      "cohorts",
      "community_canopy",
      "stem_canopy"
    )
  ),
  constants = as.list(plants_contants)
)

# animal config
animal <- list(
  functional_group_definitions_path = "../data/animal_functional_groups_Maliau_level1.csv",
  cohort_data_export = list(
    enabled = TRUE,
    cohort_attributes = list(
      "time",
      "cohort_id",
      "functional_group",
      "diet_type",
      "development_type",
      "age",
      "individuals",
      "is_alive",
      "is_mature",
      "time_to_maturity",
      "time_since_maturity",
      "location_status",
      "centroid_key",
      "territory_size",
      "territory",
      "occupancy_proportion",
      "largest_mass_achieved",
      "mass_carbon",
      "mass_nitrogen",
      "mass_phosphorus",
      "reproductive_mass_carbon",
      "reproductive_mass_nitrogen",
      "reproductive_mass_phosphorus"
    )
  )
)


# Build configuration files ----------------------------------------------

build_config(
  requested_modules = c(
    "core",
    "abiotic_simple",
    "hydrology",
    "plants",
    "animal",
    "soil",
    "litter"
  ),
  core = core,
  plants = plants,
  animal = animal,
  path = "data/scenarios/maliau/maliau_2_build_config"
)
