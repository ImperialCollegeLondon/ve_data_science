#| ---
#| title: Build the compiled configuration file for the maliau_2 scenario
#|
#| description: |
#|     This R script uses a custom function to build a single compiled TOML
#|     configuration file for the maliau_2 scenario to reduce manual TOML edits.
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
source("tools/R/R/collect_data_paths.R")


# Source new values analysed elsewhere -----------------------------------

maliau <- read_toml("data/derived/site/maliau/maliau_grid_definition.toml")
maliau_2 <- maliau$Scenario$maliau_2$core

data_paths <- collect_data_paths(
  plants = "../data/plant_input_data_Maliau_10x10.nc",
  climate = "../data/era5_maliau_10x10_2010_2020.nc",
  elevation = "../data/elevation_maliau_10x10.nc",
  soil = "../data/soil_maliau.nc",
  litter = "../data/litter_maliau.nc"
)

data_lookup <- split(data_paths, data_paths$var_name)
make_entry <- function(var_name) {
  as.list(data_lookup[[var_name]][1, c("file_path", "var_name")])
}
make_entries <- function(var_names) {
  lapply(var_names, make_entry)
}

plants_constants <- read_csv(
  "data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv"
)


# Set up a combined nested list schema -----------------------------------

core <- list(
  grid = maliau_2$grid |> discard_at("grid_type"),
  timing = maliau_2$timing,
  data = list(
    variable = list(
      abiotic_simple = make_entries(c(
        "air_temperature_ref",
        "relative_humidity_ref",
        "atmospheric_pressure_ref",
        "atmospheric_co2_ref",
        "mean_annual_temperature",
        "wind_speed_ref",
        "downward_longwave_radiation",
        "diurnal_temperature_range_ref"
      )),
      hydrology = make_entries(c("precipitation", "elevation")),
      plants = make_entries(c(
        "plant_pft_propagules",
        "subcanopy_vegetation_biomass",
        "subcanopy_seedbank_biomass",
        "downward_shortwave_radiation"
      )),
      soil = make_entries(c(
        "pH",
        "clay_fraction",
        "soil_cnp_pool_lmwc",
        "soil_cnp_pool_maom",
        "soil_c_pool_bacteria",
        "soil_c_pool_saprotrophic_fungi",
        "soil_c_pool_arbuscular_mycorrhiza",
        "soil_c_pool_ectomycorrhiza",
        "soil_cnp_pool_pom",
        "soil_cnp_pool_necromass",
        "soil_enzyme_pom_bacteria",
        "soil_enzyme_maom_bacteria",
        "soil_enzyme_pom_fungi",
        "soil_enzyme_maom_fungi",
        "soil_n_pool_ammonium",
        "soil_n_pool_nitrate",
        "soil_p_pool_primary",
        "soil_p_pool_secondary",
        "soil_p_pool_labile",
        "fungal_fruiting_bodies_cnp"
      )),
      litter = make_entries(c(
        "litter_pool_above_metabolic_cnp",
        "litter_pool_above_structural_cnp",
        "litter_pool_woody_cnp",
        "litter_pool_below_metabolic_cnp",
        "litter_pool_below_structural_cnp",
        "lignin_above_structural",
        "lignin_woody",
        "lignin_below_structural"
      ))
    )
  )
)

abiotic_simple <- list()

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

build_config(
  core = core,
  abiotic_simple = abiotic_simple,
  hydrology = hydrology,
  plants = plants,
  animal = animal,
  soil = soil,
  litter = litter,
  path = "data/scenarios/maliau/maliau_2/config",
  file_name = "config_regenerated.toml"
)
