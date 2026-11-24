library(tidyverse)
library(RcppTOML)
library(sf)

# The maliau 2 scenario spatiotemporal metadata
maliau_2 <-
  parseTOML("data/derived/site/maliau/maliau_grid_definition.toml") |>
  pluck("Scenario", "maliau_2")

# Use the SAFE gazetteer as a test case because it has a mixture of point and polygons
gazetteer <- st_read("data/primary/site/gazetteer.geojson")

# Download and read WorldClim bioclim data -------------------------

# WorldClim's 30-arc-second (~1 km) data are coarser than Maliau's 100 m grid.
bioclim_dir <- "data/primary/abiotic"
dir.create(bioclim_dir, recursive = TRUE, showWarnings = FALSE)

bioclim_zip <- file.path(bioclim_dir, "wc2.1_30s_bio.zip")
bioclim_url <- paste0(
  "https://geodata.ucdavis.edu/climate/worldclim/2_1/base/",
  "wc2.1_30s_bio.zip"
)

if (!file.exists(bioclim_zip)) {
  download.file(bioclim_url, bioclim_zip, mode = "wb")
}

unzip(bioclim_zip, exdir = bioclim_dir)
bioclim_files <- file.path(
  bioclim_dir,
  sprintf("wc2.1_30s_bio_%d.tif", 1:19)
)
bioclim <- terra::rast(bioclim_files)
