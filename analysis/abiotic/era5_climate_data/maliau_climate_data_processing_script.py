"""
---
title: Processing Script for ERA5-Land Climate Input Data for Maliau Basin.

description: |
  This script prepares ERA5-Land climate input data for the Virtual Ecosystem (VE)
  model, focusing on the Maliau Basin site. It automates downloading, processing,
  interpolation, and formatting of ERA5-Land climate data to generate a climate
  input dataset compatible with the VE abiotic and hydrology modules.

  Specifically, it:
    1. Loads the VE site configuration from a TOML file.
    2. Defines the VE target grid from the site configuration.
    3. Downloads ERA5-Land monthly averaged climate variables (2010-2020) from the
       Copernicus Climate Data Store (CDS).
    4. Downloads ERA5-Land hourly 2 m air temperature for calculating monthly
       diurnal temperature range (DTR).
    5. Processes the climate data by:
         - Calculating monthly diurnal temperature range.
         - Converting ERA5-Land variables to VE units.
         - Calculating relative humidity.
         - Selecting the climate variables required by the VE model.
    6. Interpolates the monthly climate variables and monthly DTR separately onto
       the VE target grid using bilinear interpolation, with any
       remaining missing values filled using nearest-neighbour interpolation.
    7. Creates the climate input dataset using VE-standard
       variable names:
         - air_temperature_ref
         - relative_humidity_ref
         - wind_speed_ref
         - precipitation
         - atmospheric_pressure_ref
         - downward_shortwave_radiation
         - downward_longwave_radiation
         - diurnal_temperature_range_ref
    8. Derives additional climate variables required by the VE model:
         - Mean annual temperature
         - Atmospheric CO₂ concentration
    9. Finalises the dataset by creating the VE time structure, adding global
       metadata, and saving a compressed NetCDF climate forcing dataset for use
       by the VE.

    Notes:-
    - Monthly climate variables and hourly air temperature are downloaded
      separately because monthly diurnal temperature range is derived from the
      hourly dataset.
    - Monthly climate variables and monthly DTR are interpolated separately
      because they originate from different ERA5-Land products with different
      spatial coordinate definitions.

virtual_ecosystem_module:
  - abiotic
  - hydrology

author:
  - Lelavathy Samikan

status: final

input_files:
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau
    description: |
      Defines the target grid, including grid dimensions,
      spatial resolution, coordinate reference system, and bounding box
      for given scenario for Maliau Basin.

output_files:
  - name: era5_monthly_<start_year>_<end_year>_<scenario>.nc
    path: data/primary/abiotic/era5_land
    description: |
      ERA5-Land monthly averaged climate variables downloaded from the
      Copernicus Climate Data Store.

  - name: era5_hourly_t2m_<start_year>_<end_year>_<scenario>.nc
    path: data/primary/abiotic/era5_land
    description: |
      ERA5-Land hourly 2 m air temperature downloaded from the Copernicus
      Climate Data Store and used to calculate monthly diurnal temperature
      range.

  - name: era5_<scenario>_<start_year>_<end_year>.nc
    path: data/derived/abiotic/era5_land
    description: |
      Final VE climate input dataset containing all required
      climate variables interpolated onto the Virtual Ecosystem grid and saved
      as a compressed NetCDF file for use by the VE Abiotic model.

package_dependencies:
  - pathlib
  - numpy
  - xarray
  - rasterio
  - rioxarray
  - tomllib
  - cdsapi

usage_notes: |
  Run as:

      python maliau_climate_data_processing_script.py

  Before running this script:
    - Ensure a valid CDS API configuration (~/.cdsapirc) is available.
    - Ensure the required helper modules
      `cdsapi_downloader.py` and `climate_tools.py` are available in
      the `tools/python` directory, as they provide the ERA5-Land
      download and climate processing functions used by this workflow.

  Although configured for the Maliau Basin by default, the workflow is
  transferable to other study sites (e.g. SAFE and Danum Valley) by
  updating the site-specific configuration TOML file, selecting the
  appropriate scenario defined in the TOML file, and specifying the
  corresponding geographic bounding box for ERA5-Land data download.

references: |
    Muñoz-Sabater, J., et al. (2021). ERA5-Land: A state-of-the-art global
    reanalysis dataset for land applications. Earth System Science Data,
    13(9), 4349-4383.
    https://doi.org/10.5194/essd-13-4349-2021

    Muñoz-Sabater, J. (2019). ERA5-Land monthly averaged data from 1950 to
    present. Copernicus Climate Change Service (C3S) Climate Data Store (CDS).
    https://doi.org/10.24381/cds.68d2bb30

---
"""  # noqa: D212, D205

import importlib
import sys
from pathlib import Path

# ============================================================
# PROJECT ROOT
# ============================================================
# Determine the root directory of the VE project
# and add it to the Python search path. This enables project
# modules to be imported regardless of the directory from which
# this script is executed.

project_root = Path(__file__).resolve().parents[3]

sys.path.insert(
    0,
    str(project_root),
)

# ============================================================
# IMPORT CLIMATE DATA DOWNLOAD TOOLS
# ============================================================
# Import functions for downloading ERA5-Land monthly climate
# variables and hourly 2 m air temperature from the Copernicus
# Climate Data Store (CDS).

cdsapi_downloader = importlib.import_module("tools.python.abiotic.cdsapi_downloader")
cdsapi_era5_hourly_temperature_downloader = (
    cdsapi_downloader.cdsapi_era5_hourly_temperature_downloader
)
cdsapi_era5_monthly_downloader = cdsapi_downloader.cdsapi_era5_monthly_downloader

# ============================================================
# IMPORT CLIMATE PROCESSING TOOLS
# ============================================================
# Import functions for processing, interpolating, and
# formatting ERA5-Land climate data into a Virtual Ecosystem
# climate forcing dataset.

climate_tools = importlib.import_module("tools.python.abiotic.climate_tools")
add_atmospheric_co2 = climate_tools.add_atmospheric_co2
add_global_attributes = climate_tools.add_global_attributes
add_mean_annual_temperature = climate_tools.add_mean_annual_temperature
calculate_monthly_dtr = climate_tools.calculate_monthly_dtr
calculate_relative_humidity = climate_tools.calculate_relative_humidity
convert_units = climate_tools.convert_units
create_ve_dataset = climate_tools.create_ve_dataset
finalise_ve_dataset = climate_tools.finalise_ve_dataset
get_target_grid = climate_tools.get_target_grid
interpolate_dataset = climate_tools.interpolate_dataset
interpolate_variable = climate_tools.interpolate_variable
read_site_configuration = climate_tools.read_site_configuration
save_dataset = climate_tools.save_dataset
select_required_variables = climate_tools.select_required_variables


# ============================================================
# USER SETTINGS
# ============================================================
# Configure the scenario and bounding box for ERA5-Land climate data download.


# Select  scenario (e.g., " maliau_1", "maliau_2") defined in the site
# configuration TOML file (e.g.,"maliau_grid_definition.toml").
scenario_name = "maliau_2"
# NOTE:
# Modify the scenario name defined in the site-specific
# configuration TOML file to prepare climate data for a
# different study site (e.g. SAFE or Danum).

# Geographic bounding box [north, west, south, east] used to
# define the ERA5-Land download area from the Copernicus
# Climate Data Store (CDS).
bbox = [
    4.8,  # north
    116.8,  # west
    4.6,  # south
    117.0,  # east
]
# NOTE:
# Modify the bounding box to download ERA-Land climate data
# for a different study site (e.,g SAFE or Danum).

# ============================================================
# PATHS
# ============================================================
# Define the project root directory and the input/output paths
# used throughout the climate preparation workflow.

root_dir = Path(__file__).resolve().parents[3]

# ------------------------------------------------------------
# SITE CONFIGURATION
# ------------------------------------------------------------
# Site configuration TOML file containing the target
# grid definition, spatial resolution, and coordinate
# reference system.

grid_file = (
    root_dir / "data" / "derived" / "site" / "maliau" / "maliau_grid_definition.toml"
)

# NOTE:
# Modify the file path of site configuration TOML
# file for a different study site (e.,g SAFE or Danum)

# ============================================================
# READ SITE CONFIGURATION
# ============================================================
# Read the site configuration TOML file and extract the
# target grid and simulation period required for climate
# data preparation for the selected scenario.

scenario = read_site_configuration(
    grid_file,
    scenario_name,
)

timing = scenario["core"]["timing"]

start_date = timing["start_date"]
start_year = int(start_date[:4])

run_length = int(timing["run_length"].split()[0])

end_year = start_year + run_length - 1
end_date = f"{end_year}-12-31"

target_grid = get_target_grid(scenario)

years = list(range(start_year, end_year + 1))

# ------------------------------------------------------------
# DEFINE OUTPUT DIRECTORY FOR DOWNLOADED AND PROCESSED ERA5-LAND DATA
# ------------------------------------------------------------
# Define output directory containing the downloaded and processed
# ERA5-Land climate data


# Define directory for downloaded ERA5-Land climate data obtained
# from the Copernicus Climate Data Store.
primary_data_dir = root_dir / "data" / "primary" / "abiotic" / "era5_land"

primary_data_dir.mkdir(
    parents=True,
    exist_ok=True,
)

# Define filename for the downloaded ERA5-Land
# monthly averaged climate variables
monthly_file = (
    primary_data_dir / f"era5_monthly_{start_year}_{end_year}_{scenario_name}.nc"
)

# Define filename for the downloaded ERA5-Land
# hourly 2m air temperature used to calculate monthly diurnal temperature
# range (dtr).
hourly_file = (
    primary_data_dir / f"era5_hourly_t2m_{start_year}_{end_year}_{scenario_name}.nc"
)


# Define directory for the reprojected and unit-converted
# ERA5 data (spatially interpolated) to be used as input climate data.
derived_data_dir = root_dir / "data" / "derived" / "abiotic" / "era5_land"

derived_data_dir.mkdir(
    parents=True,
    exist_ok=True,
)

# Define filename for the reprojected and unit-converted
# ERA5 data (spatially interpolated) to be used as input climate data.
output_file = derived_data_dir / f"era5_{scenario_name}_{start_year}_{end_year}.nc"

# ============================================================
# DOWNLOAD ERA5-LAND CLIMATE DATA
# ============================================================
# Download the ERA5-Land monthly climate variables and hourly
# 2 m air temperature required for climate forcing
# preparation.

print("\nDownloading ERA5-Land climate data...")

# Download monthly averaged ERA5-Land climate data.
era5_ds = cdsapi_era5_monthly_downloader(
    years=years,
    bbox=bbox,
    outfile=monthly_file,
)

# Download hourly 2m air temperature ERA5-Land data.
hourly_ds = cdsapi_era5_hourly_temperature_downloader(
    start_date=start_date,
    end_date=end_date,
    bbox=bbox,
    outfile=hourly_file,
)


# ============================================================
# PROCESS CLIMATE VARIABLES
# ============================================================
# Calculate the monthly diurnal temperature range, convert
# ERA5-Land variables to VE units, derive relative humidity,
# and retain only the variables required by the VE.

print("\nProcessing climate variables...")

monthly_dtr = calculate_monthly_dtr(hourly_ds)

era5_ds = convert_units(era5_ds)
era5_ds = calculate_relative_humidity(era5_ds)
era5_ds = select_required_variables(era5_ds)


# ============================================================
# SPATIAL INTERPOLATION
# ============================================================
# Interpolate the monthly climate variables and monthly
# diurnal temperature range onto the target grid for a given
# scenario.

# The interpolation mapping used here at the moment is the `bilinear`method of rasterio.
# Missing values generated during interpolation are filled
# using nearest-neighbour interpolation.
# Other methods are available:
# https://rasterio.readthedocs.io/en/stable/api/rasterio.enums.html#rasterio.enums.Resampling
# We might want to use a different interpolation strategy to give a smooth surface.

# Note:
# The Virtual Ecosystem model is run on a 100 x 100 m grid.
# This means that some form of spatial downscaling has to be applied to the dataset,
# for example by spatially interpolating coarser resolution climate data and including
# the effects of local topography.
# This is not yet implemented!

print("\nInterpolating climate variables...")

interpolated = interpolate_dataset(
    dataset=era5_ds,
    target_grid=target_grid,
)

interpolated["dtr"] = interpolate_variable(
    monthly_dtr,
    target_grid,
)

# ============================================================
# CREATE CLIMATE FORCING DATASET
# ============================================================
# Assemble the interpolated climate variables into the
# VE climate forcing dataset.

print("\nCreating climate forcing dataset...")

climate_ds = create_ve_dataset(interpolated)


# ============================================================
# ADDITION OF CLIMATE VARIABLES
# ============================================================
# Add additional climate variables required by the VE
# climate forcing dataset.

print("\nAdding climate variables...")

climate_ds = add_mean_annual_temperature(climate_ds)
climate_ds = add_atmospheric_co2(climate_ds)


# ============================================================
# DATASET FINALISATION
# ============================================================
# Finalise the dataset by creating the required VE time
# structure and adding global metadata.

print("\nFinalising climate forcing dataset...")

climate_ds = finalise_ve_dataset(climate_ds)
climate_ds = add_global_attributes(
    climate_ds,
    scenario_name,
)

# ============================================================
# DATASET SUMMARY
# ============================================================
# Print a summary of the VE climate forcing
# dataset to verify that the climate variables have been
# successfully processed and reformatted.

print("\nClimate forcing dataset summary")
print("-" * 60)

print(
    f"Site: {scenario_name}\n"
    f"Simulation period: {start_year}-{end_year}\n"
    f"Grid size: {scenario['cell_nx']} x {scenario['cell_ny']} cells\n"
    f"Spatial resolution: {scenario['res']} m\n"
    f"Time steps: {climate_ds.sizes['time_index']}"
)

# ------------------------------------------------------------
# CLIMATE VARIABLE SUMMARY
# ------------------------------------------------------------
# Print summary statistics and check for missing values in each
# climate variable before saving the dataset.

variables = [
    "air_temperature_ref",
    "relative_humidity_ref",
    "precipitation",
    "wind_speed_ref",
    "atmospheric_pressure_ref",
    "downward_shortwave_radiation",
    "downward_longwave_radiation",
    "diurnal_temperature_range_ref",
    "mean_annual_temperature",
    "atmospheric_co2_ref",
]

print("\nClimate variable summary")
print("-" * 110)

for variable in variables:
    if variable not in climate_ds:
        print(f"{variable:<35} Not found")
        continue

    data = climate_ds[variable]

    missing = int(data.isnull().sum().item())

    status = "✓ PASS" if missing == 0 else "✗ FAIL"

    print(
        f"{variable:<35}"
        f"min={data.min().item():8.2f}   "
        f"max={data.max().item():8.2f}   "
        f"mean={data.mean().item():8.2f}   "
        f"missing={missing:6d}   "
        f"{status}"
    )

# ------------------------------------------------------------
# DATASET QUALITY CHECK
# ------------------------------------------------------------
# Confirm whether any missing values remain in the final
# climate forcing dataset.

total_missing = int(climate_ds.to_array().isnull().sum().item())

print("\nDataset quality check")
print("-" * 60)

if total_missing == 0:
    print("✓ No missing values detected in the climate forcing dataset.")

else:
    print(
        f"✗ Warning: {total_missing} missing value(s) remain "
        "in the climate forcing dataset."
    )

# ============================================================
# SAVE CLIMATE FORCING DATASET
# ============================================================
# Save the VE climate forcing dataset as a
# compressed NetCDF file.

print("\nSaving climate forcing dataset...")

save_dataset(
    dataset=climate_ds,
    outfile=output_file,
)

print("\nClimate forcing preparation complete.")
