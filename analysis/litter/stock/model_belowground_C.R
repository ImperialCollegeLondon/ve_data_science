library(tidyverse)
library(readxl)
library(glmmTMB)




# Data --------------------------------------------------------------------

# root litter inputs
litter_root <-
  # nolint start
  read_xlsx("data/primary/litter/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx",
    sheet = 4,
    skip = 5
  ) %>%
  # nolint end
  select(ForestType:ForestPlotsCode, Mortality_FR, Mortality_CR) %>%
  mutate(root_litter_input = Mortality_FR + Mortality_CR)

# root nutrients
# Zhang, X., Wang, W. The decomposition of fine and coarse roots: their global
# patterns and controlling factors. Sci Rep 5, 9940 (2015).
# https://doi.org/10.1038/srep09940
nutrient_root <-
  read_xls("data/primary/litter/41598_2015_BFsrep09940_MOESM2_ESM.xls",
    sheet = 2
  ) %>%
  select(
    lifeform = `Life form`,
    study = Reference,
    lat = Latitude,
    size = Size,
    C = `C (mg/g)`,
    N = `N (mg/g)`,
    P = `P (mg/g)`,
    lignin = `Lignin (%)`
  ) %>%
  # convert from percentage to proportion
  mutate(lignin = lignin / 100)



# Models ------------------------------------------------------------------

# root litter input model
mod_litter_root <-
  glmmTMB(
    root_litter_input ~ 1,
    family = lognormal(),
    data = litter_root
  )

# root lignin model
# I'm going to only consider variation between lifeform and ignore latitudinal
# and size; we could include them, but then (1) I am not sure how representative
# each latitude was (it might be autocorrelated with lifeform and some
# methodological variation) and (2) size has lots of NAs
# I am including lifeform so I can predict for evergreen broadleaf later
mod_lignin_root <-
  glmmTMB(
    lignin ~ 0 + lifeform + (1 | study),
    family = beta_family,
    data = nutrient_root %>% filter(!is.na(lignin))
  )

# ditto for root C, N and P models
mod_C_root <-
  glmmTMB(
    C ~ 0 + lifeform + (1 | study),
    family = lognormal,
    data = nutrient_root %>% filter(!is.na(C))
  )

mod_N_root <-
  glmmTMB(
    N ~ 0 + lifeform + (1 | study),
    family = lognormal,
    data = nutrient_root %>% filter(!is.na(C))
  )

mod_P_root <-
  glmmTMB(
    P ~ 0 + lifeform + (1 | study),
    family = lognormal,
    data = nutrient_root %>% filter(!is.na(C))
  )



# Estimate belowground C --------------------------------------------------

# we will estimate with the equilibrium equation on
# https://github.com/ImperialCollegeLondon/ve_data_science/issues/60

# first we need the parameters estimated from the litter decay model
decay_params_df <- read_csv("data/derived/litter/turnover/decay_parameters.csv")
decay_params <- decay_params_df$value
names(decay_params) <- decay_params_df$Parameter

# root litter input rate
# convert from MgC/ha/Year to kgC/m2/day
I_root <- exp(fixef(mod_litter_root)$cond) * 1000 / 10000 / 365

# root lignin (convert from proportion to percentage)
L_root <- plogis(fixef(mod_lignin_root)$cond["lifeformEvergreen broadleaf"]) * 100

# root C:N and C:P ratio
C_root <- exp(fixef(mod_C_root)$cond["lifeformEvergreen broadleaf"])
N_root <- exp(fixef(mod_N_root)$cond["lifeformEvergreen broadleaf"])
P_root <- exp(fixef(mod_P_root)$cond["lifeformEvergreen broadleaf"])
CN_root <- C_root / N_root
CP_root <- C_root / P_root

# root metabolic fraction
fm_root <-
  decay_params["fM"] -
  L_root * (decay_params["sN"] * CN_root + decay_params["sP"] * CP_root)

# input rate of metabolic and structural fractions
I_metabolic <- I_root * fm_root
I_structural <- I_root * (1 - fm_root)

# decay rate of metabolic and structural fractions
D_metabolic <- decay_params["km"]
D_structural <- decay_params["ks"] * exp(decay_params["r"] * L_root)

# equilibrium stocks in kg C/m2
P_metabolic <- I_metabolic / D_metabolic
P_structural <- I_structural / D_structural
