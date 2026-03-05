#| ---
#| title: Estimate carbon fraction per mass in fungi
#|
#| description: |
#|     This R script estimates carbon fraction per mass in fungi from a global
#|     database. Bacteria were included in the database but all of them do not
#|     have C fraction data.
#|
#| virtual_ecosystem_module:
#|   - Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: Global_heterotroph_stoichio_v5.csv
#|     path: data/primary/animal/body_stoichiometry
#|     description: |
#|       Dataset of stoichiometric traits of heterotrophs by Andrieux et al.
#|       2021 https://doi.org/10.1111/geb.13265
#|       Downloaded from https://doi.org/10.6084/m9.figshare.13366310
#|
#| output_files:
#|   - name: C_fraction_microbe.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       Estimated C fraction in fungi and assumed C fraction in bacteria
#|
#| package_dependencies:
#|     - tidyverse
#|     - rgbif
#|     - glmmTMB
#|
#| usage_notes: |
#|   To be used in the post-hoc prediction of Maliau scenario
#| ---

library(tidyverse)
library(rgbif)
library(glmmTMB)


# Stoichiometry database
stoich <-
  read_delim("data/primary/animal/body_stoichiometry/Global_heterotroph_stoichio_v5.csv") |>
  filter(
    Group == "Microbe",
    !is.na(C_mean)
  )

# add kingdom to the database taxa using GBIF backbone
query <-
  stoich |>
  select(
    class = Class,
    family = Family,
    genus = Genus,
    species = Species
  ) |>
  pmap(name_backbone, .progress = TRUE) |>
  bind_rows()
C_frac <-
  query |>
  select(kingdom) |>
  bind_cols(stoich) |>
  filter(!is.na(kingdom)) |>
  select(kingdom, C_mean) |>
  # convert C fraction from percentage to proportion
  mutate(C_mean = C_mean / 100)

# NB: turns out only fungi have C fraction, not bacteria;
#     so for bacteria I will use one-half C per body mass assumed in
#     Whitman et al. (1998) https://doi.org/10.1073/pnas.95.12.6578

# Model to estimate C fraction for fungi
# this is a very crude model ignoring phylogenetic dependence!
mod <- glmmTMB(
  C_mean ~ 1,
  family = beta_family(),
  data = C_frac
)

# estimated C fraction in fungi and assumed C fraction in bacteria
C_frac <- c(
  fungi = as.numeric(plogis(fixef(mod)$cond)),
  bacteria = 0.5
)

# save output
write_rds(C_frac, "data/derived/soil/nutrient_pools/C_fraction_microbe.rds")
