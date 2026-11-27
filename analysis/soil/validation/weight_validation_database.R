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
#|   - mapme.biodiversity
#|   - RcppTOML
#|   - readr
#|   - sf
#|
#| usage_notes: |
#|     Run after build_soil_validation_database.R. Remote resources are cached
#|     under data/primary/validation and may take time to download on first run.
#| ---

library(arrow)
library(dplyr)
library(mapme.biodiversity)
library(RcppTOML)
library(readr)
library(sf)

source("tools/R/R/validation_weight.R")


# Input and output paths ----------------------------------------------------

scenario <- "maliau_2"
validation_database_path <-
  "data/derived/soil/validation/database_combined"
scenario_config_path <- file.path(
  "data/scenarios/maliau",
  scenario,
  "config/config.toml"
)
reference_portfolio_path <-
  "data/derived/validation/maliau_portfolio.gpkg"
validation_portfolio_path <-
  "data/derived/soil/validation/soil_validation_portfolio.gpkg"
validation_profile_path <-
  "data/derived/soil/validation/soil_validation_portfolio.csv"


# Select observations within the simulation period ------------------------

scenario_config <- parseTOML(scenario_config_path)
simulation_start <- as.Date(scenario_config$core$timing$start_date)
run_length <- trimws(scenario_config$core$timing$run_length)
run_length_parts <- strsplit(run_length, "[[:space:]]+")[[1]]

if (
  length(run_length_parts) != 2L ||
    !grepl("^[0-9]+$", run_length_parts[1]) ||
    !run_length_parts[2] %in% c("year", "years")
) {
  stop("Scenario run_length must be expressed as a whole number of years.")
}

simulation_end <- seq(
  simulation_start,
  by = run_length,
  length.out = 2
)[2]
simulation_start <- as.POSIXct(simulation_start, tz = "UTC")
simulation_end <- as.POSIXct(simulation_end, tz = "UTC")

validation_database <-
  open_dataset(validation_database_path) |>
  collect()

eligible_database <-
  validation_database |>
  filter(
    !is.na(time_start),
    !is.na(time_end),
    time_start >= simulation_start,
    time_end <= simulation_end
  )

if (nrow(eligible_database) == 0L) {
  stop("No validation observations fall within the simulation period.")
}


# Prepare one profile per validation location-date window -----------------

validation_locations <-
  eligible_database |>
  distinct(longitude, latitude, time_start, time_end) |>
  arrange(longitude, latitude, time_start, time_end) |>
  mutate(assetid = row_number()) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

reference_portfolio <- read_validation_portfolio(reference_portfolio_path)

validation_portfolio <- profile_validation_environment(
  validation_locations,
  point_radius_m = 5,
  time_zone = "Asia/Kuching",
  mapme.outdir = "data/primary/validation",
  verbose = TRUE
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
