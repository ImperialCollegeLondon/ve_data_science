library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(modelr)


# Data --------------------------------------------------------------------

# Predictors

# Elevation
elev <-
  rast("data/primary/abiotic/STRM_data_elevation/SRTM_UTM50N_processed.tif")

# Topography
topo <-
  rast("data/primary/abiotic/SAFE_topographic_roughness/SRTM_UTM50N_TRI_Wilson2007.tif")

# Climate
# tp <- 
#   rast("data/primary/abiotic/era5_land_monthly/ERA5_monthly_2010_2020_SAFE_big.nc",
#        subds = "tp") %>% 
#   mean(., na.rm = TRUE) %>%
#   project(., crs(elev))

# Hydrology
hydro <- 
  rast("data/primary/abiotic/SRTM_hydrology/SRTM_Log_Flow_Accum.tif")

# LiDAR
acd <- 
  merge(
    rast("data/primary/plant/remote_biomass/Danum_acd.tif"),
    rast("data/primary/plant/remote_biomass/Maliau_acd.tif"),
    rast("data/primary/plant/remote_biomass/SAFE_acd.tif")
  )

# Biomass
evi <-
  rast("data/primary/plant/remote_biomass/Sabah_EVI_2024_Q1.tif")

# location details
maliau <-
  parseTOML("data/sites/maliau_grid_definition_100m.toml")

extra_locations <-
  tribble(
    ~location, ~lat, ~lon,
    "OG3_DW1", 4.733986, 116.970434,
    "OG3_DW2", 4.7341235, 116.967075,
    "OG3_DW3", 4.734606, 116.965199
  ) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

location_sf <-
  st_read("data/sites/gazetteer.geojson") %>%
  bind_rows(extra_locations) %>%
  st_transform(crs = st_crs(elev)) %>%
  st_centroid()

location <-
  location_sf %>%
  st_coordinates() %>%
  as.data.frame() %>%
  mutate(location = location_sf$location)

# soil variables
soil <-
  read_xlsx(
    "data/primary/soil/nutrient/SAFE_soil_nutrient_data.xlsx",
    sheet = 3,
    skip = 4
  ) %>%
  left_join(location, by = join_by("plot_code" == "location")) %>%
  mutate(
    elev = extract(elev, .[, c("X", "Y")])[, "SRTM_UTM50N_processed"],
    topo = extract(topo, .[, c("X", "Y")])[, "SRTM_UTM50N_TRI_Wilson2007"],
    hydro = extract(hydro, .[, c("X", "Y")])[, "SRTM_Log_Flow_Accum"],
    acd = extract(acd, .[, c("X", "Y")])[, "Danum_acd"],
    evi = extract(evi, .[, c("X", "Y")])[, "EVI"]
  ) %>% 
  drop_na(elev, topo, hydro, acd, evi)

soil_vars <-
  c(
    "pH",
    "bulk_density",
    "clay",
    "total_carbon",
    "total_nitrogen",
    "total_phosphorus",
    "available_phosphorus",
    "plot_mean_o_horizon"
  )
soil_mat <- as.matrix(soil[, soil_vars])
# TODO non-Gaussian families to avoid log-transformation of responses
# though pH is tricky
soil_mat[, -c(1, 2)] <- log(soil_mat[, -c(1, 2)])
rownames(soil_mat) <- soil$plot_code

# TODO scale covariates
soil_scaled <- 
  soil %>% 
  mutate_at(vars(elev, topo, hydro, acd, evi), 
            ~as.numeric(scale(.)))




# Model -------------------------------------------------------------------

# Set up spatial basis functions for CBFM
# Number of spatial basis functions to use
num_basis <- 25

# basis functions
basis_func <-
  mrts(soil_scaled[, c("X", "Y")], num_basis) %>%
  as.matrix() %>%
  # Remove the first intercept column
  {
    .[, -(1)]
  }

# Fit CBFM
tic <- proc.time()
fitcbfm <-
  CBFM(
    y = soil_mat,
    formula = ~ 1 + elev + topo + hydro + acd + evi,
    data = soil_scaled,
    B_space = basis_func,
    family = gaussian(),
    control = list(trace = 1),
    G_control = list(rank = 2)
  )
toc <- proc.time()
toc - tic

summary(fitcbfm) %>%
  str()

coef(fitcbfm)

corrplot::corrplot(corB(fitcbfm), order = "FPC", diag = FALSE, type = "lower")
corrplot::corrplot(corX(fitcbfm), order = "FPC", diag = FALSE, type = "lower")


# Prediction --------------------------------------------------------------

maliau_grid <-
  soil %>%
  data_grid(
    X = maliau$cell_x_centres,
    Y = maliau$cell_y_centres
  )

maliau_dat <-
  maliau_grid %>%
  mutate(
    elev = extract(elev, .[, c("X", "Y")])[, "SRTM_UTM50N_processed"],
    topo = extract(topo, .[, c("X", "Y")])[, "SRTM_UTM50N_TRI_Wilson2007"],
    hydro = extract(hydro, .[, c("X", "Y")])[, "SRTM_Log_Flow_Accum"],
    # acd = extract(acd, .[, c("X", "Y")])[, "Danum_acd"],
    acd = mean(soil$acd),
    evi = extract(evi, .[, c("X", "Y")])[, "EVI"]
  ) %>% 
  mutate(elev = (elev - mean(soil$elev)) / sd(soil$elev),
         topo = (topo - mean(soil$topo)) / sd(soil$topo),
         hydro = (hydro - mean(soil$hydro)) / sd(soil$hydro),
         acd = (acd - mean(soil$acd)) / sd(soil$acd),
         evi = (evi - mean(soil$evi)) / sd(soil$evi))

maliau_basis <-
  mrts(soil[, c("X", "Y")], num_basis) %>%
  predict(newx = maliau_grid[, c("X", "Y")]) %>% 
  as.matrix() %>%
  {
    .[, -(1)]
  }

maliau_pred <- predict(
  fitcbfm,
  newdata = maliau_dat,
  new_B_space = maliau_basis
)

maliau_pred_rast <-
  cbind(maliau_dat, maliau_pred) %>%
  rast()

plot(maliau_pred_rast)
