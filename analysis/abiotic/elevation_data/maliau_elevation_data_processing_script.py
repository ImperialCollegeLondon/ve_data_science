"""
---
title: Processing Script for SRTM Elevation Input Data for Maliau Basin.

description: |
  This script prepares SRTM elevation input data for the Virtual Ecosystem
  (VE) model, focusing on the Maliau Basin site. It automates loading the site
  scenario, defining the VE target grid, reprojecting and resampling elevation
  data, and exporting a VE-compatible elevation NetCDF dataset.

  Specifically, it:
    1. Loads the VE site configuration from a TOML file.
    2. Defines the VE target grid from the site configuration.
    3. Loads a source SRTM DEM raster.
    4. Reprojects and interpolates elevation onto the VE target grid.
    5. Fills any remaining missing values by nearest-neighbour lookup.
    6. Creates a VE-style elevation dataset with dimensions (x, y).
    7. Adds global metadata and saves a compressed NetCDF output.

virtual_ecosystem_module:
  - hydrology

author:
  - Lelavathy Samikan

status: final

input_files:
  - name: SRTM_UTM50N_processed.tif
    path: data/primary/abiotic
    description: |
      Processed SRTM DEM for the study region in UTM Zone 50N.

  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau
    description: |
      Site and scenario definitions including VE grid and timing metadata.

output_files:
  - name: elevation_<scenario>.nc
    path: data/derived/abiotic/elevation_data
    description: |
      VE-compatible elevation dataset aligned to the scenario target grid.

package_dependencies:
  - pathlib
  - xarray
  - rasterio

usage_notes: |
  Run from the project root as:

uv run python analysis/abiotic/elevation_data/maliau_elevation_data_processing_script.py

  Before running this script:
    - Ensure project dependencies are installed with uv (`uv sync`).
    - Ensure the source DEM exists at data/primary/abiotic/SRTM_UTM50N_processed.tif.
    - Ensure `maliau_grid_definition.toml` contains the selected scenario.

  To adapt to another site or scenario, update:
    - `scenario_name`
    - `input_srtm`
    - `grid_file`

references: |
  Farr, T. G., et al. (2007). The Shuttle Radar Topography Mission (SRTM).
  Reviews of Geophysics, 45(2). https://doi.org/10.1029/2005RG000183
---
"""  # noqa: D212, D205

import sys
from pathlib import Path

# ============================================================
# PROJECT ROOT
# ============================================================
# Resolve the repository root and expose it on sys.path so
# local project modules can be imported reliably.

project_root = Path(__file__).resolve().parents[3]
python_source = project_root / "tools" / "python" / "src"

if str(python_source) not in sys.path:
    sys.path.insert(0, str(python_source))

from ve_data_tools import (  # noqa: E402
    build_target_grid,
    read_site_config,
    write_dataset,
)
from ve_data_tools import elevation_tools as et  # noqa: E402

# ============================================================
# USER SETTINGS
# ============================================================
# Select  scenario (e.g., " maliau_1", "maliau_2") defined in the site
# configuration TOML file (e.g.,"maliau_grid_definition.toml").

scenario_name = "maliau_1"
# NOTE:
# Modify the scenario name defined in the site-specific
# configuration TOML file to prepare climate data for a
# different study site (e.g. SAFE or Danum).

# Name of the elevation data source to use. The elevation data
# must be provided as a raster dataset covering the study area.
# For example: "SRTM", "ASTER", or another DEM raster.
source = "SRTM"

# ============================================================
# PATHS
# ============================================================
# Build input and output paths used by this workflow and
# ensure the destination directory exists.

root_dir = Path(__file__).resolve().parents[3]

grid_file = (
    root_dir / "data" / "derived" / "site" / "maliau" / "maliau_grid_definition.toml"
)

input_srtm = root_dir / "data" / "primary" / "abiotic" / "SRTM_UTM50N_processed.tif"

output_dir = root_dir / "data" / "derived" / "abiotic" / "elevation_data"

output_dir.mkdir(
    parents=True,
    exist_ok=True,
)

# ============================================================
# READ SITE CONFIGURATION
# ============================================================
# Load the selected scenario configuration and derive timing,
# target grid geometry, and output filename metadata.

scenario = read_site_config.read_site_configuration(
    grid_file,
    scenario_name,
)

timing = scenario["core"]["timing"]

start_date = timing["start_date"]
start_year = int(start_date[:4])

run_length = int(timing["run_length"].split()[0])

end_year = start_year + run_length - 1

target_grid = build_target_grid.get_target_grid(scenario)

output_file = output_dir / f"elevation_{scenario_name}.nc"

# ============================================================
# PROCESS ELEVATION
# ============================================================
# Reproject and interpolate the DEM onto the VE grid, then
# package the interpolated raster into a VE-style dataset.

print("\nProcessing elevation data...")

elevation_array = et.interpolate_elevation_to_grid(
    input_raster=input_srtm,
    target_grid=target_grid,
)

elevation_ds = et.create_elevation_dataset(
    elevation=elevation_array,
    target_grid=target_grid,
)

elevation_ds = et.add_global_attributes(
    elevation_ds,
    scenario_name,
    source,
)

# ============================================================
# DATASET SUMMARY
# ============================================================
# Print key metadata and basic quality statistics to verify
# elevation coverage before writing output.

print("\nElevation dataset summary")
print("-" * 60)

print(
    f"Site: {scenario_name}\n"
    f"Simulation period: {start_year}-{end_year}\n"
    f"Grid size: {scenario['cell_nx']} x {scenario['cell_ny']} cells\n"
    f"Spatial resolution: {scenario['res']} m"
)

elevation_data = elevation_ds["elevation"]
missing = int(elevation_data.isnull().sum().item())
status = "PASS" if missing == 0 else "FAIL"

print("\nElevation variable summary")
print("-" * 80)

print(
    f"elevation{'':<26}"
    f"min={elevation_data.min().item():8.2f}   "
    f"max={elevation_data.max().item():8.2f}   "
    f"mean={elevation_data.mean().item():8.2f}   "
    f"missing={missing:6d}   "
    f"{status}"
)

# ============================================================
# SAVE ELEVATION DATASET
# ============================================================
# Save the final elevation forcing dataset as a compressed
# NetCDF file at the derived output path.

print("\nSaving elevation dataset...")

write_dataset.save_dataset(
    dataset=elevation_ds,
    outfile=output_file,
)

print("\nElevation data preparation complete.")
