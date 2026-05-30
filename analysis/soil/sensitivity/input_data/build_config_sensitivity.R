library(tidyverse)
library(toml)
source("tools/R/build_config.R")
source("tools/R/collect_data_paths.R")


# Define config values -----------------------------------

# core values
core <-
  read_toml("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("maliau_1") |>
  pluck("core")
# values for core.grid
core_grid <-
  core$grid |>
  # modify values
  list_modify(cell_nx = 1, cell_ny = 1)
# values for core.timing
core_timing <- core$timing

# input data paths for core.data.variable
# the soil and litter data paths are placeholder environment variables
# that will be specified in the HPC job array script later
data_paths <- collect_data_paths(
  plants = "../data/plant_input_data_Maliau_50x50_mean.nc",
  climate = "../data/era5_maliau_2010_2020_100m_mean.nc",
  elevation = "../data/elevation_maliau_2010_2020_100m_mean.nc",
  soil = "$SOIL_LITTER_DATA",
  litter = "$SOIL_LITTER_DATA"
)

# new values for plants.constants
plants_contants <-
  read.csv(
    "data/derived/plant/csv_plant_input_data/plant_constants_Maliau_50x50.csv"
  )


# Set up a list of new values --------------------------------------------
# These new values reflect the Maliau scenarios

# core config
core_config <- list(
  grid = core_grid,
  timing = core_timing,
  data_output_options = list(
    save_initial_state = TRUE,
    save_continuous_data = TRUE
  ),
  data = list(variable = data_paths)
)

# plants config
plants_config <- list(
  cohort_data_path = "../data/plant_cohort_data_Maliau_50x50.csv",
  pft_definitions_path = "../data/plant_pft_definitions_Maliau_50x50.csv",
  constants = as.list(plants_contants)
)

# animal config
animal_config <- list(
  functional_group_definitions_path = "../data/animal_functional_groups_Maliau_level1.csv",
  cohort_data_export = list(enabled = FALSE)
)


# Build configuration files ----------------------------------------------
config_dir <- "data/scenarios/sensitivity_soil_litter/config"
if (!dir.exists(config_dir)) {
  dir.create(config_dir)
} else {
  message("All good, config directory already exists.")
}

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
  core = core_config,
  plants = plants_config,
  animal = animal_config,
  path = config_dir
)
# Copy over soil microbial config that does not change across scenarios
file.copy(
  "data/scenarios/maliau/maliau_1/config/soil_microbial_groups.toml",
  config_dir,
  overwrite = TRUE
)
