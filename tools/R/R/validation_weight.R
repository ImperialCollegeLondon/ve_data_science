library(tidyverse)
library(RcppTOML)
library(sf)
library(geodata)
library(mapme.biodiversity)


# The maliau 2 scenario spatiotemporal metadata
maliau_2 <-
  parseTOML("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario", "maliau_2")

# Use the SAFE gazetteer as a test case because it has a mixture of point and polygons
gazetteer <- st_read("data/primary/site/gazetteer.geojson")


# Validation coverage -------------------------------------------

validation_dir <- "data/primary/validation"
dir.create(validation_dir, recursive = TRUE, showWarnings = FALSE)

maliau_boundary <- st_as_sfc(st_bbox(
  c(
    xmin = maliau_2$ll_x, ymin = maliau_2$ll_y,
    xmax = maliau_2$ur_x, ymax = maliau_2$ur_y
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

# Download and read WorldClim bioclim data -------------------------

# Native resolution is ~1 km, not the Maliau grid's 100 m.
bioclim_tile_grid <- terra::rast(resolution = 30)
bioclim_tile_ids <- terra::cells(
  bioclim_tile_grid,
  terra::ext(terra::vect(validation_aoi))
)
bioclim_tile_centres <- terra::xyFromCell(
  bioclim_tile_grid, bioclim_tile_ids
)
bioclim_tiles <- map(seq_len(nrow(bioclim_tile_centres)), function(i) {
  tile <- geodata::worldclim_tile(
    var = "bio",
    lon = bioclim_tile_centres[i, 1],
    lat = bioclim_tile_centres[i, 2],
    path = validation_dir
  )
  if (!inherits(tile, "SpatRaster")) {
    stop("WorldClim tile download failed.")
  }
  terra::crop(tile, terra::vect(validation_aoi))
})
bioclim <- terra::merge(terra::sprc(bioclim_tiles))
stopifnot(terra::nlyr(bioclim) == 19)

# Download and read ISRIC SoilGrids -------------------------------

# Keep 250 m predictions at native resolution and in original mapped units.
soilgrids_layers <- c(
  "bdod", "cec", "cfvo", "clay", "nitrogen", "phh2o", "sand", "silt", "soc"
)
soilgrids_depths <- c("0-5cm", "5-15cm", "15-30cm")
soilgrids_file <- file.path(validation_dir, "soilgrids_mean_topsoil.tif")

# Register remote VRTs; persist only the AOI, not global soil rasters.
mapme.biodiversity::mapme_options(outdir = NULL)
mapme.biodiversity::get_resources(
  validation_aoi,
  mapme.biodiversity::get_soilgrids(
    layers = soilgrids_layers, depths = soilgrids_depths, stats = "mean"
  )
)
soilgrids <- mapme.biodiversity::prep_resources(
  validation_aoi, resources = "soilgrids"
)$soilgrids
stopifnot(
  inherits(soilgrids, "SpatRaster"),
  terra::nlyr(soilgrids) ==
    length(soilgrids_layers) * length(soilgrids_depths)
)
terra::writeRaster(soilgrids, soilgrids_file, overwrite = TRUE)
soilgrids <- terra::rast(soilgrids_file)

# Download and read human footprint -------------------------------

# Start with Maliau's baseline year; match years to validation records.
# Native resolution is ~1 km; global annual files download before AOI cropping.
human_footprint_years <- 2010
mapme.biodiversity::mapme_options(outdir = validation_dir, verbose = TRUE)
mapme.biodiversity::get_resources(
  validation_aoi,
  mapme.biodiversity::get_humanfootprint(years = human_footprint_years)
)
human_footprint <- mapme.biodiversity::prep_resources(
  validation_aoi, resources = "humanfootprint"
)$humanfootprint
stopifnot(
  inherits(human_footprint, "SpatRaster"),
  terra::nlyr(human_footprint) == length(human_footprint_years)
)

# Download and read elevation ------------------------------------

# NASADEM provides ~30 m elevation in metres, suitable for 100 m aggregation.
elevation_file <- file.path(validation_dir, "nasadem_elevation.tif")
mapme.biodiversity::mapme_options(outdir = NULL)
mapme.biodiversity::get_resources(
  validation_aoi, mapme.biodiversity::get_nasa_srtm()
)
elevation <- mapme.biodiversity::prep_resources(
  validation_aoi, resources = "nasa_srtm"
)$nasa_srtm
stopifnot(inherits(elevation, "SpatRaster"), terra::nlyr(elevation) == 1)
terra::writeRaster(elevation, elevation_file, overwrite = TRUE)
elevation <- terra::rast(elevation_file)
