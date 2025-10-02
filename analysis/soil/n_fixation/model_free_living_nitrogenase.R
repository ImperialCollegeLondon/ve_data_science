#| ---
#| title: Parameterise a temperature-dependent free-living nitrogen fixation model
#|
#| description: |
#|     This R script aims to find the best functional equation to curve-fit a
#|     temperature-dependent model for free-living nitrogen fixers. It combines
#|     a global dataset to first estimate peak fixation rate, which is used to
#|     rescale a normalised dataset of nitrogenase temperature performance, and
#|     then fit one of the best candidate model with tractable properties from
#|     a model-selection study.
#|
#| virtual_ecosystem_module: Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: BNF_AREA.csv
#|     path: data/primary/soil/n_fixation
#|     description: |
#|       Global nitrogen fixation rate database including "soil", i.e., free-
#|       living fixers; obtained from https://doi.org/10.5066/P1MFBVHK
#|   - name: SITE.csv
#|     path: data/primary/soil/n_fixation
#|     description: |
#|       Site metadata for Global nitrogen fixation rate database, which is
#|       required to filter the BNF_AREA.csv dataset to free-living group;
#|       obtained from https://doi.org/10.5066/P1MFBVHK
#|   - name: 1-s2.0-S0966842X23003566-mmc1.xlsx
#|     path: data/primary/soil/n_fixation
#|     description: |
#|       Nitrogenase thermal performance dataset. This is the normalised dataset
#|       that needs to be rescaled; obtained from
#|       https://doi.org/10.1016/j.tim.2023.12.007
#|
#| output_files:
#|   - name: free_living_fixation_parameters.csv
#|     path: data/derived/soil/n_fixation
#|     description: |
#|       Output model parameters.
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - quantreg
#|     - brms
#|     - bayesplot
#|     - tidybayes
#|
#| usage_notes: |
#|   See extra decision making on pull request #109
#| ---

library(tidyverse)
library(readxl)
library(quantreg)
library(brms)
library(bayesplot)
library(tidybayes)


# Data --------------------------------------------------------------------
# Biological nitrogen fixation dataset published by Reis Ely et al. (2025)
bnf_free_living <-
  read_csv("data/primary/soil/n_fixation/BNF_AREA.csv") %>%
  left_join(read_csv("data/primary/soil/n_fixation/SITE.csv")) %>%
  # filter to "soil" which is free-living microbes
  filter(niche == "Soil")

# Nitrogenase activity data by Houlton et al. (2008), who did not publish their
# data but was later extracted by Deutsch et al. 2024
houlton <-
  read_excel(
    "data/primary/soil/n_fixation/1-s2.0-S0966842X23003566-mmc1.xlsx",
    range = "A1:C124"
  ) %>%
  # use only data from Houlton et al. (2008)
  filter(Source == "Houlton2008")


# Model fitting ------------------------------------------------------------

# First estimate the maximum or peak fixation rate of free-living organisms
# by "maximum" I will actually estimate it using the 95th percentile to be more
# conservative
mod_max_rate <- rq(
  BNF_final ~ 1,
  data = bnf_free_living,
  tau = 0.95
)

# the estimated peak fixation rate
peak_rate <- as.vector(mod_max_rate$coefficients)

# multiply the estimated peak rate to the Houlton dataset to "denormalise" them
houlton <-
  houlton %>%
  mutate(Rate = `Rate (normalized)` * peak_rate)

# Fit the simplified beta type equation to the Houlton dataset
# This equation is selected from the list of 83 equations in
# Kontopoulos et al. (2024) 10.1038/s41467-024-53046-2
# based on five criteria:
# 1. Unimodal – has a single peak.
# 2. Continuous in T – no discontinuities across the real line.
# 3. three parameters only – I think we want to keep it simply for VE.
# 4. Asymmetric – not symmetric like Gaussian.
# 5. Easy to code – closed-form, no piecewise definitions or unstable likelihoods.
simplified_beta <-
  bf(Rate ~ rho * (a - Temperature / 10) * (Temperature / 10)^b, nl = TRUE) +
  nlf(a ~ exp(loga)) +
  nlf(b ~ exp(logb)) +
  nlf(rho ~ exp(logrho)) +
  lf(loga + logb + logrho ~ 1)

# priors (these are carefully selected from prior predictive checks)
priors <-
  prior(normal(1.5, 0.5), class = "b", nlpar = "loga") +
  prior(normal(0.4, 0.5), class = "b", nlpar = "logb") +
  prior(normal(0, 0.5), class = "b", nlpar = "logrho")

# fit the model
mod_simplified_beta <- brm(
  simplified_beta,
  family = gaussian(),
  data = houlton,
  prior = priors,
  cores = 4
)

# check trace plot and fit to data
mcmc_trace(mod_simplified_beta, regex_pars = "^b_")

plot(
  conditional_effects(
    mod_simplified_beta,
    method = "posterior_epred"
  ),
  points = TRUE
)

# save parameters (including back-transformation)
param <-
  fixef(mod_simplified_beta, summary = FALSE) %>%
  as.data.frame() %>%
  transmute(
    a = exp(loga_Intercept),
    b = exp(logb_Intercept),
    rho = exp(logrho_Intercept)
  ) %>%
  pivot_longer(
    cols = everything(),
    names_to = "Param"
  ) %>%
  group_by(Param) %>%
  median_qi()

write_csv(param, "data/derived/soil/n_fixation/free_living_fixation_parameters.csv")
