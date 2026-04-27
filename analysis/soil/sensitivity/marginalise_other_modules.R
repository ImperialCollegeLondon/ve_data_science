library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)
library(purrr)
source("tools/R/convert_array_to_nc.R")
source("tools/R/get_all_variables.R")
source("tools/R/summarise_spatial.R")


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
