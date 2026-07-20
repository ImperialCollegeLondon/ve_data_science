"""
---

title: ERA5-Land CDS API Downloader

description: |
  Download ERA5-Land climate datasets from the Copernicus Climate Data Store
  (CDS) for use in the Virtual Ecosystem (VE) climate forcing workflow.

  This script provides reusable functions for downloading ERA5-Land monthly
  averaged reanalysis variables and hourly 2 m air temperature. The downloaded
  datasets are returned as xarray datasets without any post-processing, allowing
  subsequent scripts to perform unit conversions, calculate derived climate
  variables (e.g. relative humidity and monthly diurnal temperature range), and
  interpolate the data onto the Virtual Ecosystem model grid.

virtual_ecosystem_module:
  - abiotic
  - hydrology

author:
  - Lelavathy
  - David

status: final

input_files:
  - name: None
    path: Copernicus Climate Data Store (CDS)
    description: |
      ERA5-Land climate reanalysis datasets accessed through the CDS API.
      Two datasets are downloaded:
        - ERA5-Land monthly averaged reanalysis
        - ERA5-Land hourly time series (2 m temperature)

output_files:
  - name: ERA5-land monthly averaged NetCDF
    path: User-defined output path
    description: |
      Monthly averaged ERA5-Land climate variables stored as a NetCDF file.
      This file is used as input for the climate preparation workflow.

  - name: ERA5-Land hourly temperature NetCDF
    path: User-defined output path
    description: |
      Hourly ERA5-Land 2 m air temperature stored as a NetCDF file.
      This dataset is subsequently used to calculate the monthly mean
      diurnal temperature range.

package_dependencies:
  - pathlib
  - shutil
  - zipfile
  - cdsapi
  - xarray

usage_notes: |
  This module provides helper functions for downloading ERA5-Land
  climate data from the Copernicus Climate Data Store (CDS) using the
  CDS API.

  Before using this module:

    - Register for a free Copernicus Climate Data Store (CDS) account:
      https://cds.climate.copernicus.eu/

    - Install and configure the CDS API by creating a `.cdsapirc`
      configuration file in your home directory following the official
      CDS API documentation:
      https://cds.climate.copernicus.eu/how-to-api

    Example `.cdsapirc` configuration:

        url: https://cds.climate.copernicus.eu/api
        key: <your-user-id>:<your-api-key>

  This module downloads:

    - ERA5-Land monthly averaged reanalysis variables.
    - ERA5-Land hourly 2 m air temperature for calculating monthly
      diurnal temperature range (DTR).

  Existing output files are detected automatically and are not
  downloaded again unless they are removed manually.

  ERA5-Land hourly time-series data are distributed by the CDS as a
  ZIP archive. This module automatically extracts the NetCDF file,
  removes temporary files, and returns the downloaded data as an
  `xarray.Dataset`.

  The procedure for downloading ERA5-Land data from the
  Copernicus Climate Data Store (CDS) is described in the
  dataset documentation below:

  -   Copernicus Climate Change Service (2022): ERA5-Land monthly averaged data
      from 1950 to present.Copernicus Climate Change Service (C3S) Climate Data
      Store (CDS).DOI: 10.24381/cds.68d2bb30
      https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land-monthly-means

  -   Copernicus Climate Change Service, Climate Data Store, (2025):
      ERA5 Land hourly time-series data on single levels from 1950 to present.
      Copernicus Climate Change Service (C3S) Climate Data Store (CDS),
      https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land-timeseries

references: |
 - Muñoz-Sabater, J., Dutra, E., Agustí-Panareda, A., et al. (2021).
    ERA5-Land: A state-of-the-art global reanalysis dataset for land applications.
    Earth System Science Data, 13, 4349-4383.
    https://doi.org/10.5194/essd-13-4349-2021

 -  Muñoz-Sabater, J. (2019). ERA5-Land monthly averaged data from 1950 to
    present. Copernicus Climate Change Service (C3S) Climate Data Store (CDS).
    https://doi.org/10.24381/cds.68d2bb30

---
"""  # noqa: D400, D212, D415

import shutil
import zipfile
from pathlib import Path

import cdsapi
import xarray as xr

# ============================================================
# OPEN NETCDF
# ============================================================
# Open downloaded NetCDF files using xarray.


def open_dataset(
    filename,
):
    """Open a NetCDF dataset.

    Args:
      filename: Path to a NetCDF file.

    Returns:
      The opened NetCDF dataset.

    """

    return xr.open_dataset(
        filename,
        engine="netcdf4",
    )


# ============================================================
# GENERIC DOWNLOAD
# ============================================================
# Generic routine for downloading datasets from the Copernicus Climate Data Store.


def download_dataset(
    dataset,
    request,
    outfile,
    zipped=False,
):
    """Download a dataset from the Copernicus Climate Data Store.

    Args:
      dataset: CDS dataset name.
      request: CDS API request dictionary.
      outfile: Output NetCDF filename.
      zipped: Whether the downloaded file is a ZIP archive.

    Returns:
      Path to the downloaded NetCDF file.

    """

    outfile = Path(outfile)

    outfile.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    # --------------------------------------------------------

    if outfile.exists():
        print(f"\nUsing existing dataset:\n{outfile}")

        return outfile

    # --------------------------------------------------------

    client = cdsapi.Client()

    print(f"\nDownloading {dataset}...")

    if zipped:
        zip_file = outfile.with_suffix(".zip")

        client.retrieve(
            dataset,
            request,
            str(zip_file),
        )

        extract_dir = outfile.parent / "temp_extract"

        extract_dir.mkdir(
            exist_ok=True,
        )

        with zipfile.ZipFile(
            zip_file,
            "r",
        ) as z:
            z.extractall(extract_dir)

        nc_files = list(extract_dir.glob("*.nc"))

        if len(nc_files) == 0:
            raise RuntimeError("Downloaded archive contains no NetCDF file.")

        shutil.move(
            nc_files[0],
            outfile,
        )

        shutil.rmtree(
            extract_dir,
            ignore_errors=True,
        )

        zip_file.unlink(
            missing_ok=True,
        )

    else:
        client.retrieve(
            dataset,
            request,
            str(outfile),
        )

    print(f"\nSaved:\n{outfile}")

    return outfile


# ============================================================
# ERA5-LAND MONTHLY
# ============================================================
# Download monthly averaged ERA5-Land climate variables.


def cdsapi_era5_monthly_downloader(
    years,
    bbox,
    outfile,
):
    """Download ERA5-Land monthly averaged reanalysis.

    Variables downloaded
    --------------------
    - 2 m temperature
    - 2 m dewpoint temperature
    - surface pressure
    - 10 m u wind component
    - total precipitation
    - surface solar radiation downward
    - surface thermal radiation downward

    Parameters
    ----------
    years : list[int]
        List of years to download (e.g. [2000, 2001]).

    bbox : list
        Bounding box in the format [north, west, south, east].

    outfile : Path
        Path to the output NetCDF file to save the downloaded data.

    Returns
    -------
    xarray.Dataset

    """

    request = {
        "product_type": "monthly_averaged_reanalysis",
        "variable": [
            "2m_temperature",
            "2m_dewpoint_temperature",
            "surface_pressure",
            "10m_u_component_of_wind",
            "total_precipitation",
            "surface_solar_radiation_downwards",
            "surface_thermal_radiation_downwards",
        ],
        "year": [str(year) for year in years],
        "month": [
            "01",
            "02",
            "03",
            "04",
            "05",
            "06",
            "07",
            "08",
            "09",
            "10",
            "11",
            "12",
        ],
        "time": "00:00",
        "data_format": "netcdf",
        "download_format": "unarchived",
        "area": bbox,
    }

    download_dataset(
        dataset="reanalysis-era5-land-monthly-means",
        request=request,
        outfile=outfile,
    )

    return open_dataset(outfile)


# ============================================================
# ERA5-LAND HOURLY TEMPERATURE
# ============================================================
# Download hourly ERA5-Land 2 m temperature for diurnal temperature
# range (DTR) calculation.


def cdsapi_era5_hourly_temperature_downloader(
    start_date,
    end_date,
    bbox,
    outfile,
):
    """Download ERA5-Land hourly 2 m temperature.

    Hourly temperature is required to calculate the monthly mean
    diurnal temperature range.

    Parameters
    ----------
    start_date : str
        YYYY-MM-DD

    end_date : str
        YYYY-MM-DD

    bbox : list
        Bounding box for the download in the format [north, west, south, east]
        or [north, west, south, east] in degrees. This defines the spatial
        extent to request from the API.

    outfile : Path
        Path to the output file where the downloaded dataset will be saved.

    Returns
    -------
    xarray.Dataset

    """

    request = {
        "variable": [
            "2m_temperature",
        ],
        "area": bbox,
        "date": [f"{start_date}/{end_date}"],
        "data_format": "netcdf",
    }

    download_dataset(
        dataset="reanalysis-era5-land-timeseries",
        request=request,
        outfile=outfile,
        zipped=True,
    )

    return open_dataset(outfile)
