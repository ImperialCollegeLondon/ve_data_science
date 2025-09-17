# ---
# title: VE Climate Data Downloader, Conversion, and Grid Reprojection for Maliau Basin
#
# description:
#   This script prepares ERA5-Land climate data for the Virtual Ecosystem (VE) model. It performs the following steps:
#
#     1. Loads a TOML site definition that specifies a projected grid (cell_nx, cell_ny, resolution, lower-left coordinates, EPSG code).
#     2. Downloads (or loads) monthly ERA5-Land data (2010–2020) for the Maliau site using `cdsapi_era5_downloader`.
#     3. Sets CRS and reprojects the ERA5 data from WGS84 to the target UTM50N grid.
#     4. Performs unit conversions: temperature (K → °C), precipitation (m → mm), pressure (Pa → kPa), shortwave radiation (J/m² → W/m²).
#     5. Derives additional variables: relative humidity, mean annual temperature, constant atmospheric CO₂.
#     6. Renames variables to match VE naming conventions:
#          - sp_kPa → atmospheric_pressure_ref
#          - tp_mm → precipitation
#          - t2m_C → air_temperature_ref
#          - rh → relative_humidity_ref
#          - u10 → wind_speed_ref
#          - ssrd_Wm-2 → downward_shortwave_radiation
#     7. Reformats the dataset into VE-style dimensions and coordinates (x, y, time_index) using the TOML grid.
#     8. Saves processed NetCDF output ready for VE abiotic model use.
#
# virtual_ecosystem_module: Abiotic, Hydrology
#
# author:
#   - name: Lelavathy & David
#
# status: final
#
# input_files:
#   - name: maliau_grid_definition.toml
#     path: "data/sites"
#     description: Defines the target VE grid (cell_nx, cell_ny, resolution, lower-left coordinates, EPSG code)
#     for regridding ERA5 data.
#
# output_files:
#  - name: ERA5_Maliau_2010_2020.nc
#    path: data/primary/abiotic/era5_land_monthly
#    description: 2010-2020 ERA5 data for Maliau in original 0.1° resolution.
#
#  - name: ERA5_Maliau_2010_2020_UTM50N.nc
#    path: data/derived/abiotic/era5_land_monthly
#    description: ERA5 data (2010–2020), unit-converted and reprojected to the 90 m UTM Zone 50N grid for Maliau.
#
#
# package_dependencies:
#   - numpy
#   - xarray
#   - tomllib
#   - rasterio
#   - rioxarray
#   - cdsapi
#
# usage_notes:Run as `python climate_data_processing_script.py`
#
# References:
# Muñoz-Sabater, J., et al. (2021). ERA5-Land: A state-of-the-art global reanalysis
# dataset for land applications. Earth System Science Data, 13(9), 4349–4383.
# https://doi.org/10.5194/essd-13-4349-2021
#
# Muñoz-Sabater, J. (2019). ERA5-Land monthly averaged data from 1981 to present.
# Copernicus Climate Change Service (C3S) Climate Data Store (CDS).
# https://doi.org/10.24381/cds.68d2bb30  (Last accessed: 11-09-2025)
#
# ----

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

output_filename = output_dir / "ERA5_monthly_2010_2020_Maliau.nc"

# Define the output directory for the reprojected and unit-converted ERA5 data
# (spatially interpolated) to be used in the VE model
output_dir_reprojected = Path(".../../../data/derived/abiotic/era5_land_monthly")
output_dir_reprojected.mkdir(parents=True, exist_ok=True)

output_filename_reprojected = output_dir_reprojected / "ERA5_Maliau_2010_2020_UTM50N.nc"

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
# Other methods are available:https://rasterio.readthedocs.io/en/stable/api/rasterio.enums.html#rasterio.enums.Resampling
# We might want to use a different interpolation strategy to give a smooth surface -

# Note:
# The Virtual Ecosystem example data is run on a 90 x 90 m grid.
# This means that some form of spatial downscaling has to be applied to the dataset, for example by spatially
# interpolating coarser resolution climate data and including the effects of local topography.
# This is not yet implemented!

# ---------------------------
# 4. Unit conversions
# ---------------------------
dataset = era5_data_UTM50N

# The standard output unit of 2m dewpoint temperature (d2m ) and 2m air temperature (t2m) is Kelvin (K)
# which we need to convert to degree Celsius (C) for the Virtual Ecosystem.
dataset["t2m_C"] = dataset["t2m"] - 273.15
dataset["d2m_C"] = dataset["d2m"] - 273.15

# Relative humidity (rh) is not a standard output from ERA5-Land but can be calculated
# from 2m dewpoint temperature (d2m in C) and 2m air temperature (t2m in C)
dataset["rh"] = 100.0 * (
    np.exp(17.625 * dataset["d2m_C"] / (243.04 + dataset["d2m_C"]))
    / np.exp(17.625 * dataset["t2m_C"] / (243.04 + dataset["t2m_C"]))
)

# The standard output unit for total precipitation (tp) in ERA5-Land is meters (m) which we need
# to convert to millimeters (mm). Further, the data represents mean daily accumulated
# precipitation for the 9x9km grid box, so the value has to be scaled to monthly (here
# 30 days). TODO handle daily inputs
dataset["tp_mm"] = dataset["tp"] * 1000 * 30

# The standard output unit for surface pressure (sp) in ERA5-Land is Pascal (Pa) which we
# need to convert to kilopascal (kPa) by dividing by 1000.
dataset["sp_kPa"] = dataset["sp"] / 1000

# The standard output unit for surface solar radiation downward (ssrd) in ERA5-Land is Joule per square meter (Jm-2)
# which need to be converted to Watts per square meter(Wm-2) by dividing by the number of seconds in a month
dataset["ssrd_Wm-2"] = dataset["ssrd"] / 2592000

# Rename variables to match the Virtual Ecosystem conventions.
dataset_cleaned = dataset.drop_vars(["d2m", "d2m_C", "t2m", "tp", "sp", "ssrd"])
dataset_renamed = dataset_cleaned.rename(
    {
        "sp_kPa": "atmospheric_pressure_ref",
        "tp_mm": "precipitation",
        "t2m_C": "air_temperature_ref",
        "rh": "relative_humidity_ref",
        "u10": "wind_speed_ref",
        "ssrd_Wm-2": "downward_shortwave_radiation",
    }
)

# ---------------------------
# 5. Add constant variables
# ---------------------------
# In addition to the variables from the ERA5-Land datasset, a time series of atmospheric
# CO2 is needed. We add this here as a constant field of 400ppm.
air_temp_shape = dataset_renamed["air_temperature_ref"].shape
dataset_renamed["atmospheric_co2_ref"] = xr.DataArray(
    400 * np.ones(air_temp_shape),
    dims=dataset_renamed["air_temperature_ref"].dims,
    coords=dataset_renamed["air_temperature_ref"].coords,
)

# Mean annual temperature is calculated from the full time series of air temperatures
time_dim = [
    dim for dim in dataset_renamed["air_temperature_ref"].dims if "time" in dim
][0]
dataset_renamed["mean_annual_temperature"] = dataset_renamed[
    "air_temperature_ref"
].mean(dim=time_dim)
# Note:
# In the future we plan to include a time series of mean annual data for every year.

# ---------------------------
# 6. Reformat into VE-style dataset
# ---------------------------
# Reformat coords and dims into VE-style dataset:
#  - dims: y, x, time_index
#  - coords: x (from TOML), y (from TOML), time_index (0..time-1)

cell_x = np.arange(utm50N_grid_details["cell_nx"])
cell_y = np.arange(utm50N_grid_details["cell_ny"])

time_dim = [
    dim for dim in dataset_renamed["air_temperature_ref"].dims if "time" in dim
][0]

dataset_xyt = dataset_renamed.rename_dims({time_dim: "time_index"}).assign_coords(
    {
        "x": cell_x,
        "y": cell_y,
        "time_index": np.arange(dataset_renamed.sizes[time_dim]),
    }
)

print(
    f"✅ Reformatted to VE-style TOML grid: "
    f"cell_nx = {utm50N_grid_details['cell_nx']}, "
    f"cell_ny = {utm50N_grid_details['cell_ny']}, "
    f"resolution = {utm50N_grid_details['res']} m, "
    f"time steps = {dataset_renamed.sizes[time_dim]}"
)

# ------------------------
# 7. Save the reprojected data to file
# ------------------------
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
    "atmospheric_co2_ref",
    "mean_annual_temperature",
]

print("✅ Variable summary statistics:")
for var in vars_to_check:
    if var in dataset_renamed:
        da = dataset_renamed[var]
        print(
            f"{var}: min={da.min().item():.2f}, max={da.max().item():.2f}, mean={da.mean().item():.2f}"
        )
    else:
        print(f"{var}: Not found in dataset")
