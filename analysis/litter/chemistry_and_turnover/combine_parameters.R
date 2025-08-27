#| ---
#| title: Combine the estimated litter decay parameters into an output table
#|
#| description: |
#|     This R script combines the parameters estimated by model_leaf.R,
#|     model_wood.R and model_rate_lignin.R into a single table.
#|
#| VE_module: Litter
#|
#| author:
#|   - name: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: plant_stoichiometry.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       Plant stoichiometry trait data compiled by Arne; I am using it to
#|       obtain mean leaf and stem lignin content for parameter recovery here.
#|
#| output_files:
#|   - name: decay_parameters.csv
#|     path: data/derived/litter/turnover/
#|     description: |
#|       Parameters for the litter decay model. Values are reported as
#|       posterior median and the lower and upper bounds of the 95% credible
#|       intervals (for .interval == "qi") OR point estimate and 95% confidence
#|       intervals (for .interval == "ci").
#|
#| package_dependencies:
#|     - tidybayes
#|     - readxl
#|     - brms
#|     - bayesplot
#|     - modelr
#|     - glmmTMB
#|
#| usage_notes: |
#|     The leaf litter model is Bayessian inference so it will take a few
#|     minutes to run.
#| ---


library(tidybayes)



# Source modelling codes --------------------------------------------------

# leaf litter model (takes a while to fit Bayesian inference)
source("analysis/litter/chemistry_and_turnover/model_leaf.R")

# wood litter model
source("analysis/litter/chemistry_and_turnover/model_wood.R")

# lignin model
source("analysis/litter/chemistry_and_turnover/model_rate_lignin.R")



# Combine parameter estimates ---------------------------------------------

# leaf and wood lignin (constant across species for now) to recover the original
# ks and kw
# for consistency and simplicity, I will simply use the values that Arne took
# for the plant stoichiometry script as of 24/8/2025
# see analysis/plant/plant_stoichiometry/plant_stoichiometry.R
plant_stoich <- read_csv("data/derived/plant/traits_data/plant_stoichiometry.csv")
lignin_leaf <- mean(plant_stoich$leaf_lignin)
lignin_wood <- mean(plant_stoich$stem_lignin)

# summarise the posterior
# Values are reported as median and the lower and upper bounds of the 90%
# credible intervals
param_summary <-
  # leaf model parameter ==================================================
  mod_leaf %>%
  spread_draws(
    b_logsN_Intercept,
    b_logsP_Intercept,
    b_logitfM_Intercept,
    b_logks_Intercept,
    b_logkmdiff_Intercept
  ) %>%
  # back-transform parameters and back-scale when required
  # note that at this stage r (lignin effect) is "absorbed" into kw and ks
  # we will convert kw and ks to our units later
  mutate(
    sN = exp(b_logsN_Intercept) / sd(litter$CN) / lignin_leaf,
    sP = exp(b_logsP_Intercept) / sd(litter$CP) / lignin_leaf,
    logitfM = b_logitfM_Intercept +
      exp(b_logsN_Intercept) / sd(litter$CN) * mean(litter$CN) +
      exp(b_logsP_Intercept) / sd(litter$CP) * mean(litter$CP),
    ks = exp(b_logks_Intercept) / 365.25,
    km = (ks + exp(b_logkmdiff_Intercept)) / 365.25,
    .keep = "unused"
  ) %>%
  pivot_longer(
    cols = sN:km,
    names_to = "Parameter",
    values_to = "value"
  ) %>%
  # summarise posterior
  group_by(Parameter) %>%
  median_qi(value,
    .width = 0.95
  ) %>%
  # join wood model parameter =============================================
  bind_rows(
    data.frame(
      Parameter = "kw",
      value = -param_wood["weeks", "Estimate"] / 7,
      .lower = -param_wood["weeks", "2.5 %"] / 7,
      .upper = -param_wood["weeks", "97.5 %"] / 7,
      .width = 0.95,
      .point = "mean",
      .interval = "ci"
    )
  ) %>%
  # join the lignin-rate model ============================================
  bind_rows(
    data.frame(
      Parameter = "r",
      value = param_k_lignin["lignin", "Estimate"],
      .lower = param_k_lignin["lignin", "2.5 %"],
      .upper = param_k_lignin["lignin", "97.5 %"],
      .width = 0.95,
      .point = "mean",
      .interval = "ci"
    )
  )

# now that we have r, we will convert kw and ks to the right units
# the crude assumption here is that all species have the same leaf and wood
# lignin content; also this is a crude conversion because ideally we would
# incorporate the parameter uncertainty of r, but I'm only using its mean
# estimate for simplicity here
# nolint start
param_summary[param_summary$Parameter == "kw", c("value", ".lower", ".upper")] <-
  param_summary[param_summary$Parameter == "kw", c("value", ".lower", ".upper")] /
    exp(param_summary$value[param_summary$Parameter == "r"] * lignin_wood)
param_summary[param_summary$Parameter == "ks", c("value", ".lower", ".upper")] <-
  param_summary[param_summary$Parameter == "ks", c("value", ".lower", ".upper")] /
    exp(param_summary$value[param_summary$Parameter == "r"] * lignin_leaf)
# nolint end

# save output table
write_csv(
  param_summary,
  "data/derived/litter/turnover/decay_parameters.csv"
)
