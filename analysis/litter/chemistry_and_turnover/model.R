#' ---
#' title: Estimating fungal-to-bacteria ratio from SAFE data
#'
#' description: |
#'     This R script estimates fungal-to-bacteria ratio from SAFE data
#'
#' VE_module: Soil
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: final
#'
#' input_files:
#'   - name: SAFE_Dataset.xlsx
#'     path: data/primary/soil/fungal_bacteria_ratio
#'     description: |
#'       Soil and litter chemistry, soil microbial communities and
#'       litter decomposition from tropical forest and oil palm dataset by
#'       Elias Dafydd et al. from SAFE; downloaded from
#'       https://doi.org/10.5281/zenodo.3929632
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
#'     - performance
#'
#' usage_notes: |
#'   In the future, it is possible to get a numerically more accurate ratio
#'   using bootstrap values from the point estimate AND covariances of the
#'   predict function.
#' ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

litter_compo <-
  read_xlsx("data/primary/litter/Ewers_LeafLitter.xlsx",
    sheet = 3,
    skip = 9
  ) %>%
  # use the first survey because only it has litter component weights
  filter(SurveyNum == 1) %>%
  mutate_at(vars(starts_with("WW") | starts_with("DW")), as.numeric) %>%
  mutate(
    log_days = log(as.numeric(DateCollected - DateSet)),
    DW.leaf = DW.leaves.photo + DW.leaves.other,
    DW.reproduction = DW.flower + DW.fruit + DW.seed
  ) %>%
  select(
    Plot, log_days,
    DW.leaf, DW.wood, DW.reproduction, DW.other
  ) %>%
  pivot_longer(
    cols = starts_with("DW"),
    names_to = "Type",
    values_to = "DW"
  )

litter_nutrient <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 4,
    skip = 9
  ) %>%
  select(
    Plot_ID,
    location_name,
    Pretreatment,
    leaf_N,
    leaf_P,
    leaf_C,
    lig_rec
  ) %>%
  pivot_longer(
    cols = c(leaf_N, leaf_P, leaf_C, lig_rec),
    names_to = "chemical",
    values_to = "concentration"
  )


# Lignin, N and P contents of litter





# Model -------------------------------------------------------------------

mod_compo <- glmmTMB(
  DW ~ 0 + Type + (1 | Plot) + offset(log_days),
  dispformula = ~ 0 + Type,
  family = tweedie,
  data = litter_compo
)

summary(mod_compo)

exp(fixef(mod_compo)$cond)



mod_nutrient <- glmmTMB(
  concentration ~ 0 + chemical +
    rr(chemical + 0 | location_name, d = 2),
  dispformula = ~ 0 + chemical,
  family = lognormal(),
  data = litter_nutrient
)

summary(mod_nutrient)
