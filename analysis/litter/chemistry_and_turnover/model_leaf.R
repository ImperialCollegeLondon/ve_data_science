#| ---
#| title: Estimating leaf litter decomposition rates from SAFE data
#|
#| description: |
#|     This R script estimates leaf litter decomposition rates from SAFE data.
#|     The parameters will be used for aboveground structural and metabolic
#|     litter components. The theoretical model is documented
#|     under /theory/soil/litter_theory.html on the VE website.
#|
#| VE_module: Litter
#|
#| author:
#|   - name: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: species+name+plant+traits+and+mass+loss+data+20190618.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Litter chemistry and decomposition in subtropical broadleaf forest
#|       by Tao et al. Downloaded from https://doi.org/10.5061/dryad.7hg8mp7
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - brms
#|     - bayesplot
#|     - modelr
#|
#| usage_notes: |
#|   Originally I used litter chemistry and decomposition data at SAFE
#|   by Sabine Both et al. (https://doi.org/10.5061/dryad.7hg8mp7) but
#|   the litter nutrient was only measured at the beginning of the litter bag
#|   experiment for some, but not all litter bags. So the nutrient data quality
#|   wasn't that good, and the model seemed to be very sensitive to my prior
#|   choice (i.e., weak data). At SAFE, there is also another dataset,
#|   Plowman et al. (2018) https://zenodo.org/records/1220270
#|   but the initial mass was wet weight. I also tried the dataset by
#|   Elias et al. (2020) https://zenodo.org/records/3929632 in branch
#|   60-model-litter-chemistry-and-turnover-microcosm-dataset
#|   but gave up because the leaf decomposition (in microcosm) was extremely
#|   fast.
#| ---

library(tidyverse)
library(readxl)
library(brms)
library(bayesplot)
library(modelr)



# Data --------------------------------------------------------------------

# clean up data
litter <-
  read_excel(
    "data/primary/litter/species+name+plant+traits+and+mass+loss+data+20190618.xlsx"
  ) %>%
  select(
    species = `Species Latin Name`,
    substrate = `Incubation substrate`,
    block = `Block(Replicate)`,
    x0_1 = `Initial weight1`,
    xt_1 = `Harvest1 weght`,
    x0_2 = `Initial weight2`,
    xt_2 = `Harvest2 weght`,
    CN = `Litter C:N`,
    NP = `Litter N:P`
  ) %>%
  # calculate C:P ratio
  mutate(CP = CN * NP) %>%
  # rearrange the initial and final mass variables
  # and then assign number of days to each treatment group
  pivot_longer(
    cols = starts_with("x"),
    names_to = "var",
    values_to = "x"
  ) %>%
  separate(var, c("var", "timepoint")) %>%
  pivot_wider(
    names_from = var,
    values_from = x
  ) %>%
  mutate(
    # assign day lapses
    time = case_match(
      timepoint,
      "1" ~ 7 / 12 * 365.25,
      "2" ~ 14 / 12 * 365.25
    ),
    # calculate offset term
    log_x0 = log(x0)
  ) %>%
  # only keep complete cases
  filter_at(vars(x0, xt, CN, CP), ~ !is.na(.))

# scale data for model convergence
litter_s <-
  litter %>%
  mutate(
    CN = as.numeric(scale(CN)),
    CP = as.numeric(scale(CP)),
    time = time / 365.25
  )



# Model -------------------------------------------------------------------

# model formula
# note that I needed to do a lot of reparameterisation to get the posterior
# sampled efficiency
form <-
  bf(xt ~ eta) +
  # nlf(eta ~ log(metabolic + structural)) +        # nolint
  # nlf(metabolic ~ fm * exp(-km * time)) +         # nolint
  # nlf(structural ~ (1 - fm) * exp(-ks * time)) +  # nolint
  nlf(eta ~ log_x0 + log_sum_exp(logmetabolic, logstructural)) +
  nlf(logmetabolic ~ log(fm) - km * time) +
  nlf(logstructural ~ log1m(fm) - ks * time) +
  nlf(fm ~ inv_logit(logitfM - sN * CN - sP * CP)) +
  nlf(sN ~ exp(logsN)) +
  nlf(sP ~ exp(logsP)) +
  nlf(ks ~ exp(logks)) +
  nlf(km ~ ks + exp(logkmdiff)) +
  lf(
    logitfM ~ 1 + (1 | species),
    logsN ~ 1,
    logsP ~ 1,
    logkmdiff ~ 1 + (1 | block),
    logks ~ 1 + (1 | block)
  ) +
  set_nl(TRUE)

# some strong-ish priors
priors <-
  prior(normal(1.5, 0.25), class = b, nlpar = logitfM) +
  prior(normal(-2, 0.5), class = b, nlpar = logks) +
  prior(normal(2, 0.5), class = b, nlpar = logkmdiff) +
  prior(normal(0, 1), class = b, nlpar = logsN) +
  prior(normal(0, 1), class = b, nlpar = logsP)

# initial values
inits <- list(logitfM = 1.5)
inits <- list(inits, inits, inits, inits)

# source the lognormal mean-sd parameterisation
# this will be passed to stanvars in brm
source("analysis/litter/chemistry_and_turnover/lognormal_natural.R")

# fit the model
mod <- brm(
  form,
  family = lognormal_natural,
  stanvars = stanvar(scode = stan_lognormal_natural, block = "functions"),
  data = litter_s,
  prior = priors,
  init = inits,
  control = list(adapt_delta = 0.95),
  cores = 4
)

summary(mod)

write_rds(mod, "data/derived/litter/mod_leaf_litter_decay.rds")



# Diagnostics ------------------------------------------------------------

# trace plots and posterior summaries
mcmc_trace(mod, regex_pars = "^b|^sd|^cor")
mcmc_intervals(mod, regex_pars = "^b|^sd|^cor")



# Predictions -------------------------------------------------------------

# new data and parameters for counterfactual predictions
newdat <-
  litter %>%
  data_grid(
    time = seq(0, 1, length.out = 50),
    CN = 0,
    CP = 0,
    log_x0 = 0,
    block = NA,
    species = NA
  )

# prediction
pred <-
  fitted(
    mod,
    newdata = newdat,
    allow_new_levels = TRUE
  )
newdat <-
  newdat %>%
  bind_cols(pred)

# plot
ggplot(newdat) +
  geom_ribbon(
    aes(time, ymin = Q2.5, ymax = Q97.5),
    alpha = 0.4
  ) +
  geom_line(
    aes(time, Estimate),
    linewidth = 1
  ) +
  labs(
    x = "Years",
    y = "Proportion of remaining mass"
  ) +
  coord_cartesian(
    ylim = c(0, 1),
    expand = FALSE
  ) +
  theme_bw()
