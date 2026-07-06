library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(RNetCDF)
library(glmmTMB)
library(biogas)
library(lubridate)
library(hms)
source("tools/R/convert_df_to_nc.R")

set.seed(20260703)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")
soil_meta <- soil_meta$soil


# SAFE site metadata ----------------------------------------------------

safe <-
  parseTOML("data/derived/site/safe/safe_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("safe_1")

# total number of grids
n_sim <- with(safe, cell_nx * cell_ny)


# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = safe$cell_x_centres,
    cell_y = safe$cell_y_centres
  )


# Spatial prediction from SAFE soil campaign ------------------------------

# script that fits a spatial model to the SAFE data
source("analysis/soil/initialisation/model_safe.R")

# extract covariates to the SAFE region of interest
dat <-
  dat |>
  mutate(
    elev = terra::extract(elev, pick("cell_x", "cell_y"))[,
      "SRTM_UTM50N_processed"
    ],
    topo = terra::extract(topo, pick("cell_x", "cell_y"))[,
      "SRTM_UTM50N_TRI_Wilson2007"
    ],
    hydro = terra::extract(hydro, pick("cell_x", "cell_y"))[,
      "SRTM_Log_Flow_Accum"
    ],
    acd = terra::extract(acd, pick("cell_x", "cell_y"))[, "acd"],
    evi = terra::extract(evi, pick("cell_x", "cell_y"))[, "EVI"]
  ) |>
  # fill in grids with missing ACD (LiDAR) and EVI values with the mean value
  mutate(
    acd = ifelse(is.na(acd), mean(acd, na.rm = TRUE), acd),
    evi = ifelse(is.na(evi), mean(evi, na.rm = TRUE), evi)
  ) |>
  mutate(
    elev = (elev - mean(soil$elev)) / sd(soil$elev),
    topo = (topo - mean(soil$topo)) / sd(soil$topo),
    hydro = (hydro - mean(soil$hydro)) / sd(soil$hydro),
    acd = (acd - mean(soil$acd)) / sd(soil$acd),
    evi = (evi - mean(soil$evi)) / sd(soil$evi)
  )

# new basis functions for the SAFE region
safe_basis <-
  mrts(soil[, c("X", "Y")], num_basis) |>
  predict(newx = dat[, c("cell_x", "cell_y")]) |>
  as.matrix()
# remove intercept
safe_basis <- safe_basis[, -1]

# predict onto the SAFE grids
safe_pred <- predict(
  fitcbfm,
  newdata = dat,
  new_B_space = safe_basis
)
# backtransform to observation scale
safe_pred[, -c(1, 2)] <- exp(safe_pred[, -c(1, 2)])

# add predictions to dataset
dat <- bind_cols(dat, safe_pred)

# convert to raster and then plot it for a sanity check
plot(rast(dat))


# Soil variables that can be used as is -----------------------------------

# There are soil variables collected from the SAFE soil campaign that can be
# used directly in the Maliau scenario; they do not need further processing.
# These include:
# pH
# clay_fraction

dat <-
  dat |>
  rename(
    pH = pH,
    clay_fraction = clay
  ) |>
  mutate(clay_fraction = clay_fraction / 100)

# The remaining total C, N and P will be split into separate pools

# Split SAFE campaign variables into specific pools -----------------------

# first we predict POM and MAOM carbon and nitrogen fractions:
# soil_c_pool_pom
# soil_c_pool_maom
# soil_n_pool_particulate
# soil_n_pool_maom

#### Missing data ####

# soil_c_pool_lmwc
# using DOC as a proxy

#### Missing data ####

# Microbial C fractions, including:
# soil_c_pool_arbuscular_mycorrhiza
# soil_c_pool_bacteria
# soil_c_pool_ectomycorrhiza
# soil_c_pool_saprotrophic_fungi

# first we estimate the total microbial fraction in the carbon pool
source("analysis/soil/nutrient_pools/carbon_microbial.R")
C_mic_perc_safe <- extract_microbial_to_soil_C_ratio(safe)
soil_c_pool_microbe <- dat$total_carbon * C_mic_perc_safe / 100

# then we split the total microbial fraction by guild
# use MLF plot-type predictions
source("analysis/soil/nutrient_pools/carbon_microbial_guild.R")
soil_c_pool_microbe_guild <-
  sapply(
    microbe_ratio |> filter(Plot_ID == "MLF") |> pull(p_carbon),
    \(p) {
      p * soil_c_pool_microbe
    }
  )
colnames(soil_c_pool_microbe_guild) <-
  c(
    "soil_c_pool_saprotrophic_fungi",
    "soil_c_pool_ectomycorrhiza",
    "soil_c_pool_arbuscular_mycorrhiza",
    "soil_c_pool_bacteria"
  )

# add to dataset
dat <- bind_cols(dat, soil_c_pool_microbe_guild)


# Necromass nutrient pools, including:
# soil_c_pool_necromass
# soil_n_pool_necromass
# soil_p_pool_necromass
# Value are in kg / kg SOC (fraction of soil carbon), so we scale it off the
# predicted total soil carbon
source("analysis/soil/necromass/necromass.R")

# Necromass nutrient pools, including:
# soil_c_pool_necromass
# soil_n_pool_necromass
# soil_p_pool_necromass
# Value are in kg / kg SOC (fraction of soil carbon), so we scale it off the
# predicted total soil carbon
source("analysis/soil/necromass/necromass.R")

# calculate CNP in necromass as a proportion of total C
# use secondary forest (SF) for logged forests of SAFE
necromass <- extract_necromass("SF")

dat <-
  dat |>
  mutate(
    soil_c_pool_necromass = total_carbon * necromass$C,
    soil_n_pool_necromass = total_carbon * necromass$N,
    soil_p_pool_necromass = total_carbon * necromass$P
  )

# Soil phosphorous pools
# split total phosphorous in the SAFE dataset to separate pools

#### Missing data ####

# Variables that scale / are predicted independently from SAFE -----------

# Inorganic nitrogen, including:
# soil_n_pool_ammonium
# soil_n_pool_nitrate

source("analysis/soil/ammonium_nitrate/model.R")

# find the row index of a SAFE forest site to approximate SAFE logged forests
# this is the 'forest' sites in the dataset
# we will use the first site because it does not matter which site for the
# simulation purpose (they have the same fixed effects)
flux_forest_idx <- which(flux$landuse == "forest")[1]

# simulate ammonium and nitrate
# 1 mg N cm-3 = 1 kg N m-3 so no conversion needed
ammonium_sim <- as.numeric(
  glmmTMB:::simulate.glmmTMB(mod_ammonium, nsim = n_sim)[flux_forest_idx, ]
)
nitrate_sim <- as.numeric(
  glmmTMB:::simulate.glmmTMB(mod_nitrate, nsim = n_sim)[flux_forest_idx, ]
)

# add to dataset
dat <-
  dat |>
  mutate(
    soil_n_pool_ammonium = ammonium_sim,
    soil_n_pool_nitrate = nitrate_sim
  )


# Fungal fruiting body biomass:
# fungal_fruiting_bodies
source("analysis/soil/sporocarp_biomass/sporocarp_biomass.R")

# simulate and add directly to dataset
dat <-
  dat |>
  mutate(
    fungal_fruiting_bodies = rnorm(
      n_sim,
      sporocarp_biomass_mean,
      sporocarp_biomass_sd
    )
  )


# Soil enzymatic pools, including
# soil_enzyme_maom_bacteria
# soil_enzyme_maom_fungi
# soil_enzyme_pom_bacteria
# soil_enzyme_pom_fungi
# These are notoriously hard to find empirical data for, and will be the only
# set of variables currently relying on crude guesstimates
source("analysis/soil/enzyme/enzyme_concentration.R")

# simulate total soil enzyme concentration [mg C / g soil]
soil_enzyme <- exp(rnorm(n_sim, enzyme_conc_mean, enzyme_conc_sd))
# raise the values by one order of magnitude following MEND guesstimate
soil_enzyme <- soil_enzyme * MEND_factor
# convert to unit [kg C / kg soil]
soil_enzyme <- soil_enzyme / 1e3

# split total enzyme equally among the four enzyme groups; add to dataset
dat <-
  dat |>
  mutate(
    soil_enzyme_maom_bacteria = soil_enzyme * 0.25,
    soil_enzyme_maom_fungi = soil_enzyme * 0.25,
    soil_enzyme_pom_bacteria = soil_enzyme * 0.25,
    soil_enzyme_pom_fungi = soil_enzyme * 0.25
  )
