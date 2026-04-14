#| ---
#| title: Compile initial litter data for the Maliau scenario
#|
#| description: |
#|     This R script compiles initial litter data for the Maliau scenario
#|     from various data analyses into a single netCDF file.
#|     See the metadata in data/scenarios/maliau/soil_litter_metadata.toml
#|     for specific file paths that analysed each variable.
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: soil_litter_metadata.toml
#|     path: data/scenarios/maliau
#|     description: |
#|         Metadata for soil and litter data analyses, currently including
#|         file paths and units
#|   - name: maliau_grid_definition_100m.toml
#|     path: data/derived/site
#|     description: |
#|         Metadata for Maliau grids, primarily to define the data generation
#|         area
#|   - name: litter_stock.csv
#|     path: data/derived/litter/stock
#|     description: |
#|         Estimated litter stock (aboveground/belowground metabolic and
#|         structural, and woody)
#|
#| output_files:
#|   - name: litter_maliau.nc
#|     path: data/scenarios/maliau/maliau_1/data
#|     description: |
#|         Litter input data for the Maliau scenario meant for ve_run.
#|
#| package_dependencies:
#|     - tidyverse
#|     - mvtnorm
#|     - RcppTOML
#|     - readxl
#|     - glmmTMB
#|     - RNetCDF
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
library(RNetCDF)

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
  mutate(
    x = cell_x - min(cell_x),
    y = cell_y - min(cell_y)
  )


# Litter carbon stock -----------------------------------------------------

# This section is about the "C" part in:
# litter_pool_above_metabolic_cnp
# litter_pool_above_structural_cnp
# litter_pool_woody_cnp
# litter_pool_below_metabolic_cnp
# litter_pool_below_structural_cnp

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

litter_stocks_c <- read_csv("data/derived/litter/stock/litter_stock.csv")

# retrieve stock means and then calculate SDs
# they are in log scales to generate stocks with a lognormal distribution
# to keep them positively bound
litter_stocks_c_meanlog <- log(litter_stocks_c$stock)
litter_stocks_c_sdlog <- abs(litter_stocks_c_meanlog / 10)

# simulate litter stocks
litter_stocks_c_sim <- mapply(
  function(mean, sd) rlnorm(n_sim, mean, sd),
  mean = litter_stocks_c_meanlog,
  sd = litter_stocks_c_sdlog
)
colnames(litter_stocks_c_sim) <- c(
  "litter_pool_above_metabolic_c",
  "litter_pool_above_structural_c",
  "litter_pool_below_metabolic_c",
  "litter_pool_below_structural_c",
  "litter_pool_woody_c"
)

# add to dataset
dat <- bind_cols(dat, litter_stocks_c_sim)


# Litter N and P stocks ---------------------------------------------------

# First, aboveground litter including:
# lignin_above_structural
# And the "N" and "P" parts of:
# litter_pool_above_metabolic_cnp
# litter_pool_above_structural_cnp

# source models for prediction
source("analysis/litter/nutrient_pool/initial_nutrient_aboveground.R")

# predictions, added directly to the dataset
# NB: the [1, ] index is to extract a Maliau sample site
# nolint start
dat <-
  dat |>
  mutate(
    c_n_ratio_above_metabolic = as.numeric(simulate(
      mod_C.N_met_above,
      nsim = n_sim
    )[1, ]),
    c_n_ratio_above_structural = r_century * c_n_ratio_above_metabolic,
    c_p_ratio_above_metabolic = as.numeric(simulate(
      mod_C.P_met_above,
      nsim = n_sim
    )[1, ]),
    c_p_ratio_above_structural = r_century * c_p_ratio_above_metabolic,
    lignin_above_structural = as.numeric(simulate(
      mod_lignin_above,
      nsim = n_sim
    )[1, ])
  ) |>
  # calculate litter N and P stocks from C stock and C:N & C:P ratios
  mutate(
    litter_pool_above_metabolic_n = litter_pool_above_metabolic_c /
      c_n_ratio_above_metabolic,
    litter_pool_above_structural_n = litter_pool_above_structural_c /
      c_n_ratio_above_structural,
    litter_pool_above_metabolic_p = litter_pool_above_metabolic_c /
      c_p_ratio_above_metabolic,
    litter_pool_above_structural_p = litter_pool_above_structural_c /
      c_p_ratio_above_structural
  )
# nolint end

# Second, belowground litter including:
# lignin_below_structural
# And the "N" and "P" parts of:
# litter_pool_below_metabolic_cnp
# litter_pool_below_structural_cnp

# source models for prediction
source("analysis/litter/nutrient_pool/initial_nutrient_belowground.R")

# simulate predictions
below_litter_sim <-
  # first generate random C, N, P and lignin values
  # using abs(rnorm(...)) to generate half-Normal random variates so that
  # nutrient values are positive bound
  data.frame(
    C = abs(rnorm(n_sim, C_mean, C_sd)),
    N = abs(rnorm(n_sim, N_mean, N_sd)),
    P = abs(rnorm(n_sim, P_mean, P_sd)),
    lignin = abs(rnorm(n_sim, lignin_mean, lignin_sd))
  ) |>
  # convert lignin from mass/mass to g C/g C
  # the lignin C content = 62.5% comes from
  # Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
  mutate(lignin = lignin * 0.625 / C) |>
  # convert N and P to litter content using resorption efficiencies
  mutate(
    N_resorption = abs(rnorm(n_sim, N_resorption_mean, N_resorption_sd)),
    P_resorption = abs(rnorm(n_sim, P_resorption_mean, P_resorption_sd)),
    N = N * N_resorption / 100,
    P = P * P_resorption / 100
  ) |>
  # calculate C:N and C:P ratios
  mutate(
    CN = C / N,
    CP = C / P
  ) |>
  # calculate metabolic fraction
  mutate(
    fm = plogis(
      logitfM - lignin * (sN * CN + sP * CP)
    )
  ) |>
  # calculate metabolic and structural nutrients
  # see rearranged equation on the litter theory documentation
  # nolint https://virtual-ecosystem.readthedocs.io/en/latest/virtual_ecosystem/theory/soil/litter_theory.html#split-of-nutrient-inputs-between-pools
  mutate(
    c_n_ratio_below_metabolic = CN / (r_century + fm * (1 - r_century)),
    c_p_ratio_below_metabolic = CP / (r_century + fm * (1 - r_century)),
    c_n_ratio_below_structural = r_century * c_n_ratio_below_metabolic,
    c_p_ratio_below_structural = r_century * c_p_ratio_below_metabolic
  ) |>
  select(
    c_n_ratio_below_metabolic,
    c_p_ratio_below_metabolic,
    c_n_ratio_below_structural,
    c_p_ratio_below_structural,
    lignin_below_structural = lignin
  )

# add to the dataset
dat <-
  bind_cols(dat, below_litter_sim) |>
  # calculate litter N and P stocks from C stock and C:N & C:P ratios
  mutate(
    litter_pool_below_metabolic_n = litter_pool_below_metabolic_c /
      c_n_ratio_below_metabolic,
    litter_pool_below_structural_n = litter_pool_below_structural_c /
      c_n_ratio_below_structural,
    litter_pool_below_metabolic_p = litter_pool_below_metabolic_c /
      c_p_ratio_below_metabolic,
    litter_pool_below_structural_p = litter_pool_below_structural_c /
      c_p_ratio_below_structural
  )


# Third, woody litter including:
# lignin_woody
# And the "N" and "P" parts of:
# litter_pool_woody_cnp

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
lignin_sim <- abs(rnorm(n_sim, lignin_mean, lignin_sd))
# convert lignin from mass/mass to g C/g C
# the lignin C content = 62.5% comes from
# Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
lignin_sim <-
  lignin_sim * 0.625 / (nutrient_deadwood_sim[, "C_total"] / 100)

# add to the dataset
# nolint start
dat <-
  dat |>
  mutate(
    c_n_ratio_woody = nutrient_deadwood_sim[, "C_total"] /
      nutrient_deadwood_sim[, "N_total"],
    c_p_ratio_woody = nutrient_deadwood_sim[, "C_total"] /
      nutrient_deadwood_sim[, "P_total"],
    lignin_woody = lignin_sim
  ) |>
  # calculate litter N and P stocks from C stock and C:N & C:P ratios
  mutate(
    litter_pool_woody_n = litter_pool_woody_c / c_n_ratio_woody,
    litter_pool_woody_p = litter_pool_woody_c / c_p_ratio_woody
  )
# nolint end

# Combine litter C, N and P stocks into triplets
dat <-
  dat |>
  mutate(
    litter_pool_above_metabolic_cnp = pmap(
      list(
        litter_pool_above_metabolic_c,
        litter_pool_above_metabolic_n,
        litter_pool_above_metabolic_p
      ),
      c
    ),
    litter_pool_below_metabolic_cnp = pmap(
      list(
        litter_pool_below_metabolic_c,
        litter_pool_below_metabolic_n,
        litter_pool_below_metabolic_p
      ),
      c
    ),
    litter_pool_above_structural_cnp = pmap(
      list(
        litter_pool_above_structural_c,
        litter_pool_above_structural_n,
        litter_pool_above_structural_p
      ),
      c
    ),
    litter_pool_below_structural_cnp = pmap(
      list(
        litter_pool_below_structural_c,
        litter_pool_below_structural_n,
        litter_pool_below_structural_p
      ),
      c
    ),
    litter_pool_woody_cnp = pmap(
      list(
        litter_pool_woody_c,
        litter_pool_woody_n,
        litter_pool_woody_p
      ),
      c
    ),
    .keep = "unused"
  )


# Write data to netCDF ----------------------------------------------------

# collect litter metadata
litter_meta_df <-
  reshape2::melt(lapply(litter_meta, function(meta) meta$unit)) |>
  select(
    variable = L1,
    unit = value
  ) |>
  filter(variable %in% names(dat)[-(1:4)])

# path and file name of netCDF
ncpath <- "data/scenarios/maliau/maliau_1/data/"
ncname <- "litter_maliau"
ncfname <- paste0(ncpath, ncname, ".nc")

# create netCDF file
ncout <- create.nc(ncfname, format = "netcdf4")

# define dimensions
dim.def.nc(ncout, "x", maliau$cell_nx)
dim.def.nc(ncout, "y", maliau$cell_ny)
dim.def.nc(ncout, "element", 3)
var.def.nc(ncout, "x", "NC_FLOAT", "x")
var.def.nc(ncout, "y", "NC_FLOAT", "y")
var.def.nc(ncout, "element", "NC_STRING", "element")
att.put.nc(ncout, "x", "units", "NC_CHAR", "m")
att.put.nc(ncout, "y", "units", "NC_CHAR", "m")
var.put.nc(
  ncout,
  "x",
  as.double(maliau$cell_x_centres - min(maliau$cell_x_centres))
)
var.put.nc(
  ncout,
  "y",
  as.double(maliau$cell_y_centres - min(maliau$cell_y_centres))
)
var.put.nc(ncout, "element", c("C", "N", "P"))

# define variables
litter_vars <- litter_meta_df$variable
for (i in litter_vars) {
  if (str_detect(i, "_cnp")) {
    var.def.nc(ncout, i, "NC_DOUBLE", rev(c("x", "y", "element")))
  } else {
    var.def.nc(ncout, i, "NC_DOUBLE", rev(c("x", "y")))
  }
  # add units
  # more metadata can be added here
  att.put.nc(
    ncout,
    i,
    "units",
    "NC_CHAR",
    litter_meta_df$unit[litter_meta_df$variable == i]
  )
}

# convert dataframe to arrays
array_list <- vector("list", length(litter_vars))
names(array_list) <- litter_vars
for (i in litter_vars) {
  if (str_detect(i, "_cnp")) {
    triplet_tmp <- do.call(rbind, dat[[i]])
    array_list[[i]] <-
      array(triplet_tmp, dim = rev(c(maliau$cell_nx, maliau$cell_ny, 3)))
  } else {
    array_list[[i]] <-
      array(dat[[i]], dim = rev(c(maliau$cell_nx, maliau$cell_ny)))
  }
}

# put variables from arrays to netCDF
for (i in litter_vars) {
  var.put.nc(ncout, i, array_list[[i]])
}

# add global attributes
att.put.nc(
  ncout,
  "NC_GLOBAL",
  "description",
  "NC_CHAR",
  "Litter data for the Maliau scenario"
)

# Get a summary of the created file
print.nc(ncout)

# close the file, writing data to disk
close.nc(ncout)
