#' ---
#' title: Estimate soil ammonium and nitrate for VE initialisation
#'
#' description: |
#'     This script fits models to a soil dataset from the SAFE project to
#'     estimate soil ammonium and nitrate for initialising VE. These model
#'     estimates expected nitrogen by land use type, while accounting for
#'     spatial and temporal autocorrelations. I then predicted the soil
#'     nitrogen values using forest land use type as the baseline; i.e., we
#'     use forest baseline values for VE initialisation.
#'
#' VE_module: Soil
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: final
#'
#' input_files:
#'   - name: 3_GHG_jdrewer.xlsx
#'     path: data/primary/soil/gas_flux
#'     description: |
#'       Soil greenhouse gas fluxes and associated parameters from forest and
#'       oil palm in the SAFE landscape collected by Drewer et al. (2019);
#'       downloaded from https://doi.org/10.5281/zenodo.3258117
#'
#' output_files:
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'     - lubridate
#'     - hms
#'     - glmmTMB
#'
#' usage_notes: |
#'   The soil cores in this dataset was collected from 0-10 cm soil depth. VE
#'   soil depth is 25 cm, so we are assuming that the the 0-10 cm soil properties
#'   hold until 25 cm. We may want to revisit this assumption later.
#' ---


library(tidyverse)
library(readxl)
library(lubridate)
library(hms)
library(glmmTMB)



# Data --------------------------------------------------------------------

# soil bulk density dataset
one_off <-
  read_excel("data/primary/soil/gas_flux/3_GHG_jdrewer.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  select(chamber_id, bulk_density) %>%
  mutate(chamber_id = as.character(chamber_id))

# soil flux dataset to get ammonium and nitrate measurements
flux <-
  read_excel("data/primary/soil/gas_flux/3_GHG_jdrewer.xlsx",
    sheet = 4,
    skip = 5,
    col_types = c(
      "skip",
      rep("text", 4),
      "date",
      "numeric",
      rep("numeric", 8)
    )
  ) %>%
  # join bulk density dataset
  left_join(one_off) %>%
  # convert date and time to the right format to be used in modelling
  mutate(
    date = ymd(date),
    day_since = as.factor(date - min(date)),
    time = as_hms(time * 86400),
    hour = as.factor(hour(time))
  ) %>%
  # placeholder variable for modelling
  mutate(group = 1) %>%
  # final housekeeping
  rename(
    ammonium = `NH4-N`,
    nitrate = `NO3-N`
  ) %>%
  # zero-truncate negative values
  mutate_at(vars(ammonium, nitrate), ~ ifelse(. < 0, 0, .)) %>%
  # convert nitrogen measurements from mg N g-1 to mg N cm-3
  mutate_at(vars(ammonium, nitrate), ~ . * bulk_density)




# Models ------------------------------------------------------------------

# These model estimates expected nitrogen by land use type, while accounting
# for spatial and temporal autocorrelations

# ammonium model
mod_ammonium <- glmmTMB(
  ammonium ~ 0 + landuse + (1 | site / chamber_id) + ar1(day_since + 0 | group),
  ziformula = ~ 0 + landuse,
  family = lognormal,
  data = flux
)
summary(mod_ammonium)

# nitrate model
mod_nitrate <- glmmTMB(
  nitrate ~ 0 + landuse + (1 | site / chamber_id) + ar1(day_since + 0 | group),
  ziformula = ~ 0 + landuse,
  family = lognormal,
  data = flux
)
summary(mod_nitrate)




# Predicted mean value for initialisation ---------------------------------

# counterfactual dataset using forest land use as a baseline
newdat <- data.frame(
  landuse = "forest",
  site = NA,
  chamber_id = NA,
  day_since = NA,
  group = NA
)

# predicted mean ammonium
pred_ammonium <- predict(
  mod_ammonium,
  newdat,
  allow.new.levels = TRUE,
  type = "response"
)

# predicted mean nitrate
pred_nitrate <- predict(
  mod_nitrate,
  newdat,
  allow.new.levels = TRUE,
  type = "response"
)

# 1 mg N cm-3 = 1 kg N m-3 so no conversion needed
