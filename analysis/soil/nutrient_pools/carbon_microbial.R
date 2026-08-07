#| ---
#| title: Extract microbial carbon to soil carbon ratio from a map
#|
#| description: |
#|     An R function to extract the (mean) microbial carbon to soil carbon ratio
#|     from a map by Serna-Chavez et al. (2013) Glob. Eco. Biogeog.
#|     https://doi.org/10.1111/geb.12070 It will be used for post-hoc
#|     prediction of soil input data for VE.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: cmicsoc_ratio.asc
#|     path: data/primary/soil/microbes
#|     description: |
#|       ASCII map of microbe:soil carbon ratio. Downloaded from
#|       https://onlinelibrary.wiley.com/doi/10.1111/geb.12070
#|
#| output_files:
#|
#| package_dependencies:
#|     - RcppTOML
#|     - terra
#|
#| usage_notes: |
#|   The output is a single value for the study region. It is not stored
#|   as any output object, but will be used later in a downstream prediction
#|   of microbial C in the study region.
#| ---

library(RcppTOML)
library(terra)

# function to extract microbial to soil carbon ration from
# Serna-Chavez et al. (2013)
extract_microbial_to_soil_C_ratio <- function(site_definition) {
  # Microbial to soil carbon ratio map
  C_mic <- rast("data/primary/soil/microbes/cmicsoc_ratio.asc")
  crs(C_mic) <- "epsg:4326"
  # project with reference to the scenario site
  C_mic <- project(C_mic, paste0("epsg:", site_definition$epsg_code))
  # crop the map
  site_extent <- ext(site_definition$bounds, xy = TRUE)
  C_mic_maliau <- crop(C_mic, site_extent)
  # calculate the mean for the scenario site
  # then divide by 100 because the author multiplied the ratio by 100
  # the final unit is [%]
  as.numeric(values(mean(C_mic_maliau))) / 100
}
