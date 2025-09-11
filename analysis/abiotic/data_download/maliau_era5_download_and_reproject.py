"""
---
title: ERA5 data download and reproject for the Maliau site

description: |
  This file uses the `cdsapi_era5_downloader` function to download a 3x3 grid at 0.1°
  resolution from 2010 to 2020 around the Maliau basin data sites.

  It then uses the `rasterio` package to reproject and interpolate those values to the
  90m resolution grid defined in the Maliau basin site definition file. The script
  currently uses the `nearest` interpolation strategy to map values from the 0.1° cells
  to 90m cells, but we may want to revisit this.

  Muñoz Sabater, J. (2019): ERA5-Land monthly averaged data from 1950 to present.
  Copernicus Climate Change Service (C3S) Climate Data Store (CDS).
  DOI: 10.24381/cds.68d2bb30 (Last accessed on xx-xx-2025)

author:
  - name: Lelavathy
  - name: David Orme

virtual_ecosystem_module: abiotic, abiotic_simple, hydrology

status: final

input_files:
  - name: maliau_grid_definition.toml
    path: analysis/core
    description: Site grid definition for Maliau

output_files:
  - name: ERA5_Maliau_2010_2020.nc
    path: data/primary/abiotic/era5_land_monthly
    description: 2010-2020 ERA5 data for Maliau in original 0.1° resolution.
  - name: ERA5_Maliau_2010_2020_UTM50N.nc
    path: data/primary/abiotic/era5_land_monthly
    description: 2010-2020 ERA5 data for Maliau reprojected to 90m UTM50N grid.

package_dependencies:
  - cdsapi
  - xarray
  - tomllib
  - rasterio
  - rioxarray

usage_notes: |
  Run as `python maliau_era5_download_and_reproject.py`

---
"""  # noqa: D205, D212, D400, D415

from pathlib import Path

import tomllib
import xarray
from cdsapi_downloader import cdsapi_era5_downloader
from rasterio import Affine
from rasterio.crs import CRS
from rasterio.warp import Resampling

# Define output directory and filename
output_dir = Path("../../../data/primary/abiotic/era5_land_monthly")
output_dir.mkdir(parents=True, exist_ok=True)

output_filename = output_dir / "ERA5_Maliau_2010_2020.nc"

# Run the downloader tool
cdsapi_era5_downloader(
    years=list(range(2010, 2021)),
    bbox=[4.6, 116.8, 4.8, 117.0],
    outfile=output_filename,
)

# Define the projections to be used
wgs84_crs = CRS.from_epsg(4326)
utm50N_crs = CRS.from_epsg(32650)

# Load the destination grid details
with open("../../../sites/maliau_site_definition.toml", "rb") as maliau_grid_file:
    utm50N_grid_details = tomllib.load(maliau_grid_file)

# Define the XY shape of the data in the destination dataset
dest_shape = (
    utm50N_grid_details["cell_nx"],
    utm50N_grid_details["cell_ny"],
)

# Define the affine matrix giving the coordinates of pixels in the destination dataset
dest_transform = Affine(
    utm50N_grid_details["res"],
    0,
    utm50N_grid_details["ll_x"],
    0,
    utm50N_grid_details["res"],
    utm50N_grid_details["ll_y"],
)

# Open the ERA5 dataset in WGS84 and and set the CRS manually because it is not
# set in the file. Do not decode times from CF to np.datetime64, because we'd have
# to convert back to write the file.
era5_data_WGS84 = xarray.open_dataset(
    output_filename,
    engine="rasterio",
    decode_times=False,
)
era5_data_WGS84 = era5_data_WGS84.rio.write_crs(wgs84_crs)

# Use the rasterio accessor tools to reproject the data

# NOTE: The reprojection is automatically applying downscaling to the 90m grid
# definition. The interpolation mapping used here at the moment is the `nearest`
# method of rasterio. Other methods are available:
#
# https://rasterio.readthedocs.io/en/stable/api/rasterio.enums.html#rasterio.enums.Resampling
#
# We might want to use a different interpolation strategy to give a smooth surface -
# something like a cubic interpolation or a spline - but it isn't clear to me right now
# if we'd be better off doing that or simply taking the nearest value and then doing
# something more scientifically informed from that baseline.

era5_data_UTM50N = era5_data_WGS84.rio.reproject(
    dst_crs=utm50N_crs,
    shape=dest_shape,
    transform=dest_transform,
    resampling=Resampling.nearest,
)

# Save the reprojected data to file
era5_data_UTM50N.to_netcdf(output_dir / "ERA5_Maliau_2010_2020_UTM50N.nc")
