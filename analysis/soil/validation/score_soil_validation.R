#| ---
#| title: Score soil and litter validation database
#|
#| description: |
#|   Score validation datasets against joined Virtual Ecosystem outputs
#|   using proper scores
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: database_combined
#|     path: data/derived/soil/validation/
#|     description: |
#|       Parquet dataset containing observations and matched model outputs.
#|
#| output_files: []
#|
#| source_files: []
#|
#| package_dependencies:
#|   - arrow
#|   - tidyverse
#|   - scoringutils
#|
#| usage_notes: |
#|   Build database_combined first. Its median, beta-median, and mean
#|   predictions are used for absolute, percentage, and squared errors.
#| ---

library(arrow)
library(tidyverse)
library(scoringutils)
library(rpart)


# Load the combined validation database ---------------------------------------

validation_database <-
  open_dataset("data/derived/soil/validation/database_combined") |>
  collect()


# Score point forecasts -------------------------------------------------------

# `ID` is unique only within each dataset; `var_canonical` identifies targets.
forecast_unit <- c("dataset", "ID", "var_canonical")

# The median is Bayes-optimal for absolute error (Gneiting 2011).
ae_scores <-
  as_forecast_point(
    validation_database,
    forecast_unit = forecast_unit,
    observed = "value_canonical",
    predicted = "value_VE_q50"
  ) |>
  score() |>
  select(all_of(forecast_unit), ae_point)

# The mean is Bayes-optimal for squared error (Gneiting 2011).
se_scores <-
  as_forecast_point(
    validation_database,
    forecast_unit = forecast_unit,
    observed = "value_canonical",
    predicted = "value_VE_mean"
  ) |>
  score() |>
  select(all_of(forecast_unit), se_point)

# The beta-median with beta = -1 is Bayes-optimal for absolute percentage
# error (Gneiting 2011, Table 1).
ape_scores <-
  as_forecast_point(
    validation_database,
    forecast_unit = forecast_unit,
    observed = "value_canonical",
    predicted = "value_VE_med_neg1"
  ) |>
  score() |>
  select(all_of(forecast_unit), ape)

scores <-
  ae_scores |>
  left_join(se_scores, by = forecast_unit) |>
  left_join(ape_scores, by = forecast_unit) |>
  mutate(
    element = case_when(
      str_detect(var_canonical, "(_c_|respiration)") ~ "C",
      str_detect(var_canonical, "(_n_|nitrous_oxide)") ~ "N",
      str_detect(var_canonical, "(_p_|phosphorus)") ~ "P"
    )
  )

stopifnot(!anyNA(scores$element))

scores_summary_variables <- summarise_scores(scores, by = "var_canonical")
scores_summary_groups <- summarise_scores(scores, by = "element")

pairs(scores_summary_variables[, -1], log = "xy")

# Weighted scores based on closeness to Maliau

# Regression tree
tree <- rpart(
  ape ~ var_canonical,
  data = scores |> filter(is.finite(ape)),
  method = "anova",
  control = rpart.control(cp = 0.0001)
)

plot(tree, uniform = TRUE, margin = 0.1)
text(tree, use.n = TRUE, cex = 0.8)
