#| ---
#| title: Estimating aboveground metabolic and structural stocks from SAFE data
#|
#| description: |
#|     This R script estimates aboveground litter stocks from SAFE data.
#|     It combines a dataset that measure total aboveground litter stock and
#|     another dataset that measured *physical* litter composition to estimate
#|     litter stock per physical composition. After the litter pool was split
#|     into leaf, reproductive, wood and other, they will be reassigned to
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
#|   - name: Fractal_point_nesting.xlsx
#|     path: data/primary/site/
#|     description: |
#|       SAFE plot type information including site, habitat, logging treatment,
#|       and plot nesting order; used to classify plots by logging group
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|   Oil palm ("deforested") land-use type does not have a final estimated
#|   stock at the moment; to be addressed when we do oil palm input data later.
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
  read_xlsx(
    "data/primary/litter/SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx",
    sheet = 4,
    skip = 5
  ) |>
  select(field_name:ForestPlotsCode, LitterStock) |>
  # convert litter stock from Mg C / ha to kg C / m2
  mutate(LitterStock = LitterStock * 0.1)

# SAFE plot type information
safe_plot_info <-
  read_xlsx(
    "data/primary/site/Fractal_point_nesting.xlsx",
    sheet = 3,
    skip = 5
  ) |>
  pivot_longer(
    cols = ends_with("Order"),
    names_to = "Order",
    values_to = "Plot"
  ) |>
  filter(!is.na(Plot), Plot != "NA") |>
  distinct(Site, Habitat, Logging, Order, Plot) |>
  # reclassify logging
  mutate(
    Logging_grp = replace_values(
      Logging,
      "LowIntensity" ~ "Logged",
      "Twice" ~ "Logged",
      "Variable" ~ "Logged"
    )
  )

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
  read_xlsx(
    "data/primary/litter/Ewers_LeafLitter.xlsx",
    sheet = 3,
    skip = 9
  ) |>
  # use the first survey because only it has litter component weights
  filter(SurveyNum == 1) |>
  # make sure weights are numeric
  mutate(across(starts_with("WW") | starts_with("DW"), readr::parse_double)) |>
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
  ) |>
  # convert to long format for modelling
  select(
    Plot,
    log_days,
    month,
    DW.leaf,
    DW.wood,
    DW.reproduction,
    DW.other
  ) |>
  pivot_longer(
    cols = starts_with("DW"),
    names_to = "Type",
    names_prefix = "DW\\.",
    values_to = "DW"
  ) |>
  # join SAFE plot type
  left_join(safe_plot_info |> select(Plot, Logging_grp))

# Leaf litter nutrient data
# https://doi.org/10.5281/zenodo.3247639
# to split leaf litter into aboveground metabolic and structural
nutrient_leaf <-
  read_xlsx(
    "data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 3,
    skip = 7
  ) |>
  select(
    litter_type,
    C = C_perc,
    C.N,
    C.P,
    lignin = lignin_recalcitrants
  ) |>
  mutate(
    C = C / 100,
    lignin = lignin / 100
  )


# Model -------------------------------------------------------------------

# Stock model
mod_stock <- glmmTMB(
  LitterStock ~ 0 + ForestType,
  family = lognormal,
  data = litter_stock
)

# Composition model
# ideally this is a Dirichlet component to model composition as a simplex
# but I will keep it simply here
mod_compo <- glmmTMB(
  DW ~ 0 + Type * Logging_grp + (1 | Plot) + offset(log_days),
  dispformula = ~ 0 + Type,
  family = tweedie,
  data = litter_compo
)

# Leaf nutrient models
mod_lignin_leaf <-
  glmmTMB(lignin ~ 1, family = beta_family, data = nutrient_leaf)

mod_C_leaf <-
  glmmTMB(C ~ 1, family = beta_family, data = nutrient_leaf)

mod_CN_leaf <-
  glmmTMB(C.N ~ 1, family = lognormal, data = nutrient_leaf)

mod_CN_leaf <-
  glmmTMB(C.N ~ 1, family = lognormal, data = nutrient_leaf)

mod_CP_leaf <-
  glmmTMB(C.P ~ 1, family = lognormal, data = nutrient_leaf)


# Prediction --------------------------------------------------------------

# Our stock model only predicts total aboveground litter stock
# To split it into separate litter components, we will combine
# it with the litter composition model
# Ideally we would do this with simulated posterior to propagate
# parameter uncertain better but I will do it quick and dirty
# for now because the goal is a first pass to initiate VE

# leaf litter metabolic--structural fractions
# first we need the parameters estimated from the litter decay model
decay_params <-
  read_csv("data/derived/litter/turnover/decay_parameters.csv") |>
  pull(value, name = Parameter)

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

# Expected litter stock in kg C / m2
stock_hat <-
  data.frame(stock = exp(fixef(mod_stock)$cond)) |>
  rownames_to_column("Forest") |>
  mutate(
    Forest = str_remove(Forest, "ForestType"),
    Logging_grp = replace_values(
      Forest,
      "Logged" ~ "Logged",
      "Old-growth" ~ "Never"
    )
  )

# predict litter biomass composition
new_dat_compo <-
  litter_compo |>
  distinct(Type, Logging_grp) |>
  mutate(Plot = NA, log_days = 0)
pred_compo <- predict(mod_compo, newdata = new_dat_compo, type = "response")

# start calculating aboveground carbon in metabolic, structural and wood pools
aboveground_stock <-
  bind_cols(new_dat_compo, Estimate = pred_compo) |>
  # convert litter biomass composition to proportion biomass
  group_by(Logging_grp) |>
  mutate(p = Estimate / sum(Estimate)) |>
  ungroup() |>
  select(Type, Logging_grp, p) |>
  pivot_wider(names_from = Type, values_from = p) |>
  # split leaf into metabolic and structural
  mutate(
    leaf_metabolic = leaf * fm_leaf,
    leaf_structural = leaf * (1 - fm_leaf)
  ) |>
  # calculate metabolic, structural and wood pools
  mutate(
    metabolic = leaf_metabolic + reproduction,
    structural = leaf_structural + other
  ) |>
  select(Logging_grp, metabolic, structural, wood) |>
  pivot_longer(
    cols = c(metabolic, structural, wood),
    names_to = "type",
    values_to = "p"
  ) |>
  # join litter stock predictions
  left_join(stock_hat |> select(stock, Logging_grp)) |>
  # calculate expected litter stock by physical component in kg C / m2
  mutate(stock = stock * p)
