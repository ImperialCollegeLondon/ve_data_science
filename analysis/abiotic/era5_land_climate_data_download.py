#' ---
#' title: ERA5-Land Climate Data Download Script (User-Selectable Variable)
#'
#' description: |
#'   This Python script automates the download of hourly ERA5-Land data for a user-selected
#'   climate variable (e.g., precipitation, temperature, wind) using the Copernicus Climate Data Store (CDS).
#'   It automates the download of climate variables essential for the Abiotic model of the Virtual Ecosystem (VE).
#'   It uses the `cdsapi` library and command-line arguments to flexibly retrieve data for a specific
#'   variable, region, and year with a defined spatial bounding box.
#'
#'    List of ERA5 climate variables used in the VE abiotic model:
#'     - 2m_temperature
#'     - 2m_dewpoint_temperature
#'     - total_precipitation
#'     - surface_pressure
#'     - 10m_u_component_of_wind
#'     - 10m_v_component_of_wind
#'     - surface_runoff
#'**Note:** This list can be modified or extended based on evolving requirements of the Virtual Ecosystem (VE) Abiotic module.

#' author:
#'   - name: Lelavathy
#'
#' virtual_ecosystem_module: Abiotic
#'
#' status: final
#'
#' input_files:
#'   - name: None (direct API request)
#'     path: Data retrieved via Copernicus Climate Data Store API
#'     description: |
#'       No local input files are required. Users define download parameters via the command line.
#'
#' output_files:
#'   - name: ERA5-Land Climate Dataset (user-selected variable)
#'     path: ./ERA5_<variable>_<region>_<year>.nc
#'     description: |
#'       The output is a NetCDF file containing hourly ERA5-Land data for the selected variable,
#'       year, and bounding box. It is suitable for use in hydrological modeling, climate analysis,
#'       and ecosystem simulations.
#'
#' package_dependencies:
#'   - cdsapi
#'   - netCDF4
#'   - pandas
#'   - xarray
#'
#' usage_notes: |
#'   - **Copernicus Data Store (CDS) Registration & API Key Setup**
#'     Register at [Copernicus Climate Data Store (CDS)](https://cds.climate.copernicus.eu/) and set up your `.cdsapirc` file in your home directory.
#'
#'     Example `.cdsapirc` content:
#'     ```ini
#'     url: https://cds.climate.copernicus.eu/api/v2
#'     key: your-uid:your-api-key
#'     verify: 1
#'     ```
#'
#'   - **Installing Required Packages**
#'     Install dependencies using:
#'     ```bash
#'     pip install cdsapi netCDF4 pandas xarray
#'     ```
#'
#'   - **Running the Script**
#'     Run the script using command-line arguments. For example:
#'     ```bash
#'     python download_era5_climate_variable.py \
#'       --region Maliau \
#'       --year 2020 \
#'       --bbox 4.75 116.96 4.74 116.97 \
#'       --variable total_precipitation
#'     ```
#'
#'   - **Download Time**
#'     Download duration may vary depending on:
#'       - CDS server load
#'       - Internet speed
#'       - Size of the selected bounding box
#'
#'    -**Recommendation on Data Volume**
#'     ⚠️ It is recommended to download **only one variable per year** at a time.
#'     Requesting multiple variables or years simultaneously may cause errors due to large file sizes or server timeouts.
#' ---

# ERA5-Land Cimate Data Download Script with argparse
import argparse
import sys

import cdsapi

# List of ERA5 climate variables
CLIMATE_VARIABLES = {
    "2m_temperature"
    "2m_dewpoint_temperature"
    "total_precipitation"
    "surface_pressure"
    "10m_u_component_of_wind"
    "10m_v_component_of_wind"
    "surface_runoff"
}
# **Note:** This list can be modified or extended based on evolving requirements of the Virtual Ecosystem (VE) abiotic module.


def print_supported_variables():
    print("Available ERA5 variables:")
    for key, desc in CLIMATE_VARIABLES.items():
        print(f"  - {key}: {desc}")
    print()


def main():
    print_climate_variables()

    parser = argparse.ArgumentParser(
        description="Download a single ERA5-Land climate variable for a specified region and year."
    )
    parser.add_argument(
        "--region",
        type=str,
        required=True,
        help="Region name (used in output file name)",
    )
    parser.add_argument(
        "--year", type=str, required=True, help="Year of data to download, e.g., 2020"
    )
    parser.add_argument(
        "--bbox",
        nargs=4,
        metavar=("N", "W", "S", "E"),
        type=float,
        required=True,
        help="Bounding box coordinates: North West South East",
    )
    parser.add_argument(
        "--variable",
        type=str,
        required=True,
        help="Select ONE variable name from the climate variables list above",
    )

    args = parser.parse_args()

    if args.variable not in CLIMATE_VARIABLES:
        print(f"\n❌ Error: '{args.variable}' is not in the climate variables list.")
        print("Please choose one of the following:")
        print_climate_variables()
        sys.exit(1)

    # Initialize CDS API client
    c = cdsapi.Client()

    # Define data request
    request = {
        "variable": [args.variable],
        "year": args.year,
        "month": [f"{i:02d}" for i in range(1, 13)],
        "day": [f"{i:02d}" for i in range(1, 32)],
        "time": [f"{i:02d}:00" for i in range(24)],
        "format": "netcdf",
        "area": args.bbox,
    }
    #'    -**Recommendation on Data Volume**
    #'     ⚠️ It is recommended to download **only one variable per year** at a time.
    #'     Requesting multiple variables or years simultaneously may cause errors due to large file sizes or server timeouts.
    #' ---

    output_filename = f"ERA5_{args.variable}_{args.region}_{args.year}.nc"
    print(
        f"\n📥 Downloading {CLIMATE_VARIABLES[args.variable]} to {output_filename} ..."
    )
    c.retrieve("reanalysis-era5-land", request, output_filename)
    print("✅ Download complete!")


if __name__ == "__main__":
    main()
