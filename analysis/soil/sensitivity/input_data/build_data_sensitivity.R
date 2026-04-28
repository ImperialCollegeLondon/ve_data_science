library(tidyverse)
library(sensobol)
library(tidync)
library(toml)
library(RNetCDF)
source("tools/R/convert_array_to_nc.R")
source("tools/R/get_all_variables.R")
source("tools/R/summarise_spatial.R")


# some directory paths
in_dir <- "data/scenarios/maliau/maliau_1/data/"
out_dir <- "data/scenarios/sensitivity_soil_litter/data/"


# Maliau input data -------------------------------------------------------

maliau_1 <-
  read_toml("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("maliau_1")

dat_maliau <- list(
  soil = tidync(paste0(in_dir, "soil_maliau.nc")),
  litter = tidync(paste0(in_dir, "litter_maliau.nc"))
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
# to efficiency sample the variable space of soil and litter data

maliau_vars_init <- range_maliau$variable
n_sample <- 100
mat <- sobol_matrices(
  N = n_sample,
  params = maliau_vars_init,
  order = "first",
  type = "QRN",
  seed = 777
)

# rescale to Maliau ranges
for (var in maliau_vars_init) {
  min <- range_maliau |> filter(variable == var) |> pull(min)
  max <- range_maliau |> filter(variable == var) |> pull(max)
  mat[, var] <-
    mat[, var] * (max - min) + min
}

# convert to dataframe, and then combine CNP into triplet columns
# simple function to merge triplet
merge_triplet <- function(C, N, P) {
  pmap(list(C, N, P), c)
}

sobol_df <-
  mat |>
  as.data.frame() |>
  # combine C, N and P columns into a single list column
  mutate(
    soil_cnp_pool_lmwc = merge_triplet(
      soil_cnp_pool_lmwc_C,
      soil_cnp_pool_lmwc_N,
      soil_cnp_pool_lmwc_P
    ),
    soil_cnp_pool_maom = merge_triplet(
      soil_cnp_pool_maom_C,
      soil_cnp_pool_maom_N,
      soil_cnp_pool_maom_P
    ),
    soil_cnp_pool_pom = merge_triplet(
      soil_cnp_pool_pom_C,
      soil_cnp_pool_pom_N,
      soil_cnp_pool_pom_P
    ),
    soil_cnp_pool_necromass = merge_triplet(
      soil_cnp_pool_necromass_C,
      soil_cnp_pool_necromass_N,
      soil_cnp_pool_necromass_P
    ),
    litter_pool_above_metabolic_cnp = merge_triplet(
      litter_pool_above_metabolic_cnp_C,
      litter_pool_above_metabolic_cnp_N,
      litter_pool_above_metabolic_cnp_P
    ),
    litter_pool_below_metabolic_cnp = merge_triplet(
      litter_pool_below_metabolic_cnp_C,
      litter_pool_below_metabolic_cnp_N,
      litter_pool_below_metabolic_cnp_P
    ),
    litter_pool_above_structural_cnp = merge_triplet(
      litter_pool_above_structural_cnp_C,
      litter_pool_above_structural_cnp_N,
      litter_pool_above_structural_cnp_P
    ),
    litter_pool_below_structural_cnp = merge_triplet(
      litter_pool_below_structural_cnp_C,
      litter_pool_below_structural_cnp_N,
      litter_pool_below_structural_cnp_P
    ),
    litter_pool_woody_cnp = merge_triplet(
      litter_pool_woody_cnp_C,
      litter_pool_woody_cnp_N,
      litter_pool_woody_cnp_P
    ),
    .keep = "unused"
  )

# each row will be treated as a single-grid "scenario"
# so convert the Sobol matrix to a list of single-grid variable arrays, which
# will be further converted to netCDF input data
dimnames <- list(
  x = maliau_1$ll_x,
  y = maliau_1$ur_y,
  element = c("C", "N", "P")
)

sobol_df[1, ] |>
  as.list() |>
  list_flatten() |>
  map(\(x) {
    if (length(x) == 1) {
      array(x, dim = c(1, 1), dimnames = list(x = dimnames$x, y = dimnames$y))
    } else {
      array(
        x,
        dim = c(3, 1, 1),
        dimnames = list(
          element = dimnames$element,
          x = dimnames$x,
          y = dimnames$y
        )
      )
    }
  }) |>
  convert_array_to_nc(filename = paste0(out_dir, "soil_litter_data.nc"))


# Generate mean arrays ---------------------------------------------------
# For other modules, fix their values at spatial averages

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
