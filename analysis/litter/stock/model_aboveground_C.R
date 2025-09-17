#| ---
#| title: Estimating aboveground metabolic and structural stocks from SAFE data
#|
#| description: |
#|     This R script estimates aboveground litter stocks from SAFE data.
#|     It combines a dataset that measure total aboveground litter stock and
#|     another dataset that measured *physical* litter composition to estimate
#|     litter stock per physical composition. After the litter pool was split
#|     into leaf, reproductive, wood and other, they will be reassinged to
#|     aboveground metabolic, aboveground structural and wood; Wood will be
#|     added to deadwood in another script later; Reproductive is assumed to be
#|     entirely aboveground metabolic; Other is assumed to be entirely
#|     aboveground structural; Leaf is the only physical component that needs
#|     to be further split into aboveground metabolic and structural --- we'll
#|     use leaf nutrient data to do this.
#|
#| virtual_ecosystem_module:
#|   - Litter
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: Ewers_LeafLitter.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Wet and dry weight of leaf litterfall at SAFE vegetation plots by
#|       Robert Ewers; downloaded from https://zenodo.org/records/1198587
#|   - name: SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Total and partitioned soil respiration and below-ground carbon budget
#|       in SAFE intensive carbon plots;
#|       downloaded from https://doi.org/10.5281/zenodo.4542881
#|   - name: Both_litter_decomposition_experiment.xlsx
#|     path: data/primary/litter/
#|     description: |
#|       Leaf litter decomposition in old-growth and selectively logged forest
#|       at SAFE; downloaded from https://doi.org/10.5281/zenodo.3247639
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|   If more data is needed for even more accurate parameterisation, consider
#|   Turner et al. (2019) https://zenodo.org/records/3265722
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

# Litter stock data by Riutta et al.
# https://zenodo.org/records/4542881
# This dataset pools leaves, reproductive parts, twigs < 2 cm diameter
# we will reassign them to aboveground metabolic and aboveground structural later

litter_stock <-
  # nolint start
  read_xlsx("data/primary/litter/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx",
    sheet = 4,
    skip = 5
  ) %>%
  # nolint end
  select(field_name:ForestPlotsCode, LitterStock) %>%
  # convert litter stock from Mg C / ha to kg C / m2
  mutate(LitterStock = LitterStock * 0.1)

# Litter composition data from litter traps by Ewers
# https://zenodo.org/records/1198587
# this is used to first split the litter pool into leaf, reproductive, wood and
# other;
# Wood will be added to deadwood in another script
# (analysis/litter/stock/model_deadwood_C.R) later;
# Reproductive is assumed to be entirely aboveground metabolic;
# Other is assumed to be entirely aboveground structural;
# Leaf is the only physical component that needs to be further split into
# aboveground metabolic and structural --- we'll use leaf nutrient data to do this

litter_compo <-
  read_xlsx("data/primary/litter/Ewers_LeafLitter.xlsx",
    sheet = 3,
    skip = 9
  ) %>%
  # use the first survey because only it has litter component weights
  filter(SurveyNum == 1) %>%
  # make sure weights are numeric
  mutate_at(vars(starts_with("WW") | starts_with("DW")), as.numeric) %>%
  mutate(
    # month of collection (in case there is phenological trend)
    # later: ok there were only four month (Apr - Jul) so I don't think it is
    # worth including as a covariate
    month = month(DateCollected),
    # calculate log number of day lapsed as offsets
    log_days = log(as.numeric(DateCollected - DateSet)),
    # pool leaf mass
    DW.leaf = DW.leaves.photo + DW.leaves.other,
    # pool reproductive mass
    DW.reproduction = DW.flower + DW.fruit + DW.seed
  ) %>%
  # convert to long format for modelling
  select(
    Plot, log_days, month,
    DW.leaf, DW.wood, DW.reproduction, DW.other
  ) %>%
  pivot_longer(
    cols = starts_with("DW"),
    names_to = "Type",
    names_prefix = "DW\\.",
    values_to = "DW"
  )

# Leaf litter nutrient data
# https://doi.org/10.5281/zenodo.3247639
# to split leaf litter into aboveground metabolic and structural
nutrient_leaf <-
  read_xlsx("data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 3,
    skip = 7
  ) %>%
  select(
    litter_type,
    C = C_perc,
    C.N,
    C.P,
    lignin = lignin_recalcitrants
  ) %>%
  mutate(
    C = C / 100,
    lignin = lignin / 100
  )



# Model -------------------------------------------------------------------

# Stock model
mod_stock <- glmmTMB(
  LitterStock ~ 1,
  family = lognormal,
  data = litter_stock
)

# Composition model
# ideally this is a Dirichlet component to model composition as a simplex
# but I will keep it simply here
mod_compo <- glmmTMB(
  DW ~ 0 + Type + (1 | Plot) + offset(log_days),
  dispformula = ~ 0 + Type,
  family = tweedie,
  data = litter_compo
)

# Leaf nutrient models
mod_lignin_leaf <-
  glmmTMB(
    lignin ~ 1,
    family = beta_family,
    data = nutrient_leaf
  )

mod_C_leaf <-
  glmmTMB(
    C ~ 1,
    family = beta_family,
    data = nutrient_leaf
  )

mod_CN_leaf <-
  glmmTMB(
    C.N ~ 1,
    family = lognormal,
    data = nutrient_leaf
  )

mod_CN_leaf <-
  glmmTMB(
    C.N ~ 1,
    family = lognormal,
    data = nutrient_leaf
  )

mod_CP_leaf <-
  glmmTMB(
    C.P ~ 1,
    family = lognormal,
    data = nutrient_leaf
  )




# Prediction --------------------------------------------------------------

# Our stock model only predicts total aboveground litter stock
# To split it into separate litter components, we will combine
# it with the litter composition model
# Ideally we would do this with simulated posterior to propagate
# parameter uncertain better but I will do it quick and dirty
# for now because the goal is a first pass to initiate VE

# leaf litter metabolic--structural fractions
# first we need the parameters estimated from the litter decay model
decay_params_df <- read_csv("data/derived/litter/turnover/decay_parameters.csv")
decay_params <- decay_params_df$value
names(decay_params) <- decay_params_df$Parameter

# leaf nutrient expected values
C_leaf <- plogis(fixef(mod_C_leaf)$cond)
CN_leaf <- exp(fixef(mod_CN_leaf)$cond)
CP_leaf <- exp(fixef(mod_CP_leaf)$cond)

# leaf lignin
L_leaf <- plogis(fixef(mod_lignin_leaf)$cond)
# convert leaf lignin to g C in lignin / g C in dry mass
# assuming 0.625 of lignin is carbon; see Arne's plant stoichiometry script
L_leaf <- (L_leaf * 0.625) / C_leaf

# leaf metabolic fraction
fm_leaf <-
  plogis(
    decay_params["logitfM"] -
      L_leaf * (decay_params["sN"] * CN_leaf + decay_params["sP"] * CP_leaf)
  )

# Expected litter composition in proportions
compo_hat <- exp(fixef(mod_compo)$cond)
compo_hat <- compo_hat / sum(compo_hat)

# split leaf into metabolic and structural
leaf_metabolic <- compo_hat["Typeleaf"] * fm_leaf
leaf_structural <- compo_hat["Typeleaf"] * (1 - fm_leaf)

# reassign above litter to metabolic, structural and wood
compo_pool <- c(
  leaf_metabolic + compo_hat["Typereproduction"],
  leaf_structural + compo_hat["Typeother"],
  compo_hat["Typewood"]
)
names(compo_pool) <- c("metabolic", "structural", "wood")

# Expected litter stock in kg C / m2
stock_hat <- exp(fixef(mod_stock)$cond)

# Expected litter stock by physical component in kg C / m2
aboveground_stock <-
  data.frame(
    type = names(compo_pool),
    stock = as.numeric(stock_hat * compo_pool)
  )
