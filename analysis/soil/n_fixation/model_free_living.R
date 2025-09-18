library(tidyverse)
library(terra)
library(nls.multstart)
library(minpack.lm)
library(AICcmodavg)

# Functions to fit candidate models from Kontopoulos et al. (2024)
# https://doi.org/10.1038/s41467-024-53046-2
# I will source it directly from their GitHub repo
source("https://raw.githubusercontent.com/dgkontopoulos/Kontopoulos_et_al_83_TPC_models_2024/refs/heads/main/Code/TPC_fitting_functions.R") # nolint




# Data --------------------------------------------------------------------

# Global map of soil temperature
# https://doi.org/10.5281/zenodo.7134169
# I think using soil temperature is better than ambient temperature (?)
soil_temp <-
  rast("data/primary/soil/abiotic/SBIO1_0_5cm_Annual_Mean_Temperature.tif")

# Biological nitrogen fixation dataset published by Reis Ely et al. (2025)
# https://doi.org/10.5066/P1MFBVHK
bnf_free_living <-
  read_csv("data/primary/soil/n_fixation/BNF_AREA.csv") %>%
  left_join(read_csv("data/primary/soil/n_fixation/SITE.csv")) %>%
  # filter to "soil" which is free-living microbes
  # remove zero fixation rates because they cannot be log-transformed in the
  # Kontopoulos models
  filter(
    niche == "Soil",
    !is.na(lat),
    !is.na(lon),
    BNF_final > 0
  )

# extract soil temperatures from the map
soil_temp_ext <- extract(soil_temp, bnf_free_living %>% select(lon, lat))

# join soil temperature to the main dataset
# and then remove subzero soil temperature (only a few of them) because some of
# the Kontopoulos models cannot support them
bnf_free_living <-
  bnf_free_living %>%
  mutate(soil_temp = soil_temp_ext$SBIO1_0_5cm_Annual_Mean_Temperature) %>%
  filter(
    !is.na(soil_temp),
    soil_temp > 0
  )

# a two-column dataframe for modelling
in_dat <-
  bnf_free_living %>%
  select(
    temp = soil_temp,
    trait_value = BNF_final
  )




# Model fitting ------------------------------------------------------------

# Instead fof fitting all 83 candidate models, I will only fit the top ten
# models that Kontopoulos et al. have found to be best for physiological traits

# Ashrafi II
ashrafi2 <- fit_Ashrafi_II_3_pars(in_dat)

# Second-order polynomial
quadratic <- fit_2nd_order_polynomial_3_pars(in_dat)

# Atkin
atkin <- fit_Atkin_3_pars(in_dat)

# Gaussian
Gaussian <- fit_Gaussian_3_pars(in_dat)

# Janisch I
janisch1 <- fit_Janisch_I_3_pars(in_dat)

# Ashrafi I
ashrafi1 <- fit_Ashrafi_I_3_pars(in_dat)

# Mitchell--Angilletta
mitchell_angilletta <- fit_Mitchell_Angilletta_3_pars(in_dat)

# Eubank
eubank <- fit_Eubank_3_pars(in_dat)

# Taylor--Sexton (doesn't fit successfully)
taylor_sexton <- fit_Taylor_Sexton_3_pars(in_dat)

# Analytis--Kontodimas
analytis_kontodimas <- fit_Analytis_Kontodimas_3_pars(in_dat)




# Model comparison --------------------------------------------------------

# compare candidate models using AICc the same way as Kontopoulos et al.
# the Taylor--Sexton is not included as it did not fit well
mod_comp <-
  tribble(
    ~model, ~AICc,
    "ashrafi2", AICc(ashrafi2),
    "quadratic", AICc(quadratic),
    "atkin", AICc(atkin),
    "Gaussian", AICc(Gaussian),
    "janisch1", AICc(janisch1),
    "ashrafi1", AICc(ashrafi1),
    "mitchell_angilletta", AICc(mitchell_angilletta),
    "eubank", AICc(eubank),
    "analytis_kontodimas", AICc(analytis_kontodimas)
  ) %>%
  arrange(AICc) %>%
  mutate(dAICc = AICc - min(AICc))

# the best model I obtained is the Eubank, which turns out to be similar to the
# Lorentzian or Cauchy function (i.e., heavy tailed)




# Prediction --------------------------------------------------------------

# Plot fitted line against data

newdat <- data.frame(temp = seq(0, 40, length.out = 200))
newdat$linpred <-
  predict(eubank,
    newdata = newdat
  )
# backtransform to original scale
newdat$pred <- exp(newdat$linpred)

with(
  newdat,
  plot(temp, pred,
    type = "l",
    col = "steelblue",
    lwd = 2,
    ylim = c(0, max(in_dat$trait_value))
  )
)
with(
  in_dat,
  points(temp, trait_value)
)
