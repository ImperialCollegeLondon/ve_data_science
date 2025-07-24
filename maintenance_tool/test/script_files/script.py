"""
title: Data downloader tools for ERA5

description: |
  This file defines a Python function that can be used to automates the download of
  ERA5-Land monthly averaged datasets. It uses the Copernicus Climate Data Store
  (CDS) API.

author:
  - Lelavathy
  - David Orme

virtual_ecosystem_module:
  - abiotic
  - abiotic_simple
  - hydrology

status: final

input_files:
  - name: None (direct API request)
    path: Data retrieved via Copernicus Climate Data Store API
    description: |
      No local input files are required. Download parameters are defined within
      the script and can be customized through command-line arguments.

output_files:

package_dependencies:
  - cdsapi

usage_notes: |
   **Copernicus Data Store (CDS) Registration & API Key Setup**
   Register at [](https://cds.climate.copernicus.eu/) and configure your `.cdsapirc`
   file in your home directory.

   Example `.cdsapirc`:
     url: https://cds.climate.copernicus.eu/api
     key: your-api-key

   The Copernicus Climate Data Store provides comprehensive guidance on setting
   up and using their API: https://cds.climate.copernicus.eu/how-to-api
"""  # noqa : D400

a = 1
