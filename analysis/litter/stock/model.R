#' ---
#' title: Estimating litter stocks from SAFE data
#'
#' description: |
#'     This R script estimates litter stocks (leaf, wood, reproductive)
#'     from SAFE data. It combines a dataset that measured
#'     total aboveground litter stock and another dataset that
#'     measured litter composition (can be converted to
#'     proportions) to estimate litter stock per composition.
#'     Belowground stock is still missing for now.
#'
#' VE_module: Litter
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: wip
#'
#' input_files:
#'   - name: Ewers_LeafLitter.xlsx
#'     path: data/primary/litter/
#'     description: |
#'       Wet and dry weight of leaf litterfall at SAFE vegetation plots by
#'       Robert Ewers; downloaded from https://zenodo.org/records/1198587
#'   - name: SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx
#'     path: data/primary/litter/
#'     description: |
#'       Litter stock from SAFE carbon inventory by
#'       Riutta et al.; downloaded from https://zenodo.org/records/4542881
#'
#' output_files:
#'   - name: NA
#'     path: NA
#'     description: |
#'       NA
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'     - glmmTMB
#'
#' usage_notes: |
#'   If more data is needed for even more accurate parameterisation, see
#'   Turner et al. (2019) https://zenodo.org/records/3265722
#' ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

# Litter stock data by Riutta et al.
# https://zenodo.org/records/4542881

litter_stock <-
  # nolint start
  read_xlsx("data/primary/litter/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx",
    sheet = 4,
    skip = 5
  ) %>%
  # nolint end
  select(field_name:ForestPlotsCode, LitterStock) %>%
  # convert litter stock from Mg C / ha to kg C / m2
  mutate(LitterStock = LitterStock * 0.1)

# Litter composition data from litter traps by Ewers
# https://zenodo.org/records/1198587

litter_compo <-
  read_xlsx("data/primary/litter/Ewers_LeafLitter.xlsx",
    sheet = 3,
    skip = 9
  ) %>%
  # use the first survey because only it has litter component weights
  filter(SurveyNum == 1) %>%
  # make sure weights are numeric
  mutate_at(vars(starts_with("WW") | starts_with("DW")), as.numeric) %>%
  mutate(
    # calculate log number of day lapsed as offsets
    log_days = log(as.numeric(DateCollected - DateSet)),
    # pool leaf mass
    DW.leaf = DW.leaves.photo + DW.leaves.other,
    # pool reproductive mass
    DW.reproduction = DW.flower + DW.fruit + DW.seed
  ) %>%
  # convert to long format for modelling
  select(
    Plot, log_days,
    DW.leaf, DW.wood, DW.reproduction, DW.other
  ) %>%
  pivot_longer(
    cols = starts_with("DW"),
    names_to = "Type",
    names_prefix = "DW\\.",
    values_to = "DW"
  )




# Model -------------------------------------------------------------------

# Stock model
mod_stock <- glmmTMB(
  LitterStock ~ 1,
  family = lognormal,
  data = litter_stock
)

summary(mod_stock)

# Composition model
mod_compo <- glmmTMB(
  DW ~ 0 + Type + (1 | Plot) + offset(log_days),
  dispformula = ~ 0 + Type,
  family = tweedie,
  data = litter_compo
)

summary(mod_compo)





# Prediction --------------------------------------------------------------

# Our stock model only predicts total aboveground litter stock
# To split it into separate litter components, we will combine
# it with the litter composition model
# Ideally we would do this with simulated posterior to propagate
# parameter uncertain better but I will do it quick and dirty
# for now because the goal is a first pass for VE

# Expected litter composition in proportions
compo_hat <- exp(fixef(mod_compo)$cond)
compo_hat <- compo_hat / sum(compo_hat)

# Expected litter stock in kg C / m2
stock_hat <- exp(fixef(mod_stock)$cond)

# Expected litter stock by component
stock_compo <- stock_hat * compo_hat
