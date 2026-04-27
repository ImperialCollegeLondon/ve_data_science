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
in_dir <- "data/scenarios/maliau/maliau_1/data/"
out_dir <- "data/scenarios/sensitivity_soil_litter/"

# Climate / abiotic data
tidync(paste0(in_dir, "era5_maliau_2010_2020_100m.nc")) |>
  get_all_variables() |>
  summarise_spatial(FUN = mean) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "era5_maliau_2010_2020_100m_mean.nc")
  )

# Elevation data
tidync(paste0(in_dir, "elevation_maliau_2010_2020_100m.nc")) |>
  get_all_variables() |>
  summarise_spatial(FUN = mean) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "elevation_maliau_2010_2020_100m_mean.nc")
  )

# Plant data
tidync(paste0(in_dir, "plant_input_data_Maliau_50x50.nc")) |>
  get_all_variables() |>
  summarise_spatial(FUN = mean) |>
  convert_array_to_nc(
    filename = paste0(out_dir, "plant_input_data_Maliau_50x50_mean.nc")
  )
