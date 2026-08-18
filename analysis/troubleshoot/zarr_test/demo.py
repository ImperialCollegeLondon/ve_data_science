"""
---
title: Demo for working with output Zarr files in python

description: |
    This demo shows how to read and work with Zarr files
    produced by the virtual ecosystem model. It demonstrates how to access the data,
    log transform it, and save a slice of the data to a new NetCDF file for further
    analysis.

virtual_ecosystem_module: All

author:
  - name: Nick

status: final

input_files:
  - name: model_data.zarr
    path: analysis/troubleshoot/zarr_test/ve_example/out/
    description: |
      VE model output in Zarr format, containing inputs, init conditions, and outputs
      for a single run of the model. This file is used as input for the demo to
      demonstrate how to read and analyze Zarr files in Python.

output_files:
  - name: transpiration_slice_log.nc
    path: analysis/troubleshoot/zarr_test/ve_example/out/
    description: |
      Log-transformed slice of the transpiration data saved as a NetCDF file.

package_dependencies:
  - xarray
  - zarr
  - numpy
  - os

usage_notes: |
  This demo is to explore the Zarr file format and how to read and work with Zarr files
  in Python. It is not intended to be a comprehensive analysis of the model outputs,
  but rather a demonstration of how to access and manipulate the data in the Zarr file
  format.

  Make sure to have the dependencies for zarr input file for xarray IO backends.
  Install Zarr package for dependencies: pip install zarr

  To run the demo,

  If you are using linux,
  setup VE in the right environment and version using the bash
  script: analysis/troubleshoot/zarr_test/setup_linux.sh.
  Then run the demo script using the command in your terminal:
  chmod +x analysis/troubleshoot/zarr_test/setup_linux.sh
  ./analysis/troubleshoot/zarr_test/setup_linux.sh

  If you are using windows,
  setup VE in the right virtual environment and right version
  using the bash script: analysis/troubleshoot/zarr_test/setup.sh
  To run the bash script, run bash analysis/troubleshoot/zarr_test/setup.sh
  in your terminal (I use Git Bash). This will also install the example
  data and then run ve_run on it to obtain the new Zarr output files.

  This will install the example data and then run ve_run on it to obtain
  the new Zarr output files.
---
"""  # noqa: D400, D212, D205, D415

import os

import numpy as np
import xarray

# ============================================================
# Open the DataTree from the Zarr file
# ============================================================

t = xarray.open_datatree(
    "analysis/troubleshoot/zarr_test/ve_example/out/model_data.zarr"
)

# ============================================================
# Inspect the DataTree structure
# ============================================================

# print the hierachy and inspect the top level groups
print(t)
# print output can be long given the large number of VE output variables

# ============================================================
# List inputs and outputs
# ============================================================

outputs = t["outputs"]
print("Available output variables:")
print(list(outputs.data_vars))

inputs = t["inputs"]
print("Available input variables:")
print(list(inputs.data_vars))

# ============================================================
# Looking at single array and its dimensions and attributes
# ============================================================

# Access transpiration from outputs
transpiration = outputs["transpiration"]

# Check shape
print("Shape:", transpiration.shape)

# Check dimensions
print("Dimensions:", transpiration.dims)

# Check coordinates
print("Coordinates:", transpiration.coords)

# Check attributes (unit, description)
print("Units:", transpiration.attrs["unit"])
print("Description:", transpiration.attrs["description"])

# ============================================================
# Inspect a slice of the transpiration data so we can feed to conventional functions
# ============================================================
# Select time indices 1-3
transpiration_slice = transpiration.sel(time_index=slice(1, 3))

# Basic statistics
print("Mean transpiration:", transpiration_slice.mean().values)
print("Max transpiration: ", transpiration_slice.max().values)
print("Min transpiration: ", transpiration_slice.min().values)

# log transform
transpiration_slice_log = transpiration_slice.copy()
transpiration_slice_log.values = np.log(transpiration_slice_log.values)

# create new path for saving the manipulated slice
save_path = "analysis/troubleshoot/zarr_test/ve_example/out/transpiration_slice_log.nc"

# remove pre-existing file if it exists
if os.path.exists(save_path):
    os.remove(save_path)

# writes manipulated slice to a new netcdf file
transpiration_slice_log.to_netcdf(save_path)

# verify the new netcdf file was created and inspect its contents
new_t = xarray.open_dataset(save_path)
print(new_t)
