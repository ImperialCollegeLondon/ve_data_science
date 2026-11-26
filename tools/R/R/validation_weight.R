library(tidyverse)
library(RcppTOML)
library(sf)
library(mapme.biodiversity)
library(terra)


# Use the SAFE gazetteer as a test case because it has a mixture of point and
# polygons
gazetteer <- st_read("data/primary/site/gazetteer.geojson")


# Validation coverage -------------------------------------------

validation_dir <- "data/primary/validation"

# The maliau 2 scenario spatiotemporal metadata
maliau_2 <-
  parseTOML("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario", "maliau_2")
maliau_boundary <- st_as_sfc(st_bbox(
  c(
    xmin = maliau_2$ll_x,
    ymin = maliau_2$ll_y,
    xmax = maliau_2$ur_x,
    ymax = maliau_2$ur_y
  ),
  crs = st_crs(maliau_2$epsg_code)
))
# Buffer in metres to include neighbouring coarse raster cells.
validation_aoi <- c(
  st_geometry(st_transform(gazetteer, maliau_2$epsg_code)),
  maliau_boundary
) |>
  st_buffer(dist = 1000) |>
  st_bbox() |>
  st_as_sfc() |>
  st_transform(4326) |>
  st_as_sf()

# Set up mapme options; also for reusing caches
mapme_options(outdir = validation_dir, verbose = TRUE)

aoi_resources <-
  validation_aoi |>
  get_resources(
    get_nasa_srtm(),
    get_humanfootprint(years = 2010:2020),
    get_worldclim_precipitation(years = 2010:2020, resolution = "10m"),
    get_soilgrids(
      layers = "soc",
      depths = c("0-5cm", "5-15cm", "15-30cm"),
      stats = "mean"
    )
  ) |>
  calc_indicators(
    calc_elevation(),
    calc_humanfootprint(),
    calc_precipitation_wc(),
    calc_soilproperties()
  )
