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
#' status: wip
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
#'   - name: Output file name
#'     path: Full file path on shared drive
#'     description: |
#'       What the output file contains and its significance, are they used in any other
#'       scripts?
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'     - glmmTMB
#'
#' usage_notes: |
#'   Any known issues or bugs? Future plans for script/extensions or improvements
#'   planned that should be noted?
#' ---

library(tidyverse)
library(readxl)
library(glmmTMB)
library(performance)



# Data --------------------------------------------------------------------

# subplot coordinates
coord <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 2
  ) %>%
  filter(Type == "Carbon Subplot") %>%
  rename(location_name = `Location name`)

soil <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 3,
    skip = 9
  )

# PLFA concentrations containing fungal:bacterial ratio
plfa <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 5,
    skip = 9
  ) %>%
  # convert to long-format to model fungi and bacteria as groups
  select(Plot, location_name, Fungal_PLFA, Bacteria_PLFA) %>%
  pivot_longer(
    cols = ends_with("_PLFA"),
    names_to = "Group",
    names_pattern = "(.*)_PLFA",
    values_to = "PLFA"
  ) %>%
  mutate(Group = as.factor(Group))

# combine data
dat <-
  plfa %>%
  # join soil variables
  left_join(soil) %>%
  # join spatial coordinates and convert to glmmTMB-compatible class
  left_join(coord) %>%
  mutate(
    pos = numFactor(Longitude, Latitude),
    # dummy grouping variable for spatial modelling
    group = factor(1)
  )

dat_scaled <-
  dat %>%
  mutate_at(vars(soil_N, soil_C, soil_P), log) %>%
  mutate_at(
    vars(soil_pH, soil_N, soil_C, soil_P),
    ~ as.numeric(scale(.))
  )




# Model -------------------------------------------------------------------

mod_n <- glmmTMB(
  PLFA ~ 0 + Group * (soil_pH + soil_N) +
    (1 | Plot_ID),
  dispformula = ~ 0 + Group,
  family = lognormal(link = "log"),
  data = dat_scaled
)
mod_c <- glmmTMB(
  PLFA ~ 0 + Group * (soil_pH + soil_C) +
    (1 | Plot_ID),
  dispformula = ~ 0 + Group,
  family = lognormal(link = "log"),
  data = dat_scaled
)
mod_p <- glmmTMB(
  PLFA ~ 0 + Group * (soil_pH + soil_P) +
    (1 | Plot_ID),
  dispformula = ~ 0 + Group,
  family = lognormal(link = "log"),
  data = dat_scaled
)

compare_performance(mod_N, mod_C, mod_P,
  metrics = c("AICc"),
  rank = TRUE
)

summary(mod_C)

newdat <- data.frame(
  Group = unique(plfa$Group),
  Plot = NA
)
yhat <-
  predict(mod,
    newdata = newdat,
    allow.new.levels = TRUE,
    type = "response",
    cov.fit = TRUE
  )
yhat$fit[1] / yhat$fit[2]
