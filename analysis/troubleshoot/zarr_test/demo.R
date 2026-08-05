#| ---
#| title: Demo for working with output Zarr files in R
#|
#| description: |
#|     Demonstrates examining, manipulating, and converting
#|     Virtual Ecosystem model output stored in Zarr format using pizzarr.
#|     Includes array inspection, log transformation, saving
#|     to modified Zarr stores, and conversion to NetCDF using
#|     Python's xarray via reticulate.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: model_data.zarr
#|     path: analysis/troubleshoot/zarr_test/ve_example/out/
#|     description: |
#|       VE model output in Zarr format with init, inputs,
#|       and outputs groups. This is created with the bash script
#|       analysis/troubleshoot/zarr_test/setup.sh, see usage_notes below.
#|
#| output_files:
#|   - name: model_data_modified.zarr
#|     path: analysis/troubleshoot/zarr_test/ve_example/out/
#|     description: |
#|       Modified Zarr store with transformed arrays (this is gitignored)
#|   - name: model_data.nc
#|     path: analysis/troubleshoot/zarr_test/ve_example/out/
#|     description: |
#|       NetCDF converted from the Zarr outputs (this is gitignored)
#|
#| package_dependencies:
#|     - pizzarr
#|     - reticulate
#|     - ncdf4
#|
#| usage_notes: |
#|     This demo focuses on the R package, pizzarr. There are a few zarr-based
#|     but I opted for pizzarr because it is well-supported and aims to
#|     stay in touch with the sister Python package, zarr-python (see
#|     https://zarr.dev/pizzarr/index.html#validation-with-zarr-python). It is
#|     also R6 class so it will be familiar to Python users in terms of syntax.
#|     See https://zarr.dev/pizzarr/ for more information.
#|
#|     To begin, setup VE in the right virtual environment and right version
#|     using the bash script: analysis/troubleshoot/zarr_test/setup.sh
#|     To run the bash script, run bash analysis/troubleshoot/zarr_test/setup.sh
#|     in your terminal (I use Git Bash). This will also install the example
#|     data and then run ve_run on it to obtain the new Zarr output files.
#|
#|     Then, go through this R script to get a sense of how Zarr works in R.
#| ---

library(pizzarr)
library(reticulate)
library(ncdf4)

# Open the model output Zarr store
zarr_path <- "analysis/troubleshoot/zarr_test/ve_example/out/model_data.zarr"
outputs <- zarr_open(zarr_path)


# Examine and manipulate Zarr file ---------------------------------------

# Print the store hierarchy and inspect the top-level groups
# the print output can be long given the large number of VE output variables
outputs$tree()

# Print the store structure, just like a file directory
# we expect to see init (initial values), inputs (input data), and outputs
# (output data), plus some hidden files
root_store <- outputs$get_store()
root_items <- root_store$listdir()
root_items

# List arrays under the outputs group
# These are what we've been calling output variables or all-continuous variables
outputs_group <- outputs$get_item("outputs")
output_array_names <- outputs_group$get_store()$listdir("outputs")
output_array_names <- output_array_names[
  !output_array_names %in% c(".zattrs", ".zgroup")
]
output_array_names

# Get a single array and its attributes
soil_cnp_pool_maom <- outputs_group$get_item("soil_cnp_pool_maom")
# relative path to the array store
soil_cnp_pool_maom$get_name()
soil_cnp_pool_maom$get_path()
# array dimension (a.k.a. shape)
soil_cnp_pool_maom$get_shape()
# array dimension names (NULL if unavailable)
soil_cnp_pool_maom$get_dimension_names()

# array attributes
# (note: dimension names are found here...)
soil_cnp_pool_maom_attrs <- soil_cnp_pool_maom$get_attrs()$to_list()
soil_cnp_pool_maom_attrs

# Read the full array into R and inspect a small slice
# the data become an array class in R, so we can use conventional functions
# that have been working with matrix/array in R
soil_cnp_pool_maom_data <- soil_cnp_pool_maom$as.array()
soil_cnp_pool_maom_data[, 1:3, ]
class(soil_cnp_pool_maom_data)

# Log-transform the array, as an example of data manipulation
soil_cnp_pool_maom_log <- log(soil_cnp_pool_maom_data)

# Save manipulated arrays back to Zarr
modified_zarr_path <- "analysis/troubleshoot/zarr_test/ve_example/out/model_data_modified.zarr"
# remove pre-existing modified zarr file so we're always pretending to be
# writing a new file
if (dir.exists(modified_zarr_path)) {
  unlink(modified_zarr_path, recursive = TRUE)
}
# open a new Zarr file with write mode
# (note: in Zarr reading is just like writing?)
modified_root <- zarr_open(modified_zarr_path, mode = "w")
# assign the new array to the new Zarr file
modified_outputs <- modified_root$create_group("outputs")
modified_outputs$create_dataset(
  "soil_cnp_pool_maom_log",
  data = soil_cnp_pool_maom_log,
  shape = dim(soil_cnp_pool_maom_log)
)
# verify that the new data has been stored in the modified Zarr file
modified_root$tree()


# Convert Zarr to NetCDF using Python's xarray ---------------------------

# There are a few ways to convert Zarr to NetCDF:
# 1. read and convert using the star package, but star flattens the netCDF
#    which is no good
# 2. read using pizzarr, and write using RNetCDF, but this results in very
#    verbose code that is hard to maintain
# 3. simply piggy-back on Python's xarray, which reads and write both Zarr and
#    netCDF --- this is what we'll do here using reticulate

# Import xarray from Python (requires zarr to be installed: pip install zarr)
xr <- import("xarray")

# Open the entire Zarr group
ds <- xr$open_dataset(zarr_path, engine = "zarr", group = "outputs")

# Convert full dataset to netCDF
nc_path <- "analysis/troubleshoot/zarr_test/ve_example/out/model_data.nc"
ds$to_netcdf(nc_path)

# Verify in R
nc <- nc_open(nc_path)
print(nc)
nc_close(nc)
