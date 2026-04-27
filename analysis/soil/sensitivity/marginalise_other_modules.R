library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)
library(purrr)
source("tools/R/convert_array_to_nc.R")
source("tools/R/subset_nc.R")
source("tools/R/get_mean_array.R")
source("tools/R/cell_id_to_xy.R")


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

in_dir <- "data/scenarios/maliau/maliau_1/data/"
out_dir <- "data/scenarios/sensitivity_soil_litter/"

# Climate / abiotic data
get_mean_array(
  nc = paste0(in_dir, "era5_maliau_2010_2020_100m.nc"),
  ll_x = ll_x,
  ll_y = ll_y,
  ur_x = ur_x,
  ur_y = ur_y
) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "era5_maliau_2010_2020_100m_mean.nc")
  )

# Elevation data
get_mean_array(
  nc = paste0(in_dir, "elevation_maliau_2010_2020_100m.nc"),
  ll_x = ll_x,
  ll_y = ll_y,
  ur_x = ur_x,
  ur_y = ur_y
) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "elevation_maliau_2010_2020_100m_mean.nc")
  )

# Plant data
# needs a special treatment to convert them from cell_id-based to xy-based
# to be used in the same functions above
cell_id_to_xy(
  nc = paste0(in_dir, "plant_input_data_Maliau_50x50.nc"),
  x = maliau$cell_x_centres,
  y = maliau$cell_y_centres,
  filename = paste0(out_dir, "plant_input_data_Maliau_50x50_xy.nc")
)
get_mean_array(
  nc = paste0(out_dir, "plant_input_data_Maliau_50x50_xy.nc"),
  ll_x = ll_x,
  ll_y = ll_y,
  ur_x = ur_x,
  ur_y = ur_y
) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "plant_input_data_Maliau_50x50_mean.nc")
  )
