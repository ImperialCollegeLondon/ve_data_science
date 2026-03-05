

library(tidyverse)
library(rgbif)
library(glmmTMB)



# Stoichiometry database
stoich <- 
  read_delim("data/primary/animal/body_stoichiometry/Global_heterotroph_stoichio_v5.csv") |> 
  filter(Group == "Microbe",
         !is.na(C_mean))

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

# estimated C fraction in fungi
plogis(fixef(mod)$cond)
