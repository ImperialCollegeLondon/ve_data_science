#| ---
#| title: Showcase the tidy_continuous_data() function for visualisation
#|
#| description: |
#|     This R script applies the tidy_continuous_data() function on the
#|     visualisation of some continuous soil outputs from VE. Variables from
#|     other modules should also work!
#|
#| VE_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: model_data.zarr
#|     path: data/scenarios/maliau/maliau_2/out
#|     description: |
#|       Virtual Ecosystem output dataset from the maliau_2 simulation
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - pizzarr
#|     - reshape2
#|
#| usage_notes:
#| ---

library(tidyverse)
source("tools/R/R/get_ve_variables.R")
source("tools/R/R/tidy_continuous_data.R")

model_data_path <-
  "data/scenarios/maliau/maliau_2/out/model_data.zarr"

# an example use of tidy_continuous_data() on state variables with the CNP
# element dimension;
cnp_example <-
  tidy_continuous_data(
    path = model_data_path,
    variables = c(
      "soil_cnp_pool_pom",
      "soil_cnp_pool_maom",
      "soil_cnp_pool_lmwc"
    ),
    initial = TRUE
  )
# plot
ggplot(cnp_example) +
  facet_grid(variable ~ element, scales = "free_y") +
  geom_line(aes(timestamp, value, group = cell_id), alpha = 0.4)

# the same concept also applied for other extra dimensions, e.g., layers, pft
soil_moisture <-
  tidy_continuous_data(
    path = model_data_path,
    variables = "soil_moisture",
    initial = TRUE
  )
ggplot(soil_moisture) +
  facet_grid(variable ~ layers) +
  geom_line(aes(timestamp, value, group = cell_id), alpha = 0.4)

# another example with variables without the element dimension
# note the automatic lack of "element" column in this example
xy_example <-
  tidy_continuous_data(
    path = model_data_path,
    variables = c(
      "soil_n_pool_ammonium",
      "soil_n_pool_nitrate",
      "soil_p_pool_labile"
    ),
    initial = TRUE
  )
ggplot(xy_example) +
  facet_wrap(~variable) +
  geom_line(aes(timestamp, value, group = cell_id), alpha = 0.4)

# spatial mapping of a temporal slice, e.g., 2nd year
# pardon the imperfect colour scale, ideally they should be independent across
# panels
xy_example |>
  filter(time_index == 2 * 12 - 1) |>
  ggplot() +
  facet_wrap(~variable) +
  geom_raster(aes(x = x, y = y, fill = value)) +
  scale_fill_viridis_c() +
  coord_fixed()
