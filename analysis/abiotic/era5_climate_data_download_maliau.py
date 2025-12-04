#' ---
#' title: ERA5-Land Monthly Averaged Data Download Script for Maliau Basin (2010–2020)
#'
#' description: |
#'   This Python script automates the download of ERA5-Land monthly averaged  data for the Maliau Basin region for the years 2010 to 2020.
#'   It uses the Copernicus Climate Data Store (CDS) API and argparse to support user input for selecting specific variables.
#'   This modular approach supports flexible download of different variables, aiding hydrological modeling, climate analysis, and ecosystem simulations in the Virtual Ecosystem (VE) Abiotic module.
#'
#' author:
#'   - name: Lelavathy
#'
#' virtual_ecosystem_module: abiotic, abiotic_simple, hydrology
#'
#' status: final
#'
#' input_files:
#'   - name: None (direct API request)
#'     path: Data retrieved via Copernicus Climate Data Store API
#'     description: |
#'       No local input files are required. Download parameters are defined within the script and can be customized through command-line arguments.
#'
#' output_files:
#'   - name: era5_land_monthly_maliau_2010_2020.nc
#'     path: ./era5_land_monthly_<variable>_maliau_<year>.nc
#'     description: |
#'       The output is a NetCDF file containing monthly averaged ERA5-Land data for the selected abiotic/ hydrological variable over the Maliau Basin bounding box.
#'
#' package_dependencies:
#'   - cdsapi
#'   - netCDF4
#'   - pandas
#'   - xarray

#' usage_notes: |
#'   - **Copernicus Data Store (CDS) Registration & API Key Setup**
#'     Register at [Copernicus Climate Data Store (CDS)](https://cds.climate.copernicus.eu/) and configure your `.cdsapirc` file in your home directory.
#'
#'     Example `.cdsapirc`:
#'     ```ini
#'     url: https://cds.climate.copernicus.eu/api/v2
#'     key: your-uid:your-api-key
#'     verify: 1
#'     ```
#'
#'   - **Installing Required Packages**
#'     Install dependencies using:
#'     ```bash
#'     pip install cdsapi
#'     ```
#'
#'   - **Running the Script with Variable Input**
#'     Run the script using a command line interface with the `--variable` flag. Example:
#'     ```bash
#'     python download_era5_data.py --variable total_precipitation
#'     ```
#'
#'   - **Recommended Download Practice**
#'     To avoid CDS download errors caused by large requests, it's recommended to download **one variable** per run.
#'
#' 💡 Remark:
#'    - the Copernicus Climate Data Store provides comprehensive guidance on setting up and using their API.
#'    - This documentation can help you understand how to structure your requests and handle data downloads effectively.
#'    - Access the documentation here: https://cds.climate.copernicus.eu/how-to-api
#'
#' ---

# ERA5-Land Monthly Averaged Data Download Script for Maliau Basin (2010–2020) with argparse functionality
import argparse
import os
import sys

import cdsapi

# List of selected ERA5 climate variables
selected_variables = [
    "2m_temperature",  # abiotic variable
    "2m_dewpoint_temperature",  # abiotic variable
    "surface_pressure",  # abiotic variable
    "10m_u_component_of_wind",  # abiotic variable
    "total_precipitation",  # hydrological variable
    "surface_runoff",  # hydrological variable
]

# Set up argparse
parser = argparse.ArgumentParser(
    description="Download ERA5-Land monthly averaged data for a specific variable."
)
parser.add_argument(
    "--variable",
    type=str,
    required=True,
    help=f"Selected variable to download. Choose from: {', '.join(selected_variables)}",
)
args = parser.parse_args()

# Validate user input
if args.variable not in selected_variables:
    print(f"Error: '{args.variable}' is not a valid variable.")
    print(f"Choose from: {', '.join(selected_variables)}")
    sys.exit(1)

# Set up request
dataset = "reanalysis-era5-land-monthly-means"
request = {
    "product_type": ["monthly_averaged_reanalysis"],
    "variable": [args.variable],
    "year": [str(y) for y in range(2010, 2021)],  # 2010 to 2020 inclusive
    "month": [f"{i:02d}" for i in range(1, 13)],  # all months in a year
    "time": [f"{i:02d}:00" for i in range(24)],  # all hours in a day
    "data_format": "netcdf",
    "download_format": "unarchived",
    "area": [
        4.757,
        116.949,
        4.728,
        116.983,
    ],  # Maliau Basin bounding box (North, West, South, East)
}

# Define output directory and filename
output_dir = os.path.join("data", "abiotic", "era5_land_monthly")
os.makedirs(output_dir, exist_ok=True)
output_filename = f"era5_{args.variable}_monthly_Maliau_2010_2020.nc"
output_path = os.path.join(output_dir, output_filename)

# Download data
client = cdsapi.Client()
client.retrieve(dataset, request).download(
    f"era5_{args.variable}_monthly_Maliau_2010_2020.nc"
)
print(f"✅ Downloaded successfully: {args.variable}")
