#| ---
#| title: Compile initial soil data for the Maliau scenario
#|
#| description: |
#|     This R script compiles initial soil data for the Maliau scenario
#|     from various data analyses into a single netCDF file.
#|     See the metadata in data/scenarios/maliau/soil_litter_metadata.toml
#|     for specific file paths that analysed each variable.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: soil_litter_metadata.toml
#|     path: data/scenarios/maliau
#|     description: |
#|         Metadata for soil and litter data analyses, currently including
#|         file paths and units
#|   - name: maliau_grid_definition_100m.toml
#|     path: data/derived/site
#|     description: |
#|         Metadata for Maliau grids, primarily to define the data generation
#|         area
#|   - name:
#|     path:
#|     description: |
#|
#|
#| output_files:
#|   - name:
#|     path:
#|     description: |
#|
#|
#| package_dependencies:
#|     - tidyverse
#|     - RcppTOML
#|     - ncdf4
#|
#| usage_notes: |
#|     For more details on statistical and data assumptions, see
#|     data/scenarios/maliau/soil_metadata.toml
#| ---

library(tidyverse)
library(RcppTOML)
library(ncdf4)

set.seed(20260313)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")


# Maliau site metadata ----------------------------------------------------

maliau <- parseTOML("data/derived/site/maliau_grid_definition_100m.toml")

# total number of grids
n_sim <- with(maliau, cell_nx * cell_ny)


# Set up dataframe --------------------------------------------------------
# this dataframe will store generated initial values, and then be converted
# to a netCDF output at the end

dat <-
  expand_grid(
    cell_x = maliau$cell_x_centres,
    cell_y = maliau$cell_y_centres
  ) |>
  # calculate displacements
  mutate(
    x = cell_x - min(cell_x),
    y = cell_y - min(cell_y)
  )



# Spatial prediction from SAFE soil campaign ------------------------------


