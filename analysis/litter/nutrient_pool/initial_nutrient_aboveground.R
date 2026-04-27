#| ---
#| title: Models to predict aboveground litter nutrient composition for Maliau
#|
#| description: |
#|     This script uses previously inferred litter decay parameters to split
#|     SAFE aboveground litter data into structural and metabolic pools, then
#|     builds a predictive model for the Maliau initialisation project.
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: decay_parameters.csv
#|     path: data/derived/litter/turnover
#|     description: |
#|         Litter decay parameters to split field-collected litter into
#|         structural and metabolic pools
#|   - name: Both_litter_decomposition_experiment.xlsx
#|     path: data/primary/litter
#|     description: |
#|         Leaf litter decomposition in old-growth and selectively logged
#|         forest in SAFE. Downloaded from https://zenodo.org/records/3247639
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


# Parameters --------------------------------------------------------------

# Fitted litter decay parameters from a previous PR (#104)
# they are used to split litter into structural and metabolic pools
decay_param <- read_csv("data/derived/litter/turnover/decay_parameters.csv")
logitfM <- decay_param$value[decay_param$Parameter == "logitfM"]
sN <- decay_param$value[decay_param$Parameter == "sN"]
sP <- decay_param$value[decay_param$Parameter == "sP"]

# Ratio of structural vs metabolic C:N and C:P (r in the CENTURY model)
# this is from Kirschbaum and Paul (2002) Soil Biology and Biochemistry
# Since the structural and metabolic pools are abstract pools (unfortunately)
# there is no reason to modify this abstract ratio
r_century <- 5


# Data --------------------------------------------------------------------

# Litter data from SAFE
litter <-
  read_xlsx(
    "data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 3,
    skip = 7
  ) |>
  # convert lignin from mass/mass to g C/g C
  # the lignin C content = 62.5% comes from
  # Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
  mutate(lignin = lignin_recalcitrants * 0.625 / C_perc) |>
  select(
    litter_type,
    C.N,
    C.P,
    lignin,
  ) |>
  # calculate metabolic fraction
  mutate(
    fm = plogis(
      logitfM - lignin * (sN * C.N + sP * C.P)
    )
  ) |>
  # calculate metabolic and structural nutrients
  # see rearranged equation on the litter theory documentation
  # https://virtual-ecosystem.readthedocs.io/en/latest/virtual_ecosystem/theory/soil/litter_theory.html#split-of-nutrient-inputs-between-pools
  mutate(
    C.N_metabolic = C.N / (r_century + fm * (1 - r_century)),
    C.P_metabolic = C.P / (r_century + fm * (1 - r_century)),
    C.N_structural = r_century * C.N_metabolic,
    C.P_structural = r_century * C.P_metabolic
  )


# Model -------------------------------------------------------------------

# Models to predict aboveground litter nutrient composition for Maliau
# litter_type as covariate to predict for Maliau

# C:N model
mod_C.N_met_above <- glmmTMB(
  C.N_metabolic ~ 0 + litter_type,
  family = lognormal,
  data = litter
)

# C:P model
mod_C.P_met_above <- glmmTMB(
  C.P_metabolic ~ 0 + litter_type,
  family = lognormal,
  data = litter
)

# lignin model
mod_lignin_above <- glmmTMB(
  lignin ~ 0 + litter_type,
  family = beta_family(),
  data = litter
)
