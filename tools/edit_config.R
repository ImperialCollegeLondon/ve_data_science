library(tidyverse)
library(toml)
library(reticulate)
use_virtualenv("./ve_release")
source("tools/build_config.R")

# first generate a template for modification later
toml_dest <- "data/scenarios/maliau/maliau_2/config/config_template.toml"

build_config(
  list(
    "core",
    "abiotic_simple",
    "hydrology",
    "plants",
    "animal",
    "soil",
    "litter"
  ),
  filename = toml_dest
)

# read the template config TOML
config_template <-
  read_toml(toml_dest) |>
  write_toml()


# Source new values analysed elsewhere -----------------------------------

# new values for core.grid
maliau <- read_toml("data/derived/site/maliau_grid_definition.toml")
maliau_2 <- maliau$Scenario$maliau_2
maliau_2_core.grid <-
  maliau_2["core"] |>
  list_flatten(name_spec = "{outer}.{inner}") |>
  list_flatten(name_spec = "{outer}.{inner}")

# new values for plants.constants
plants_contants <-
  read.csv(
    "data/derived/plant/csv_plant_input_data/plant_constants_Maliau_10x10.csv"
  ) |>
  as.list()
names(plants_contants) <- paste0("plants.contants.", names(plants_contants))

# Set up a list of new values --------------------------------------------

config_edits <-
  # core.grid
  list_assign(maliau_2_core.grid) |>
  # core.timing
  list_assign(
    core.timing.start_date = "2010-01-01",
    core.timing.update_interval = "1 month",
    core.timing.run_length = "11 years"
  ) |>
  # core.data_output_options
  list_assign(core.data_output_options.save_initial_state = TRUE) |>
  # core.data.variable
  # plants
  list_assign(
    plants.cohort_data_path = "../data/plant_cohort_data_Maliau_10x10.csv",
    plants.pft_definitions_path = "../data/plant_pft_definitions_Maliau_10x10.csv"
  ) |>
  # plants.community_data_export
  list_assign(
    plants.community_data_export.required_data = list(
      "cohorts",
      "community_canopy",
      "stem_canopy"
    )
  ) |>
  # plants.constants
  list_merge(plants_contants)

# recursively edit all new values in the template config
for (i in seq_along(config_edits)) {
  field <- names(config_edits)[i]
  value <- config_edits[[i]]
  config_template <- edit_toml(config_template, field, value)
}
