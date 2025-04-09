#' ---
#' title: ERA5-Land Rainfall Data Download Script for Maliau Basin (2010-2020)
#'
#' description: |
#'   This Python script automates the download of hourly ERA5-Land total precipitation data for the Maliau Basin region spanning the years 2010 to 2020. It utilizes the Copernicus Climate Data Store (CDS) API to retrieve data, which is essential for hydrological modeling, climate analysis, and ecosystem simulations in the Virtual Ecosystem (VE) Abiotic module.
#'
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
#'       No local input files are required. The script defines download parameters internally.
#'
#' output_files:
#'   - name: ERA5-Land Total Precipitation Dataset for Maliau Basin (2010-2020)
#'     path: ./ERA5_total_precipitation_Maliau_<year>.nc
#'     description: |
#'       The output consists of NetCDF files containing hourly ERA5-Land total precipitation data for each year from 2010 to 2020 for the Maliau Basin region.
#'
#' package_dependencies:
#'   - cdsapi
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
#'     pip install cdsapi
#'     ```
#'
#'   - **Running the Script**
#'     Simply execute the script. It will sequentially download data for each year from 2010 to 2020.
#'
#'   - **Download Time**
#'     Download duration may vary depending on:
#'       - CDS server load
#'       - Internet speed
#'       - Size of the selected bounding box
#' ---

import cdsapi

# Define the climate variable and region
VARIABLE = "total_precipitation"
REGION = "Maliau"
BBOX = [4.9, 116.7, 4.5, 117.1]  # North, West, South, East

# Define the range of years
START_YEAR = 2010
END_YEAR = 2020

# Initialize CDS API client
c = cdsapi.Client()

# Loop through each year and download data
for year in range(START_YEAR, END_YEAR + 1):
    print(f"\n📥 Requesting ERA5-Land data for {VARIABLE}, year: {year}")

    request = {
        "variable": [VARIABLE],
        "year": str(year),
        "month": [f"{i:02d}" for i in range(1, 13)],
        "day": [f"{i:02d}" for i in range(1, 32)],
        "time": [f"{i:02d}:00" for i in range(24)],
        "format": "netcdf",
        "area": BBOX,  # [N, W, S, E]
    }

    output_filename = f"ERA5_{VARIABLE}_{REGION}_{year}.nc"
    c.retrieve("reanalysis-era5-land", request, output_filename)

    print(f"✅ Downloaded: {output_filename}")
