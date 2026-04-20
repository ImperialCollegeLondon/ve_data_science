library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)
library(purrr)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/subset_nc.R")


# Maliau site metadata ----------------------------------------------------

maliau <-
  parseTOML("data/derived/site/maliau/maliau_grid_definition_100m.toml")
ll_x <- maliau$ll_x
ll_y <- maliau$ll_y
ur_x <- maliau$ur_x
ur_y <- maliau$ur_y


# Generate mean arrays ---------------------------------------------------

# use the subset_array() to convert netCDF to arrays but setting the coordinate
# limits to the same as Maliau; this asks the function to simply return the
# same extend but converts data to array
get_mean_array(
  nc = "data/scenarios/maliau/maliau_1/data/era5_maliau_2010_2020_100m.nc",
  ll_x = ll_x,
  ll_y = ll_y,
  ur_x = ur_x,
  ur_y = ur_y
) |>
  convert_array_to_nc(
    filename = "data/scenarios/sensitivity_soil_litter/era5_maliau_2010_2020_100m_mean.nc"
  )
