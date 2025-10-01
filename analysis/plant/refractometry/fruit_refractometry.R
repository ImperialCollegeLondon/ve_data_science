library(tidyverse)
library(brms)

refrac <-
  read_csv("data/primary/plant/traits_data/white1985.csv") %>%
  mutate(Lipid = Total_solids - Lipid_free_solids) %>%
  mutate_at(vars(Refract_estimate_mean:Total_solids), ~ . / 100)

pairs(refrac[, -1])



mod <- brm(
  Soluble_CHO ~ 1 + me(Refract_estimate_mean, Refract_estimate_sd),
  family = Beta(),
  data = refrac,
  cores = 4
)

summary(mod)
