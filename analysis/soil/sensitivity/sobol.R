library(tidyverse)
library(sensobol)
library(tidync)
source("analysis/soil/initialisation/convert_array_to_nc.R")


# Maliau input data -------------------------------------------------------

dat_maliau <- list(
  soil = tidync("data/scenarios/maliau/maliau_1/data/soil_maliau.nc"),
  litter = tidync("data/scenarios/maliau/maliau_1/data/litter_maliau.nc")
)
vars <-
  dat_maliau |>
  map(
    \(x) {
      x$variable |> filter(dim_coord == FALSE) |> pull(name)
    }
  ) |>
  list_c()

dat_maliau$soil |>
  activate(vars[1]) |>
  hyper_array()

# function to extract the range of input data
get_range <- function(nc, variable) {
  dat_maliau$soil |>
    activate(variable) |>
    hyper_array()
  vars_tmp <- intersect(ve_vars_init, names(data$var))
  t(sapply(vars_tmp, function(var) {
    ncvar_get(data, var) |> range()
  }))
}

soil_range <-
  get_maliau_range("data/scenarios/maliau/maliau_1/data/soil_maliau.nc")
litter_range <-
  get_maliau_range("data/scenarios/maliau/maliau_1/data/litter_maliau.nc")

maliau_range <- rbind(soil_range, litter_range)
maliau_vars_init <- rownames(maliau_range)


# Set up Sobol matrix -----------------------------------------------------

n_sample <- 100
mat <- sobol_matrices(
  N = n_sample,
  params = maliau_vars_init,
  order = "first",
  type = "QRN"
)

# rescale to Maliau ranges
for (i in maliau_vars_init) {
  mat[, i] <-
    mat[, i] * (maliau_range[i, 2] - maliau_range[i, 1]) + maliau_range[i, 1]
}

# each row will be treated as a single-grid "scenario"
# so convert the Sobol matrix to a list of single-grid variable arrays, which
# will be further converted to netCDF input data
foo <- as.list(mat[1, ])


# Convert data in the Sobol Matrix to netCDFs ----------------------------

convert_array_to_nc()
