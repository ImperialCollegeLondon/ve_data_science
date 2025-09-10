# ---
# title: VE Climate Data Preparation Script
#
# description: |
# This script:
#   1. Loads a TOML site definition that defines a projected grid
#   2. Loads a monthly averaged ERA5-Land dataset in NetCDF format (e.g., era5_monthly_2010_2020_maliau.nc)
#   3. Performs unit conversions (K → °C, m → mm, Pa → kPa, J/m² → W/m²)
#   4. Adds derived and required variables (relative humidity, constant CO₂, mean annual temperature)
#   5. Interpolate the gridded ERA5-Land variables to the TOML grid latitude/longitude points (90X90m resolution)
#   6. Write a VE-style NetCDF that uses x/y/time_index coordinates and variable names 
#   7. Saves processed NetCDF output
#
#   The resulting dataset provides climate driver inputs to the Virtual Ecosystem.
#
# virtual_ecosystem_module: Abiotic
#
# author:
#   - Lelavathy (adapted from original script)
#
# status: wip
#
# input_files:
#   - name: TOML site definition
#     path: C:\Users\User\OneDrive\Desktop\ve_model\ve_example\generation_scripts\maliau_grid_definition.toml
#     description: |
#       Site-specific TOML file defining projected grid cell centre coordinates
#       (cell_x_centres, cell_y_centres), WGS84 bounds, EPSG code and grid
#       resolution. Used to build the target 2D grid for interpolation.
#
#   - name: ERA5-Land monthly NetCDF (2010–2020)
#     path: C:\Users\User\OneDrive\Desktop\ve_model\ve_example\era5_monthly_data\2010_2020\ERA5_monthly_2010_2020_Maliau.nc
#     description: |
#       Monthly ERA5-Land variables (t2m, d2m, tp, sp, ssrd, u10 etc.)
#       providing coarse-resolution climate forcing to be regridded to the
#       Virtual Ecosystem site grid.
#
# output_files:
#   - name: example_climate_from_toml_grid.nc
#     path: C:\Users\User\OneDrive\Desktop\ve_model\ve_example\data\example_climate_from_toml_grid.nc
#     description: |
#       VE-style NetCDF containing variables renamed to Virtual Ecosystem
#       conventions, with x, y, latitude, longitude, and time_index coordinates.
#       Ready for ingestion by the VE data loader.
#
# package_dependencies:
#   - numpy
#   - xarray
#   - tomllib (Python 3.11+)
#   - pyproj
#
# usage_notes: |
#   - Uses nearest-neighbour interpolation (xarray.interp with method='nearest').
#   - EPSG code in the TOML must be valid for pyproj (e.g. 32650).
#   - Precipitation conversion assumes 30-day months (tp * 1000 * 30).
#   - Spatial downscaling/topographic correction is not yet implemented.
# ---


import numpy as np
import xarray as xr
import tomllib
from pyproj import Transformer

# ---------------------------
# File paths (edit here)
# ---------------------------
toml_file = r"C:....ve_data_analysis\abiotic\data_download\site\maliau_grid_definition.toml"
era5_file = r"C:.....ve_data_science\data\primary\abiotic\era5_monthly_2010_2020_maliau.nc"
output_file = r"C:....ve_data_science\data\derived\abiotic\processed_climate_data_maliau.nc"

# ---------------------------
# 1. Load TOML site definition
# ---------------------------
# The TOML file is **site-specific**. It provides:
#   - Projected grid cell centres (cell_x, cell_y)
#   - EPSG code for the coordinate reference system (e.g., UTM zone)
#   - WGS84 bounds (lat/lon extent of the study area)
#   - Target resolution for VE grid cells
# Each site should have its own TOML definition for correct alignment.

with open(toml_file, "rb") as f:
    site_config = tomllib.load(f)

bounds_wgs84 = site_config["wgs84_bounds"]  # [lat_min, lon_min, lat_max, lon_max]
epsg_code = site_config["epsg_code"]
res = site_config["res"]

cell_x = np.array(site_config["cell_x_centres"])
cell_y = np.array(site_config["cell_y_centres"])

# Build 2D meshgrid in projected CRS
x_grid, y_grid = np.meshgrid(cell_x, cell_y)

# Convert projected UTM grid → WGS84 lat/lon
transformer = Transformer.from_crs(epsg_code, 4326, always_xy=True)
lon_grid, lat_grid = transformer.transform(x_grid, y_grid)

# ---------------------------
# 2. Load ERA5-Land dataset
# ---------------------------
# This ERA5-Land dataset covers a large area of grid cells at a coarser resolution (~9 km).

dataset = xr.open_dataset(era5_file)

if "valid_time" in dataset.dims or "valid_time" in dataset.coords:
    dataset = dataset.rename({"valid_time": "time"})

# ---------------------------
# 3. Unit conversions
# ---------------------------
# The standard output unit of ERA5-Land temperatures is Kelvin which we need to convert
# to degree Celsius for the Virtual Ecosystem. This includes 2m air temperature and
# 2m dewpoint temperature which are used to calculate relative humidity in next step.
dataset["t2m_C"] = dataset["t2m"] - 273.15
dataset["d2m_C"] = dataset["d2m"] - 273.15

# Relative humidity (RH) is not a standard output from ERA5-Land but can be calculated
# from 2m dewpoint temperature (DPT) and 2m air temperature (T)
dataset["rh2m"] = 100.0 * (
    np.exp(17.625 * dataset["d2m_C"] / (243.04 + dataset["d2m_C"])) /
    np.exp(17.625 * dataset["t2m_C"] / (243.04 + dataset["t2m_C"]))
)

# The standard output unit for total precipitation in ERA5-Land is meters which we need
# to convert to millimeters. Further, the data represents mean daily accumulated
# precipitation for the 9x9km grid box, so the value has to be scaled to monthly (here
# 30 days). TODO handle daily inputs
dataset["tp_mm"] = dataset["tp"] * 1000 * 30

# The standard output unit for surface pressure in ERA5-Land is Pascal (Pa) which we
# need to convert to Kilopascal (kPa) by dividing by 1000.
dataset["sp_kPa"] = dataset["sp"] / 1000

# The standard output unit for surface solar radiation downward in ERA5-Land is J m-2
# which need to be converted to W m-2 by dividing by the number of seconds in a month
dataset["ssrd_Wm-2"] = dataset["ssrd"] / 2592000


# In this step, we delete the initial temperature variables (K), precipitation (m), and
# surface pressure(Pa), surface solar radiation downward (ssrd), 10m u compoenent wind speed (u10) and 
# rename the remaining variables according to the Virtual Ecosystem naming convention.
dataset_cleaned = dataset.drop_vars(["d2m", "d2m_C", "t2m", "tp", "sp", "ssrd"])
dataset_renamed = dataset_cleaned.rename({
    "sp_kPa": "atmospheric_pressure_ref",
    "tp_mm": "precipitation",
    "t2m_C": "air_temperature_ref",
    "rh2m": "relative_humidity_ref",
    "u10": "wind_speed_ref",
    "ssrd_Wm-2": "downward_shortwave_radiation",
})

# ---------------------------
# 4. Add required variables
# ---------------------------
# In addition to the variables from the ERA5-Land datasset, a time series of atmospheric
# CO2 is needed. We add this here as a constant field.
air_temp_shape = dataset_renamed["air_temperature_ref"].shape
dataset_renamed["atmospheric_co2_ref"] = xr.DataArray(
    400 * np.ones(air_temp_shape),
    dims=dataset_renamed["air_temperature_ref"].dims,
    coords=dataset_renamed["air_temperature_ref"].coords,
)

# Mean annual temperature is calculated from the full time series of air temperatures;
dataset_renamed["mean_annual_temperature"] = dataset_renamed["air_temperature_ref"].mean(dim="time")

# ---------------------------
# 5. Interpolate to TOML grid (lat/lon from WGS84 grid)
# ---------------------------
# Prepare input dims names used in dataset (assumes ERA5 dataset uses 'latitude' and 'longitude')
# If dataset uses different names, xarray will raise an error.
# We select method='nearest' to mimic original behaviour; this can be changed later.

data_interp = dataset_renamed.interp(
    latitude=("y", lat_grid[:, 0]),
    longitude=("x", lon_grid[0, :]),
    method="nearest"
)
#Note: 
# The Virtual Ecosystem example data is run on a 90 x 90 m grid. 
# This means that some form of spatial downscaling has to be applied to the dataset, for example by spatially
# interpolating coarser resolution climate data and including the effects of local topography. 
# This is not yet implemented!

# ---------------------------
# 6. Reformat into VE-style dataset
# ---------------------------
#Reformat coords and dims into VE-style dataset:
#  - dims: y, x, time_index
# - coords: x (from TOML), y (from TOML), time_index (0..T-1)
   
ny, nx = lat_grid.shape
time_len = data_interp.sizes["time"]

# Rename only time -> time_index
dataset_xyt = (
    data_interp.rename_dims({"time": "time_index"})
    .drop_vars({"time"})
    .assign_coords({
        "x": cell_x,  # from TOML
        "y": cell_y,
        "time_index": np.arange(0, time_len),
        "latitude": (("y", "x"), lat_grid),
        "longitude": (("y", "x"), lon_grid),
    })
)

print(f"✅ Interpolated to TOML grid: nx = {nx}, ny = {ny}, resolution = {res} m")

# ---------------------------
# 7. Save to NetCDF
# ---------------------------
# Once we confirmed that our dataset is complete and our calculations are correct, we
# save it as a new netcdf file. 
dataset_xyt.to_netcdf(output_file)
print(f"💾 Saved processed dataset to: {output_file}")