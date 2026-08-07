"""
---

title: Climate Input Data Processing Tools.

description: |
  Provide reusable functions for preparing ERA5-Land climate input data for the
  abiotic and hydrology modules of Virtual Ecosystem (VE) model.
  This scripts performs climate variable processing, spatial interpolation, and
  climate forcing dataset generation but does not download climate data.

  Specifically, it:
    1. Reads the site configuration TOML file.
    2. Creates the target grid needed for spatial interpolation.
    3. Calculates monthly mean diurnal temperature range (DTR) from
       ERA5-Land hourly 2 m air temperature.
    4. Converts ERA5-Land variables to the units required by the
       abiotic and hydrology modules.
    5. Calculates relative humidity from air temperature and dewpoint
       temperature.
    6. Selects the climate variables required by the abiotic and hydrology modules.
    7. Interpolates monthly climate variables and monthly DTR onto the
       target grid using bilinear interpolation, with
       nearest-neighbour interpolation used to fill remaining missing
       values.
    8. Creates the climate input dataset using  VE-standard
       variable names.
    9. Adds additional climate variables, including mean annual
       temperature and atmospheric CO₂ concentration.
   10. Finalises the climate input dataset by creating the required
       VE time structure, adding global metadata, and
       saving a compressed NetCDF file.

virtual_ecosystem_module:
  - abiotic
  - hydrology

author:
  - Lelavathy Samikan
  - David Orme

status: final

package_dependencies:
  - pathlib
  - tomllib
  - numpy
  - xarray
  - rioxarray
  - rasterio

usage_notes: |
  This module performs climate data processing only and does
  not download ERA5-Land datasets.

  It is intended to be used together with
  `cdsapi_downloader.py`, located in the `tools/python`
  directory, which downloads ERA5-Land datasets from the
  Copernicus Climate Data Store (CDS).

---
"""  # noqa: D212

import tomllib
from pathlib import Path

import numpy as np
import xarray as xr
from rasterio.crs import CRS
from rasterio.enums import Resampling
from rasterio.transform import from_origin

# ============================================================
# SITE CONFIGURATION
# ============================================================
# Read the Virtual Ecosystem site configuration from a TOML file.


def read_site_configuration(
    toml_file: Path | str,
    scenario_name: str,
) -> dict:
    """Read a site configuration TOML file.

    Args:
      toml_file: Path to the site configuration TOML file.
      scenario_name: Name of the scenario to load.

    Returns:
      Dictionary containing the selected scenario configuration.

    """

    toml_file = Path(toml_file)

    with open(
        toml_file,
        "rb",
    ) as f:
        config = tomllib.load(f)

    return config["Scenario"][scenario_name]


# ============================================================
# TARGET GRID
# ============================================================
# Create the  target grid used for spatial interpolation.


def get_target_grid(scenario: dict) -> dict:
    """Create the target grid used for spatial interpolation.

    Extract the grid geometry from the site configuration and generate the
    coordinate reference system, affine transform, and output grid shape
    required for spatial interpolation.

    Args:
      scenario: Site configuration dictionary containing the target grid
        definition.

    Returns:
      Dictionary containing the coordinate reference system, affine
      transform, grid shape, and x/y coordinates of the target grid.

    """

    x = np.asarray(scenario["cell_x_centres"], dtype=float)
    y = np.asarray(scenario["cell_y_centres"], dtype=float)

    resolution = float(scenario["res"])

    transform = from_origin(
        x.min() - resolution / 2,
        y.max() + resolution / 2,
        resolution,
        resolution,
    )

    return {
        "crs": CRS.from_epsg(scenario["epsg_code"]),
        "transform": transform,
        "shape": (
            scenario["cell_ny"],
            scenario["cell_nx"],
        ),
        # Preserve the coordinate ordering defined in the TOML file.
        "x": x,
        "y": y,
    }


# ============================================================
# CLIMATE VARIABLES PROCESSING
# ============================================================
# Process the ERA5-Land climate variables into the format required
# for the Virtual Ecosystem climate forcing workflow.

# ------------------------------------------------------------
# Calculation of monthly diurnal temperature range (dtr)
# ------------------------------------------------------------
# Calculate the monthly mean diurnal temperature range (dtr)
# from hourly ERA5-Land 2 m air temperature.


def calculate_monthly_dtr(
    hourly_ds: xr.Dataset,
) -> xr.DataArray:
    """Calculate monthly mean diurnal temperature range.

    Calculate the monthly mean diurnal temperature range (DTR)
    from hourly ERA5-Land 2 m air temperature.

    Args:
      hourly_ds: ERA5-Land hourly temperature dataset.

    Returns:
      Monthly mean diurnal temperature range.

    """

    time_dim = "valid_time" if "valid_time" in hourly_ds.coords else "time"

    t2m = hourly_ds["t2m"]

    # Calculate daily maximum 2 m temperature from hourly data
    # for each grid cell.

    daily_max = t2m.resample({time_dim: "1D"}).max()

    # Calculate daily minimum 2 m temperature from hourly data
    # for each grid cell.

    daily_min = t2m.resample({time_dim: "1D"}).min()

    # Calculate daily diurnal temperature range (dtr) for each grid cell.
    # by subtracting the daily minimum from the daily maximum.

    daily_dtr = daily_max - daily_min

    # Calculate monthly mean diurnal temperature range (dtr) for each grid cell.
    # by averaging the daily dtr values.

    monthly_dtr = daily_dtr.resample({time_dim: "1MS"}).mean()

    monthly_dtr.name = "dtr"

    monthly_dtr.attrs = {
        "long_name": "Monthly mean diurnal temperature range",
        "units": "K",
    }

    return monthly_dtr


# ------------------------------------------------------------
# Unit Conversion of ERA5-Land Monthly Averaged Variables
# ------------------------------------------------------------
# Convert ERA5-Land variables into the units required by the
# Virtual Ecosystem.


def convert_units(
    dataset: xr.Dataset,
) -> xr.Dataset:
    """Convert ERA5-Land variables to VE units.

    Args:
      dataset: ERA5-Land climate dataset.

    Returns:
      Climate dataset with variables converted to VE units.

    """

    climate = dataset.copy()

    # The standard output unit of  2m air temperature (t2m) is Kelvin (K)
    # which we need to convert to degree Celsius (C) for the Virtual Ecosystem.
    climate["t2m"] = climate["t2m"] - 273.15
    climate["t2m"].attrs["units"] = "degC"

    # The standard output unit of 2m dewpoint temperature (d2m ) a is Kelvin (K)
    # which we need to convert to degree Celsius (C) for the Virtual Ecosystem.
    climate["d2m"] = climate["d2m"] - 273.15
    climate["d2m"].attrs["units"] = "degC"

    # The standard output unit for surface pressure (sp) in ERA5-Land is Pascal (Pa)
    # which we need to convert to kilopascal (kPa) by dividing by 1000
    climate["sp"] = climate["sp"] / 1000.0
    climate["sp"].attrs["units"] = "kPa"

    # The standard output unit for total precipitation (tp) in ERA5-Land is meters (m)
    # which we need to convert to millimeters (mm) by multiplying by 1000.Further, the
    # data represents mean daily accumulated precipitation for each grid cell, so the
    # value has to be scaled tomonthly (here 30 days). TODO handle daily inputs.
    climate["tp"] = climate["tp"] * 1000.0 * 30.0
    climate["tp"].attrs["units"] = "mm"

    # The standard output unit for surface solar radiation downward (ssrd) in ERA5-Land
    # is Joule per square meter (Jm-2) which need to be converted to Watts per square
    # meter (Wm-2) by dividing by the number of seconds in a day (86400 seconds).
    climate["ssrd"] = climate["ssrd"] / 86400.0
    climate["ssrd"].attrs["units"] = "W m-2"

    # The standard output unit for surface thermal radiation downward (strd) in
    # ERA5-Land is Joule per square meter (Jm-2) which need to be converted to Watts
    # per square meter (Wm-2) by by the number of seconds in a day (86400 seconds).
    climate["strd"] = climate["strd"] / 86400.0
    climate["strd"].attrs["units"] = "W m-2"

    return climate


# ------------------------------------------------------------
# Calculation of relative humidity
# ------------------------------------------------------------
# Relative humidity (rh) is not a standard output from ERA5-Land monthly averaged
# but can be calculated from 2m dewpoint temperature (d2m in C) and
# 2m air temperature (t2m in C)


def calculate_relative_humidity(
    dataset: xr.Dataset,
) -> xr.Dataset:
    """Calculate relative humidity.

    Args:
      dataset: ERA5-Land climate dataset.

    Returns:
      Climate dataset with relative humidity added.

    """

    climate = dataset.copy()

    climate["rh"] = (
        100.0
        * np.exp((17.67 * climate["d2m"]) / (climate["d2m"] + 243.5))
        / np.exp((17.67 * climate["t2m"]) / (climate["t2m"] + 243.5))
    ).clip(0, 100)

    climate["rh"].attrs = {"long_name": "Relative humidity", "units": "%"}

    return climate


# ============================================================
# SELECT VARIABLES
# ============================================================
# Select the climate variables required by the Virtual Ecosystem
# from the processed era5-land monthly averaged climate variables.


def select_required_variables(
    dataset: xr.Dataset,
) -> xr.Dataset:
    """Select the required climate variables.

    Args:
      dataset: Processed ERA5-Land climate dataset.

    Returns:
      Dataset containing only the variables required by VE.

    """

    return dataset[
        [
            "t2m",
            "rh",
            "tp",
            "u10",
            "sp",
            "ssrd",
            "strd",
        ]
    ]


# ============================================================
# SPATIAL INTERPOLATION
# ============================================================
# Interpolate ERA5-Land climate variables onto the Virtual
# Ecosystem target grid.

# ============================================================
# SPATIAL INTERPOLATION
# ============================================================
# Interpolate ERA5-Land climate data onto the Virtual
# Ecosystem target grid.
#
# NOTE:
# The monthly averaged climate variables are obtained from the
# ERA5-Land monthly averaged dataset, whereas the hourly 2 m
# air temperature used to calculate monthly DTR is obtained
# from the ERA5-Land hourly dataset. Because these datasets
# have different spatial coordinate definitions, the derived
# monthly DTR cannot be combined directly with the monthly
# averaged dataset before interpolation. Instead, it is
# interpolated separately using the same bilinear interpolation
# workflow and later merged into the final Virtual Ecosystem
# climate forcing dataset.

# The interpolation mapping used here at the moment is the `bilinear`method of rasterio.
# Missing values generated during interpolation are filled
# using nearest-neighbour interpolation.
# Other methods are available:
# https://rasterio.readthedocs.io/en/stable/api/rasterio.enums.html#rasterio.enums.Resampling
# We might want to use a different interpolation strategy to give a smooth surface.


# ------------------------------------------------------------
# Interpolation of monthly diurnal temperature range (dtr)
# ------------------------------------------------------------
# Interpolate the monthly diurnal temperature range (DTR),
# derived from hourly ERA5-Land 2 m air temperature, onto the
# Virtual Ecosystem target grid.


def interpolate_variable(
    data: xr.DataArray,
    target_grid: dict,
) -> xr.DataArray:
    """Interpolate monthly diurnal temperature range onto the VE grid.

    Interpolate the monthly diurnal temperature range (DTR),
    derived from hourly ERA5-Land 2 m air temperature, onto the
    Virtual Ecosystem target grid using bilinear interpolation.
    Missing values generated during interpolation are filled
    using nearest-neighbour interpolation.

    Args:
      data: Monthly diurnal temperature range (DTR) to
        interpolate.
      target_grid: Virtual Ecosystem target grid definition.

    Returns:
      Monthly diurnal temperature range interpolated onto the
      Virtual Ecosystem target grid.

    """

    # Identify the longitude and latitude coordinate names used
    # by the input dataset.
    if "longitude" in data.coords:
        x_dim = "longitude"
        y_dim = "latitude"

    elif "lon" in data.coords:
        x_dim = "lon"
        y_dim = "lat"

    else:
        raise ValueError("Cannot determine longitude and latitude coordinates.")

    # Assign the spatial dimensions and geographic coordinate
    # reference system to the input data.
    data = data.rio.set_spatial_dims(
        x_dim=x_dim,
        y_dim=y_dim,
    ).rio.write_crs("EPSG:4326")

    # Interpolate the climate variable onto the VE target grid
    # using bilinear resampling.

    interpolated = data.rio.reproject(
        dst_crs=target_grid["crs"],
        transform=target_grid["transform"],
        shape=target_grid["shape"],
        resampling=Resampling.bilinear,
    )

    # Perform nearest-neighbour interpolation to fill cells that
    # remain undefined after bilinear interpolation.

    nearest = data.rio.reproject(
        dst_crs=target_grid["crs"],
        transform=target_grid["transform"],
        shape=target_grid["shape"],
        resampling=Resampling.nearest,
    )
    interpolated = interpolated.fillna(nearest)

    # Fill any isolated missing cells along both spatial
    # dimension.
    interpolated = interpolated.ffill("x").bfill("x")
    interpolated = interpolated.ffill("y").bfill("y")

    # Restore the coordinate ordering defined in the VE site
    # configuration.
    interpolated = interpolated.reindex(
        x=target_grid["x"],
        y=target_grid["y"],
    )

    return interpolated


# ------------------------------------------------------------
# Interpolation of ERA5-Land monthly averaged climate variables
# ------------------------------------------------------------
# Interpolate the monthly averaged ERA5-Land climate variables
# onto the Virtual Ecosystem target grid by applying the
# single-variable bilinear interpolation workflow to each
# climate variable.


def interpolate_dataset(
    dataset: xr.Dataset,
    target_grid: dict,
) -> dict:
    """Interpolate the monthly averaged ERA5-Land climate dataset.

    Interpolate each monthly averaged ERA5-Land climate variable
    onto the Virtual Ecosystem target grid by applying the
    single-variable interpolation workflow. Each variable is
    interpolated using bilinear interpolation, with
    nearest-neighbour gap filling applied where required.

    Args:
      dataset: Monthly averaged ERA5-Land climate dataset.
      target_grid: Virtual Ecosystem target grid definition.

    Returns:
      Dictionary containing the interpolated climate variables.

    """

    interpolated = {}
    for variable in dataset.data_vars:
        print(f"Interpolating {variable}...")

        interpolated[variable] = interpolate_variable(
            dataset[variable],
            target_grid,
        )

    return interpolated


# ============================================================
# VE DATASET CREATION
# ============================================================
# Create the Virtual Ecosystem climate input dataset from
# the interpolated ERA5-Land climate variables.
# Map the interpolated ERA5-Land climate variables to the
# variable names required by the Virtual Ecosystem.


def create_ve_dataset(
    interpolated: dict,
) -> xr.Dataset:
    """Create the Virtual Ecosystem climate forcing dataset.

    Assemble the interpolated ERA5-Land climate variables into
    an xarray dataset using the variable names required by the
    Virtual Ecosystem climate forcing workflow.

    Args:
      interpolated: Dictionary containing the interpolated
        ERA5-Land climate variables.

    Returns:
      Virtual Ecosystem climate forcing dataset.

    """

    return xr.Dataset(
        {
            "air_temperature_ref": interpolated["t2m"],
            "relative_humidity_ref": interpolated["rh"],
            "wind_speed_ref": interpolated["u10"],
            "precipitation": interpolated["tp"],
            "atmospheric_pressure_ref": interpolated["sp"],
            "downward_shortwave_radiation": interpolated["ssrd"],
            "downward_longwave_radiation": interpolated["strd"],
            "diurnal_temperature_range_ref": interpolated["dtr"],
        }
    )


# ============================================================
# ADDITION OF CLIMATE VARIABLES
# ============================================================
# Add additional climate variables that are not obtained from
# the ERA5-Land climate dataset but are required by the
# Virtual Ecosystem climate forcing dataset. Mean annual
# temperature is derived from the monthly air temperature,
# while atmospheric CO₂ is added as a constant user-defined
# forcing variable.

# ------------------------------------------------------------
# Mean annual temperature
# ------------------------------------------------------------
# Calculate the mean annual air temperature for each grid cell
# and assign the annual value to every month within the
# corresponding year.


def add_mean_annual_temperature(
    climate: xr.Dataset,
) -> xr.Dataset:
    """Add mean annual air temperature.

    Calculate the mean annual air temperature for each grid
    cell from the monthly air temperature. The annual mean is
    calculated separately for each year and assigned to every
    month within that year.

    Args:
      climate: Virtual Ecosystem climate forcing dataset.

    Returns:
      Climate forcing dataset with the mean annual temperature
      variable added.

    """

    # Determine the name of the temporal coordinate.

    if "valid_time" in climate.coords:
        time_dim = "valid_time"

    elif "time" in climate.coords:
        time_dim = "time"

    else:
        raise ValueError("No valid time coordinate found.")

    time = climate[time_dim]
    years = time.dt.year

    # Calculate the annual mean air temperature for each grid
    # cell.

    annual_mat = climate["air_temperature_ref"].groupby(years).mean(dim=time_dim)

    # Create a copy of the monthly temperature array to store
    # the annual mean values.

    mat = climate["air_temperature_ref"].copy()

    # Assign the annual mean temperature to every month within
    # the corresponding year.

    for year in annual_mat.year.values:
        mask = years == year
        mat.loc[{time_dim: time[mask]}] = annual_mat.sel(year=year)

    mat.name = "mean_annual_temperature"

    mat.attrs = {
        "long_name": "Mean annual air temperature",
        "units": "degC",
    }

    climate["mean_annual_temperature"] = mat

    return climate


# ------------------------------------------------------------
# Atmospheric CO₂ concentration
# ------------------------------------------------------------
# Add a constant atmospheric CO₂ concentration to every grid
# cell and time step.


def add_atmospheric_co2(
    dataset: xr.Dataset,
    concentration: float = 400.0,
) -> xr.Dataset:
    """Add atmospheric CO₂ concentration.

    Create a constant atmospheric CO₂ concentration field and
    add it to the Virtual Ecosystem climate forcing dataset.

    Args:
      dataset: Virtual Ecosystem climate forcing dataset.
      concentration: Atmospheric CO₂ concentration (ppm).

    Returns:
      Climate forcing dataset with atmospheric CO₂
      concentration added.

    """

    climate = dataset.copy()

    climate["atmospheric_co2_ref"] = xr.full_like(
        climate["air_temperature_ref"],
        concentration,
    )

    climate["atmospheric_co2_ref"].attrs = {
        "units": "ppm",
        "long_name": "Atmospheric CO₂ concentration",
    }

    return climate


# ============================================================
# DATASET FINALISATION
# ============================================================
# Finalise the Virtual Ecosystem climate forcing dataset and
# save it as a NetCDF file.


# ------------------------------------------------------------
# Finalise climate dataset
# ------------------------------------------------------------
# Prepare the Virtual Ecosystem climate forcing dataset for
# output by creating the required time coordinate structure.


def finalise_ve_dataset(
    dataset: xr.Dataset,
) -> xr.Dataset:
    """Finalise the Virtual Ecosystem climate forcing dataset.

    Rename the temporal dimension to ``time_index``, assign a
    sequential integer index, preserve the original timestamps
    as the ``valid_time`` coordinate, and reorder the dataset
    dimensions to match the Virtual Ecosystem convention.

    Args:
      dataset: Virtual Ecosystem climate forcing dataset.

    Returns:
      Finalised Virtual Ecosystem climate forcing dataset.

    """

    climate = dataset.copy()

    # Determine the temporal coordinate used by the dataset.

    if "valid_time" in climate.coords:
        time_dim = "valid_time"
    else:
        time_dim = "time"

    # Replace the temporal coordinate with a sequential integer
    # index while preserving the original timestamps.

    ntime = climate.sizes[time_dim]
    original_time = climate[time_dim].values

    climate = climate.rename({time_dim: "time_index"})

    climate = climate.assign_coords(
        time_index=np.arange(
            ntime,
            dtype=np.int32,
        )
    )

    climate = climate.assign_coords(
        valid_time=(
            "time_index",
            original_time,
        )
    )

    # Arrange the dataset dimensions in the order required by
    # the Virtual Ecosystem.

    return climate.transpose(
        "x",
        "y",
        "time_index",
    )


# ------------------------------------------------------------
# Add global attributes
# ------------------------------------------------------------
# Add global metadata describing the climate forcing dataset.


def add_global_attributes(
    dataset: xr.Dataset,
    scenario_name: str,
) -> xr.Dataset:
    """Add global metadata.

    Add global metadata describing the Virtual Ecosystem
    climate forcing dataset.

    Args:
      dataset: Virtual Ecosystem climate forcing dataset.
      scenario_name: Name of the study site or scenario.

    Returns:
      Climate forcing dataset with global metadata added.

    """

    climate = dataset.copy()

    climate.attrs = {
        "title": "Virtual Ecosystem climate forcing",
        "site": scenario_name,
        "source": "ERA5-Land",
        "Conventions": "CF-1.10",
    }

    return climate


# ------------------------------------------------------------
# Save climate dataset
# ------------------------------------------------------------
# Save the Virtual Ecosystem climate forcing dataset as a
# compressed NetCDF file.


def save_dataset(
    dataset: xr.Dataset,
    outfile: Path,
) -> Path:
    """Save the climate forcing dataset.

    Save the Virtual Ecosystem climate forcing dataset as a
    compressed NetCDF file.

    Args:
      dataset: Virtual Ecosystem climate forcing dataset.
      outfile: Output NetCDF file.

    Returns:
      Path to the saved NetCDF file.

    """

    outfile = Path(outfile)

    # Create the output directory if it does not already exist.

    outfile.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    # Apply lossless compression to all climate variables.

    encoding = {
        variable: {
            "zlib": True,
            "complevel": 4,
        }
        for variable in dataset.data_vars
    }

    # --------------------------------------------------------
    # SAVE DATASET
    # --------------------------------------------------------
    # Write the climate forcing dataset to a NetCDF file.

    dataset.to_netcdf(
        outfile,
        encoding=encoding,
    )

    print(f"\nSaved:\n{outfile}")

    return outfile
