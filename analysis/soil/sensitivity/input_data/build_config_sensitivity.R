library(tidyverse)
library(toml)
source("tools/R/build_config.R")
source("tools/R/collect_data_paths.R")


# Define config values -----------------------------------

# new values for core.grid
core_grid <-
  read_toml("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("maliau_1") |>
  pluck("core") |>
  pluck("grid") |>
  # modify values
  list_modify(cell_nx = 1, cell_ny = 1)

# input data paths for core.data.variable
# first list the soil and litter data files to loop over
data_paths_soil_litter <- paste0(
  "../../data/",
  list.files(
    "data/scenarios/sensitivity_soil_litter/data",
    "soil_litter_data",
  )
)
data_paths <-
  data_paths_soil_litter |>
  map(\(path) {
    collect_data_paths(
      plants = "../../data/plant_input_data_Maliau_50x50_mean.nc",
      climate = "../../data/era5_maliau_2010_2020_100m_mean.nc",
      elevation = "../../data/elevation_maliau_2010_2020_100m_mean.nc",
      soil = path,
      litter = path
    )
  })

# new values for plants.constants
plants_contants <-
  read.csv(
    "data/derived/plant/csv_plant_input_data/plant_constants_Maliau_50x50.csv"
  )


# Set up a list of new values --------------------------------------------
# These new values reflect the Maliau scenarios

# core config
core_list <-
  map(
    data_paths,
    \(data_path) {
      list(
        grid = core_grid,
        timing = list(
          start_date = "2010-01-01",
          update_interval = "1 month",
          run_length = "11 years"
        ),
        data_output_options = list(
          save_initial_state = FALSE,
          save_continuous_data = FALSE
        ),
        data = list(variable = data_path)
      )
    }
  )

# plants config
plants <- list(
  cohort_data_path = "../../data/plant_cohort_data_Maliau_50x50.csv",
  pft_definitions_path = "../../data/plant_pft_definitions_Maliau_50x50.csv",
  constants = as.list(plants_contants)
)

# animal config
animal <- list(
  functional_group_definitions_path = "../../data/animal_functional_groups_Maliau_level1.csv",
  cohort_data_export = list(enabled = FALSE)
)


# Build configuration files ----------------------------------------------

iwalk(core_list, \(x, idx) {
  config_dir <- paste0("data/scenarios/sensitivity_soil_litter/config/", idx)
  if (!dir.exists(config_dir)) {
    dir.create(config_dir)
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
    core = x,
    plants = plants,
    animal = animal,
    path = config_dir
  )
  # Copy over soil microbial config that does not change across scenarios
  file.copy(
    "data/scenarios/maliau/maliau_1/config/soil_microbial_groups.toml",
    config_dir
  )
})
