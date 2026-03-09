

library(tidyverse)


# empirical fractions of phosphorus in a lowland tropical rainforest
# of Deramakot, Borneo (Imai et al. 2012)
# https://jtfs.frim.gov.my/jtfs/article/view/472

# Fractions are listed by Imai et al.'s nomenclature, in units [kg/ha]
# these are P fractions by sequential extraction
# I list them using the original nomenclature for transparency
# later they will be assigned (approximally) to the VE fractions based on
# Gijsman et al. (1996; Fig. 2)
# https://doi.org/10.2134/agronj1996.00021962003600060008x

Pi_CO3 <- 35.5
Po_CO3 <- 94.8
Pi_OH <- 58.7
Po_OH <- 211.2
Ca_Pi <- 15.1
Occl_Pi <- 2909.5
T_P <- 3294.4

# The Imai et al. dataset has Po_OH, which can be a proxy of P in POM + MAOM
# so we need another ratio to split this value into the POM and MAOM pool
# P pool fractionalisation data is very very scarce, I will rely on a study in
# the Amazon (Hoosbeek et al. 2023) https://doi.org/10.1007/s10342-023-01577-6
# In their Figure 3, they showed results of P in three soil fractions:
# free light (fLF), occluded light (oLF) and mineral associated heavy (maHF)
# According to the method paper they cited (Six et al. 2002), the fLF fraction
# seems to be a proxy for POM, and I'll use oLF + maHF as a proxy for MAOM
# Now the challenge is that their figure is poor in resolution so value
# extraction is not easy. I will eyeball it, which should be fine given that
# we are trying to estimate initial values, not really constants / parameters
# I eyeballed the proportion of P in POM to be 5% and the rest (95%) in MAOM

P_fraction_POM <- 0.05

# map P fractions in Imai et al. to VE pools
p_pools <-
  data.frame(
    soil_p_pool_dop = Po_CO3,
    soil_p_pool_labile = Pi_CO3,
    soil_p_pool_particulate = Po_OH * P_fraction_POM,
    soil_p_pool_maom = Po_OH * (1 - P_fraction_POM),
    soil_p_pool_secondary = Pi_OH + Occl_Pi,
    soil_p_pool_primary = Ca_Pi
  ) |>
  pivot_longer(cols = everything(),
               names_to = "fraction",
               values_to = "amount") |>
  # convert amount to proportions, which will be used to split predicted
  # total P into separate pools
  mutate(prop = amount / T_P)
