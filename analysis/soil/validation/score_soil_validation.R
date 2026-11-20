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

# Establish the scoring contract -----------------------------------------

# TODO: Define model/version, scenario and parameter-configuration identifiers.
# TODO: Check whether dataset, ID and var_canonical uniquely identify a target.
# TODO: Audit missing, non-finite and unsupported matches. Report input,
# eligible, excluded and scored counts, with reasons and join classes.
# TODO: Map value_canonical to observed and value_VE_q50 to predicted.
# The q50 is a median across matched cells and timestamps, not a predictive mean.

# Score univariate point forecasts ---------------------------------------

# TODO: Set forecast_unit explicitly and select ae_point and se_point.
# TODO: Score observations, then calculate MAE as mean(ae_point) and RMSE as
# sqrt(mean(se_point)), grouped by canonical variable, unit and join class.
# TODO: Compare with yardstick on the same observations, including log1p.
# log1p scores do not make variables with different units or scales comparable.

univariate_scores <-
  as_forecast_point(
    validation_database,
    observed = "value_canonical",
    predicted = "value_VE_q50"
  ) |>
  score()

summarise_scores(univariate_scores, by = "var_canonical")

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

# Prepare for sample-based evaluation -------------------------------------

# TODO: Define a long-table contract with target and comparator IDs, sample_id,
# observed and predicted. Preserve sample IDs across all joint components.
# Matched cells, timestamps and marginal quantiles are not stochastic replicates.
