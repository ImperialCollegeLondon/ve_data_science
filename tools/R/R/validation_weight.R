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


# Download and read WorldClim climate data -------------------------

# Keep the baseline year consistent with the human-impact data below.
climate_years <- 2010
climate_file <- file.path(validation_dir, "worldclim_climate.tif")
mapme_options(outdir = NULL)
get_resources(
  validation_aoi,
  get_worldclim_precipitation(
    years = climate_years,
    resolution = "2.5m"
  ),
  get_worldclim_min_temperature(
    years = climate_years,
    resolution = "2.5m"
  ),
  get_worldclim_max_temperature(
    years = climate_years,
    resolution = "2.5m"
  )
)
climate_resources <- prep_resources(
  validation_aoi,
  resources = c(
    "worldclim_precipitation",
    "worldclim_min_temperature",
    "worldclim_max_temperature"
  )
)
climate <- c(
  climate_resources$worldclim_precipitation,
  climate_resources$worldclim_min_temperature,
  climate_resources$worldclim_max_temperature
)
stopifnot(nlyr(climate) == 36 * length(climate_years))
writeRaster(climate, climate_file, overwrite = TRUE)
climate <- rast(climate_file)


# Download and read ISRIC SoilGrids -------------------------------

# Keep 250 m predictions at native resolution and in original mapped units.
soilgrids_layers <- c(
  "bdod",
  "cec",
  "cfvo",
  "clay",
  "nitrogen",
  "phh2o",
  "sand",
  "silt",
  "soc"
)
soilgrids_depths <- c("0-5cm", "5-15cm", "15-30cm")
soilgrids_file <- file.path(validation_dir, "soilgrids_mean_topsoil.tif")

# Register remote VRTs; persist only the AOI, not global soil rasters.
mapme_options(outdir = NULL)
get_resources(
  validation_aoi,
  get_soilgrids(
    layers = soilgrids_layers,
    depths = soilgrids_depths,
    stats = "mean"
  )
)
soilgrids <- prep_resources(
  validation_aoi,
  resources = "soilgrids"
)$soilgrids
stopifnot(
  inherits(soilgrids, "SpatRaster"),
  nlyr(soilgrids) == length(soilgrids_layers) * length(soilgrids_depths)
)
writeRaster(soilgrids, soilgrids_file, overwrite = TRUE)
soilgrids <- rast(soilgrids_file)

# Download and read human footprint -------------------------------

# Start with Maliau's baseline year; match years to validation records.
# Native resolution is ~1 km; global annual files download before AOI cropping.
human_footprint_years <- 2010
mapme_options(outdir = validation_dir, verbose = TRUE)
get_resources(
  validation_aoi,
  get_humanfootprint(years = human_footprint_years)
)
human_footprint <- prep_resources(
  validation_aoi,
  resources = "humanfootprint"
)$humanfootprint
stopifnot(
  inherits(human_footprint, "SpatRaster"),
  nlyr(human_footprint) == length(human_footprint_years)
)

# Download and read elevation ------------------------------------

# NASADEM provides ~30 m elevation in metres, suitable for 100 m aggregation.
elevation_file <- file.path(validation_dir, "nasadem_elevation.tif")
mapme_options(outdir = NULL)
get_resources(
  validation_aoi,
  get_nasa_srtm()
)
elevation <- prep_resources(
  validation_aoi,
  resources = "nasa_srtm"
)$nasa_srtm
stopifnot(inherits(elevation, "SpatRaster"), nlyr(elevation) == 1)
writeRaster(elevation, elevation_file, overwrite = TRUE)
elevation <- rast(elevation_file)
