#| ---
#| title: explore_plant_outputs_maliau_2
#|
#| description: |
#|   Load Virtual Ecosystem outputs stored in Zarr format and inspect the
#|   available variables. The exploration will focus on plant-related output
#|   variables and evaluate their dimensions before further analysis.
#|
#| virtual_ecosystem_module: Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#| input_files:
#|   - name: Virtual Ecosystem model output Zarr store
#|     path: data/scenarios/maliau/maliau_2/out/model_data.zarr
#|     description: |
#|       Zarr dataset containing the initial, input, and continuous output
#|       variables produced by a Virtual Ecosystem simulation.
#|
#| output_files:
#|   - name: model_data.nc
#|     path: data/scenarios/maliau/maliau_2/out/
#|     description: |
#|       NetCDF conversion of the VE Zarr outputs for use with the NetCDF
#|       helper functions in get_ve_variables.R.
#|
#| source_files:
#|   - name: get_ve_variables.R
#|     path: tools/R/R/get_ve_variables.R
#|     description: |
#|       Provides helpers for reading variables from VE Zarr and NetCDF output
#|       datasets.
#|
#| package_dependencies:
#|   - pizzarr
#|   - reticulate
#|   - ncdf4
#|   - tidync
#|   - dplyr
#|   - purrr
#|   - tibble
#|
#| usage_notes: |
#|   Update the input path for the VE simulation being explored. The script is
#|   exploratory and will be extended as plant output variables are identified.
#|
#|   Uses the repository's uv-managed `.venv` (via reticulate) both to convert
#|   Zarr to NetCDF with xarray and to import the installed
#|   `virtual_ecosystem` package for the PlantsModel variable lists. This
#|   assumes that `.venv` has the same virtual_ecosystem version that produced
#|   the model output being explored; re-run `uv sync` if that assumption no
#|   longer holds.
#| ---

# Load required packages
library(pizzarr)
library(reticulate)
library(ncdf4)
library(tidync)
library(dplyr)
library(purrr)
library(tibble)

# Load the shared VE Zarr reader.
source("../../../../tools/R/R/get_ve_variables.R")

#####

# Open the model output Zarr store
zarr_path <- "../../../../data/scenarios/maliau/maliau_2/out/model_data.zarr"
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

# Convert Zarr to NetCDF using Python's xarray ---------------------------

# Piggy-back on Python's xarray, which reads and write both Zarr and
# netCDF using reticulate

# Use the repository Python environment for xarray.
# required = TRUE : R must find and use that environment.
# If it cannot, the script stops with an error instead of silently choosing
# another Python installation.
use_virtualenv("../../../../.venv", required = TRUE)
xr <- import("xarray")

# Open the entire Zarr group
ds <- xr$open_dataset(zarr_path, engine = "zarr", group = "outputs")

# Convert full dataset to netCDF
nc_path <- "../../../../data/scenarios/maliau/maliau_2/out/model_data.nc"
ds$to_netcdf(nc_path)

# Verify in R
nc <- nc_open(nc_path)
print(nc)
nc_close(nc)

#####

# The section below uses the get_data_variables_nc() function to read variables
# from the NetCDF file. It somewhat repeats the verification step above, but
# since the step above is part of Hao Ran's demo I chose not to modify it.

# Load the NetCDF output with the shared NetCDF reader.
nc_data <- tidync::tidync(nc_path)
ve_outputs <- get_data_variables_nc(nc_data)

# Extract each dimension coordinate into R objects.
# These dimensions are shared across all model outputs (including plant outputs).
ve_dimensions <- purrr::map(
  unique(nc_data$dimension$name),
  function(dim_name) {
    nc_data$transforms[[dim_name]][[dim_name]]
  }
) |>
  stats::setNames(unique(nc_data$dimension$name))

# Create individual objects in the global environment for each dimension
# (e.g. cell_id, time, layers, element, pft)
list2env(ve_dimensions, envir = .GlobalEnv)

# Preview the unique dimension names and their coordinate values.
names(ve_dimensions)
ve_dimensions

# Record the dimensions of the variables loaded from NetCDF, labelled with
# their dimension names (e.g. time, layers) rather than bare sizes.
ve_output_dimensions <- purrr::map(names(ve_outputs), function(var) {
  var_dim <- dim(ve_outputs[[var]])
  # scalar/0-dimensional variables have no dim() to label
  if (is.null(var_dim)) {
    return(var_dim)
  }
  dim_names <- nc_data |>
    tidync::activate(var) |>
    tidync::hyper_dims(name = var) |>
    dplyr::pull(name)
  stats::setNames(var_dim, dim_names)
})
names(ve_output_dimensions) <- names(ve_outputs)

# Display the NetCDF variables and their dimensions.
names(ve_outputs)
ve_output_dimensions

#####

# The section below generates a summary of which array variables belong to
# plants by extracting this from the VE code.
# The plant output variables are those listed on the PlantsModel class as
# "vars_updated" (i.e. variables the plants model writes each update step).

# Import from the same .venv activated earlier (use_virtualenv() above), so
# this pulls the PlantsModel class from the repository's installed
# virtual_ecosystem version rather than any other Python environment.
plants_model <- import("virtual_ecosystem.models.plants.plants_model")

# Variables the plants model writes/updates each step: these are the
# plant-related entries expected among the NetCDF output variables.
plant_vars_updated <- plants_model$PlantsModel$vars_updated

# Subset the loaded NetCDF outputs and their dimensions to plant variables.
plant_outputs <- ve_outputs[names(ve_outputs) %in% plant_vars_updated]
plant_output_dimensions <- ve_output_dimensions[
  names(ve_output_dimensions) %in% plant_vars_updated
]

names(plant_outputs)
plant_output_dimensions

# Should check if it's possible to add units to e.g. plant output dimensions

#####
