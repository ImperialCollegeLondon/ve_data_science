# noqa: D100

#' ---
#' title: Data downloader tools for ERA5
#'
#' description: |
#'   This file defines a Python function that can be used to automates the download of
#'   ERA5-Land monthly averaged datasets. It uses the Copernicus Climate Data Store
#    (CDS) API.
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
#'   - name: None (direct API request)
#'     path: Data retrieved via Copernicus Climate Data Store API
#'     description: |
#'       No local input files are required. Download parameters are defined within
#'       the script and can be customized through command-line arguments.
#'
#' output_files:
#'   - name: None (tool)
#'
#' package_dependencies:
#'   - cdsapi
#'
#' usage_notes: |
#'   - **Copernicus Data Store (CDS) Registration & API Key Setup**
#'     Register at [](https://cds.climate.copernicus.eu/) and configure your `.cdsapirc`
#'     file in your home directory.
#'
#'     Example `.cdsapirc`:
#'
#'     ```ini
#'     url: https://cds.climate.copernicus.eu/api
#'     key: your-uid:your-api-key
#'     verify: 1
#'     ```
#'
#' 💡 Remark:
#'    - The Copernicus Climate Data Store provides comprehensive guidance on setting
#'       up and using their API: https://cds.climate.copernicus.eu/how-to-api
#'
#' ---


from pathlib import Path

import cdsapi


def cdsapi_era5_downloader(
    var: str, years: list[int], bbox: list[float], outfile: Path
):
    """ERA5 hourly data downloader.

    Downloads a time series of a given variable from the CDS for the
    "reanalysis-era5-land-monthly-means" dataset for the region within a provided
    bounding box and for a set of years.

    Args:
        var: The variable to download
        years: A list of years to download
        bbox: The bounding box of the data to download in degrees,
        outfile: An output path for the data file.

    """

    # Create the request dictionary - all hourly observations of the requested variable
    # in the requested years
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

    client = cdsapi.Client()
    client.retrieve("reanalysis-era5-land-monthly-means", request).download(outfile)
