#| ---
#| title: Profile soil validation observations for weighting
#|
#| description: |
#|     This R script selects observations whose measurement windows fall within
#|     the maliau_2 simulation period and profiles their locations with the
#|     environmental resources used for validation weighting.
#|
#|     It prepares both validation and scenario reference profiles. Similarity
#|     calculation and final weights are intentionally not calculated here.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: database_combined
#|     path: data/derived/soil/validation/database_combined
#|     description: Soil validation observations combined with VE outputs.
#|   - name: config.toml
#|     path: data/scenarios/maliau/maliau_2/config/config.toml
#|     description: Scenario timing configuration.
#|   - name: maliau_portfolio.gpkg
#|     path: data/derived/validation/maliau_portfolio.gpkg
#|     description: Environmental profiles for the maliau_2 reference grid.
#|
#| output_files:
#|   - name: soil_validation_portfolio.gpkg
#|     path: data/derived/soil/validation/soil_validation_portfolio.gpkg
#|     description: Environmental profiles for eligible location-date windows.
#|   - name: soil_validation_portfolio.csv
#|     path: data/derived/soil/validation/soil_validation_portfolio.csv
#|     description: Validation environmental profiles in long format.
#|
#| source_files:
#|   - name: validation_weight.R
#|     path: tools/R/R/
#|     description: Environmental profiling and portfolio-reading functions.
#|
#| package_dependencies:
#|   - arrow
#|   - dplyr
#|   - future
#|   - lubridate
#|   - mapme.biodiversity
#|   - RcppTOML
#|   - readr
#|   - sf
#|   - terra
#|
#| usage_notes: |
#|     Run after build_soil_validation_database.R. Remote resources are cached
#|     under data/primary/validation. A one-time local SoilGrids crop and grid-
#|     aware deduplication avoid repeated remote and zonal extraction.
#| ---

library(arrow)
library(dplyr)
library(future)
library(lubridate)
library(mapme.biodiversity)
library(RcppTOML)
library(readr)
library(sf)
library(terra)

source("tools/R/R/validation_weight.R")


# Input and output paths ----------------------------------------------------

scenario <- "maliau_2"
validation_database_path <- "data/derived/soil/validation/database_combined"
scenario_config_path <- file.path(
  "data/scenarios/maliau",
  scenario,
  "config/config.toml"
)
reference_portfolio_path <- "data/derived/validation/maliau_portfolio.gpkg"
validation_portfolio_path <-
  "data/derived/soil/validation/soil_validation_portfolio.gpkg"
validation_profile_path <-
  "data/derived/soil/validation/soil_validation_portfolio.csv"


# Select observations within the simulation period ------------------------

scenario_config <- parseTOML(scenario_config_path)
simulation_start <- as.Date(scenario_config$core$timing$start_date)
run_length <- trimws(scenario_config$core$timing$run_length)
simulation_end <- simulation_start %m+% lubridate::period(run_length)
simulation_start <- as.POSIXct(simulation_start, tz = "UTC")
simulation_end <- as.POSIXct(simulation_end, tz = "UTC")

validation_database <-
  open_dataset(validation_database_path) |>
  collect()

eligible_rows <-
  !is.na(validation_database$time_start) &
  !is.na(validation_database$time_end) &
  validation_database$time_start >= simulation_start &
  validation_database$time_end <= simulation_end

if (nrow(validation_database) == 0L || !all(eligible_rows)) {
  stop("All validation observations must fall within the simulation period.")
}


# Prepare one profile per validation location-date window -----------------

validation_locations <-
  validation_database |>
  distinct(longitude, latitude, time_start, time_end) |>
  arrange(longitude, latitude, time_start, time_end) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

reference_portfolio <- read_validation_portfolio(reference_portfolio_path)

local_soilgrids_path <- prepare_local_validation_soilgrids(
  validation_locations
)
profile_grids <- read_validation_profile_grids(
  soilgrids_path = local_soilgrids_path
)

validation_portfolio <- with(
  future::plan(future::multisession, workers = 4L),
  profile_validation_environment(
    validation_locations,
    point_radius_m = 5,
    time_zone = "Asia/Kuching",
    mapme.outdir = "data/primary/validation",
    verbose = TRUE,
    grid_rasters = profile_grids,
    soilgrids_path = local_soilgrids_path
  )
)

validation_profiles <- portfolio_long(
  validation_portfolio,
  drop_geoms = TRUE
)
reference_profiles <- portfolio_long(
  reference_portfolio,
  drop_geoms = TRUE
)


# Save prepared profiles ---------------------------------------------------

if (file.exists(validation_portfolio_path)) {
  unlink(validation_portfolio_path)
}

write_portfolio(validation_portfolio, validation_portfolio_path)
write_csv(validation_profiles, validation_profile_path)
