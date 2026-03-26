#! /bin/bash

# This script sets up a new python environment for running VE on the HPC. It creates the
# environment in a fixed location within the ve_data_science repo, with the intention
# that it can be called by multiple users. Users will still have to install and setup
# miniforge, but hopefully can share the existing environment.
#
# If a user has not installed conda, they can do so by running the following commands:
#    miniforge-setup

# We will use conda to create a new environment with the required packages.
module load miniforge/3

# Once conda is installed.

# Activate the base conda environment to make conda commands available
eval "$(~/miniforge3/bin/conda shell.bash hook)"
# Create a new conda environment
conda create -p /rds/general/project/virtual_rainforest/live/ve_data_science/hpc_jobs/virtual_ecosystem_py314 python=3.14


# Activate that conda environment
conda activate /rds/general/project/virtual_rainforest/live/ve_data_science/hpc_jobs/virtual_ecosystem_py314

# We need the following packages:
# Install packages from conda-forge to read TIFF raster data and netCDF files.
conda install -c conda-forge rasterio xarray dask netCDF4 bottleneck h5netcdf libgdal-hdf5 ipython
# The VE package is only available on PyPI, so install using pip.
pip install virtual_ecosystem
