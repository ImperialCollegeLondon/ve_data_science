"""Script to download ERA5 for Maliau."""

from pathlib import Path

from cdsapi_downloader import cdsapi_era5_downloader

# Define output directory and filename
output_dir = Path("../../../data/primary/abiotic/era5_land_monthly")
output_dir.mkdir(parents=True, exist_ok=True)

output_filename = output_dir / "ERA5_Maliau_2010_2020.nc"

cdsapi_era5_downloader(
    years=list(range(2010, 2021)),
    bbox=[4.6, 116.8, 4.8, 117.0],
    outfile=output_filename,
)
