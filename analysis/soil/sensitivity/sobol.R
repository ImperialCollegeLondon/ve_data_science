library(tidyverse)
library(sensobol)
library(tidync)
library(toml)
library(RNetCDF)
source("tools/R/convert_df_to_nc.R")
source("tools/R/get_all_variables.R")
source("tools/R/summarise_spatial.R")


# Maliau input data -------------------------------------------------------

maliau_1 <-
  read_toml("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("maliau_1")

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
convert_df_to_nc(
  sobol_df[1, ],
  filename = "data/scenarios/sensitivity_soil_litter/soil_litter_data.nc",
  x = maliau_1$ll_x,
  y = maliau_1$ll_y,
  element = c("C", "N", "P"),
  units = rep("", length(maliau_vars_init)),
  variables = maliau_vars_init
)
