#| ---
#| title: Calculate proportions of carbon by microbial pools
#|
#| description: |
#|     This R script takes outputs from
#|     1. analysis/soil/fungi_bacteria_ratio/model.R
#|     2. analysis/soil/fungi_guild_ratio/model_SAFE.R
#|     3. analysis/soil/stoichiometry/bacteria_fungi.R
#|     and combine them to calculate how soil microbial carbon (extracted
#|     from analysis/soil/nutrient_pools/carbon_microbial.R) should be split
#|     into bacteria, saprotrophic, AM and EM fungi.
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
#|   - name: fungal_bacteria_ratio.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       Fungal to bacterial ratio
#|   - name: fungi_rel_abun.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       Relative abundance of different fungal guilds
#|   - name: C_fraction_microbe.rds
#|     path: data/derived/soil/nutrient_pools
#|     description: |
#|       Carbon fraction per mass of microbes
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|
#| usage_notes: |
#|   To be used in the post-hoc prediction of Maliau scenario
#| ---

library(tidyverse)



# Derived quantities ------------------------------------------------------

# Fungal to bacteria ratio
fungal_bacteria_ratio <-
  read_rds("data/derived/soil/nutrient_pools/fungal_bacteria_ratio.rds")

# Fungal guild composition / relative abundance
fungi_rel_abun <-
  read_rds("data/derived/soil/nutrient_pools/fungi_rel_abun.rds")

# Fungal and bacterial carbon fraction
C_fraction_microbe <-
  read_rds("data/derived/soil/nutrient_pools/C_fraction_microbe.rds")


# Calculation -------------------------------------------------------------

# the goal is to convert abundance ratios of fungal guilds and bacteria to
# carbon ratios

# start with fungal to bacteria ratio
# set bacteria as baseline (=1)
microbe_ratio <- c(
  fungi = as.numeric(fungal_bacteria_ratio),
  bacteria = 1
)

# then split fungi into saprotroph, AM and EM
# re-normalise the relative abundance using these three groups only
fungi_rel_abun <- fungi_rel_abun[c("saprotroph", "EM", "AM")]
fungi_rel_abun <- fungi_rel_abun / sum(fungi_rel_abun)
microbe_ratio <- c(
  microbe_ratio["fungi"] * fungi_rel_abun,
  microbe_ratio["bacteria"]
)

# lastly convert biomass ratios to carbon ratios
microbe_ratio <-
  microbe_ratio * c(
    rep(C_fraction_microbe["fungi"], 3),
    C_fraction_microbe["bacteria"]
  )
# re-normalise again so the values sum to one
# this will be used to split total microbial carbon into each pool
microbe_ratio <- microbe_ratio / sum(microbe_ratio)
