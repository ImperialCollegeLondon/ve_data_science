"""
---
title: Build VE Modular Configuration Files for Maliau Scenarios

description: |
  This script generates Virtual Ecosystem (VE) modular configuration
  TOML files for predefined Maliau Basin simulation scenarios.

  The workflow loads scenario-based grid and timing configurations
  from a TOML file, allows users to interactively select a scenario,
  and automatically builds the required VE configuration files
  needed to run ecosystem simulations.

  Generated configuration files include:
    - ve_run.toml
    - data_config.toml
    - animal_config.toml
    - plants_config.toml
    - soil_microbial_groups.toml

  The script also:
    - loads plant constants from CSV files
    - generates scenario-specific file naming
    - creates modular VE configuration structures
    - automatically writes TOML files to scenario output directories

  Variable definitions for climate, soil, litter, and plant
  datasets are imported from helper utility modules to improve
  maintainability and reduce repetitive TOML-writing code.

virtual_ecosystem_module:
  - Abiotic
  - Hydrology
  - Plant
  - Soil
  - Animal

author:
  - Lelavathy Samikan

status: final

input_files:
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau/maliau_grid_definition.toml
    description: |
      Scenario definition file containing VE grid structure,
      spatial configuration, and simulation timing settings.

  - name: plant_constants_Maliau_<grid_suffix>.csv
    path: data/data/plant_constants_Maliau_<grid_suffix>.csv
    description: |
      CSV file containing plant model constants used
      for VE plant module configuration.

output_files:
  - name: ve_run.toml
    path: data/scenarios/maliau/<scenario>_config/
    description: |
      Main VE run configuration file specifying
      enabled ecosystem modules.

  - name: data_config.toml
    path: data/scenarios/maliau/<scenario>_config/
    description: |
      VE data configuration file containing climate,
      elevation, soil, and litter variable definitions.

  - name: animal_config.toml
    path: data/scenarios/maliau/<scenario>_config/
    description: |
      Configuration file for VE animal module settings
      and cohort export options.

  - name: plants_config.toml
    path: data/scenarios/maliau/<scenario>_config/
    description: |
      Configuration file for VE plant module settings,
      plant input datasets, and plant constants.

  - name: soil_microbial_groups.toml
    path: data/scenarios/maliau/<scenario>_config/
    description: |
      Configuration file defining soil microbial
      functional groups and enzyme classes.

package_dependencies:
  - pathlib
  - pandas
  - toml

usage_notes: |
  - Ensure that scenario definitions are properly specified in
    `maliau_grid_definition.toml` under the scenario section
    (e.g., `maliau_1`, `maliau_2`).
  - Ensure that all required NetCDF input datasets and CSV parameter
    files exist in data folder before running the script.
  - Update placeholder file paths for climate, elevation, soil,
    litter, and plant datasets if necessary.
  - In the terminal, run this script from the project root directory
    using:

      python -m analysis.site.build_modular_config_maliau

  - Select a scenario interactively by typing its name
    (e.g., `maliau_1`, `maliau_2`) or the corresponding number
    when prompted.
  - The script will load the selected scenario configuration and
    automatically generate the required VE TOML configuration files.
  - Output configuration files will be written to:

      data/scenarios/maliau/<scenario>_build_config/

  - To generate configuration files for another scenario,
    rerun the script and select a different scenario.

  Run as: python -m analysis.site.build_modular_config_maliau
---
"""  # noqa: D400, D212, D205, D415


# =============================================================================
# Import packages
# =============================================================================
# Import required Python libraries for:
#   - file handling
#   - TOML parsing
#   - CSV processing
#   - VE helper utilities for configuration buildings.

from pathlib import Path

import pandas as pd

from tools.python.build_config import (
    add_data_variables,
    get_grid_suffix,
    load_scenario,
    select_scenario,
    write_toml,
)
from tools.python.data_variables import (
    climate_variables,
    litter_variables,
    plant_variables,
    soil_variables,
)

# =============================================================================
# Scenario definition file
# =============================================================================
# Define the scenario-based VE configuration TOML file
# containing multiple Maliau simulation scenarios.

scenario_file = "data/derived/site/maliau/maliau_grid_definition.toml"

# =============================================================================
# Select VE scenario
# =============================================================================
# Display available VE scenarios and allow
# the user to select one interactively.

scenario = select_scenario(scenario_file)

# =============================================================================
# Load selected scenario
# =============================================================================
# Load VE grid and timing configuration
# from the selected scenario.

scenario_core = load_scenario(
    scenario_file,
    scenario,
)

core_grid = scenario_core["grid"]

core_timing = scenario_core["timing"]

# =============================================================================
# Add canopy structure settings
# =============================================================================
# Define canopy structure parameters required
# for VE vegetation and abiotic simulations.

core_grid["canopy_layers"] = 10

core_grid["above_canopy_height_offset"] = 2.0

core_grid["subcanopy_layer_height"] = 1.5

core_grid["surface_layer_height"] = 0.1

# =============================================================================
# Generate grid suffix
# =============================================================================
# Create scenario-specific grid suffix used
# for naming VE datasets consistently.

grid_suffix = get_grid_suffix(core_grid)

print(f"\nselected scenario : {scenario}")
print(f"grid size         : {grid_suffix}")

# =============================================================================
# Output directory (Manually edit if necessary)
# =============================================================================
# Create scenario-specific output directory
# for generated VE configuration files.

output_dir = Path(f"data/scenarios/maliau/{scenario}_config")

output_dir.mkdir(
    parents=True,
    exist_ok=True,
)

# =============================================================================
# Dataset file paths (Manually edit if necessary)
# =============================================================================
# Define VE dataset paths for:
#   - climate
#   - elevation
#   - soil
#   - litter
#   - plant inputs

climate_file = f"../data/era5_maliau_{grid_suffix}_2010_2020.nc"

elevation_file = f"../data/elevation_maliau_{grid_suffix}.nc"

soil_file = f"../data/soil_maliau_{grid_suffix}.nc"

litter_file = f"../data/litter_maliau_{grid_suffix}.nc"

plant_file = f"../data/plant_input_data_Maliau_{grid_suffix}.nc"

# =============================================================================
# Load plant constants (Manually edit if necessary)
# =============================================================================
# Load VE plant constant parameters from CSV
# and convert them into dictionary format.

plant_constants_file = f"data/plant_constants_Maliau_{grid_suffix}.csv"

plant_constants_df = pd.read_csv(plant_constants_file)

plant_constants = plant_constants_df.iloc[0].to_dict()

# =============================================================================
# Generate ve_run.toml
# =============================================================================
# Build main VE module activation configuration.

ve_run = {
    "core": {},
    "abiotic_simple": {},
    "hydrology": {},
    "plants": {},
    "animal": {},
    "soil": {},
    "litter": {},
}

write_toml(
    ve_run,
    output_dir / "ve_run.toml",
)

# =============================================================================
# Generate data_config.toml
# =============================================================================
# Build VE core data configuration including:
#   - grid settings
#   - timing settings
#   - canopy structure settings
#   - climate variables
#   - elevation variables
#   - soil variables
#   - litter variables

data_config_text = f"""[core.grid]
grid_type = "{core_grid["grid_type"]}"
cell_area = {core_grid["cell_area"]}
cell_nx = {core_grid["cell_nx"]}
cell_ny = {core_grid["cell_ny"]}
xoff = {core_grid["xoff"]}
yoff = {core_grid["yoff"]}

canopy_layers = {core_grid["canopy_layers"]}
above_canopy_height_offset = {core_grid["above_canopy_height_offset"]}
subcanopy_layer_height = {core_grid["subcanopy_layer_height"]}
surface_layer_height = {core_grid["surface_layer_height"]}

[core.timing]
start_date = "{core_timing["start_date"]}"
update_interval = "{core_timing["update_interval"]}"
run_length = "{core_timing["run_length"]}"

[core.data_output_options]
save_initial_state = true
"""

# Add climate variables
data_config_text = add_data_variables(
    text=data_config_text,
    file_path=climate_file,
    variables=climate_variables,
    section_name="Climate data",
)

# Add elevation variable
data_config_text += f"""

# Elevation data

[[core.data.variable]]
file_path = "{elevation_file}"
var_name = "elevation"
"""

# Add soil variables
data_config_text = add_data_variables(
    text=data_config_text,
    file_path=soil_file,
    variables=soil_variables,
    section_name="Soil data",
)

# Add litter variables
data_config_text = add_data_variables(
    text=data_config_text,
    file_path=litter_file,
    variables=litter_variables,
    section_name="Litter data",
)

# Write data_config.toml
data_config_file = output_dir / "data_config.toml"

with open(
    data_config_file,
    "w",
) as file:
    file.write(data_config_text)

print(f"written: {data_config_file}")

# =============================================================================
# Generate animal _config.toml
# =============================================================================
# Generate the VE animal module configuration file
# including cohort export settings and attributes.

animal_config_text = """[animal]
functional_group_definitions_path = '../data/animal_functional_groups_Maliau_level1.csv'

[animal.cohort_data_export]
enabled = true

# select whichever subset of attributes is of interest
cohort_attributes = [
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
  "reproductive_mass_phosphorus",
]

float_format = "%0.5f"
"""

animal_config_file = output_dir / "animal_config.toml"

with open(
    animal_config_file,
    "w",
) as file:
    file.write(animal_config_text)

print(f"written: {animal_config_file}")

# =============================================================================
# Generate plants_config.toml
# =============================================================================
# Build VE plant module configuration file
# including plant datasets and constants.

plants_config_text = f"""[plants]
cohort_data_path = "../data/plant_cohort_data_Maliau_{grid_suffix}.csv"
pft_definitions_path = "../data/plant_pft_definitions_Maliau_{grid_suffix}.csv"

[plants.community_data_export]
required_data = ["cohorts","community_canopy","stem_canopy"]
cohort_attributes = []
community_canopy_attributes = []
stem_canopy_attributes = []
float_format = "%0.5f"
"""

# Add VE plant input variable definitions.
plants_config_text = add_data_variables(
    text=plants_config_text,
    file_path=plant_file,
    variables=plant_variables,
    section_name="Plant data",
)

# Add VE plant constants from CSV file.
plants_config_text += """

[plants.constants]
"""

for key, value in plant_constants.items():
    plants_config_text += f"{key} = {value}\n"

# Write plants_config.toml
plants_config_file = output_dir / "plants_config.toml"

with open(
    plants_config_file,
    "w",
) as file:
    file.write(plants_config_text)

print(f"written: {plants_config_file}")

# =============================================================================
# Generate soil_microbial_groups.toml
# =============================================================================
# Generate the VE soil microbial functional group
# and enzyme class configuration definitions.

soil_microbial_groups_text = """[[soil.microbial_group_definition]]"
name = "bacteria"
taxonomic_group = "bacteria"
max_uptake_rate_labile_C = 0.04
activation_energy_uptake_rate = 47000
half_sat_labile_C_uptake = 0.364
activation_energy_uptake_saturation = 30000
max_uptake_rate_ammonium = 5e-3
half_sat_ammonium_uptake = 0.02275
max_uptake_rate_nitrate = 5e-4
half_sat_nitrate_uptake = 0.02275
max_uptake_rate_labile_p = 0.0025
half_sat_labile_p_uptake = 0.02275
turnover_rate = 0.005
activation_energy_turnover = 20000
reference_temperature = 12.0
c_n_ratio = 5.2
c_p_ratio = 16
enzyme_production.pom = 0.005
enzyme_production.maom = 0.005
reproductive_allocation = 0.0
symbiote_nitrogen_uptake_fraction = 0.0
symbiote_phosphorus_uptake_fraction = 0.0


[[soil.microbial_group_definition]]
name = "saprotrophic_fungi"
taxonomic_group = "fungi"
max_uptake_rate_labile_C = 0.04
activation_energy_uptake_rate = 47000
half_sat_labile_C_uptake = 0.364
activation_energy_uptake_saturation = 30000
max_uptake_rate_ammonium = 5e-3
half_sat_ammonium_uptake = 0.02275
max_uptake_rate_nitrate = 5e-4
half_sat_nitrate_uptake = 0.02275
max_uptake_rate_labile_p = 0.0025
half_sat_labile_p_uptake = 0.02275
turnover_rate = 0.005
activation_energy_turnover = 20000
reference_temperature = 12.0
c_n_ratio = 6.5
c_p_ratio = 40.0
enzyme_production.pom = 0.005
enzyme_production.maom = 0.005
reproductive_allocation = 0.1
symbiote_nitrogen_uptake_fraction = 0.0
symbiote_phosphorus_uptake_fraction = 0.0


[[soil.microbial_group_definition]]
name = "arbuscular_mycorrhiza"
taxonomic_group = "fungi"
max_uptake_rate_labile_C = 0.04
activation_energy_uptake_rate = 47000
half_sat_labile_C_uptake = 0.364
activation_energy_uptake_saturation = 30000
max_uptake_rate_ammonium = 5e-3
half_sat_ammonium_uptake = 0.02275
max_uptake_rate_nitrate = 5e-4
half_sat_nitrate_uptake = 0.02275
max_uptake_rate_labile_p = 0.0025
half_sat_labile_p_uptake = 0.02275
turnover_rate = 0.005
activation_energy_turnover = 20000
reference_temperature = 12.0
c_n_ratio = 18.0
c_p_ratio = 120.0
enzyme_production.pom = 0.0
enzyme_production.maom = 0.0
reproductive_allocation = 0.1
symbiote_nitrogen_uptake_fraction = 0.2
symbiote_phosphorus_uptake_fraction = 0.2


[[soil.microbial_group_definition]]
name = "ectomycorrhiza"
taxonomic_group = "fungi"
max_uptake_rate_labile_C = 0.04
activation_energy_uptake_rate = 47000
half_sat_labile_C_uptake = 0.364
activation_energy_uptake_saturation = 30000
max_uptake_rate_ammonium = 5e-3
half_sat_ammonium_uptake = 0.02275
max_uptake_rate_nitrate = 5e-4
half_sat_nitrate_uptake = 0.02275
max_uptake_rate_labile_p = 0.0025
half_sat_labile_p_uptake = 0.02275
turnover_rate = 0.005
activation_energy_turnover = 20000
reference_temperature = 12.0
c_n_ratio = 18.0
c_p_ratio = 120.0
enzyme_production.pom = 0.02
enzyme_production.maom = 0.02
reproductive_allocation = 0.1
symbiote_nitrogen_uptake_fraction = 0.2
symbiote_phosphorus_uptake_fraction = 0.2


[[soil.enzyme_class_definition]]
source = "bacteria"
substrate = "pom"
maximum_rate = 60.0
half_saturation_constant = 70.0
activation_energy_rate = 37000
activation_energy_saturation = 30000
reference_temperature = 12.0
turnover_rate = 2.4e-2
c_n_ratio = 5.2
c_p_ratio = 16


[[soil.enzyme_class_definition]]
source = "bacteria"
substrate = "maom"
maximum_rate = 24.0
half_saturation_constant = 350.0
activation_energy_rate = 47000
activation_energy_saturation = 30000
reference_temperature = 12.0
turnover_rate = 2.4e-2
c_n_ratio = 5.2
c_p_ratio = 16


[[soil.enzyme_class_definition]]
source = "fungi"
substrate = "pom"
maximum_rate = 120.0
half_saturation_constant = 35.0
activation_energy_rate = 37000
activation_energy_saturation = 30000
reference_temperature = 12.0
turnover_rate = 2.4e-2
c_n_ratio = 6.5
c_p_ratio = 40.0


[[soil.enzyme_class_definition]]
source = "fungi"
substrate = "maom"
maximum_rate = 48.0
half_saturation_constant = 175.0
activation_energy_rate = 47000
activation_energy_saturation = 30000
reference_temperature = 12.0
turnover_rate = 2.4e-2
c_n_ratio = 6.5
c_p_ratio = 40.0
"""

soil_microbial_groups_file = output_dir / "soil_microbial_groups.toml"

with open(
    soil_microbial_groups_file,
    "w",
) as file:
    file.write(soil_microbial_groups_text)

print(f"written: {soil_microbial_groups_file}")

# =============================================================================
# Complete
# =============================================================================
# Print completion message after all VE
# configuration files are successfully generated.

print("\nconfiguration build complete.")
print(f"output directory : {output_dir}")
