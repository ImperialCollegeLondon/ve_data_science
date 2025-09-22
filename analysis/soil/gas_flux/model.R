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
#'   Any known issues or bugs? Future plans for script/extensions or improvements
#'   planned that should be noted?
#' ---


library(tidyverse)
library(readxl)
library(lubridate)
library(hms)
library(glmmTMB)



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
  mutate(
    date = ymd(date),
    day_since = as.factor(date - min(date)),
    time = as_hms(time * 86400),
    hour = as.factor(hour(time))
  ) %>%
  mutate(group = 1) %>%
  rename(
    flux_CO2 = `flux_CO2-C`,
    flux_N2O = `flux_N2O-N`
  )




# Model -------------------------------------------------------------------


mod <- glmmTMB(
  flux_CO2 ~ 0 + landuse +
    (1 | site / chamber_id) +
    ar1(day_since + 0 | group),
  dispformula = ~ 0 + landuse,
  family = lognormal,
  data = flux
)

summary(mod)

# compare to 10.5194/bg-18-1559-2021
