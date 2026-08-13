library(CBFM)

# Run script that fits a spatial model to the SAFE data
source("analysis/soil/initialisation/model_safe.R")

# Variance partitioning
# calculate variance component for each covariate (five of them),
# including the intercept; hence the 1:6 index
var_part <- varpart(fitcbfm, groupX = 1:6)
var_part_df <-
  with(var_part, rbind(varpart_X, varpart_B_space)) |>
  as.data.frame() |>
  rownames_to_column("predictor") |>
  mutate(
    predictor = recode_values(
      predictor,
      "Group1" ~ "Intercept",
      "Group2" ~ "Elevation",
      "Group3" ~ "Topography",
      "Group4" ~ "Hydrology",
      "Group5" ~ "ACD",
      "Group6" ~ "EVI",
      "varpart_B_space" ~ "spatial_residual"
    )
  ) |>
  pivot_longer(,
    cols = -predictor,
    names_to = "response",
    values_to = "p_variance"
  ) |>
  # remove intercepts since they explained no variance in this particular model
  filter(predictor != "Intercept")

# Calculate median variance explained by each predictor
predictor_order <-
  var_part_df |>
  group_by(predictor) |>
  summarise(median_variance = median(p_variance), .groups = "drop") |>
  arrange(median_variance) |>
  pull(predictor)

# Reorder predictor as factor
var_part_df <-
  var_part_df |>
  mutate(predictor = factor(predictor, levels = predictor_order))

# Visualise
ggplot(var_part_df, aes(y = response, x = p_variance, fill = predictor)) +
  geom_col(position = "stack") +
  scale_fill_grey() +
  theme_bw() +
  coord_cartesian(expand = FALSE) +
  labs(
    title = "Variance partitioning across soil response variables",
    x = "Proportion of variance explained",
    y = "Response variable",
    fill = "Predictor"
  ) +
  theme(legend.position = "bottom")
