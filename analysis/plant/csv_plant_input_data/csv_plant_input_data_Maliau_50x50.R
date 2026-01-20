#| ---
#| title: CSV plant input data Maliau 50x50
#|
#| description: |
#|     This script generates the final versions of the CSV files that are used as
#|     the plant input data.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: plant_functional_type_cohort_distribution_Maliau_50x50.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains an overview of the individuals per
#|       DBH class for each PFT, for each cell.
#|   - name: plant_stoichiometry.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of stoichiometric ratios and lignin
#|       content for different biomass pools for each PFT.
#|  - name: t_model_parameters.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of updated T model parameters for each PFT.
#|  - name: reproductive_tissue_allocation.csv
#|     path: data/derived/plant/reproductive_tissue_allocation
#|     description: |
#|       This CSV file contains a summary of the ratios needed to calculate
#|       reproductive tissue allocation, and to separate propagules from non-
#|       propagules.
#|  - name: subcanopy_parameters.csv
#|     path: data/derived/plant/subcanopy
#|     description: |
#|       This CSV file contains the subcanopy parameters, which are part of the
#|       plant model constants.
#|
#| output_files:
#|   - name: plant_pft_definitions_Maliau_50x50.csv
#|     path: data/derived/plant/csv_plant_input_data
#|     description: |
#|       This CSV file contains the plant pft definitions for Maliau.
#|   - name: plant_cohort_data_Maliau_50x50.csv
#|     path: data/derived/plant/csv_plant_input_data
#|     description: |
#|       This CSV file contains the plant cohort distribution for Maliau.
#|   - name: plant_constants_Maliau_50x50.csv
#|     path: data/derived/plant/csv_plant_input_data
#|     description: |
#|       This CSV file contains the plant constants for Maliau.
#|
#| package_dependencies:
#|     - XX
#|
#| usage_notes: |
#|   This script prepares the final version of the plant input data for Maliau.
#| ---


# Load packages

library(tidyverse)

# Load the input data files

cohort_distribution <- read.csv(
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_Maliau_50x50.csv", # nolint
  header = TRUE
)

plant_stoichiometry <- read.csv(
  "../../../data/derived/plant/traits_data/plant_stoichiometry.csv",
  header = TRUE
)

t_model_parameters <- read.csv(
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  header = TRUE
)

reproductive_tissue_allocation <- read.csv(
  "../../../data/derived/plant/reproductive_tissue_allocation/reproductive_tissue_allocation.csv", # nolint
  header = TRUE
)

subcanopy_parameters <- read.csv(
  "../../../data/derived/plant/subcanopy/subcanopy_parameters.csv",
  header = TRUE
)

##########

# Prepare plant_pft_definitions_Maliau_50x50

# Start from t_model_parameters

plant_pft_definitions_Maliau_50x50 <- t_model_parameters # nolint

# Variables required:
# name OK
# a_hd OK
# ca_ratio OK
# h_max OK
# rho_s OK
# lai OK
# sla OK
# tau_f OK
# tau_rt OK
# tau_r OK
# par_ext OK
# yld OK
# zeta OK
# resp_r OK
# resp_rt OK
# resp_s OK
# resp_f OK

# m ADD default
# n ADD default
# f_g ADD default
# q_m ADD default
# z_max_prop ADD default
# gpp_topslice ADD default


# p_foliage_for_reproductive_tissue ADD from reproductive_tissue_allocation

# deadwood_c_n_ratio ADD from stoichiometry
# deadwood_c_p_ratio ADD from stoichiometry
# leaf_turnover_c_n_ratio ADD from stoichiometry
# leaf_turnover_c_p_ratio ADD from stoichiometry
# plant_reproductive_tissue_turnover_c_n_ratio ADD from stoichiometry
# plant_reproductive_tissue_turnover_c_p_ratio ADD from stoichiometry
# root_turnover_c_p_ratio ADD from stoichiometry
# root_turnover_c_n_ratio ADD from stoichiometry
# foliage_c_n_ratio ADD from stoichiometry
# foliage_c_p_ratio ADD from stoichiometry

# Add missing ones

# m
plant_pft_definitions_Maliau_50x50$m <- 2 # nolint
# n
plant_pft_definitions_Maliau_50x50$n <- 5 # nolint
# f_g
plant_pft_definitions_Maliau_50x50$f_g <- 0.02 # nolint
# gpp_topslice
plant_pft_definitions_Maliau_50x50$gpp_topslice <- 0.1 # nolint

# p_foliage_for_reproductive_tissue
# Use Kitayama et al., 2015 reference in Aoyagi et al., 2018 (row 10) in
# reproductive_tissue_allocation
plant_pft_definitions_Maliau_50x50$p_foliage_for_reproductive_tissue <- 0.073545706 # nolint

# deadwood_c_n_ratio
# deadwood_c_p_ratio
# leaf_turnover_c_n_ratio
# leaf_turnover_c_p_ratio
# plant_reproductive_tissue_turnover_c_n_ratio
# plant_reproductive_tissue_turnover_c_p_ratio
# root_turnover_c_n_ratio
# root_turnover_c_p_ratio
# foliage_c_n_ratio
# foliage_c_p_ratio
temp <- plant_stoichiometry[, c(
  "name",
  "deadwood_c_n_ratio",
  "deadwood_c_p_ratio",
  "leaf_turnover_c_n_ratio",
  "leaf_turnover_c_p_ratio",
  "plant_reproductive_tissue_turnover_c_n_ratio",
  "plant_reproductive_tissue_turnover_c_p_ratio",
  "root_turnover_c_n_ratio",
  "root_turnover_c_p_ratio",
  "foliage_c_n_ratio",
  "foliage_c_p_ratio"
)]

plant_pft_definitions_Maliau_50x50 <- # nolint
  left_join(plant_pft_definitions_Maliau_50x50, temp, by = "name")

# Write out summary of variable data types and units

# Write CSV file

write.csv(
  plant_pft_definitions_Maliau_50x50,
  "../../../data/derived/plant/csv_plant_input_data/plant_pft_definitions_Maliau_50x50.csv", # nolint
  row.names = FALSE
)

##########

# Prepare plant_constants_Maliau_50x50

# Start from subcanopy_parameters
plant_constants_Maliau_50x50 <- subcanopy_parameters

# Variables required:
# subcanopy_extinction_coef OK
# subcanopy_specific_leaf_area OK
# subcanopy_respiration_fraction OK
# subcanopy_yield OK
# subcanopy_reproductive_allocation OK
# subcanopy_sprout_rate OK
# subcanopy_sprout_yield OK
# subcanopy_vegetation_turnover OK
# subcanopy_seedbank_turnover OK
# subcanopy_seedbank_c_n_ratio OK
# subcanopy_seedbank_c_p_ratio OK
# subcanopy_vegetation_c_n_ratio OK
# subcanopy_vegetation_c_p_ratio OK
# subcanopy_vegetation_lignin OK
# subcanopy_seedbank_lignin OK

# per_stem_annual_mortality_probability ADD from t_model_parameters
# per_propagule_annual_recruitment_probability ADD from t_model_parameters
# dsr_to_ppfd ADD default
# stem_lignin ADD from plant_stoichiometry
# senesced_leaf_lignin ADD from plant_stoichiometry
# leaf_lignin ADD from plant_stoichiometry
# plant_reproductive_tissue_lignin ADD from plant_stoichiometry
# root_lignin ADD from plant_stoichiometry
# root_exudates ADD from t_model_parameters
# propagule_mass_portion ADD from reproductive_tissue_allocation
# carbon_mass_per_propagule ADD from plant_stoichiometry

# Add missing ones

# per_stem_annual_mortality_probability
plant_constants_Maliau_50x50$per_stem_annual_mortality_probability <-
  unique(t_model_parameters$per_stem_annual_mortality_probability)
# per_propagule_annual_recruitment_probability
plant_constants_Maliau_50x50$per_propagule_annual_recruitment_probability <-
  unique(t_model_parameters$per_propagule_annual_recruitment_probability)
# root_exudates
plant_constants_Maliau_50x50$root_exudates <-
  unique(t_model_parameters$root_exudates)

# dsr_to_ppfd
plant_constants_Maliau_50x50$dsr_to_ppfd <- 2.04

# stem_lignin
plant_constants_Maliau_50x50$stem_lignin <-
  unique(plant_stoichiometry$stem_lignin)
# senesced_leaf_lignin
plant_constants_Maliau_50x50$senesced_leaf_lignin <-
  unique(plant_stoichiometry$senesced_leaf_lignin[
    plant_stoichiometry$name == "emergent"
  ]) # Note that 1 value can only be assigned
# leaf_lignin
plant_constants_Maliau_50x50$leaf_lignin <-
  unique(plant_stoichiometry$leaf_lignin[
    plant_stoichiometry$name == "emergent"
  ]) # Note that 1 value can only be assigned
# plant_reproductive_tissue_lignin
plant_constants_Maliau_50x50$plant_reproductive_tissue_lignin <-
  unique(plant_stoichiometry$plant_reproductive_tissue_lignin)
# root_lignin
plant_constants_Maliau_50x50$root_lignin <-
  unique(plant_stoichiometry$root_lignin)

# propagule_mass_portion
# Use propagule live organ carbon percentage (row 19; based on live organ estimates
# in dipterocarp forest) from reproductive_tissue_allocation
plant_constants_Maliau_50x50$propagule_mass_portion <- 0.773915715

# carbon_mass_per_propagule
plant_constants_Maliau_50x50$carbon_mass_per_propagule <-
  unique(plant_stoichiometry$carbon_mass_per_propagule)

# Write out summary of variable data types and units

# Write CSV file

write.csv(
  plant_constants_Maliau_50x50,
  "../../../data/derived/plant/csv_plant_input_data/plant_constants_Maliau_50x50.csv",
  row.names = FALSE
)

##########

# Prepare plant_cohort_data_Maliau_50x50
# Note that the base cohort distribution is already prepared on a per hectare basis

# Start from cohort_distribution
plant_cohort_data_Maliau_50x50 <- cohort_distribution

# Write CSV file

write.csv(
  plant_cohort_data_Maliau_50x50,
  "../../../data/derived/plant/csv_plant_input_data/plant_cohort_data_Maliau_50x50.csv",
  row.names = FALSE
)
