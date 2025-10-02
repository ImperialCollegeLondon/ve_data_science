library(tidyverse)
library(readxl)
library(quantreg)
library(brms)


# Data --------------------------------------------------------------------
# Biological nitrogen fixation dataset published by Reis Ely et al. (2025)
# https://doi.org/10.5066/P1MFBVHK
bnf_free_living <-
  read_csv("data/primary/soil/n_fixation/BNF_AREA.csv") %>%
  left_join(read_csv("data/primary/soil/n_fixation/SITE.csv")) %>%
  # filter to "soil" which is free-living microbes
  filter(niche == "Soil")

# Nitrogenase activity data by Houlton et al. 2008, who did not publish their
# data but was later extracted by Deutsch et al. 2024
# https://doi.org/10.1016/j.tim.2023.12.007
houlton <-
  read_excel(
    "data/primary/soil/n_fixation/1-s2.0-S0966842X23003566-mmc1.xlsx",
    range = "A1:C124"
  ) %>%
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
simplified_beta <-
  bf(Rate ~ rho * (a - Temperature / 10) * (Temperature / 10)^b,
    nl = TRUE
  ) +
  nlf(a ~ exp(loga)) +
  nlf(b ~ exp(logb)) +
  nlf(rho ~ exp(logrho)) +
  lf(loga + logb + logrho ~ 1)

# priors
priors <-
  prior(normal(1.5, 0.5), class = "b", nlpar = "loga") +
  prior(normal(0.4, 0.5), class = "b", nlpar = "logb") +
  prior(normal(0, 0.5), class = "b", nlpar = "logrho")

# fit
mod_simplified_beta <- brm(
  simplified_beta,
  family = gaussian(),
  data = houlton,
  prior = priors,
  cores = 4
)

bayesplot::mcmc_trace(mod_simplified_beta, regex_pars = "^b_")
plot(
  conditional_effects(
    mod_simplified_beta,
    method = "posterior_epred"
  ),
  points = TRUE
)
summary(mod_simplified_beta)
