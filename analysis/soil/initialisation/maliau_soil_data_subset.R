#| ---
#| title: Subset initial soil data for the Maliau scenario
#|
#| description: |
#|     This R script subsets the initial soil data for the Maliau
#|     scenario compiled by another script
#|     analysis/soil/initialisation/maliau_soil_data_subset.R
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: soil_maliau.nc
#|     path: data/scenarios/maliau/maliau_1/data
#|     description: |
#|         Full input data for the Maliau scenario. This file is not
#|         pushed but instead transferred via Globus
#|   - name: maliau_grid_definition_100m.toml
#|     path: data/derived/site
#|     description: |
#|         Metadata for Maliau grids, primarily to define the data generation
#|         area
#|
#| output_files:
#|   - name: soil_maliau.nc
#|     path: data/scenarios/maliau/maliau_2/data
#|     description: The subset soil input data
#|
#| package_dependencies:
#|     - tidyverse
#|     - RcppTOML
#|     - RNetCDF
#|     - tidync
#|
#| usage_notes:
#| ---

library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)


# Maliau site metadata ----------------------------------------------------

maliau_subset <- parseTOML(
  "data/derived/site/maliau/maliau_grid_definition_100m_10x10.toml"
)
ll_x <- maliau_subset$ll_x
ll_y <- maliau_subset$ll_y
ur_x <- maliau_subset$ur_x
ur_y <- maliau_subset$ur_y


# Subset input data ------------------------------------------------------

soil_subset <-
  tidync("data/scenarios/maliau/maliau_1/data/soil_maliau.nc") |>
  hyper_filter(
    x = x > ll_x & x < ur_x,
    y = y > ll_y & y < ur_y
  )
soil_subset_3D <-
  soil_subset |>
  activate("D2,D1,D0") |>
  hyper_array()
soil_subset_2D <-
  soil_subset |>
  activate("D1,D0") |>
  hyper_array()
soil_subset_x <-
  soil_subset |>
  activate("D0") |>
  hyper_array()
soil_subset_y <-
  soil_subset |>
  activate("D1") |>
  hyper_array()
soil_subset_element <-
  soil_subset |>
  activate("D2") |>
  hyper_array()


# Output subset data -----------------------------------------------------

# path and file name of netCDF
ncpath <- "data/scenarios/maliau/maliau_2/data/"
ncname <- "soil_maliau"
ncfname <- paste0(ncpath, ncname, ".nc")

# create netCDF file
ncout <- create.nc(ncfname, format = "netcdf4")

# define dimensions
dim.def.nc(ncout, "x", maliau_subset$cell_nx)
dim.def.nc(ncout, "y", maliau_subset$cell_ny)
dim.def.nc(ncout, "element", 3)
var.def.nc(ncout, "x", "NC_FLOAT", "x")
var.def.nc(ncout, "y", "NC_FLOAT", "y")
var.def.nc(ncout, "element", "NC_STRING", "element")
att.put.nc(ncout, "x", "units", "NC_CHAR", "m")
att.put.nc(ncout, "y", "units", "NC_CHAR", "m")
var.put.nc(ncout, "x", soil_subset_x$x)
var.put.nc(ncout, "y", soil_subset_y$y)
var.put.nc(ncout, "element", soil_subset_element$element)

# define and put variables
for (i in names(soil_subset_2D)) {
  var.def.nc(ncout, i, "NC_DOUBLE", rev(c("x", "y")))
  var.put.nc(ncout, i, soil_subset_2D[[i]])
  # add units
  # more metadata can be added here
  att.put.nc(
    ncout,
    i,
    "units",
    "NC_CHAR",
    soil_subset$attribute$value[soil_subset$attribute$variable == i]$units
  )
}

for (i in names(soil_subset_3D)) {
  var.def.nc(ncout, i, "NC_DOUBLE", rev(c("x", "y", "element")))
  var.put.nc(ncout, i, soil_subset_3D[[i]])
  # add units
  # more metadata can be added here
  att.put.nc(
    ncout,
    i,
    "units",
    "NC_CHAR",
    soil_subset$attribute$value[soil_subset$attribute$variable == i]$units
  )
}

# add global attributes
att.put.nc(
  ncout,
  "NC_GLOBAL",
  "description",
  "NC_CHAR",
  "Soil data for the Maliau 2 scenario"
)

# Get a summary of the created file
print.nc(ncout)

# close the file, writing data to disk
close.nc(ncout)
