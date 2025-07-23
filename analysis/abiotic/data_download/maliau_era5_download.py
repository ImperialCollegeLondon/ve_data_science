"""Script to download ERA5 for Maliau."""

from pathlib import Path

from .cdsapi_downloader import cdsapi_era5_downloader

# List of selected ERA5 climate variables
selected_variables = [
    "2m_temperature",  # abiotic variable
    "2m_dewpoint_temperature",  # abiotic variable
    "surface_pressure",  # abiotic variable
    "10m_u_component_of_wind",  # abiotic variable
    "total_precipitation",  # hydrological variable
    "surface_runoff",  # hydrological variable
]

# Define output directory and filename
output_dir = Path("../../../data/primary/abiotic/era5_land_monthly")
output_dir.mkdir(parents=True, exist_ok=True)

for var in selected_variables:
    output_filename = output_dir / f"ERA5_{var}_Maliau_2010_2020.nc"

    cdsapi_era5_downloader(
        var=var,
        years=list(range(2010, 2021)),
        bbox=[4.6, 116.8, 4.8, 117.0],
        outfile=output_filename,
    )
