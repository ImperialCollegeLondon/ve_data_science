# Note on R6 class and cross validation with zarr-python
# https://zarr.dev/pizzarr/index.html#validation-with-zarr-python

library(pizzarr)
library(reticulate)

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
library(ncdf4)
nc <- nc_open(nc_path)
print(nc)
nc_close(nc)
