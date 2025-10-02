library(tidyverse)
library(readxl)
library(brms)

# Functions to fit candidate models from Kontopoulos et al. (2024)
# https://doi.org/10.1038/s41467-024-53046-2
# I will source it directly from their GitHub repo
source("https://raw.githubusercontent.com/dgkontopoulos/Kontopoulos_et_al_83_TPC_models_2024/refs/heads/main/Code/TPC_fitting_functions.R") # nolint


# Data --------------------------------------------------------------------

# Nitrogenase activity data by Houlton et al. 2008, who did not publish their
# data but was later extracted by Deutsch et al. 2024
# https://doi.org/10.1016/j.tim.2023.12.007
houlton <-
  read_excel(
    "data/primary/soil/n_fixation/1-s2.0-S0966842X23003566-mmc1.xlsx",
    range = "A1:C124"
  ) %>%
  filter(Source == "Houlton2008") %>%
  # some of the extracted normalised rates are >1, probably due to accuracy
  # error during visual extraction, I will just cap them to 0.999
  mutate(
    Rate = ifelse(`Rate (normalized)` > 1, 0.999, `Rate (normalized)`),
    .keep = "unused"
  ) %>%
  # scale temperature
  mutate(T_s = Temperature / sd(Temperature))


# Model fitting ------------------------------------------------------------

# Instead fof fitting all 83 candidate models, I will only fit the top ten
# models that Kontopoulos et al. have found to be best for physiological traits

# Ashrafi II
ashrafi2 <-
  bf(Rate ~ a + b * T_s^(3 / 2) - c * T_s^2, nl = TRUE) +
  nlf(b ~ exp(logb)) +
  nlf(c ~ exp(logc)) +
  lf(a + logb + logc ~ 1)

# Second-order polynomial
quadratic <-
  bf(Rate ~ 1 + T_s + I(T_s^2))

# Atkin
atkin <-
  bf(Rate ~ B0 * (a - b * T_s)^T_s / 10)

# Gaussian
Gaussian <-
  bf()

# Janisch I
janisch1 <-
  bf()

# Ashrafi I
ashrafi1 <-
  bf()

# Mitchell--Angilletta
mitchell_angilletta <-
  bf()

# Eubank
eubank <-
  bf()

# Taylor--Sexton (doesn't fit successfully)
taylor_sexton <-
  bf()

# Analytis--Kontodimas
analytis_kontodimas <-
  bf()

#
mod_ashrafi2 <- brm(
  ashrafi2,
  family = Beta(),
  data = houlton,
  prior = prior(normal(-5, 1), class = "b", nlpar = "a") +
    prior(normal(1.8, 1), class = "b", nlpar = "logb") +
    prior(normal(1.5, 1), class = "b", nlpar = "logc"),
  cores = 4
)

mod_quadratic <- brm(
  quadratic,
  family = Beta(),
  data = houlton,
  cores = 4
)
