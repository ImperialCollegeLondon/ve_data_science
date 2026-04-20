#| ---
#| title: Subset initial litter data for the Maliau scenario
#|
#| description: |
#|     This R script subsets the initial litter data for the Maliau
#|     scenario compiled by another script
#|     analysis/litter/initialisation/maliau_litter_data_subset.R
#|
#| virtual_ecosystem_module: litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: litter_maliau.nc
#|     path: data/scenarios/maliau/maliau_1/data
#|     description: |
#|         Full input data for the Maliau scenario. This file is not
#|         pushed but instead transferred via Globus
#|   - name: maliau_grid_definition_100m_10x10.toml
#|     path: data/derived/site
#|     description: |
#|         Metadata for Maliau grids, primarily to define the data generation
#|         area
#|
#| output_files:
#|   - name: litter_maliau.nc
#|     path: data/scenarios/maliau/maliau_2/data
#|     description: The subset litter input data
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


# Maliau site metadata ----------------------------------------------------

maliau_subset <- parseTOML(
  "data/derived/site/maliau/maliau_grid_definition_100m_10x10.toml"
)
ll_x <- maliau_subset$ll_x
ll_y <- maliau_subset$ll_y
ur_x <- maliau_subset$ur_x
ur_y <- maliau_subset$ur_y


# Subset input data ------------------------------------------------------

litter_subset <-
  tidync("data/scenarios/maliau/maliau_1/data/litter_maliau.nc") |>
  hyper_filter(
    x = x > ll_x & x < ur_x,
    y = y > ll_y & y < ur_y
  )
litter_subset_3D <-
  litter_subset |>
  activate("D2,D1,D0") |>
  hyper_array()
litter_subset_2D <-
  litter_subset |>
  activate("D1,D0") |>
  hyper_array()
litter_subset_array <- c(litter_subset_3D, litter_subset_2D)


# Output subset data -----------------------------------------------------

ncout <-
  convert_array_to_nc(
    array = litter_subset_array,
    filename = "data/scenarios/maliau/maliau_2/data/litter_maliau.nc",
    description = "Litter data for the Maliau 2 scenario",
    close.nc = FALSE
  )

# add units
att.put.nc(ncout, "x", "units", "NC_CHAR", "m")
att.put.nc(ncout, "y", "units", "NC_CHAR", "m")

# Get a summary of the created file
print.nc(ncout)

# close the file, writing data to disk
close.nc(ncout)
