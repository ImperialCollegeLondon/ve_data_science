# noqa: D100
from pathlib import Path

import tomllib
import xarray
from rasterio import Affine
from rasterio.crs import CRS
from rasterio.warp import Resampling

# Define the projections to be used
wgs84_crs = CRS.from_epsg(4326)
utm50N_crs = CRS.from_epsg(32650)

# Load the destination grid details
with open("../../core/maliau_grid_definition.toml", "rb") as maliau_grid_file:
    utm50N_grid_details = tomllib.load(maliau_grid_file)

# Define the XY shape of the data in the destination dataset
dest_shape = (
    utm50N_grid_details["cell_nx"],
    utm50N_grid_details["cell_ny"],
)

# Define the affine matrix giving the coordinates of pixels in the destination dataset
dest_transform = Affine(
    utm50N_grid_details["res"],
    0,
    utm50N_grid_details["min_x"],
    0,
    utm50N_grid_details["res"],
    utm50N_grid_details["min_y"],
)

# Set the source directory
source_directory = Path("../../../data/primary/abiotic/era5_land_monthly/")

# Get the target file
source_filename = source_directory / "ERA5_Maliau_2010_2020.nc"


# Open the ERA5 dataset in WGS84 and and set the CRS manually because it is not
# set in the file. Do not decode times from CF to np.datetime64, because we'd have
# to convert back to write the file.
era5_data_WGS84 = xarray.open_dataset(
    source_filename,
    engine="rasterio",
    decode_times=False,
)
era5_data_WGS84 = era5_data_WGS84.rio.write_crs(wgs84_crs)

# Use the rasterio accessor tools to reproject the data
era5_data_UTM50N = era5_data_WGS84.rio.reproject(
    dst_crs=utm50N_crs,
    shape=dest_shape,
    transform=dest_transform,
    resampling=Resampling.nearest,
)

# Save the reprojected data to file
era5_data_UTM50N.to_netcdf(source_directory / "ERA5_Maliau_2010_2020_UTM50N.nc")
