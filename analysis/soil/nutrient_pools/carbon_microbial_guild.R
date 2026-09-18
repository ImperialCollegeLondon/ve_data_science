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
# AM fungi don't have carbon value, so we assume it to have the average of
# EM and saprotroph
C_fraction_microbe <- c(
  C_fraction_microbe,
  AM = mean(C_fraction_microbe["EM"], C_fraction_microbe["saprotroph"])
)


# Calculation -------------------------------------------------------------

# first, split fungi into saprotroph, AM and EM
fungi_rel_abun <-
  as.data.frame(fungi_rel_abun) |>
  rownames_to_column("land_use") |>
  select(land_use, saprotroph, EM, AM) |>
  # re-normalise the relative abundance using these three groups only
  mutate(
    new_total = saprotroph + EM + AM,
    across(c(saprotroph, EM, AM), ~ .x / new_total)
  ) |>
  select(-new_total)

# convert abundance ratios of fungal guilds and bacteria to carbon ratios
microbe_ratio <-
  fungal_bacteria_ratio |>
  select(Plot_ID, Fungal, Bacteria) |>
  rename(bacteria = Bacteria) |>
  # assign land-use category: HLF and MLF are both logged forest (SL = selectively logged)
  mutate(land_use = ifelse(Plot_ID %in% c("HLF", "MLF"), "SL", Plot_ID)) |>
  # join the fungal guild relative abundances (saprotroph, EM, AM) by land_use
  left_join(fungi_rel_abun) |>
  # scale each guild's relative abundance by the total fungal abundance
  # to get absolute abundance relative to bacteria (= 1)
  # compute the new total of all microbial groups (bacteria + fungi)
  # re-normalise so that all four groups sum to 1 (i.e., relative biomass)
  mutate(
    across(c(saprotroph, EM, AM), ~ .x * Fungal),
    new_total = bacteria + saprotroph + EM + AM,
    across(c(saprotroph, EM, AM, bacteria), ~ .x / new_total),
  ) |>
  select(Plot_ID, land_use, saprotroph, EM, AM, bacteria) |>
  pivot_longer(
    cols = c(saprotroph, EM, AM, bacteria),
    names_to = "guild",
    values_to = "p_biomass"
  ) |>
  # join the carbon fraction per unit biomass for each guild
  left_join(
    C_fraction_microbe |> as.data.frame() |> rownames_to_column("guild")
  ) |>
  # convert relative biomass to relative carbon by multiplying by the
  # guild-specific carbon fraction
  mutate(p_carbon = p_biomass * C_fraction_microbe) |>
  # renormalise p_carbon within each plot so that the four guilds' carbon
  # contributions sum to 1 (i.e., relative carbon contribution)
  group_by(Plot_ID) |>
  mutate(p_carbon = p_carbon / sum(p_carbon))
