#| ---
#| title: Models for predicting POM and MAOM carbon/nitrogen content from total
#|     soil carbon/nitrogen
#|
#| description: |
#|     To predict POM and MAOM carbon/nitrogen content from total soil
#|     carbon/nitrogen for the initialisation project. Current I am using the
#|     soil campaign dataset from SAFE to generate initial data, but the
#|     campaign only collected total soil C or total N. I am going to use
#|     a dataset from BCI Panama to estimate C/N fraction in POM and MAOM, so
#|     we can predict POM and MAOM C/N fractions post-hoc from the soil
#|     campaign model.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: SayerEtAl2021_GLiMP_SoilCN_Fractions.csv
#|     path: data/primary/soil/nutrient
#|     description: |
#|       Soil carbon and nitrogen content in POM and MAOM measured through
#|       fractionalisation. Data were collected from a litter-manipulation
#|       study at BCI Panama.
#|       Obtained from https://doi.org/10.6084/m9.figshare.31440067
#|       Refer to metadata for more info: SayerEtAl2021_Metadata.docx
#|
#| output_files:
#|   - name: model_C_POM_MAOM.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       glmmTMB model to predict carbon content in POM and MAOM from total
#|       soil carbon
#|   - name: model_N_POM_MAOM.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       glmmTMB model to predict nitrogen content in POM and MAOM from total
#|       soil nitrogen
#|
#| package_dependencies:
#|     - tidyverse
#|     - glmmTMB
#|
#| usage_notes: |
#|   Use the saved model output objects for downstream prediction later.
#| ---

library(tidyverse)
library(glmmTMB)


# Data --------------------------------------------------------------------

sayer <-
  read_csv(
    "data/primary/soil/nutrient/SayerEtAl2021_GLiMP_SoilCN_Fractions.csv"
  )

# split raw data into total bulk vs. fraction measurements
# the bulk subset data will be used as offset terms in the regression
bulk <-
  sayer %>%
  filter(frac == "total") %>%
  select(treatm:bulkD,
    C_total = mgCgsoilBD,
    N_total = mgNgsoilBD
  )

# the fraction measurements will be the response variables
frac <-
  sayer %>%
  filter(frac != "total") %>%
  group_by(treatm, block, plot, class) %>%
  summarise(
    C = sum(mgCgsoilBD),
    N = sum(mgNgsoilBD)
  ) %>%
  left_join(bulk) |>
  # convert total C and N from mg/g to g/g to match SAFE data
  mutate_at(
    vars(C, N, C_total, N_total),
    ~ . / 1e3
  )


# Model -------------------------------------------------------------------

# Model fraction carbon and nitrogen as a function of fraction class (POM vs
# MAOM) and litter treatment, with block as a random intercept. The contrast
# of the categorical variables just so happen to anchor the baseline intercept
# to control treatment. Use log total nutrient content as offset.

mod_C <- glmmTMB(
  C ~ 0 + class + treatm + (1 | block),
  offset = log(C_total),
  family = lognormal,
  data = frac
)

mod_N <- glmmTMB(
  N ~ 0 + class + treatm + (1 | block),
  offset = log(N_total),
  family = lognormal,
  data = frac
)
