#| ---
#| title: Estimating woody litter decomposition rates from SAFE data
#|
#| description: |
#|     This R script estimates litter decomposition rates from SAFE data.
#|     The goal is to parameterise the litter theoretical model documented
#|     under /theory/soil/litter_theory.html on the VE website. This script
#|     focuses on the woody litter component only.
#|
#| VE_module: Litter
#|
#| author:
#|   - name: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Deadwood decay and traits in the SAFE landscape by Terhi Riutta et al.
#|       Downloaded from https://zenodo.org/records/4899610
#|
#| output_files:
#|   - name: decay_parameters.csv
#|     path: data/derived/litter/turnover/
#|     description: |
#|       Parameters for the litter decay model. Values are reported as
#|       posterior median and the lower and upper bounds of the 90% credible
#|       intervals.
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|     For future reference, there is 10.1093/jpe/rtt041 but they did not
#|     provide open data, and did not measure lignin. There is also
#|     10.1111/1365-2435.14025 but their code is very, very dense and hard to
#|     read; managing it would cost us too much time.
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

litter_wood_raw <-
  read_xlsx(
    "data/primary/litter/SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  filter(SampleType == "Wood") %>%
  group_by(
    SamplingCampaign,
    SamplingDate,
    Block,
    Plot,
    PlotCode,
    Tag
  ) %>%
  # use wood density to determine decay, I think this is okay because density is
  # mass/volume, so basically relativising mass decay by volume but will not change
  # the interpretation of parameter
  mutate(Density_WaterDisplacement = as.numeric(Density_WaterDisplacement)) %>%
  summarise(Density = mean(Density_WaterDisplacement, na.rm = TRUE)) %>%
  # remove deadwood without repeated measurement
  group_by(Tag) %>%
  filter(n() > 1) %>%
  ungroup()

# wrangle wood decomposition to a format that is friendly for analysis
litter_wood <-
  litter_wood_raw %>%
  filter(SamplingCampaign == "1st") %>%
  select(-SamplingCampaign) %>%
  left_join(
    litter_wood_raw %>%
      filter(SamplingCampaign != "1st") %>%
      select(
        SamplingDate2 = SamplingDate,
        Tag,
        Density2 = Density
      )
  ) %>%
  # remove deadwood without a third measurement (some only measured twice)
  filter(!is.na(Density2)) %>%
  # calculate days lapsed
  mutate(
    days = as.numeric(SamplingDate2 - SamplingDate),
    .keep = "unused"
  ) %>%
  # then convert days to weeks for promote model convergence
  mutate(weeks = days / 7) %>%
  # calculate offset
  mutate(log_Density = log(Density))



# Model -------------------------------------------------------------------

# fit the wood decomposition model
# here I linearised it in the linear predictor of a lognormal GLMM
mod_wood <- glmmTMB(
  Density2 ~ 0 + weeks + (0 + weeks | PlotCode),
  offset = log_Density,
  family = lognormal(),
  data = litter_wood
)
summary(mod_wood)
param_wood <- confint(mod_wood)




# Prediction --------------------------------------------------------------

# counterfactual data
newdat <-
  data.frame(
    weeks = seq(0, 52 * 3, 1),
    log_Density = 0,
    PlotCode = NA
  )
newdat$estimate <-
  predict(mod_wood,
    newdata = newdat,
    type = "response",
    allow.new.levels = TRUE
  )

ggplot(newdat) +
  geom_line(aes(weeks * 7, estimate)) +
  coord_cartesian(expand = FALSE, ylim = c(0.5, 1)) +
  labs(x = "Days", y = "Proportion of mass remaining") +
  theme_bw()
