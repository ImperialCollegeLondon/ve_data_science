"""
---
title: VE Elevation Data Preparation and Grid Reprojection for Maliau Basin

description: |
  This script prepares Shuttle Radar Topography Mission (SRTM) elevation data
  for use in the Virtual Ecosystem (VE) model using a scenario-based grid
  definition. Unlike the standard workflow that relies on a fixed site definition,
  this script dynamically loads grid configurations from a TOML file containing
  multiple scenarios.

  The VE hydrology module requires elevation data aligned to the model grid
  resolution and spatial extent. The original SRTM DEM (typically ~30 m resolution)
  is therefore resampled to the target grid resolution defined in each scenario.
  Bilinear resampling is used to preserve smooth terrain gradients while ensuring
  consistency with VE grid structure.

  The workflow performs the following steps:
    1. Loads a selected scenario from a TOML configuration file, including:
         - Grid dimensions (nx, ny)
         - Resolution (res)
         - Grid origin (xoff, yoff)
    2. Constructs real UTM Zone 50N grid coordinates (cell_x, cell_y)
       based on scenario parameters.
    3. Loads the processed 30 m SRTM DEM for the SAFE Project region
       (covering 4°N 116°E to 5°N 117°E).
    4. Reprojects and resamples the DEM to match the scenario grid configuration
       using bilinear interpolation.
    5. Handles invalid values:
         - Masks raster nodata values
         - Fills remaining NaNs using nearest-neighbour interpolation
    6. Sorts and formats the grid into VE-style structure with dimensions (x, y)
       using real-world UTM coordinates.
    7. Exports the processed elevation dataset as a NetCDF file for VE input.

  The SRTM DEM used here was obtained from the Shuttle Radar Topography Mission
  and reprojected to UTM Zone 50N for the SAFE Project area (4°N 116°E to 5°N 117°E).
  Documentation and preprocessing steps are described on the SAFE wiki:
  https://safeproject.net/dokuwiki/safe_gis/srtm

  The reprojected SAFE Project DEM (UTM Zone 50N) is also available from:
  https://zenodo.org/records/3490488

  References: -
  Farr, T. G., et al. (2007). The Shuttle Radar Topography Mission (SRTM).
  Reviews of Geophysics, 45(2). https://doi.org/10.1029/2005RG000183

  USGS (2017). Shuttle Radar Topography Mission (SRTM) 1 Arc-Second Global.
  https://doi.org/10.5066/F7PR7TFT (Accessed: 2025-09-18)


virtual_ecosystem_module: hydrology

author:
  - Lelavathy

status: final

input_files:
  - name: SRTM_UTM50N_processed.tif
    path: data/primary/abiotic/
    description: |
      30 m SRTM DEM for the SAFE Project region (4°N 116°E to 5°N 117°E), reprojected
      to UTM Zone 50N. The dataset is available via:
      https://zenodo.org/records/349048850N.

  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau/
    description: |
      Scenario-based grid definition file containing VE grid configuration (core.grid)
      and timing configuration (core.timing)

output_files:
  - name: elevation_{scenario_name}_{nx}x{ny}.nc
    path: data/derived/abiotic/elevation_data/
    description: |
      Scenario-specific elevation dataset aligned to the VE grid, stored as
      (x, y, elevation) using real UTM coordinates. Missing values are filled
      using nearest-neighbour interpolation.

package_dependencies:
  - numpy
  - xarray
  - tomllib
  - rasterio
  - scipy.ndimage

usage_notes: |
  - Ensure that scenario definitions are properly specified in
    `maliau_grid_definition.toml` under the `Scenario` section (e.g., `maliau_1`,
    `maliau_2`, etc.).
  - In the terminal, run this script `python maliau_elevation_data_processing_script.py`
    from the project root directory.
  - Select a scenario interactively by typing its name (e.g., `maliau_1`,
    `maliau_2`) or the corresponding number when prompted.
  - The script will load the selected scenario configuration and process
    the elevation data based on the defined grid.
  - A NetCDF file will be generated in the specified `output_dir`, with a filename
    reflecting the grid dimensions, and resolution.
  - To process additional scenarios, rerun the script and select a different
    scenario.
  - Each scenario produces a separate elevation dataset aligned to its
    corresponding (x, y) UTM Zone 50N grid.

  Run as: python maliau_elevation_data_processing_script.py
---
"""  # noqa: D400, D212, D205, D415

from pathlib import Path

import numpy as np
import rasterio
import tomllib
import xarray as xr
from rasterio.enums import Resampling
from rasterio.warp import reproject
from scipy import ndimage

# ============================================================
# FILE PATHS
# ============================================================

# Define input SRTM DEM (processed and reprojected to UTM Zone 50N)
# covering the SAFE Project region (4°N 116°E to 5°N 117°E)
input_srtm = Path("data/primary/abiotic/SRTM_UTM50N_processed.tif")

# Define TOML file containing multiple VE scenarios
# Each scenario defines grid resolution, extent, and origin
toml_path = Path("data/derived/site/maliau/maliau_grid_definition.toml")

# Define output directory for storing processed elevation datasets
output_dir = Path("data/derived/abiotic/elevation_data")
output_dir.mkdir(parents=True, exist_ok=True)


# ============================================================
# LOAD SCENARIO
# ============================================================


def load_scenario(toml_path, scenario_name):
    """Load grid configuration and construct UTM coordinates for a scenario.

    This function reads the TOML configuration file, extracts the selected
    scenario, and constructs the corresponding grid parameters including
    dimensions, resolution, and real UTM50N cell centre coordinates.

    Args:
        toml_path (Path): Path to the TOML configuration file.
        scenario_name (str): Name of the scenario under `Scenario`.

    Returns:
        tuple: nx, ny, res, cell_x, cell_y arrays defining the VE grid.

    """
    # Load TOML configuration file containing multiple scenarios
    with open(toml_path, "rb") as f:
        config = tomllib.load(f)

    scenarios = config["Scenario"]

    # Validate selected scenario
    if scenario_name not in scenarios:
        raise ValueError(f"invalid scenario: {scenario_name}")

    # Extract grid configuration from selected scenario
    scenario = scenarios[scenario_name]
    grid = scenario["core"]["grid"]

    nx = grid["cell_nx"]  # number of grid cells in x direction
    ny = grid["cell_ny"]  # number of grid cells in y direction
    res = scenario["res"]  # grid resolution (m)

    ll_x = grid["xoff"]  # lower-left x coordinate (UTM)
    ll_y = grid["yoff"]  # lower-left y coordinate (UTM)

    # Construct REAL UTM grid cell centres
    # This defines spatial coordinates directly in projected space
    cell_x = ll_x + res / 2 + np.arange(nx) * res
    cell_y = ll_y + res / 2 + np.arange(ny) * res

    return nx, ny, res, cell_x.astype(np.float32), cell_y.astype(np.float32)


# ============================================================
# PROCESS ELEVATION
# ============================================================


def process_elevation(input_srtm, nx, ny, res, cell_x, cell_y):
    """Reproject and resample SRTM DEM to match the scenario grid.

    This function loads the input DEM, masks nodata values, and performs
    reprojection and bilinear resampling to align the elevation data with
    the VE grid defined by the scenario. Missing values are filled using
    nearest-neighbour interpolation.

    Args:
        input_srtm (Path): Path to the input SRTM DEM.
        nx (int): Number of grid cells in x direction.
        ny (int): Number of grid cells in y direction.
        res (float): Grid resolution (m).
        cell_x (array): UTM x coordinates.
        cell_y (array): UTM y coordinates.

    Returns:
        np.ndarray: Resampled elevation array of shape (ny, nx).

    """
    # Open SRTM DEM using rasterio
    # Provides access to georeferenced elevation raster
    with rasterio.open(input_srtm) as src:
        data = src.read(1).astype(np.float32)

        # Mask invalid nodata values using raster metadata
        nodata_val = src.nodata
        data = np.where(data == nodata_val, np.nan, data)

        # Define target VE grid transform using scenario grid
        # Aligns raster to (x, y) coordinates defined earlier
        transform = rasterio.transform.from_origin(
            west=min(cell_x) - res / 2,
            north=max(cell_y) + res / 2,
            xsize=res,
            ysize=res,
        )

        # Prepare destination array (ny, nx)
        dst = np.empty((ny, nx), dtype=np.float32)

        # Reproject and resample DEM to VE grid
        # Bilinear interpolation is used because:
        # - Elevation is continuous data
        # - Produces smooth transitions between cells
        reproject(
            source=data,
            destination=dst,
            src_transform=src.transform,
            src_crs=src.crs,
            dst_transform=transform,
            dst_crs="EPSG:32650",
            resampling=Resampling.bilinear,
        )

    # Fill missing values (NaNs) using nearest neighbour interpolation
    # Ensures spatial continuity for hydrological modelling
    if np.isnan(dst).any():
        mask = np.isnan(dst)
        idx = ndimage.distance_transform_edt(
            mask, return_distances=False, return_indices=True
        )
        dst[mask] = dst[tuple(idx[:, mask])]

    return dst


# ============================================================
# BUILD DATASET (x, y, elevation)
# ============================================================


def build_dataset(dst, cell_x, cell_y):
    """Construct an xarray Dataset with (x, y, elevation) structure.

    This function sorts the grid coordinates, reorders the elevation array,
    and formats the data into a VE-compatible xarray Dataset using real
    UTM50N coordinates.

    Args:
        dst (np.ndarray): Elevation array (ny, nx).
        cell_x (array): UTM x coordinates.
        cell_y (array): UTM y coordinates.

    Returns:
        xr.Dataset: Dataset with dimensions (x, y) and elevation variable.

    """
    # --------------------------------------------------------
    # SORT GRID (BOTTOM-LEFT ORIGIN)
    # --------------------------------------------------------

    # Ensure coordinates are ordered consistently
    x_idx = np.argsort(cell_x)
    y_idx = np.argsort(cell_y)

    x = cell_x[x_idx]
    y = cell_y[y_idx]

    # IMPORTANT:
    # Raster data is originally (y, x)
    # → reorder indices
    # → transpose to (x, y) to match VE convention
    elevation = dst[np.ix_(y_idx, x_idx)].astype(np.float32).T

    # --------------------------------------------------------
    # BUILD DATASET
    # --------------------------------------------------------
    # Create xarray Dataset with:
    #   - dimensions: (x, y)
    #   - variable: elevation (m)
    #   - coordinates: real UTM Easting/Northing

    ds = xr.Dataset(
        {"elevation": (("x", "y"), elevation)},
        coords={
            "x": ("x", x),  # UTM Easting
            "y": ("y", y),  # UTM Northing
        },
    )

    return ds


# ============================================================
# RUN PIPELINE
# ============================================================


def run(scenario_name):
    """Run the elevation processing pipeline for a selected scenario.

    This function loads the scenario configuration, processes the SRTM DEM,
    builds the VE-compatible dataset, and saves the output as a NetCDF file.

    Args:
        scenario_name (str): Scenario name defined in the TOML file.

    Returns:
        None. Output is written to disk.

    """

    # Load scenario grid configuration
    nx, ny, res, cell_x, cell_y = load_scenario(toml_path, scenario_name)

    print(f"\nrunning scenario: {scenario_name}")
    print(f"grid: {nx} x {ny}")

    # Process elevation data
    dst = process_elevation(input_srtm, nx, ny, res, cell_x, cell_y)

    # Convert to structured dataset
    ds = build_dataset(dst, cell_x, cell_y)

    # Define output file name based on scenario and grid properties
    output_file = output_dir / f"elevation_{scenario_name}_{nx}x{ny}.nc"

    # Save dataset to NetCDF
    ds.to_netcdf(output_file)

    print(f"\nsaved: {output_file}")
    print("\nDataset structure:\n", ds)


# ============================================================
# INTERACTIVE ENTRY POINT
# ============================================================
# Loads scenarios from the TOML file, displays them, prompts user selection,
# validates the input, and runs the selected scenario via `run()`.

if __name__ == "__main__":
    # Load available scenarios from TOML file
    with open(toml_path, "rb") as f:
        config = tomllib.load(f)

    scenarios = list(config["Scenario"].keys())

    print("\navailable scenarios:\n")
    for i, s in enumerate(scenarios, start=1):
        print(f" {i}. {s}")

    # Interactive selection
    choice = input("\nselect scenario: ").strip()

    if choice.isdigit():
        scenario_name = scenarios[int(choice) - 1]
    elif choice in scenarios:
        scenario_name = choice
    else:
        raise ValueError("invalid selection")

    # Run full processing pipeline
    run(scenario_name)
