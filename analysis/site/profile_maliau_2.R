#| ---
#| title: Profile the Maliau 2 validation environment
#|
#| description: |
#|   Builds the environmental reference distribution for the maliau_2 grid.
#|   Each 100 m grid cell is treated as a separate portfolio asset so that
#|   downstream comparisons preserve spatial combinations of covariates.
#|   Indicators cover elevation, human footprint, precipitation, and soil
#|   organic carbon within the scenario's 2010--2020 observation window.
#|
#| virtual_ecosystem_module: All
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau/maliau_grid_definition.toml
#|     description: Scenario bounds, CRS, grid dimensions, resolution, and timing.
#|
#| output_files:
#|   - name: maliau_portfolio.gpkg
#|     path: data/derived/validation/maliau_portfolio.gpkg
#|     description: |
#|       Environmental indicator values for each maliau_2 grid cell.
#|   - name: maliau_portfolio.csv
#|     path: data/derived/validation/maliau_portfolio.csv
#|     description: |
#|       Environmental indicator values in long format without geometry.
#|
#| source_files:
#|   - name: validation_weight.R
#|     path: tools/R/R/validation_weight.R
#|     description: Reusable remote-sensing profiling helper.
#|
#| package_dependencies:
#|   - mapme.biodiversity
#|   - lubridate
#|   - RcppTOML
#|   - sf
#|   - tidyverse
#|   - terra
#|
#| usage_notes: |
#|   Run from the repository root. Remote resources are cached under
#|   data/primary/validation. The output is generated data and is git-ignored.
#| ---

library(tidyverse)
library(lubridate)
library(RcppTOML)
library(sf)
library(mapme.biodiversity)
library(terra)

source("tools/R/R/validation_weight.R")


# Validation coverage ----------------------------------------------------

# Convert the maliau_2 metadata to a sf grids

maliau_2 <-
  parseTOML("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario", "maliau_2")

simulation_start <- as.Date(maliau_2$core$timing$start_date)
simulation_end <-
  simulation_start %m+% lubridate::period(maliau_2$core$timing$run_length)

maliau_boundary <- st_as_sfc(st_bbox(
  c(
    xmin = maliau_2$ll_x,
    ymin = maliau_2$ll_y,
    xmax = maliau_2$ur_x,
    ymax = maliau_2$ur_y
  ),
  crs = st_crs(maliau_2$epsg_code)
))

maliau_grid <-
  st_make_grid(
    maliau_boundary,
    cellsize = maliau_2$res,
    what = "polygons"
  ) |>
  st_as_sf() |>
  mutate(assetid = row_number())


# Download and cache remote sensing data ---------------------------------

# Download from supported databases in the mapme.biodiversity package
# Then calculate zonal statistics per grid
# Download will take a while, but subsequent runs will use the cached files

aoi_resources <- profile_validation_environment(
  maliau_grid,
  time_start = rep(simulation_start, nrow(maliau_grid)),
  time_end = rep(simulation_end, nrow(maliau_grid)),
  mapme.outdir = "data/primary/validation",
  verbose = TRUE
)

# write data as a Geopackage
write_portfolio(
  x = aoi_resources,
  dsn = "data/derived/validation/maliau_portfolio.gpkg"
)

# also write data as a dataframe / CSV
aoi_resources_flat <- portfolio_long(aoi_resources, drop_geoms = TRUE)
write_csv(aoi_resources_flat, "data/derived/validation/maliau_portfolio.csv")
