library(tidyverse)
library(tidync)


source("tools/R/tidy_continuous_data.R")

df_long <-
  tidy_continuous_data(
    continuous = "data/scenarios/maliau/maliau_2/out/all_continuous_data.nc",
    variables = c("soil_cnp_pool_pom", "soil_cnp_pool_maom")
  )


ggplot(df_long) +
  facet_grid(variable ~ element, scales = "free_y") +
  geom_line(aes(timestamp, value, group = cell_id), alpha = 0.4)
