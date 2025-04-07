---
title: ERA5-Land Rainfall Data Download Script-General

description: |
    This Python script retrieves ERA5-Land rainfall data from the Copernicus Climate Data Store (CDS).
    It automates the download of high-resolution precipitation data, which is useful for hydrological
    modeling, climate studies, and ecosystem analysis.

    The script utilizes the `cdsapi` package to request ERA5-Land hourly total precipitation data
    for a specified year, covering all months and days.

author:
  - name: Lelavathy

virtual_ecosystem_module: Abiotic

status: final

input_files:
  - name: None (direct API request)
    path: Data retrieved via Copernicus Data Store API
    description: |
      The script does not require any local input files. Instead, it queries ERA5-Land data
      directly from the Copernicus Data Store (CDS) based on user-defined parameters.

output_files:
  - name: ERA5-Land Rainfall Dataset_location  #specify the location of the dataset
    path: ./../../data/derived/abiotic/rainfall/ERA5_rainfall_<region>_<year>.nc #specify the region and year
    description: |
      The output file contains ERA5-Land precipitation data (m/hr) for the selected
      time range and region. It is saved in NetCDF format and can be used for
      hydrological analysis, climate modeling, and further post-processing.

package_dependencies:
    - cdsapi
    - netCDF4
    - pandas
    - xarray

 usage_notes: |
  - **Copernicus Data Store (CDS) Registration & API Key Setup**
    To access ERA5-Land data, users must register for a free account at the [Copernicus Climate Data Store (CDS)](https://cds.climate.copernicus.eu/).
    After registration, an API key is provided, which must be configured in a local `.cdsapirc` file for authentication.
    The file should be placed in the user’s home directory (`~/.cdsapirc` on Linux/macOS or `C:\Users\YourUsername\.cdsapirc` on Windows) and contain the following format:

    ```ini
    url: https://cds.climate.copernicus.eu/api/v2
    key: your-uid:your-api-key
    verify: 1
    ```

  - **Installing and Configuring the `cdsapi` Package**
    The `cdsapi` Python package is required to communicate with the Copernicus Data Store. Install it using:
    ```bash
    pip install cdsapi
    ```
    Ensure the `cdsapi.Client()` function is correctly initialized in the script before making any requests.

  - **Download Time Considerations**
    The dataset request spans an entire year (12 months, 365 days, 24-hourly data points per day).
    Due to the large data volume, download times vary based on:
      - Internet speed
      - CDS server response time (which may slow down during high demand)
      - The selected spatial extent (smaller regions will download faster)


# ERA5-Land Rainfall Data Download Script
import cdsapi

# Initialize the CDS API client
c = cdsapi.Client()

# Define dataset and request parameters
dataset = "reanalysis-era5-land"
request = {
    "variable": ["total_precipitation"],
    "year": "<year>",  # Replace with desired year, e.g., "2020"
    "month": [f"{i:02d}" for i in range(1, 13)],  # January to December
    "day": [f"{i:02d}" for i in range(1, 32)],  # Days 1 to 31
    "time": [f"{i:02d}:00" for i in range(24)],  # Hourly data (00:00 to 23:00)
    "data_format": "netcdf",
    "area": [<N>, <W>, <S>, <E>],  # Replace with bounding box coordinates
}

# Download the dataset
output_filename = "ERA5_rainfall_<region>_<year>.nc"
c.retrieve(dataset, request, output_filename)

print(f"Download completed: {output_filename}")
