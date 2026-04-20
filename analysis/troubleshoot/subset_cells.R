library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)
library(purrr)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/subset_nc.R")


# Maliau site metadata ----------------------------------------------------

maliau_subset <- parseTOML(
  "data/derived/site/maliau/maliau_grid_definition_100m_10x10.toml"
)
ll_x <- maliau_subset$ll_x
ll_y <- maliau_subset$ll_y
ur_x <- maliau_subset$ur_x
ur_y <- ll_y + seq_len(maliau_subset$cell_ny) * maliau_subset$res


# Subset input data ------------------------------------------------------

# To quantify runtime per cell, we vary the subset data to be 1x10, 2x10, 3x10
# ... cells from the Maliau 2 scenario data

for (j in seq_along(ur_y)) {
  # soil
  subset_nc(
    nc = "data/scenarios/maliau/maliau_1/data/soil_maliau.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/soil_maliau_",
      j,
      "x10.nc"
    )
  )

  # litter
  subset_nc(
    nc = "data/scenarios/maliau/maliau_1/data/litter_maliau.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/litter_maliau_",
      j,
      "x10.nc"
    )
  )

  # elevation
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/elevation_maliau_10x10.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/elevation_maliau_",
      j,
      "x10.nc"
    )
  )

  # climate / abiotic
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/era5_maliau_10x10_2010_2020.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/era5_maliau_",
      j,
      "x10_2010_2020.nc"
    )
  )

  # plant
  subset_nc(
    nc = "data/scenarios/maliau/maliau_2/data/era5_maliau_10x10_2010_2020.nc",
    ll_x = ll_x,
    ll_y = ll_y,
    ur_x = ur_x,
    ur_y = ur_y[j],
    filename = paste0(
      "data/scenarios/runtime_per_cell/data/plant_input_data_maliau_",
      j,
      "x10.nc"
    )
  )
}
