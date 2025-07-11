#' ---
#' title: Estimating litter stocks from SAFE data
#'
#' description: |
#'     This R script estimates litter stocks (leaf, wood, reproductive)
#'     from SAFE data
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
#'   This model estimates litter stock in kg/m2/day, but VE takes kg/m2 for
#'   initialisation. We will discuss more about this.
#'   If more data is needed for even more accurate parameterisation, see
#'   Turner et al. (2019) https://zenodo.org/records/3265722
#' ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

litter_stock <-
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
    values_to = "DW"
  )




# Model -------------------------------------------------------------------

# Tweedie log-link GLMM
mod <- glmmTMB(
  DW ~ 0 + Type + (1 | Plot) + offset(log_days),
  dispformula = ~ 0 + Type,
  family = tweedie,
  data = litter_stock
)

summary(mod)

# expected litter stock per litter type
# original measurement was in g/m2/day, convert to kg/m2/day
stock_fitted <- exp(fixef(mod)$cond) / 1000
stock_fitted
