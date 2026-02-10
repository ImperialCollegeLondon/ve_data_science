"""
---
title: VE Climate Data Downloader, Conversion, and Grid Reprojection for Maliau Basin

description: |
  This script prepares ERA5-Land climate data for the Virtual Ecosystem (VE) model,
  focusing on the Maliau Basin site. It automates downloading, reprojection, and
  variable transformation of ERA5-Land monthly averaged data (2010-2020). The workflow
  includes grid preparation, unit conversion, and standardization to VE naming
  conventions.

  Specifically, it:
    1. Loads a TOML grid definition specifying resolution, cell size, and EPSG code.
    2. Downloads or loads ERA5-Land monthly averaged data (2010-2020) using the CDS API.
    3. Sets CRS and reprojects ERA5 data from WGS84 to UTM Zone 50N.
    4. Converts units:
         - Temperature (K → °C)
         - Precipitation (m → mm)
         - Pressure (Pa → kPa)
         - Downward shortwave radiation (J/m² → W/m²)
         - Downward longwave radiation (J/m² → W/m²)
    5. Derives relative humidity, mean annual temperature, and constant atmospheric CO₂.
    6. Renames variables to VE-standard names:
         - sp_kPa → atmospheric_pressure_ref
         - tp_mm → precipitation
         - t2m_C → air_temperature_ref
         - rh → relative_humidity_ref
         - u10 → wind_speed_ref
         - ssrd_Wm-2 → downward_shortwave_radiation
         - strd_WM-2 → downward_longwave_radiation
    7. Reformats datasets to VE-style grid dimensions (x, y, time_index).
    8. Saves processed NetCDF outputs for use in the VE Abiotic model.


  References:-
    Muñoz-Sabater, J., et al. (2021). ERA5-Land: A state-of-the-art global
    reanalysis dataset for land applications. Earth System Science Data, 13(9),
    4349-4383.https://doi.org/10.5194/essd-13-4349-2021

    Muñoz-Sabater, J. (2019). ERA5-Land monthly averaged data from 1981 to present.
    Copernicus Climate Change Service (C3S) Climate Data Store (CDS).
    https://doi.org/10.24381/cds.68d2bb30 (Accessed: 11-09-2025)

  Notes:-
    - Ensure CDS API is configured in ~/.cdsapirc before running.
    - For large variable downloads, it is recommended to run one variable at a time.


virtual_ecosystem_module: abiotic, hydrology

author:
  - Lelavathy
  - David Orme

status: final

input_files:
  - name: maliau_grid_definition.toml
    path: data/sites
    description: |
      Defines the target VE grid structure (cell_nx, cell_ny, resolution,
      lower-left coordinates, EPSG code) for regridding ERA5-Land data.

output_files:
  - name: era5_monthly_2010_2020_maliau.nc
    path: data/primary/abiotic/era5_land_monthly
    description: |
      ERA5-Land monthly averaged data (2010-2020) for Maliau Basin in original 0.1°
      resolution, downloaded from the Copernicus Climate Data Store (CDS).

  - name: era5_maliau_2010_2020_90m.nc
    path: data/derived/abiotic/era5_land_monthly
    description: |
      Processed ERA5-Land data (2010-2020), reprojected to UTM Zone 50N, converted
      to VE units, and aligned with the Maliau grid for VE model integration.

package_dependencies:
  - numpy
  - xarray
  - tomllib
  - rasterio
  - rioxarray
  - cdsapi

usage_notes: |
  Run as:
    python maliau_climate_data_processing_script.py

---

"""  # noqa: D400, D212, D205, D415

from pathlib import Path

import numpy as np
import tomllib
import xarray
import xarray as xr
from cdsapi_downloader import cdsapi_era5_downloader
from rasterio import Affine
from rasterio.crs import CRS
from rasterio.warp import Resampling

# Define output directory and filename for the downloaded ERA5 data from the CDS
output_dir = Path("../../../data/primary/abiotic/era5_land_monthly")
output_dir.mkdir(parents=True, exist_ok=True)
output_filename = output_dir / "era5_monthly_2010_2020_maliau.nc"

# Define the output directory and filename for the reprojected and unit-converted
# ERA5 data (spatially interpolated) to be used in the VE model
output_dir_reprojected = Path(".../../../data/derived/abiotic/era5_land_monthly")
output_dir_reprojected.mkdir(parents=True, exist_ok=True)
output_filename_reprojected = output_dir_reprojected / "eRA5_maliau_2010_2020_90m.nc"

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
    site_config = tomllib.load(maliau_grid_file)

# Define the XY shape of the data in the destination dataset
dest_shape = (
    site_config["cell_nx"],
    site_config["cell_ny"],
)

# Define the affine matrix giving the coordinates of pixels in the destination dataset
dest_transform = Affine(
    site_config["res"],
    0,
    site_config["ll_x"],
    0,
    site_config["res"],
    site_config["ll_y"],
)

# Open the ERA5 dataset in WGS84 and and set the CRS manually because it is not
# set in the file. Do not decode times from CF to np.datetime64, because we'd have
# to convert back to write the file.
era5_data_WGS84 = xarray.open_dataset(
    output_filename,
    engine="netcdf4",
    decode_times=False,
)
era5_data_WGS84 = era5_data_WGS84.rio.write_crs(wgs84_crs)

# Use the rasterio accessor tools to reproject the data

era5_data_UTM50N = era5_data_WGS84.rio.reproject(
    dst_crs=utm50N_crs,
    shape=dest_shape,
    transform=dest_transform,
    resampling=Resampling.nearest,
)
# The interpolation mapping used here at the moment is the `nearest`method of rasterio.
# Other methods are available:
# https://rasterio.readthedocs.io/en/stable/api/rasterio.enums.html#rasterio.enums.Resampling
# We might want to use a different interpolation strategy to give a smooth surface -

# Note:
# The Virtual Ecosystem example data is run on a 90 x 90 m grid.
# This means that some form of spatial downscaling has to be applied to the dataset,
# for example by spatially interpolating coarser resolution climate data and including
# the effects of local topography.
# This is not yet implemented!


# Unit conversions
dataset = era5_data_UTM50N

# The standard output unit of 2m dewpoint temperature (d2m ) and 2m air temperature
# (t2m) is Kelvin (K) which we need to convert to degree Celsius (C) for the
# Virtual Ecosystem.
dataset["t2m_C"] = dataset["t2m"] - 273.15
dataset["d2m_C"] = dataset["d2m"] - 273.15

# Relative humidity (rh) is not a standard output from ERA5-Land but can be calculated
# from 2m dewpoint temperature (d2m in C) and 2m air temperature (t2m in C)
dataset["rh"] = 100.0 * (
    np.exp(17.625 * dataset["d2m_C"] / (243.04 + dataset["d2m_C"]))
    / np.exp(17.625 * dataset["t2m_C"] / (243.04 + dataset["t2m_C"]))
)

# The standard output unit for total precipitation (tp) in ERA5-Land is meters (m)
# which we need to convert to millimeters (mm). Further, the data represents mean daily
# accumulated precipitation for the 9x9km grid box, so the value has to be scaled to
#  monthly (here 30 days). TODO handle daily inputs
dataset["tp_mm"] = dataset["tp"] * 1000 * 30

# The standard output unit for surface pressure (sp) in ERA5-Land is Pascal (Pa) which
# weneed to convert to kilopascal (kPa) by dividing by 1000.
dataset["sp_kPa"] = dataset["sp"] / 1000

# The standard output unit for surface solar radiation downward (ssrd) in ERA5-Land is
# Joule per square meter (Jm-2) which need to be converted to Watts per square meter
# (Wm-2) by dividing by the number of seconds in a month
dataset["ssrd_Wm-2"] = dataset["ssrd"] / 2592000

# The standard output unit for surface thermal radiation downward (strd) in ERA5-Land is
# Joule per square meter (Jm-2) which need to be converted to Watts per square meter
# (Wm-2) by dividing by the number of seconds in a month
dataset["strd_Wm-2"] = dataset["strd"] / 2592000

# Rename variables to match the Virtual Ecosystem conventions.
dataset_cleaned = dataset.drop_vars(["d2m", "d2m_C", "t2m", "tp", "sp", "ssrd", "strd"])
dataset_renamed = dataset_cleaned.rename(
    {
        "sp_kPa": "atmospheric_pressure_ref",
        "tp_mm": "precipitation",
        "t2m_C": "air_temperature_ref",
        "rh": "relative_humidity_ref",
        "u10": "wind_speed_ref",
        "ssrd_Wm-2": "downward_shortwave_radiation",
        "strd_Wm-2": "downward_longwave_radiation",
    }
)

# Add constant variables
# In addition to the variables from the ERA5-Land datasset, a time series of atmospheric
# CO2 is needed. We add this here as a constant field of 400ppm.
air_temp_shape = dataset_renamed["air_temperature_ref"].shape
dataset_renamed["atmospheric_co2_ref"] = xr.DataArray(
    400 * np.ones(air_temp_shape),
    dims=dataset_renamed["air_temperature_ref"].dims,
    coords=dataset_renamed["air_temperature_ref"].coords,
)

# Mean annual temperature is calculated from the full time series of air temperatures

# Mean annual temperature is calculated from the full time series of air temperatures
time_dim = next(
    dim for dim in dataset_renamed["air_temperature_ref"].dims if "time" in dim
)

dataset_renamed["mean_annual_temperature"] = dataset_renamed[
    "air_temperature_ref"
].mean(dim=time_dim)

# Note:
# In the future we plan to include a time series of mean annual data for every year.

# Reformat x, y and time_index dimensions into VE-style dataset:
# This section converts the reprojected climate dataset into the
# Virtual Ecosystem (VE) spatial layout, using x and y as physical
# spatial dimensions and time_index as the temporal dimension.
cell_x = np.array(site_config["cell_x_centres"])  # UTM eastings
cell_y = np.array(site_config["cell_y_centres"])  # UTM northings
epsg_code = site_config["epsg_code"]
res = site_config["res"]  # target resolution (90 m)


# The original grid coordinates (cell_x, cell_y) represent projected UTM
# cell-centre positions. To ensure consistency with VE inputs, these coordinates are
# converted to distances relative to the grid origin (cell centre based).
# This results in regularly spaced x and y coordinates starting at 0 and increasing by
# the grid resolution.
x = cell_x - cell_x[0]
y = cell_y - cell_y[0]

# Identify the existing time dimension name in the dataset (e.g. 'time'),
# allowing the script to remain robust to different NetCDF conventions.
time_dim = next(
    dim for dim in dataset_renamed["air_temperature_ref"].dims if "time" in dim
)

# Rename the time dimension to "time_index" and assign spatial
# coordinates (x, y) as explicit coordinate variables.
n_time = dataset_renamed.sizes[time_dim]

dataset_xyt = dataset_renamed.rename_dims({time_dim: "time_index"}).assign_coords(
    {
        "x": x.astype(np.float32),
        "y": y.astype(np.float32),
        "time_index": np.arange(n_time, dtype=np.int32),
    }
)


# Explicitly enforce dimension order as (x, y, time_index).
dataset_xyt = dataset_xyt.transpose("x", "y", "time_index")

# Print a concise summary to confirm that the dataset has been
# successfully reformatted to the VE grid and time structure,
# including grid size, resolution, and number of time steps.
print(
    f"✅ Reformatted to VE-style TOML grid: "
    f"cell_nx = {site_config['cell_nx']}, "
    f"cell_ny = {site_config['cell_ny']}, "
    f"resolution = {site_config['res']} m, "
    f"time steps = {dataset_renamed.sizes[time_dim]}"
)

# Once we confirmed that our dataset is complete and our calculations are correct, we
# save it as a new netcdf file.
dataset_xyt.to_netcdf(output_filename_reprojected)


# Print a summary of the reprojected dataset

print(
    f"✅ Reformatted to VE-style TOML grid: "
    f"cell_nx = {site_config['cell_nx']}, "
    f"cell_ny = {site_config['cell_ny']}, "
    f"resolution = {site_config['res']} m, "
    f"time steps = {dataset_renamed.sizes[time_dim]}"
)

# Once we confirmed that our dataset is complete and our calculations are correct, we
# save it as a new netcdf file.
dataset_xyt.to_netcdf(output_filename_reprojected)

# Print summary statistics for key variables to check values
vars_to_check = [
    "air_temperature_ref",
    "relative_humidity_ref",
    "precipitation",
    "wind_speed_ref",
    "atmospheric_pressure_ref",
    "downward_shortwave_radiation",
    "downward_longwave_radiation",
    "atmospheric_co2_ref",
    "mean_annual_temperature",
]

print("✅ Variable summary statistics:")
for var in vars_to_check:
    if var in dataset_renamed:
        da = dataset_renamed[var]
        print(
            f"{var}: "
            f"min={da.min().item():.2f}, "
            f"max={da.max().item():.2f}, "
            f"mean={da.mean().item():.2f}"
        )
    else:
        print(f"{var}: Not found in dataset")
