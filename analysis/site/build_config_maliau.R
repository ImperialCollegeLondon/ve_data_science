library(tidyverse)
library(toml)


# Source new values analysed elsewhere -----------------------------------

# new values for core.grid
maliau <- read_toml("data/derived/site/maliau_grid_definition.toml")
maliau_2 <- maliau$Scenario$maliau_2$core

# new values for plants.constants
plants_contants <-
  read.csv(
    "data/derived/plant/csv_plant_input_data/plant_constants_Maliau_10x10.csv"
  ) |>
  as.list()

# input data paths
data_paths <-
  # plant data
  data.frame(
    var_name = c(
      "plant_pft_propagules",
      "subcanopy_vegetation_biomass",
      "subcanopy_seedbank_biomass"
    ),
    file_path = "../data/plant_input_data_Maliau_10x10.nc"
  ) |>
  # climate data
  bind_rows(
    data.frame(
      var_name = c(
        "air_temperature_ref",
        "relative_humidity_ref",
        "atmospheric_pressure_ref",
        "precipitation",
        "atmospheric_co2_ref",
        "mean_annual_temperature",
        "wind_speed_ref",
        "downward_longwave_radiation",
        "downward_shortwave_radiation"
      ),
      file_path = "../data/era5_maliau_10x10_2010_2020.nc"
    )
  ) |>
  # elevation data
  bind_rows(
    data.frame(
      var_name = "elevation",
      file_path = "../data/elevation_maliau_10x10.nc"
    )
  ) |>
  # soil data
  bind_rows(
    data.frame(
      var_name = c(
        "soil_cnp_pool_lmwc",
        "soil_cnp_pool_maom",
        "soil_cnp_pool_necromass",
        "soil_cnp_pool_pom",
        "clay_fraction",
        "fungal_fruiting_bodies",
        "pH",
        "soil_c_pool_arbuscular_mycorrhiza",
        "soil_c_pool_bacteria",
        "soil_c_pool_ectomycorrhiza",
        "soil_c_pool_saprotrophic_fungi",
        "soil_enzyme_maom_bacteria",
        "soil_enzyme_maom_fungi",
        "soil_enzyme_pom_bacteria",
        "soil_enzyme_pom_fungi",
        "soil_n_pool_ammonium",
        "soil_n_pool_nitrate",
        "soil_p_pool_labile",
        "soil_p_pool_primary",
        "soil_p_pool_secondary"
      ),
      file_path = "../data/soil_maliau.nc"
    )
  ) |>
  # litter data
  bind_rows(
    data.frame(
      var_name = c(
        "litter_pool_above_metabolic_cnp",
        "litter_pool_above_structural_cnp",
        "litter_pool_below_metabolic_cnp",
        "litter_pool_below_structural_cnp",
        "litter_pool_woody_cnp",
        "lignin_above_structural",
        "lignin_below_structural",
        "lignin_woody"
      ),
      file_path = "../data/litter_maliau.nc"
    )
  )

# Set up a list of new values --------------------------------------------

config_edits <-
  # set up list, this line is not necessary but I want to be explicit that
  # config_edits can be an empty list (i.e., no edit)
  list() |>
  list_assign(
    # core config
    core = list(
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
    ),
    # plants
    plants = list(
      cohort_data_path = "../data/plant_cohort_data_Maliau_10x10.csv",
      pft_definitions_path = "../data/plant_pft_definitions_Maliau_10x10.csv",
      community_data_export = list(
        required_data = list(
          "cohorts",
          "community_canopy",
          "stem_canopy"
        )
      ),
      constants = plants_contants
    ),
    # animals
    animal = list(
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
  )

build_config_user(
  requested_modules = c(
    "core",
    "abiotic_simple",
    "hydrology",
    "plants",
    "animal",
    "soil",
    "litter"
  ),
  config_edits,
  path = "data/scenarios/maliau/maliau_2_edit_config"
)
