"""
---
title: VE Variable Definitions for Configuration Generation

description: |
  This module contains grouped variable name definitions used
  for generating Virtual Ecosystem (VE) configuration files.

  The variable groups are organised by VE module and are used
  when constructing:
    - climate input definitions
    - soil input definitions
    - litter input definitions
    - plant input definitions

  Centralising variable definitions in this module reduces
  repetitive hardcoded TOML-writing blocks and improves
  maintainability across VE preprocessing workflows.

virtual_ecosystem_module:
  - Abiotic
  - Hydrology
  - Soil
  - Litter
  - Plant

author:
  - Lelavathy Samikan

status: final

input_files: []

output_files: []

package_dependencies: []

usage_notes: |
  - This module is intended to be imported into VE
    configuration-building scripts.

  - Variable groups are organised by VE subsystem:
      - climate_variables
      - soil_variables
      - litter_variables
      - plant_variables

  - The variable lists can be looped through to
    automatically generate:

        [[core.data.variable]]

    TOML blocks for VE configuration files.

  - Add or remove variables here to update all
    downstream VE configuration workflows consistently.

  Run as:

      imported as helper module

---
"""  # noqa: D400, D212, D205, D415
# =============================================================================
# VE variable definitions
# =============================================================================
# Define grouped VE variable names used for
# automatic TOML configuration generation.

climate_variables = [
    "air_temperature_ref",
    "relative_humidity_ref",
    "atmospheric_pressure_ref",
    "precipitation",
    "atmospheric_co2_ref",
    "mean_annual_temperature",
    "wind_speed_ref",
    "downward_longwave_radiation",
    "downward_shortwave_radiation",
]

soil_variables = [
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
    "soil_p_pool_secondary",
]

litter_variables = [
    "litter_pool_above_metabolic_cnp",
    "litter_pool_above_structural_cnp",
    "litter_pool_below_metabolic_cnp",
    "litter_pool_below_structural_cnp",
    "litter_pool_woody_cnp",
    "lignin_above_structural",
    "lignin_below_structural",
    "lignin_woody",
]

plant_variables = [
    "plant_pft_propagules",
    "subcanopy_vegetation_biomass",
    "subcanopy_seedbank_biomass",
]
