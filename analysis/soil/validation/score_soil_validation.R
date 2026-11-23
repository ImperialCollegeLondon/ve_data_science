#| ---
#| title: Score soil and litter validation forecasts
#|
#| description: |
#|   Starter workflow for scoring harmonised observations against joined Virtual
#|   Ecosystem outputs. Scoring and reporting steps remain to be implemented.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: []
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
#|   Build database_combined first. Scoring decisions, outputs, and the
#|   scoringutils dependency in renv.lock still need to be established.
#| ---

library(arrow)
library(tidyverse)
library(scoringutils)

# Load the combined validation database ---------------------------------------

validation_database <-
  open_dataset("data/derived/soil/validation/database_combined") |>
  collect()


# Score univariate point forecasts ---------------------------------------

univariate_scores <-
  as_forecast_point(
    validation_database,
    # Use `c("dataset", "ID", "var_canonical")` as the observation-target key.
    # `ID` comes from source keys, which are unique only within each dataset.
    # `var_canonical` distinguishes measured targets; `dataset` prevents ID
    # collisions across datasets.
    forecast_unit = c("dataset", "ID", "var_canonical"),
    observed = "value_canonical",
    predicted = "value_VE_q50"
  ) |>
  # log shift transformation does not work on all VE data variables
  # transform_forecasts(offset = 1) |>
  score() |>
  select(-se_point, -ape)

univariate_scores |>
  summarise_scores(by = "var_canonical")


# Pilot multivariate point forecasts -------------------------------------

# TODO: Identify genuinely co-observed components using dataset and ID.
# Check sampling support, define fixed component scales, and report incomplete
# vectors. Report a blocker if suitable paired observations are unavailable.
# TODO: Score a justified joint vector with the variogram score alongside
# univariate metrics; the variogram alone misses a common additive bias.

multivariate_scores <-
  as_forecast_multivariate_point(
    validation_database,
    joint_across = "module", # placeholder
    observed = "value_canonical",
    predicted = "value_VE_q50"
  ) |>
  score()

summarise_scores(multivariate_scores)
