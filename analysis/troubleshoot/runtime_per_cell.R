library(tidyverse)
library(RcppTOML)
library(RNetCDF)
library(tidync)
library(purrr)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/subset_nc.R")
source("analysis/soil/sensitivity/cell_id_to_xy.R")


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
  # needs a special treatment to convert them from cell_id-based to xy-based
  # to be used in the same functions above
  cell_id_to_xy(
    nc = "data/scenarios/maliau/maliau_2/data/plant_input_data_maliau_10x10.nc",
    x = maliau_subset$cell_x_centres,
    y = maliau_subset$cell_y_centres,
    filename = "data/scenarios/runtime_per_cell/data/plant_input_data_maliau_10x10_xy.nc",
    return = TRUE
  )
  subset_nc(
    nc = "data/scenarios/runtime_per_cell/data/plant_input_data_maliau_10x10_xy.nc",
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

# Subset plant cohort
# NB: For plant I could match cell_id to the netCDF subsets in the loop above
# but I decided to simply fix the plant cohort to the same so we remove an
# extra moving part from this exercise (though as of now plant cohorts are the
# same across cells)
plant_cohort <-
  read_csv(
    "data/scenarios/maliau/maliau_2/data/plant_cohort_data_maliau_10x10.csv"
  ) |>
  filter(plant_cohorts_cell_id == 0)
write_csv(
  plant_cohort,
  "data/scenarios/runtime_per_cell/data/plant_cohort_data_maliau.csv"
)

# Copy over the remaining input data that do not require to vary cell number
copy_dir <- "data/scenarios/maliau/maliau_2/data/"
paste_dir <- "data/scenarios/runtime_per_cell/data/"
files_to_copy <- c(
  "animal_functional_groups_Maliau_level1.csv",
  "plant_constants_Maliau_10x10.csv",
  "plant_pft_definitions_maliau_10x10.csv"
)
file.copy(paste0(copy_dir, files_to_copy), paste_dir)


# Generate config files --------------------------------------------------

config_template <- parseTOML(
  "data/scenarios/maliau/maliau_2/config/data_config.toml"
)
