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



# Data --------------------------------------------------------------------

# subplot coordinates
coord <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 2
  ) %>%
  filter(Type == "Carbon Subplot") %>%
  rename(location_name = `Location name`)

# PLFA concentrations containing fungal:bacterial ratio
plfa <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 5,
    skip = 9
  ) %>%
  rename(FBR = `Fungal:Bacteria`) %>%
  # join spatial coordinates and convert to glmmTMB-compatible class
  left_join(coord) %>%
  mutate(
    pos = numFactor(Longitude, Latitude),
    # dummy grouping variable for spatial modelling
    group = factor(1)
  )




# Model -------------------------------------------------------------------

mod <- glmmTMB(
  FBR ~ 1 + (1 | Plot_ID),
  family = beta_family(link = "logit"),
  data = plfa
)

summary(mod)

newdat <- data.frame(
  Plot_ID = NA
)
predict(mod,
  newdata = newdat,
  allow.new.levels = TRUE,
  type = "response"
)
