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
#|     - RNetCDF
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
library(RNetCDF)
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
# nolint start
dat <-
  dat |>
  mutate(
    elev = terra::extract(elev, pick("cell_x", "cell_y"))[
      ,
      "SRTM_UTM50N_processed"
    ],
    topo = terra::extract(topo, pick("cell_x", "cell_y"))[
      ,
      "SRTM_UTM50N_TRI_Wilson2007"
    ],
    hydro = terra::extract(hydro, pick("cell_x", "cell_y"))[
      ,
      "SRTM_Log_Flow_Accum"
    ],
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
# nolint end

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

# Both are predicted from control plots from a tropical forest in BCI
source("analysis/soil/nutrient_pools/pom_maom_sayer.R")

# nolint start
dat <-
  dat |>
  mutate(
    soil_c_pool_pom = predict(
      mod_C,
      newdata = dat |>
        select(C_total = total_carbon) |>
        mutate(
          class = "POM",
          treatm = "CT",
          block = NA
        ),
      allow.new.levels = TRUE,
      type = "response"
    ),
    soil_c_pool_maom = predict(
      mod_C,
      newdata = dat |>
        select(C_total = total_carbon) |>
        mutate(
          class = "MAOM",
          treatm = "CT",
          block = NA
        ),
      allow.new.levels = TRUE,
      type = "response"
    ),
    soil_n_pool_particulate = predict(
      mod_N,
      newdata = dat |>
        select(N_total = total_nitrogen) |>
        mutate(
          class = "POM",
          treatm = "CT",
          block = NA
        ),
      allow.new.levels = TRUE,
      type = "response"
    ),
    soil_n_pool_maom = predict(
      mod_N,
      newdata = dat |>
        select(N_total = total_nitrogen) |>
        mutate(
          class = "MAOM",
          treatm = "CT",
          block = NA
        ),
      allow.new.levels = TRUE,
      type = "response"
    )
  )
# nolint end

# soil_c_pool_lmwc
# using DOC as a proxy
# then convert units from [microgram / gram] to [kg/kg]
# NB: the LWMC values are in the same order of magnitude as POM C, which is
#     possible although we expected LMWC to be lower; I am letting this pass
#     for now for the purpose of initialisation

source("analysis/soil/nutrient_pools/doc_don.R")

dat <-
  dat |>
  mutate(
    soil_c_pool_lmwc = rnorm(n_sim, doc_mean, doc_sd),
    soil_c_pool_lmwc = soil_c_pool_lmwc / 1e6
  )

# soil_n_pool_don
# values are quite high compared to POM and MAOM, worth checking later
dat <-
  dat |>
  mutate(
    soil_n_pool_don = rnorm(n_sim, don_mean, don_sd),
    soil_n_pool_don = soil_n_pool_don / 1e6
  )


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

dat <-
  dat |>
  mutate(
    soil_c_pool_necromass = total_carbon * necromass_C,
    soil_n_pool_necromass = total_carbon * necromass_N,
    soil_p_pool_necromass = total_carbon * necromass_P
  )


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


# Convert from per-mass to per-volume basis -------------------------------
# The SAFE soil dataset measured nutrients in mass [nutrient] / kg soil
# we need to convert this to mass [nutrient] / m^3 soil using bulk density

dat <-
  dat |>
  mutate_at(
    vars(
      soil_c_pool_pom,
      soil_c_pool_maom,
      soil_c_pool_lmwc,
      soil_c_pool_saprotrophic_fungi,
      soil_c_pool_ectomycorrhiza,
      soil_c_pool_arbuscular_mycorrhiza,
      soil_c_pool_bacteria,
      soil_c_pool_necromass,
      soil_enzyme_maom_bacteria,
      soil_enzyme_maom_fungi,
      soil_enzyme_pom_bacteria,
      soil_enzyme_pom_fungi,
      soil_n_pool_particulate,
      soil_n_pool_maom,
      soil_n_pool_don,
      soil_n_pool_necromass,
      soil_p_pool_dop,
      soil_p_pool_labile,
      soil_p_pool_particulate,
      soil_p_pool_maom,
      soil_p_pool_secondary,
      soil_p_pool_primary,
      soil_p_pool_necromass
    ),
    ~ . * (bulk_density * 1e3)
  ) |>
  # special treatment for CNP triplets
  mutate(
    soil_cnp_pool_lmwc = pmap(
      list(soil_c_pool_lmwc, soil_n_pool_don, soil_p_pool_dop),
      c
    ),
    soil_cnp_pool_maom = pmap(
      list(soil_c_pool_maom, soil_n_pool_maom, soil_p_pool_maom),
      c
    ),
    soil_cnp_pool_pom = pmap(
      list(soil_c_pool_pom, soil_n_pool_particulate, soil_p_pool_particulate),
      c
    ),
    soil_cnp_pool_necromass = pmap(
      list(soil_c_pool_necromass, soil_n_pool_necromass, soil_p_pool_necromass),
      c
    ),
    .keep = "unused"
  )


# Write data to netCDF ----------------------------------------------------

# collect soil metadata
soil_meta_df <-
  reshape2::melt(lapply(soil_meta, function(meta) meta$unit)) |>
  select(
    variable = L1,
    unit = value
  ) |>
  filter(variable %in% names(dat))

# path and file name of netCDF
ncpath <- "data/scenarios/maliau/maliau_1/data/"
ncname <- "soil_maliau"
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
soil_vars <- soil_meta_df$variable
for (i in soil_vars) {
  if (str_detect(i, "_cnp_")) {
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
    soil_meta_df$unit[soil_meta_df$variable == i]
  )
}

# convert dataframe to arrays
# note that I am explicitly using rev() to reverse the order of the element
# dimension here in R so in Python it is ordered in the 'right' way
array_list <- vector("list", length(soil_vars))
names(array_list) <- soil_vars
for (i in soil_vars) {
  if (str_detect(i, "_cnp_")) {
    triplet_tmp <- do.call(rbind, dat[[i]])
    array_list[[i]] <-
      array(triplet_tmp, dim = rev(c(maliau$cell_nx, maliau$cell_ny, 3)))
  } else {
    array_list[[i]] <-
      array(dat[[i]], dim = rev(c(maliau$cell_nx, maliau$cell_ny)))
  }
}

# put variables from arrays to netCDF
for (i in soil_vars) {
  var.put.nc(ncout, i, array_list[[i]])
}

# add global attributes
att.put.nc(
  ncout,
  "NC_GLOBAL",
  "description",
  "NC_CHAR",
  "Soil data for the Maliau scenario"
)

# Get a summary of the created file
print.nc(ncout)

# close the file, writing data to disk
close.nc(ncout)
