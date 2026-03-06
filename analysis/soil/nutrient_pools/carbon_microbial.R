#| ---
#| title: Extract microbial carbon to soil carbon ratio from a map
#|
#| description: |
#|     This R script extracts the (mean) microbial carbon to soil carbon ratio
#|     from a map by Serna-Chavez et al. (2013) Glob. Eco. Biogeog. It will be
#|     used for post-hoc prediction of soil initialisation data in Maliau.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: maliau_grid_definition_100m.toml
#|     path: data/sites
#|     description: |
#|       Maliau grid definition TOML file to define extent
#|   - name: cmicsoc_ratio.asc
#|     path: data/primary/soil/microbes
#|     description: |
#|       ASCII map of microbe:soil carbon ratio.
#|
#| output_files:
#|   - name:
#|     path:
#|     description:
#|
#| package_dependencies:
#|     - RcppTOML
#|     - terra
#|
#| usage_notes: |
#|   The output is a single value for the Maliau study region. It is not stored
#|   as any output object, but will be used later in a downstream prediction
#|   of microbial C in the Maliau region.
#| ---

library(RcppTOML)
library(terra)

# Maliau basin extent
maliau <- parseTOML("data/sites/maliau_grid_definition_100m.toml")
maliau_ext <- ext(maliau$bounds, xy = TRUE)

# Microbial to soil carbon ratio map
C_mic <- rast("data/primary/soil/microbes/cmicsoc_ratio.asc")
crs(C_mic) <- "epsg:4326"
# project with reference to Maliau
C_mic <- project(C_mic, paste0("epsg:", maliau$epsg_code))
# crop the map
C_mic_maliau <- crop(C_mic, maliau_ext)
# calculate the mean for maliau
# NB: it only contains one grid so the mean is just itself
# then divide by 100 because the author multiplied the ratio by 100
# the final unit is [%]
values(mean(C_mic_maliau)) / 100
