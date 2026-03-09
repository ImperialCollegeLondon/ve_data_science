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
library(readxl)
library(rgbif)
library(glmmTMB)

# fungal guild database
trait <-
  read_excel("data/primary/soil/fungi/13225_2020_466_MOESM4_ESM.xlsx") |>
  select(
    family = Family,
    genus = GENUS,
    guild = primary_lifestyle
  )

# Stoichiometry database
stoich <-
  read_delim(
    "data/primary/animal/body_stoichiometry/Global_heterotroph_stoichio_v5.csv"
  ) |>
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
  # add guild info
  left_join(trait) |>
  # add guild and kingdom info
  bind_cols(stoich) |>
  # remove taxa without established taxonomy and trait
  filter(
    !is.na(kingdom),
    !is.na(guild)
  ) |>
  # rename / merge guilds into coarser groups that we want
  # and then sum their abundances
  mutate(guild = case_when(
    guild == "arbuscular_mycorrhizal" ~ "AM",
    guild == "ectomycorrhizal" ~ "EM",
    str_detect(guild, "saprotroph") ~ "saprotroph",
    str_detect(guild, "pathogen") ~ "pathogen",
    str_detect(guild, "parasite") ~ "parasite",
    str_detect(guild, "endophyte") ~ "endophyte",
    str_detect(guild, "lichenized") ~ "lichenized",
    str_detect(guild, "epiphyte") ~ "epiphyte",
    .default = "other"
  )) |>
  # FIXME if bacteria are added back in the future, need to manually
  # assign them a "guild" name, i.e., "bacteria" to keep this part working
  # next, only keep guild of interest
  filter(guild %in% c("AM", "EM", "saprotroph")) |>
  select(kingdom, guild, C_mean) |>
  # convert C fraction from percentage to proportion
  mutate(C_mean = C_mean / 100)

# NB: turns out only fungi have C fraction, not bacteria;
#     so for bacteria I will use one-half C per body mass assumed in
#     Whitman et al. (1998) https://doi.org/10.1073/pnas.95.12.6578

# Model to estimate C fraction for fungi
# this is a very crude model ignoring phylogenetic dependence!
mod <- glmmTMB(
  C_mean ~ 0 + guild,
  family = beta_family(),
  data = C_frac
)

# estimated C fraction in fungi and assumed C fraction in bacteria
C_frac_est <- c(
  plogis(fixef(mod)$cond),
  bacteria = 0.5
)
names(C_frac_est) <- str_remove(names(C_frac_est), "guild")

# save output
write_rds(
  C_frac_est,
  "data/derived/soil/nutrient_pools/C_fraction_microbe.rds"
)
