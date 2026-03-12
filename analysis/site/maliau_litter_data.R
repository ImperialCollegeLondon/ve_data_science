#| ---
#| title:
#|
#| description: |
#|     This R script
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name:
#|     path:
#|     description: |
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - mvtnorm
#|     - RcppTOML
#|     - readxl
#|     - glmmTMB
#|     - ncdf4
#|     - reshape2
#|
#| usage_notes: |
#|     For more details on statistical and data assumptions, see
#|     data/scenarios/maliau/soil_metadata.toml
#| ---

library(tidyverse)
library(mvtnorm)
library(RcppTOML)
library(readxl)
library(glmmTMB)
library(ncdf4)

set.seed(20260312)



# Litter metadata ---------------------------------------------------------

litter_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")



# Maliau site metadata ----------------------------------------------------

maliau <- parseTOML("data/derived/site/maliau_grid_definition_100m.toml")

# total number of grids
n_sim <- with(maliau, cell_nx * cell_ny)



# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = maliau$cell_x_centres,
    cell_y = maliau$cell_y_centres
  ) |>
  # calculate displacements
  mutate(x = cell_x - min(cell_x),
         y = cell_y - min(cell_y))



# Litter stock ------------------------------------------------------------

# Including:
# litter_pool_above_metabolic
# litter_pool_above_structural
# litter_pool_woody
# litter_pool_below_metabolic
# litter_pool_below_structural

# Litter stock means are straightforward, but not their variances. This is
# because we modelled physical litter types (e.g., leaf, root, twig) but then
# converted them to more abstract pools (e.g., metabolic and structural).
# During this conversion, the propagation of mean values is straightforward,
# but not the propagation of variances is less so. For example, we may know
# that the mean of a structural pool is (1 - f_m) * X, but what is its
# variance? There are a few statistical approaches (e.g., delta method and
# numerical simulation) but they are either slightly out of my comfort zone or
# time consuming. So I opted to set standard deviations at 1/10 of their mean.
# This value is selected such that the aboveground pool sum has similar range
# to their observed physical counterparts at SAFE. Then I assume the same also
# applies to the woody and belowground pools.

litter_stocks <- read_csv("data/derived/litter/stock/litter_stock.csv")

# retrieve stock means and then calculate SDs
# they are in log scales to generate stocks with a lognormal distribution
# to keep them positively bound
litter_stocks_meanlog <- log(litter_stocks$stock)
litter_stocks_sdlog <- abs(litter_stocks_meanlog / 10)

# simulate litter stocks
litter_stocks_sim <- mapply(
  function(mean, sd) rlnorm(n_sim, mean, sd),
  mean = litter_stocks_meanlog,
  sd = litter_stocks_sdlog
)
colnames(litter_stocks_sim) <- c(
  "litter_pool_above_metabolic",
  "litter_pool_above_structural",
  "litter_pool_below_metabolic",
  "litter_pool_below_structural",
  "litter_pool_woody"
)

# add to dataset
dat <- bind_cols(dat, litter_stocks_sim)




# Litter nutrient contents ------------------------------------------------

# First, aboveground litter including:
# lignin_above_structural
# c_n_ratio_above_metabolic
# c_n_ratio_above_structural
# c_p_ratio_above_metabolic
# c_p_ratio_above_structural

# source models for prediction
source("analysis/litter/nutrient_pool/initial_nutrient_aboveground.R")

# predictions, added directly to the dataset
# NB: the [1, ] index is to extract a Maliau sample site
dat <-
  dat |>
  mutate(
    c_n_ratio_above_metabolic =
      as.numeric(simulate(mod_C.N_met_above, nsim = n_sim)[1, ]),
    c_n_ratio_above_structural =
      r_century * c_n_ratio_above_metabolic,
    c_p_ratio_above_metabolic =
      as.numeric(simulate(mod_C.P_met_above, nsim = n_sim)[1, ]),
    c_p_ratio_above_structural =
      r_century * c_p_ratio_above_metabolic,
    lignin_above_structural =
      as.numeric(simulate(mod_lignin_above, nsim = n_sim)[1, ]),
  )


# Second, belowground litter including:
# lignin_below_structural
# c_n_ratio_below_metabolic
# c_n_ratio_below_structural
# c_p_ratio_below_metabolic
# c_p_ratio_below_structural

# source models for prediction
source("analysis/litter/nutrient_pool/initial_nutrient_belowground.R")

# simulate predictions
below_litter_sim <-
  # first generate random C, N, P and lignin values
  data.frame(
    C = rnorm(n_sim, C_mean, C_sd),
    N = rnorm(n_sim, N_mean, N_sd),
    P = rnorm(n_sim, P_mean, P_sd),
    lignin = rnorm(n_sim, lignin_mean, lignin_sd)
  ) |>
  # convert lignin from mass/mass to g C/g C
  # the lignin C content = 62.5% comes from
  # Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
  mutate(lignin = lignin * 0.625 / C) |>
  # convert N and P to litter content using resorption efficiencies
  mutate(
    N_resorption = rnorm(n_sim, N_resorption_mean, N_resorption_sd),
    P_resorption = rnorm(n_sim, P_resorption_mean, P_resorption_sd),
    N = N * N_resorption / 100,
    P = P * P_resorption / 100
  ) |>
  # calculate C:N and C:P ratios
  mutate(
    CN = C / N,
    CP = C / P
  ) |>
  # calculate metabolic fraction
  mutate(fm = plogis(
    logitfM - lignin * (sN * CN + sP * CP)
  )) |>
  # calculate metabolic and structural nutrients
  # see rearranged equation on the litter theory documentation
  # nolint https://virtual-ecosystem.readthedocs.io/en/latest/virtual_ecosystem/theory/soil/litter_theory.html#split-of-nutrient-inputs-between-pools
  mutate(
    c_n_ratio_below_metabolic = CN / (r_century + fm * (1 - r_century)),
    c_p_ratio_below_metabolic = CP / (r_century + fm * (1 - r_century)),
    c_n_ratio_below_structural = r_century * c_n_ratio_below_metabolic,
    c_p_ratio_below_structural = r_century * c_p_ratio_below_metabolic
  ) |>
  select(c_n_ratio_below_metabolic,
         c_p_ratio_below_metabolic,
         c_n_ratio_below_structural,
         c_p_ratio_below_structural,
         lignin_below_structural = lignin
  )

# add to the dataset
dat <- bind_cols(dat, below_litter_sim)


# Third, woody litter including:
# lignin_woody
# c_n_ratio_woody
# c_p_ratio_woody

# source models for prediction
source("analysis/litter/nutrient_pool/initial_nutrient_woody.R")

# find the row index of a Maliau site, there will be three rows for P, N and C
# we will use the first site because it does not matter which site for the
# simulation purpose (they have the same fixed effects)
deadwood_maliau_idx <- which(nutrient_deadwood$Block == "OG")[1:3]

# simulate deadwood P, N and C
nutrient_deadwood_sim <-
  t(simulate(mod_nutrient_deadwood, nsim = n_sim)[deadwood_maliau_idx, ])
colnames(nutrient_deadwood_sim) <- nutrient_deadwood$Type[deadwood_maliau_idx]

# simulate deadwood lignin
lignin_sim <- rnorm(n_sim, lignin_mean, lignin_sd)
# convert lignin from mass/mass to g C/g C
# the lignin C content = 62.5% comes from
# Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
lignin_sim <-
  lignin_sim * 0.625 / (nutrient_deadwood_sim[, "C_total"] / 100)

# add to the dataset
dat <-
  dat |>
  mutate(
    c_n_ratio_woody =
      nutrient_deadwood_sim[, "C_total"] / nutrient_deadwood_sim[, "N_total"],
    c_p_ratio_woody =
      nutrient_deadwood_sim[, "C_total"] / nutrient_deadwood_sim[, "P_total"],
    lignin_woody = lignin_sim
  )




# Write data to netCDF ----------------------------------------------------

# collect litter metadata
litter_meta_df <-
  reshape2::melt(lapply(litter_meta, function(x) x$unit)) |>
  select(variable = L1,
         unit = value) |>
  filter(variable %in% names(dat)[-(1:4)])

# convert dataframe to arrays
litter_vars <- litter_meta_df$variable
array_list <- vector("list", length(litter_vars))
names(array_list) <- litter_vars
for (i in litter_vars) {
  array_list[[i]] <-
    array(dat[[i]], dim = c(maliau$cell_nx, maliau$cell_ny))
}

# path and file name of netCDF
ncpath <- "data/scenarios/maliau/maliau_1/data/"
ncname <- "litter_maliau"
ncfname <- paste(ncpath, ncname, ".nc", sep = "")

# create and write the netCDF file -- ncdf4 version
# define dimensions
xdim <-
  ncdim_def(
    "x", "m",
    as.double(maliau$cell_x_centres - min(maliau$cell_x_centres))
  )
ydim <-
  ncdim_def(
    "y", "m",
    as.double(maliau$cell_y_centres - min(maliau$cell_y_centres))
  )
# define variables
vardef <- vector("list", nrow(litter_meta_df))
for (i in seq_along(vardef)) {
  vardef[[i]] <-
    ncvar_def(litter_meta_df$variable[i],
              litter_meta_df$unit[i],
              list(xdim, ydim))
}

# create netCDF file and put arrays
ncout <- nc_create(ncfname, vardef, force_v4 = TRUE)

# put variables
for (i in seq_along(litter_vars)) {
  ncvar_put(ncout, vardef[[i]], array_list[[i]])
}

# add global attributes
ncatt_put(
  ncout, 0, "description",
  "Litter data for the Maliau scenario"
)

# Get a summary of the created file:
ncout

# close the file, writing data to disk
nc_close(ncout)
