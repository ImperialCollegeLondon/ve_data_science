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
library(purrr)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/subset_nc.R")
source("analysis/soil/initialisation/get_all_variables.R")


# Maliau site metadata ----------------------------------------------------

maliau_subset <- parseTOML(
  "data/derived/site/maliau/maliau_grid_definition_100m_10x10.toml"
)
ll_x <- maliau_subset$ll_x
ll_y <- maliau_subset$ll_y
ur_x <- maliau_subset$ur_x
ur_y <- maliau_subset$ur_y


# Subset input data ------------------------------------------------------

ncout <- subset_nc(
  nc = "data/scenarios/maliau/maliau_1/data/soil_maliau.nc",
  ll_x = ll_x,
  ll_y = ll_y,
  ur_x = ur_x,
  ur_y = ur_y,
  filename = "data/scenarios/maliau/maliau_2/data/soil_maliau.nc",
  description = "Soil data for the Maliau 2 scenario",
  close.nc = FALSE
)

# add units
att.put.nc(ncout, "x", "units", "NC_CHAR", "m")
att.put.nc(ncout, "y", "units", "NC_CHAR", "m")

# Get a summary of the created file
print.nc(ncout)

# close the file, writing data to disk
close.nc(ncout)
