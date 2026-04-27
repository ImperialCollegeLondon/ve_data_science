library(tidyverse)
library(sensobol)
library(tidync)
source("analysis/soil/initialisation/convert_array_to_nc.R")
source("analysis/soil/initialisation/get_all_variables.R")
source("analysis/soil/sensitivity/summarise_spatial.R")


# Maliau input data -------------------------------------------------------

dat_maliau <- list(
  soil = tidync("data/scenarios/maliau/maliau_1/data/soil_maliau.nc"),
  litter = tidync("data/scenarios/maliau/maliau_1/data/litter_maliau.nc")
)

vars_maliau <-
  dat_maliau |>
  map(get_all_variables) |>
  list_c()

range_maliau <-
  vars_maliau |>
  summarise_spatial(FUN = min) |>
  reshape2::melt(value.name = "min") |>
  left_join(
    vars_maliau |>
      summarise_spatial(FUN = max) |>
      reshape2::melt(value.name = "max")
  ) |>
  # paste variable names with their extra dimension names to treat them as
  # individual variables
  mutate(
    variable = ifelse(is.na(element), L1, paste(L1, element, sep = "_"))
  ) |>
  select(variable, min, max)


# Set up Sobol matrix -----------------------------------------------------

maliau_vars_init <- range_maliau$variable
n_sample <- 100
mat <- sobol_matrices(
  N = n_sample,
  params = maliau_vars_init,
  order = "first",
  type = "QRN"
)

# rescale to Maliau ranges
for (var in maliau_vars_init) {
  min <- range_maliau |> filter(variable == var) |> pull(min)
  max <- range_maliau |> filter(variable == var) |> pull(max)
  mat[, var] <-
    mat[, var] * (max - min) + min
}

# each row will be treated as a single-grid "scenario"
# so convert the Sobol matrix to a list of single-grid variable arrays, which
# will be further converted to netCDF input data
foo <- as.list(mat[1, ])


# Convert data in the Sobol Matrix to netCDFs ----------------------------

convert_array_to_nc()
