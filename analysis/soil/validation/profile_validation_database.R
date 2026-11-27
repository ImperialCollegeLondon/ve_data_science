#| ---
#| title: Profile soil validation observations
#|
#| description: |
#|     This R script selects observations whose measurement windows fall within
#|     the maliau_2 simulation period and profiles their locations with the
#|     environmental resources used for validation weighting.
#|
#|     It prepares validation profiles. Request deduplication and a persistent
#|     local SoilGrids crop reduce runtime. Similarity calculation and final
#|     weights are intentionally not calculated here.
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
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau/maliau_grid_definition.toml
#|     description: Scenario timing configuration.
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
#|     description: Environmental profiling functions.
#|
#| package_dependencies:
#|   - arrow
#|   - dplyr
#|   - lubridate
#|   - mapme.biodiversity
#|   - RcppTOML
#|   - readr
#|   - sf
#|   - terra
#|
#| usage_notes: |
#|     Run after build_soil_validation_database.R. Remote resources are cached
#|     under data/primary/validation. The script reduces runtime by extracting
#|     each matching raster-cell and time-period combination once and using a
#|     persistent local SoilGrids crop. Creating or refreshing the crop can be
#|     slow on its first run. A cached 100-row subset reduced runtime from 278
#|     seconds to 121 seconds. The full cached dataset of 854 observations took
#|     1021 seconds and produced 616 extraction requests.
#| ---

library(arrow)
library(dplyr)
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
scenario_definition_path <-
  "data/derived/site/maliau/maliau_grid_definition.toml"
validation_portfolio_path <-
  "data/derived/soil/validation/soil_validation_portfolio.gpkg"
validation_profile_path <-
  "data/derived/soil/validation/soil_validation_portfolio.csv"


# Select observations within the simulation period ------------------------

scenario_definition <- parseTOML(scenario_definition_path)$Scenario[[scenario]]
simulation_start <- as.Date(scenario_definition$core$timing$start_date)
run_length <- trimws(scenario_definition$core$timing$run_length)
simulation_end <- simulation_start %m+% lubridate::period(run_length)
simulation_start <- as.POSIXct(simulation_start, tz = "UTC")
simulation_end <- as.POSIXct(simulation_end, tz = "UTC")

validation_database <-
  open_dataset(validation_database_path) |>
  collect()

validation_database <- validation_database |>
  filter(
    !is.na(time_start),
    !is.na(time_end),
    time_start >= simulation_start,
    time_end <= simulation_end
  )

if (nrow(validation_database) == 0L) {
  stop("No validation observations fall within the simulation period.")
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

local_soilgrids_path <- prepare_local_validation_soilgrids(
  validation_locations
)
profile_grids <- read_validation_profile_grids(
  soilgrids_path = local_soilgrids_path
)

validation_portfolio <- profile_validation_environment(
  validation_locations,
  point_radius_m = 5,
  time_zone = "Asia/Kuching",
  mapme.outdir = "data/primary/validation",
  verbose = TRUE,
  grid_rasters = profile_grids,
  soilgrids_path = local_soilgrids_path
)

validation_profiles <- portfolio_long(
  validation_portfolio,
  drop_geoms = TRUE
)


# Save prepared profiles ---------------------------------------------------

if (file.exists(validation_portfolio_path)) {
  unlink(validation_portfolio_path)
}

write_portfolio(validation_portfolio, validation_portfolio_path)
write_csv(validation_profiles, validation_profile_path)
