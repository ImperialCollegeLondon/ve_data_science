#| ---
#| title: Profile the Maliau 2 validation environment
#|
#| description: |
#|     Builds the environmental reference distribution for the maliau_2 grid.
#|     Each 100 m grid cell is treated as a separate portfolio asset so that
#|     downstream comparisons preserve spatial combinations of covariates.
#|
#| virtual_ecosystem_module: All
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau/maliau_grid_definition.toml
#|     description: Scenario bounds, CRS, grid dimensions, and resolution.
#|
#| output_files:
#|   - name: maliau_portfolio.gpkg
#|     path: data/derived/validation/maliau_portfolio.gpkg
#|     description: |
#|       Environmental indicator values for each maliau_2 grid cell.
#|
#| source_files:
#|
#| package_dependencies:
#|   - mapme.biodiversity
#|   - RcppTOML
#|   - sf
#|   - tidyverse
#|   - terra
#|
#| usage_notes: |
#|     Run from the repository root. Remote resources are cached under
#|     data/primary/validation. The output is generated data and is git-ignored.
#| ---

library(tidyverse)
library(RcppTOML)
library(sf)
library(mapme.biodiversity)
library(terra)


# Validation coverage ----------------------------------------------------

# Convert the maliau_2 metadata to a sf grids

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

mapme_options(outdir = "data/primary/validation", verbose = TRUE)

aoi_resources <-
  maliau_grid |>
  st_transform(4326) |>
  get_resources(
    get_nasa_srtm(),
    get_humanfootprint(years = 2010:2020),
    get_worldclim_precipitation(years = 2010:2020, resolution = "10m"),
    get_soilgrids(
      layers = "soc",
      depths = "0-5cm",
      stats = "mean"
    )
  ) |>
  calc_indicators(
    calc_elevation(),
    calc_humanfootprint(),
    calc_precipitation_wc(),
    calc_soilproperties()
  )

# write data as a Geopackage
write_portfolio(
  x = aoi_resources,
  dsn = "data/derived/validation/maliau_portfolio.gpkg"
)

# also write data as a dataframe / CSV
aoi_resources_flat <- portfolio_long(aoi_resources, drop_geoms = TRUE)
write_csv(aoi_resources_flat, "data/derived/validation/maliau_portfolio.csv")
