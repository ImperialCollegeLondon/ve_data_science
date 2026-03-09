#| ---
#| title: Models to predict woody litter nutrient composition for Maliau
#|
#| description: |
#|     This script builds a predictive model of woody litter C, N and P for
#|     the Maliau initialisation project. For woody litter lignin, empirical
#|     data are scarce; I will use a long-term tropical hardwood data compiled
#|     by CIRAD (https://dx.doi.org/10.19182/bft2019.342.a31809).
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx
#|     path: data/primary/litter
#|     description: |
#|         Deadwood decay and traits in the SAFE landscape.
#|         Downloaded from https://zenodo.org/records/4899610
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)




# Data --------------------------------------------------------------------

# N, C and P from SAFE deadwood survey
nutrient_deadwood <-
  read_xlsx(
    "data/primary/litter/SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx",
    sheet = 4,
    skip = 5
  ) |>
  # regroup all OG plots together to predict them as a single forest type
  mutate(Block = ifelse(str_detect(Block, "OG"), "OG", Block)) |>
  # relevel Block so OG is the baseline
  mutate(Block = fct_relevel(Block, "OG")) |>
  # convert P to g/g
  mutate(P_total = P_total / 1e3) |>
  # convert to long format for modelling
  select(Block, PlotCode, ends_with("_total")) |>
  pivot_longer(cols = ends_with("_total"),
               names_to = "Type",
               values_to = "Nutrient") |>
  # remove a few zero P values, assuming that these are below detection
  # threshold and not true zeros
  filter(Nutrient > 0)

# lignin is hard to find and is unavailable from SAFE data
# I will use a long-term tropical hardwood data compiled by CIRAD
# https://dx.doi.org/10.19182/bft2019.342.a31809
# NB: these are lignin for live wood, but we assume that deadwood lignin value
#     is similar because (1) lignin decomposes very slowly and (2) there is
#     little reabsorption into the plant biomass prior to senescence
# Table III provides mean and CV for 599 species
lignin_mean <- 0.291
lignin_cv   <- 0.14
# calculate standard deviation from mean and CV
lignin_sd   <- lignin_mean * lignin_cv
# mean and sd will be used downstream to simulate lignin distribution in Maliau



# Model -------------------------------------------------------------------

# predictive model for deadwood C, N and P (g/g)
# TODO currently predicting C, N and P separately rather than as C:N and C:P ratios
mod_nutrient_deadwood <-
  glmmTMB(
    Nutrient ~ 0 + Type * Block + (1 | PlotCode),
    family = lognormal(),
    data = nutrient_deadwood
  )

predict_nutrient_deadwood <-
  data.frame(
    Type = c("C_total", "N_total", "P_total"),
    Block = "OG",
    PlotCode = NA
  ) |>
  mutate(estimate = predict(
    mod_nutrient_deadwood,
    newdata_nutrient_deadwood,
    # TODO prediction intervals
    type = "response",
    allow.new.levels = TRUE
  ))

# for deadwood lignin, an example simulation is as follows
lignin_sim <- rnorm(1000, lignin_mean, lignin_sd)
# convert lignin from mass/mass to g C/g C
# the lignin C content = 62.5% comes from
# Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
C_perc <-
  predict_nutrient_deadwood$estimate[predict_nutrient_deadwood$Type == "C_total"]
# FIXME C_perc needs to incorporate prediction uncertainty after fixing the
#       prediction intervals TODO above
lignin_sim <- lignin_sim * 0.625 / (C_perc/100)
