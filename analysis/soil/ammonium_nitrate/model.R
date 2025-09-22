#' ---
#' title: Descriptive name of the script
#'
#' description: |
#'     https://doi.org/10.5281/zenodo.3251900
#'
#' VE_module: Animal, Plant, Abiotic, Soil, None, etc
#'
#' author:
#'   - name: David Orme
#'
#' status: final or wip
#'
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
#'   Soil depth
#' ---


library(tidyverse)
library(readxl)
library(lubridate)
library(hms)
library(glmmTMB)



one_off <-
  read_excel("data/primary/soil/gas_flux/3_GHG_jdrewer.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  select(chamber_id, bulk_density) %>%
  mutate(chamber_id = as.character(chamber_id))



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
  left_join(one_off) %>%
  mutate(
    date = ymd(date),
    day_since = as.factor(date - min(date)),
    time = as_hms(time * 86400),
    hour = as.factor(hour(time))
  ) %>%
  mutate(group = 1) %>%
  rename(
    ammonium = `NH4-N`,
    nitrate = `NO3-N`
  ) %>%
  # zero-truncate negative values
  mutate_at(vars(ammonium, nitrate), ~ ifelse(. < 0, 0, .)) %>%
  # convert nitrogen measurements from mg N g-1 to mg N cm-3
  mutate_at(vars(ammonium, nitrate), ~ . * bulk_density)




# Models ------------------------------------------------------------------

mod_ammonium <- glmmTMB(
  ammonium ~ 0 + landuse + (1 | site / chamber_id) + ar1(day_since + 0 | group),
  ziformula = ~ 0 + landuse,
  family = lognormal,
  data = flux
)
summary(mod_ammonium)

mod_nitrate <- glmmTMB(
  nitrate ~ 0 + landuse + (1 | site / chamber_id) + ar1(day_since + 0 | group),
  ziformula = ~ 0 + landuse,
  family = lognormal,
  data = flux
)
summary(mod_nitrate)




# Predicted mean value for initialisation ---------------------------------

# using forest land use as a baseline
newdat <- data.frame(
  landuse = "forest",
  site = NA,
  chamber_id = NA,
  day_since = NA,
  group = NA
)

pred_ammonium <- predict(
  mod_ammonium,
  newdat,
  allow.new.levels = TRUE,
  type = "response"
)

pred_nitrate <- predict(
  mod_nitrate,
  newdat,
  allow.new.levels = TRUE,
  type = "response"
)

# 1 mg N cm-3 = 1 kg N m-3 so no conversion needed
