#' ---
#' title: Descriptive name of the script
#'
#' description: |
#'     Brief description of what the script does, its main purpose, and any important
#'     scientific context. Keep it concise but informative.
#'
#'     This can include multiple paragraphs.
#'
#' VE_module: Soil
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: wip
#'
#' input_files:
#'   - name: Input file name
#'     path: Full file path on shared drive
#'     description: |
#'       Source (short citation) and a brief explanation of what this input file
#'       contains and its use case in this script
#'
#' output_files:
#'   - name: Output file name
#'     path: Full file path on shared drive
#'     description: |
#'       What the output file contains and its significance, are they used in any other
#'       scripts?
#'
#' package_dependencies:
#'     - tools
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
  FBR ~ 1 + exp(pos + 0 | group),
  family = beta_family(link = "logit"),
  data = plfa
)

summary(mod)
