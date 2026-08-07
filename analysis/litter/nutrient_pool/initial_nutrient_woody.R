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
#|   - name: Fractal_point_nesting.xlsx
#|     path: data/primary/site/
#|     description: |
#|       SAFE plot type information including site, habitat, logging treatment,
#|       and plot nesting order; used to classify plots by logging group
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

# SAFE plot type information
safe_plot_info <-
  read_xlsx(
    "data/primary/site/Fractal_point_nesting.xlsx",
    sheet = 3,
    skip = 5
  ) |>
  pivot_longer(
    cols = ends_with("Order"),
    names_to = "Order",
    values_to = "Plot"
  ) |>
  filter(!is.na(Plot), Plot != "NA") |>
  distinct(Site, Habitat, Logging, Order, Plot) |>
  # reclassify logging
  mutate(
    Logging_grp = replace_values(
      Logging,
      "LowIntensity" ~ "Logged",
      "Twice" ~ "Logged",
      "Variable" ~ "Logged"
    )
  )

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
  pivot_longer(
    cols = ends_with("_total"),
    names_to = "Type",
    values_to = "Nutrient"
  ) |>
  # remove a few zero P values, assuming that these are below detection
  # threshold and not true zeros
  filter(Nutrient > 0) |>
  # join SAFE plot type
  left_join(safe_plot_info |> select(PlotCode = Plot, Logging_grp))

# lignin is hard to find and is unavailable from SAFE data
# I will use a long-term tropical hardwood data compiled by CIRAD
# https://dx.doi.org/10.19182/bft2019.342.a31809
# NB: these are lignin for live wood, but we assume that deadwood lignin value
#     is similar because (1) lignin decomposes very slowly and (2) there is
#     little reabsorption into the plant biomass prior to senescence
# Table III provides mean and CV for 599 species
lignin_mean <- 0.291
lignin_cv <- 0.14
# calculate standard deviation from mean and CV
lignin_sd <- lignin_mean * lignin_cv
# mean and sd will be used downstream to simulate lignin distribution in Maliau

# Model -------------------------------------------------------------------

# predictive model for deadwood C, N and P (g/g)
mod_nutrient_deadwood <-
  glmmTMB(
    Nutrient ~ 0 + Type * Logging_grp + (1 | PlotCode),
    family = lognormal(),
    data = nutrient_deadwood
  )
