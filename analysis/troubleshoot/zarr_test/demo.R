# Note on R6 class and cross validation with zarr-python
# https://zarr.dev/pizzarr/index.html#validation-with-zarr-python

library(pizzarr)
library(reticulate)

# Open the model output Zarr store
outputs <- zarr_open(
  "analysis/troubleshoot/zarr_test/ve_example/out/model_data.zarr"
)

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
soil_cnp_pool_maom_data <- soil_cnp_pool_maom$as.array()
soil_cnp_pool_maom_data[, 1:3, ]

# Log-transform the array
soil_cnp_pool_maom_log <- log(soil_cnp_pool_maom_data)

# Save manipulated arrays back to Zarr
modified_zarr <- "analysis/troubleshoot/zarr_test/ve_example/out/model_data_modified.zarr"
if (dir.exists(modified_zarr)) {
  unlink(modified_zarr, recursive = TRUE)
}
modified_root <- zarr_open(modified_zarr, mode = "w")
modified_outputs <- modified_root$create_group("outputs")
modified_outputs$create_dataset(
  "soil_cnp_pool_maom_log",
  data = soil_cnp_pool_maom_log
)
print("Modified Zarr store hierarchy:")
modified_root$tree()


# Convert Zarr to NetCDF using Python's xarray ---------------------------

# Import xarray (requires zarr to be installed: pip install zarr)
xr <- import("xarray")

# Open the entire Zarr group
zarr_path <- "analysis/troubleshoot/zarr_test/ve_example/out/model_data.zarr"
ds <- xr$open_dataset(zarr_path, engine = "zarr", group = "outputs")

# Convert full dataset to netCDF
ds$to_netcdf("output_all.nc")

# Select and save a subset
air_temp_subset <- ds[c("air_temperature")]
air_temp_subset$to_netcdf("air_temperature.nc")

# Verify in R
library(ncdf4)
nc <- nc_open("air_temperature.nc")
print(nc)
nc_close(nc)
