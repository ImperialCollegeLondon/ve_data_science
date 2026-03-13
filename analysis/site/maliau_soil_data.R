#| ---
#| title: Compile initial soil data for the Maliau scenario
#|
#| description: |
#|     This R script compiles initial soil data for the Maliau scenario
#|     from various data analyses into a single netCDF file.
#|     See the metadata in data/scenarios/maliau/soil_litter_metadata.toml
#|     for specific file paths that analysed each variable.
#|
#| virtual_ecosystem_module: Soil
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
#|   - name:
#|     path:
#|     description: |
#|
#|
#| output_files:
#|   - name:
#|     path:
#|     description: |
#|
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - RcppTOML
#|     - sf
#|     - terra
#|     - autoFRK
#|     - CBFM
#|     - ncdf4
#|     - glmmTMB
#|     - biogas
#|     - lubridate
#|     - hms
#|
#| usage_notes: |
#|     For more details on statistical and data assumptions, see
#|     data/scenarios/maliau/soil_metadata.toml; The CBFM package needs to be
#|     installed from https://github.com/fhui28/CBFM
#| ---

library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(ncdf4)
library(glmmTMB)
library(biogas)
library(lubridate)
library(hms)

set.seed(20260313)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")


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



# Spatial prediction from SAFE soil campaign ------------------------------

# script that fits a spatial model to the SAFE data
source("analysis/soil/initialisation/model_safe.R")

# extract covariates to the Maliau region of interest
dat <-
  dat |>
  mutate(
    elev = terra::extract(elev, pick("cell_x", "cell_y"))[, "SRTM_UTM50N_processed"],
    topo = terra::extract(topo, pick("cell_x", "cell_y"))[, "SRTM_UTM50N_TRI_Wilson2007"],
    hydro = terra::extract(hydro, pick("cell_x", "cell_y"))[, "SRTM_Log_Flow_Accum"],
    # set acd to mean because there is no full data coverage
    # for the entire Maliau region
    acd = mean(soil$acd),
    evi = terra::extract(evi, pick("cell_x", "cell_y"))[, "EVI"]
  ) |>
  mutate(
    elev = (elev - mean(soil$elev)) / sd(soil$elev),
    topo = (topo - mean(soil$topo)) / sd(soil$topo),
    hydro = (hydro - mean(soil$hydro)) / sd(soil$hydro),
    acd = (acd - mean(soil$acd)) / sd(soil$acd),
    evi = (evi - mean(soil$evi)) / sd(soil$evi)
  ) |>
  # we need to fill in two NA grids in the EVI layer,
  # I think they are due to rivers / water bodies
  fill(evi)

# new basis functions for the Maliau region
maliau_basis <-
  mrts(soil[, c("X", "Y")], num_basis) |>
  predict(newx = dat[, c("cell_x", "cell_y")]) |>
  as.matrix()
# remove intercept
maliau_basis <- maliau_basis[, -1]

# predict onto the Maliau grids
maliau_pred <- predict(
  fitcbfm,
  newdata = dat,
  new_B_space = maliau_basis
)
# backtransform to observation scale
maliau_pred[, -c(1, 2)] <- exp(maliau_pred[, -c(1, 2)])

# add predictions to dataset
dat <- bind_cols(dat, maliau_pred)

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
  rename(pH = pH,
         clay_fraction = clay) |>
  mutate(clay_fraction = clay_fraction / 100)

# The remaining total C, N and P will be split into separate pools



# Split SAFE campaign variables into specific pools -----------------------

# first we predict POM and MAOM carbon and nitrogen fractions:
# soil_c_pool_pom
# soil_c_pool_maom
# soil_n_pool_particulate
# soil_n_pool_maom

# Both are predicted from control plots from a tropical forest in BCI
source("analysis/soil/nutrient_pools/pom_maom_sayer.R")

dat <-
  dat |>
  mutate(
    soil_c_pool_pom =
      predict(mod_C,
              newdata =
                dat |>
                select(C_total = total_carbon) |>
                mutate(class = "POM",
                       treatm = "CT",
                       block = NA),
              allow.new.levels = TRUE,
              type = "response"),
    soil_c_pool_maom =
      predict(mod_C,
              newdata =
                dat |>
                select(C_total = total_carbon) |>
                mutate(class = "MAOM",
                       treatm = "CT",
                       block = NA),
              allow.new.levels = TRUE,
              type = "response"),
    soil_n_pool_particulate =
      predict(mod_N,
              newdata =
                dat |>
                select(N_total = total_nitrogen) |>
                mutate(class = "POM",
                       treatm = "CT",
                       block = NA),
              allow.new.levels = TRUE,
              type = "response"),
    soil_n_pool_maom =
      predict(mod_N,
              newdata =
                dat |>
                select(N_total = total_nitrogen) |>
                mutate(class = "MAOM",
                       treatm = "CT",
                       block = NA),
              allow.new.levels = TRUE,
              type = "response")
  )


# soil_c_pool_lmwc
# using DOC as a proxy
# then convert units to kg/m^3 using bulk density from SAFE converted to kg/m^3
# NB: the LWMC values are in the same order of magnitude as POM C, which is
#     possible although we expected LMWC to be lower; I am letting this pass
#     for now for the purpose of initialisation

source("analysis/soil/nutrient_pools/doc_don.R")

dat <-
  dat |>
  mutate(soil_c_pool_lmwc = rnorm(n_sim, doc_mean, doc_sd),
         soil_c_pool_lmwc = soil_c_pool_lmwc  / 1e6 * (bulk_density * 1e3))

# soil_n_pool_don
# values are quite high compared to POM and MAOM, worth checking later
dat <-
  dat |>
  mutate(soil_n_pool_don = rnorm(n_sim, don_mean, don_sd),
         soil_n_pool_don = soil_n_pool_don  / 1e6 * (bulk_density * 1e3))


# Microbial C fractions, including:
# soil_c_pool_arbuscular_mycorrhiza
# soil_c_pool_bacteria
# soil_c_pool_ectomycorrhiza
# soil_c_pool_saprotrophic_fungi

# first we estimate the total microbial fraction in the carbon pool
source("analysis/soil/nutrient_pools/carbon_microbial.R")
soil_c_pool_microbe <- dat$total_carbon * C_mic_perc_maliau / 100

# then we split the total microbial fraction by guild
source("analysis/soil/nutrient_pools/carbon_microbial_guild.R")
soil_c_pool_microbe_guild <-
  sapply(microbe_ratio, function(ratio) ratio * soil_c_pool_microbe)
names(soil_c_pool_microbe_guild) <-
  c("soil_c_pool_saprotrophic_fungi",
    "soil_c_pool_ectomycorrhiza",
    "soil_c_pool_arbuscular_mycorrhiza",
    "soil_c_pool_bacteria")

# add to dataset
dat <- bind_cols(dat, soil_c_pool_microbe_guild)


# Necromass nutrient pools, including:
# soil_c_pool_necromass
# soil_n_pool_necromass
# soil_p_pool_necromass
# Value are in kg / kg SOC (fraction of soil carbon), so we scale it off the
# predicted total soil carbon
source("analysis/soil/necromass/necromass.R")

dat <-
  dat |>
  mutate(soil_c_pool_necromass = total_carbon * necromass_C,
         soil_n_pool_necromass = total_carbon * necromass_N,
         soil_p_pool_necromass = total_carbon * necromass_P)


# Soil phosphorous pools
# split total phosphorous in the SAFE dataset to separate pools
source("analysis/soil/nutrient_pools/phosphorous_pools.R")

p_fractions <-
  sapply(p_pools$prop, function(prop) prop * dat$total_phosphorus)
# convert phosphorous from mg/kg to kg/kg
p_fractions <- p_fractions / 1e6
colnames(p_fractions) <- p_pools$fraction

# add to dataset
dat <- bind_cols(dat, p_fractions)

# NB: at this point, soil_p_pool_necromass seems very higher (even than the
#     total phosphorous amount). This is definitely worth checking later.




# Variables that scale / are predicted independently from SAFE -----------

# Inorganic nitrogen, including:
# soil_n_pool_ammonium
# soil_n_pool_nitrate

source("analysis/soil/ammonium_nitrate/model.R")

# find the row index of a SAFE forest site to approximate Maliau
# (though note them are OG)
# we will use the first site because it does not matter which site for the
# simulation purpose (they have the same fixed effects)
flux_forest_idx <- which(flux$landuse == "forest")[1]

# simulate ammonium and nitrate
# 1 mg N cm-3 = 1 kg N m-3 so no conversion needed
ammonium_sim <-
  as.numeric(
    glmmTMB:::simulate.glmmTMB(mod_ammonium, nsim = n_sim)[flux_forest_idx, ])
nitrate_sim <-
  as.numeric(
    glmmTMB:::simulate.glmmTMB(mod_nitrate, nsim = n_sim)[flux_forest_idx, ])





# Soil enzymatic pools ----------------------------------------------------





# Convert from per-mass to per-volume basis -------------------------------


