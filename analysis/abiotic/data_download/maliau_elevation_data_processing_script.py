"""
---
title: VE Elevation Data Preparation and Grid Reprojection for Maliau Basin

description: |
  This script prepares Shuttle Radar Topography Mission (SRTM) elevation data
  for use in the Virtual Ecosystem (VE) model. The VE hydrological module
  requires elevation input aligned to a resolution of 90 m grid, whereas the original
  SRTM product is provided at approximately 30 m resolution. To reconcile this
  difference, the elevation data is resampled to the target 90 m grid using
  bilinear aggregation, which smooths fine-scale terrain while preserving
  broad-scale topographic patterns. This ensures consistency with the VE spatial
  resolution. In future, terrain-preserving or hydrologically explicit
  resampling approaches could also be explored.

  The workflow performs the following steps:
    1. Loads a TOML site definition specifying the projected VE grid
       (cell_x, cell_y, resolution, EPSG code) for Maliau Basin in UTM Zone 50N.
    2. Loads the processed 30 m SRTM DEM for the SAFE Project region
       (covering 4°N 116°E to 5°N 117°E).
    3. Defines the target VE grid in UTM Zone 50N using maliau_site_definition.toml.
    4. Resamples the 30 m DEM to 90 m resolution using bilinear resampling.
    5. Handles invalid values:
         - Masks raster nodata values
         - Fills remaining NaNs using nearest-neighbour interpolation
    6. Reformats the elevation dataset into VE-style (x, y, elevation) layout.
    7. Saves the processed NetCDF output ready for VE abiotic model use.

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

virtual_ecosystem_module: Abiotic

author:
  - Lelavathy Samikan

status: final

input_files:
  - name: SRTM_UTM50N_processed.tif
    path: data/sites/
    description: |
      30 m SRTM DEM for the SAFE Project region (4°N 116°E to 5°N 117°E), reprojected
      to UTM Zone 50N. The dataset is available via:
      https://zenodo.org/records/3490488

  - name: maliau_site_definition.toml
    path: data/sites/
    description: |
      Site definition file specifying the target VE grid for Maliau Basin.
      Contains x/y cell centres, grid resolution (90 m), and projection details
      in UTM Zone 50N (EPSG:32650).

output_files:
  - name: elevation_Maliau_2010_2020_UTM50N.nc
    path: data/derived/abiotic/elevation_data/
    description: |
      Elevation dataset resampled to a 90 m grid in UTM Zone 50N. Invalid values
      (nodata) are filled using nearest-neighbour interpolation. The output is
      formatted in VE-style with flattened x, y, and elevation arrays.

package_dependencies:
  - numpy
  - xarray
  - tomllib
  - rasterio
  - scipy.ndimage

usage_notes: |
  Run using: python maliau_elevation_data_processing_script.py
  The script checks for nodata or NaN elevation values and replaces them with
  nearest-neighbour values to ensure a clean DEM input for the VE hydrology
  model.
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

# Define input directory and filename for the SRTM dataset for the SAFE Project area,
# covering the region 4°N 116°E to 5°N 117°E
input_srtm = Path("../../../data/sites/SRTM_UTM50N_processed.tif")


# Define the output directory and filename for the reprojected and spatially
# interpolated elevation data to be used in the VE model
output_dir = Path("../../../data/derived/abiotic/elevation_data")
output_dir.mkdir(parents=True, exist_ok=True)
output_filename = output_dir / "elevation_Maliau_2010_2020_UTM50N.nc"

# Load the destination grid details
with open("../../../sites/maliau_site_definition.toml", "rb") as f:
    site_config = tomllib.load(f)

cell_x = np.array(site_config["cell_x_centres"])  # UTM eastings
cell_y = np.array(site_config["cell_y_centres"])  # UTM northings
epsg_code = site_config["epsg_code"]
res = site_config["res"]  # target resolution (90 m)

# Open the input SRTM (Shuttle Radar Topography Mission) DEM file using rasterio.
# This provides access to the georeferenced raster data (elevation values).
with rasterio.open(input_srtm) as src:
    data = src.read(1).astype(float)
    data = np.where(data < 0, np.nan, data)  # mask invalid

    # Prepare the target grid following the resolution and spatial extent we want for
    # resampling the DEM. This grid will be used to reproject or resample
    # the original SRTM data.
    ny, nx = len(cell_y), len(cell_x)
    transform = rasterio.transform.from_origin(
        west=min(cell_x) - res / 2, north=max(cell_y) + res / 2, xsize=res, ysize=res
    )
    dst_data = np.empty((ny, nx), dtype=np.float32)

    # We use `bilinear`resampling method,  which averages values within a block of
    # cells to compute the new cell value. This is smoother than nearest-neighbor,
    # avoids artifacts, and is suitable for continuous data like elevation.

    reproject(
        source=data,
        destination=dst_data,
        src_transform=src.transform,
        src_crs=src.crs,
        dst_transform=transform,
        dst_crs=f"EPSG:{epsg_code}",
        resampling=Resampling.bilinear,
    )

# Note:
# In future, we could also consider methods that explicitly capture terrain
# variability (e.g., variance-preserving aggregation) or preserve hydrological
# connectivity (e.g., flow-directed resampling).
# This is not yet implemented!

# Use the nodata value from the raster metadata to mask invalid data
nodata_val = src.nodata
dst_data = np.where(dst_data == nodata_val, np.nan, dst_data)

# Note:
# Many DEM products (e.g., SRTM, ASTER, Copernicus DEM) use special placeholder
# values such as -9999 or -32768 to indicate missing data (nodata). These values
# are not real elevations and must be masked out.
# Instead of assuming all negative values are invalid (which would incorrectly
# remove genuine terrain below sea level), we read the official "nodata" value
# from the raster metadata (src.nodata) and replace only those flagged cells
# with NaN.This makes the script more general-purpose and safe for use in
# coastal or low-lying regions where valid elevations can be negative.


# If NaNs remain, fill with nearest neighbor
# This ensures the DEM is spatially continuous and can be used in hydrological
# or other modeling workflows without gaps.
if np.isnan(dst_data).any():
    mask = np.isnan(dst_data)
    filled_data = dst_data.copy()

    nearest_index = ndimage.distance_transform_edt(
        mask, return_distances=False, return_indices=True
    )
    filled_data[mask] = dst_data[tuple(nearest_index[:, mask])]
    dst_data = filled_data

# After cleaning and resampling, we prepare the DEM in a structured dataset format.
elev_flat = dst_data.flatten()
x_flat, y_flat = np.meshgrid(cell_x, cell_y)
x_flat = x_flat.flatten()
y_flat = y_flat.flatten()

# Build an xarray Dataset with coordinates and elevation
# Each grid cell is flattened into a single row, indexed by the "points" dimension.
#   - "points" acts as a simple index (0, 1, 2, …) for each grid cell.
#   - Variables:
#       * x: easting coordinate of the grid cell centre (UTM)
#       * y: northing coordinate of the grid cell centre (UTM)
#       * elevation: elevation value (m) at that grid cell
dataset_xy = xr.Dataset(
    {
        "x": (("points",), x_flat.astype(np.float32)),
        "y": (("points",), y_flat.astype(np.float32)),
        "elevation": (("points",), elev_flat.astype(np.float32)),
    },
    coords={"points": np.arange(len(x_flat))},
)


# Once we have reprojected, resampled, and validated the elevation dataset
# (with all invalid values handled), we save the final result as a NetCDF file.
dataset_xy.to_netcdf(output_filename)

print(f"✅ Saved resampled elevation ({res} m) to {output_filename}")
