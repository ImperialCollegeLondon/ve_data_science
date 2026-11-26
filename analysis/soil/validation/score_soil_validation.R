#| ---
#| title: Score soil and litter validation forecasts
#|
#| description: |
#|   Score harmonised observations against joined Virtual Ecosystem outputs
#|   using point predictions optimal for each default scoring rule.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
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
#|   - dplyr
#|   - here
#|   - scoringutils
#|
#| usage_notes: |
#|   Build database_combined first. Its median, beta-median, and mean
#|   predictions are used for absolute, percentage, and squared errors.
#| ---

library(arrow)
library(tidyverse)
library(scoringutils)

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
  left_join(ape_scores, by = forecast_unit)

scores_summary <-
  summarise_scores(scores, by = "var_canonical")

pairs(scores_summary[, -1], log = "xy")
