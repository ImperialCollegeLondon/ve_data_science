# noqa: D100

#' ---
#' title: Data downloader tools for ERA5
#'
#' description: |
#'   This file defines the `cdsapi_era5_downloader` Python function that automates the
#'   download of ERA5-Land monthly averaged datasets. It uses the Copernicus Climate
#'   Data Store (CDS) API.
#'
#' author:
#'   - name: Lelavathy
#'   - name: David Orme
#'
#' virtual_ecosystem_module: abiotic, abiotic_simple, hydrology
#'
#' status: final
#'
#' input_files:
#'
#' output_files:
#'
#' package_dependencies:
#'   - cdsapi
#'   - xarray
#'
#' usage_notes: |
#'   Copernicus Data Store (CDS) Registration & API Key Setup:
#'   Register at [](https://cds.climate.copernicus.eu/) and configure your `.cdsapirc`
#'   file in your home directory. The Copernicus Climate Data Store provides
#'   comprehensive guidance on setting up and using their API at
#'   https://cds.climate.copernicus.eu/how-to-api
#'
#'   Example `.cdsapirc`:
#'
#'     url: https://cds.climate.copernicus.eu/api
#'     key: your-api-key
#' ---


from pathlib import Path

import cdsapi
import xarray

# List of required ERA5 climate variables
REQUIRED_VARIABLES = [
    "2m_temperature",  # abiotic variable
    "2m_dewpoint_temperature",  # abiotic variable
    "surface_pressure",  # abiotic variable
    "10m_u_component_of_wind",  # abiotic variable
    "total_precipitation",  # hydrological variable
    "surface_runoff",  # hydrological variable
]


def cdsapi_era5_downloader(years: list[int], bbox: list[float], outfile: Path):
    """ERA5 hourly data downloader.

    Downloads a time series of the set of required variables from the CDS for the
    "reanalysis-era5-land-monthly-means" dataset for the region within a provided
    bounding box and for a set of years.


    Args:
        years: A list of years to download
        bbox: The bounding box of the data to download in degrees,
        outfile: An output path for the compiled data file.

    """

    # Each variable is downloaded to a separate file, so collect temporary filenames
    downloaded_files = []

    # Get the CDSAPI client
    client = cdsapi.Client()

    for var in REQUIRED_VARIABLES:
        # Create the request dictionary - all hourly observations of the requested
        # variable in the requested years
        request = {
            "product_type": ["monthly_averaged_reanalysis"],
            "variable": var,
            "year": [str(y) for y in years],
            "month": [f"{i:02d}" for i in range(1, 13)],  # All months in a year
            "time": [f"{i:02d}:00" for i in range(24)],  # All hours in a day
            "data_format": "netcdf",
            "download_format": "unarchived",
            "area": bbox,
        }

        # Retrieve the request from the client. The file will download to a random UUID
        # filename by default - we collect these to compile the data to a single file.
        file = client.retrieve(
            name="reanalysis-era5-land-monthly-means", request=request
        ).download()
        downloaded_files.append(file)

    # Load the individual datafiles and then merge them into a single Dataset
    netcdf_datasets = [xarray.load_dataarray(d) for d in downloaded_files]
    compiled_data = xarray.merge(netcdf_datasets)

    # Write the compiled data to the output file
    compiled_data.to_netcdf(outfile)

    # Tidy up the individual variable files
    for file in downloaded_files:
        Path(file).unlink()
