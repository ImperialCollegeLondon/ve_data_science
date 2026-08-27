#| ---
#| title: stoichiometry_maliau
#|
#| description: |
#|     This script focuses on collecting stoichiometric ratios and lignin content
#|     for each of the biomass pools in the plant model: leaves, sapwood, roots
#|     and reproductive tissue, which consists of propagules (fruits/seeds) and
#|     non-propagules (flowers).
#|     The script works with multiple datasets and calculates the ratios at PFT
#|     level where possible. Species are linked to their PFT using the output of
#|     the PFT classification script in the plant input data library workflow.
#|     If PFT-specific values are not available, values for tropical rain forests
#|     in Sabah are used.
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
#|   - name: pfts_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file containing the plant functional type classification for taxa
#|       in the tree census. The file includes taxa_name and pft_name columns
#|       linking each taxon to its assigned plant functional type (PFT).
#|   - name: inagawa_nutrients_wood_density.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.8158811
#|       Nutrients and wood density in coarse root, trunk and branches in
#|       Bornean tree species.
#|   - name: both_tree_functional_traits.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.3247631
#|       Functional traits of tree species in old-growth and selectively
#|       logged forest.
#|   - name: kitayama_2015_element_concentrations_of_litter_fractions.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.1111/1365-2745.12379
#|       Element concentrations of litter fractions.
#|
#| output_files:
#|   - name: stoichiometry_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains PFT-level stoichiometric ratios and lignin
#|       fractions for plant biomass pools, including sapwood, foliage,
#|       senesced leaves, reproductive tissue, fruits, flowers, and fine roots.
#|       Where PFT-specific measurements are unavailable, literature-derived
#|       proxy values are used.
#|     variables:
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "pfts_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           PFT names are inherited from pfts_maliau.csv and identify the plant
#|           functional type associated with each output record.
#|       - name: deadwood_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for sapwood / deadwood tissue.
#|         references:
#|           - citation: "Inagawa et al. (2023)"
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Calculated from sapwood nutrient concentrations and averaged across the limited species sample rather than by PFT."
#|       - name: deadwood_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for sapwood / deadwood tissue.
#|         references:
#|           - citation: "Inagawa et al. (2023)"
#|             doi: "https://doi.org/10.5281/zenodo.8158811"
#|             url: "https://zenodo.org/records/8158811"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Calculated from sapwood nutrient concentrations and averaged across the limited species sample rather than by PFT."
#|       - name: stem_lignin
#|         type: numeric
#|         units: g lignin C g^-1 stem C
#|         description: |
#|           Fraction of stem carbon mass present as lignin.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
#|             origin: null
#|             biome: null
#|             vegetation_type: "deciduous broadleaf forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Muddasar et al. (2024)"
#|             doi: "https://doi.org/10.1016/j.mtsust.2024.100990"
#|             url: "https://www.sciencedirect.com/science/article/pii/S2589234724003269"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived by combining literature lignin fraction with mean sapwood carbon content from the SAFE wood nutrient dataset."
#|       - name: foliage_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for foliage.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Calculated from leaf trait measurements and aggregated to PFT using species-to-PFT matching, with genus-level matching where species-level matching is unavailable."
#|       - name: foliage_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for foliage.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Calculated from leaf trait measurements and aggregated to PFT using species-to-PFT matching, with genus-level matching where species-level matching is unavailable."
#|       - name: leaf_lignin
#|         type: numeric
#|         units: g lignin C g^-1 leaf C
#|         description: |
#|           Fraction of leaf carbon mass present as lignin.
#|         references:
#|           - citation: "Muddasar et al. (2024)"
#|             doi: "https://doi.org/10.1016/j.mtsust.2024.100990"
#|             url: "https://www.sciencedirect.com/science/article/pii/S2589234724003269"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project and Danum Valley Conservation Area, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2014-2018"
#|         assumptions: |
#|           Leaf lignin measurements are taken from the functional-traits
#|           dataset and converted from a dry-mass basis to a carbon-mass basis
#|           using the lignin carbon-content value reported by Muddasar et al.
#|           (2024).
#|       - name: leaf_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for senesced leaf turnover material.
#|         references:
#|           - citation: "Han et al. (2013)"
#|             doi: "https://doi.org/10.1371/journal.pone.0083366"
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: "evergreen broadleaf forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from foliage C:N using a fixed nitrogen resorption efficiency rather than direct senesced leaf measurements."
#|       - name: leaf_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for senesced leaf turnover material.
#|         references:
#|           - citation: "Han et al. (2013)"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: "evergreen broadleaf forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from foliage C:P using a fixed phosphorus resorption efficiency rather than direct senesced leaf measurements."
#|       - name: senesced_leaf_lignin
#|         type: numeric
#|         units: g lignin C g^-1 senesced leaf C
#|         description: |
#|           Fraction of senesced leaf carbon mass present as lignin.
#|         references:
#|           - citation: "Both et al. (2019)"
#|             doi: "https://doi.org/10.5281/zenodo.3247631"
#|             url: "https://zenodo.org/records/3247631"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Assumed equal to live foliage lignin because senesced leaf-specific lignin data were not separately derived."
#|       - name: plant_reproductive_tissue_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for reproductive tissue turnover.
#|         references:
#|           - citation: "Kitayama et al. (2015)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: "Mount Kinabalu, Borneo"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Based on combined reproductive-organ litter fractions from selected Kitayama sites, so flowers, fruits and seeds are not separated."
#|       - name: plant_reproductive_tissue_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for reproductive tissue turnover.
#|         references:
#|           - citation: "Kitayama et al. (2015)"
#|             doi: "https://doi.org/10.1111/1365-2745.12379"
#|             url: "https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2745.12379"
#|             origin: "Mount Kinabalu, Borneo"
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Based on combined reproductive-organ litter fractions from selected Kitayama sites, so flowers, fruits and seeds are not separated."
#|       - name: mature_fruit_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for mature fruit tissue.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from mature fruit values for Dipterocarpus tempehes and used as a proxy for propagule tissue."
#|       - name: mature_fruit_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for mature fruit tissue.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from mature fruit values for Dipterocarpus tempehes and used as a proxy for propagule tissue."
#|       - name: mature_fruit_c_mass
#|         type: numeric
#|         units: g C
#|         description: |
#|           Carbon mass per mature fruit.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Calculated from mature fruit dry mass and carbon percentage for Dipterocarpus tempehes."
#|       - name: carbon_mass_per_propagule
#|         type: numeric
#|         units: g C
#|         description: |
#|           Carbon mass per propagule, represented here by seed carbon mass.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1079/SSR2004181"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived using seed dry mass from Nakagawa and Nakashizuka with fruit carbon concentration from Ichie as a proxy for seed carbon concentration."
#|       - name: plant_reproductive_tissue_lignin
#|         type: numeric
#|         units: g lignin C g^-1 reproductive tissue C
#|         description: |
#|           Fraction of reproductive tissue carbon mass present as lignin.
#|         references:
#|           - citation: "Nakagawa and Nakashizuka (2004)"
#|             doi: "https://doi.org/10.1079/SSR2004181"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|           - citation: "Muddasar et al. (2024)"
#|             doi: "https://doi.org/10.1016/j.mtsust.2024.100990"
#|             url: "https://www.sciencedirect.com/science/article/pii/S2589234724003269"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Estimated from seed lignin and carbon content, so it serves as a propagule-based proxy for broader reproductive tissue lignin."
#|       - name: flower_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for flower tissue.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Calculated as the mean across several flower developmental stages for Dipterocarpus tempehes."
#|       - name: flower_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for flower tissue.
#|         references:
#|           - citation: "Ichie et al. (2005)"
#|             doi: "https://doi.org/10.1017/S0266467404002214"
#|             url: null
#|             origin: null
#|             biome: "tropical"
#|             vegetation_type: "dipterocarp forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Calculated as the mean across several flower developmental stages for Dipterocarpus tempehes."
#|       - name: root_turnover_c_n_ratio
#|         type: numeric
#|         units: g C g^-1 N
#|         description: |
#|           Carbon-to-nitrogen ratio for fine root turnover material.
#|         references:
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: null
#|             origin: "Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Used directly from fine-root stoichiometry values rather than derived separately for turnover material."
#|       - name: root_turnover_c_p_ratio
#|         type: numeric
#|         units: g C g^-1 P
#|         description: |
#|           Carbon-to-phosphorus ratio for fine root turnover material.
#|         references:
#|           - citation: "Imai et al. (2010)"
#|             doi: "https://doi.org/10.1017/S0266467410000350"
#|             url: null
#|             origin: "Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "mixed dipterocarp lowland tropical rain forest"
#|             site_condition: null
#|             date: null
#|         assumptions: "Used directly from fine-root stoichiometry values rather than derived separately for turnover material."
#|       - name: root_lignin
#|         type: numeric
#|         units: g lignin C g^-1 root C
#|         description: |
#|           Fraction of fine root carbon mass present as lignin.
#|         references:
#|           - citation: "White et al. (2000)"
#|             doi: "https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2"
#|             url: "https://journals.ametsoc.org/view/journals/eint/4/3/1087-3562_2000_004_0003_pasaot_2.0.co_2.xml"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|           - citation: "Muddasar et al. (2024)"
#|             doi: "https://doi.org/10.1016/j.mtsust.2024.100990"
#|             url: "https://www.sciencedirect.com/science/article/pii/S2589234724003269"
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: "Derived from a global mean fine-root lignin fraction combined with fine-root carbon content from Imai et al. rather than from site-specific lignin measurements."
#|
#| package_dependencies:
#|   - readxl
#|   - dplyr
#|   - ggplot2
#|   - stringr
#|
#| usage_notes: |
#|   Run from this script's directory because input and output paths are
#|   relative. The output contains PFT-level stoichiometric ratios and lignin
#|   parameters derived from multiple datasets. Where PFT-specific observations
#|   are unavailable, literature values or proxy relationships are used.
#| ---

# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(stringr)

# Load PFT classification and clean up a bit

PFT_species_classification_base <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pfts_maliau.csv",
  header = TRUE
)

PFT_species_classification_base <- PFT_species_classification_base[,
  c("pft_name", "taxa_name")
]
PFT_species_classification_base <- unique(PFT_species_classification_base)

data_taxa <- PFT_species_classification_base

################################################################################

# Stem stoichiometry

# Load wood nutrients data and clean up a bit

inagawa_nutrients_wood_density <- read_excel(
  "../../../../data/primary/plant/traits_data/inagawa_nutrients_wood_density.xlsx",
  sheet = "Nutrients",
  col_names = FALSE
)

data <- inagawa_nutrients_wood_density

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:427, ]
names(data)

data <- data[, c("Species", "TissueType", "C_total", "N_total", "P_total")]
colnames(data) <- c("species", "TissueType", "C_total", "N_total", "P_total")

data$C_total <- as.numeric(data$C_total)
data$N_total <- as.numeric(data$N_total)
data$P_total <- as.numeric(data$P_total)

data$P_total <- data$P_total * 0.1
# Convert to % in order to match unit of C_total and N_total

data[data$P_total == 0, ]
data <- data[data$P_total != 0, ]
# If not removed ratio is problematic (cannot divide by zero)

data$CN <- data$C_total / data$N_total
data$CP <- data$C_total / data$P_total

##########

# Because we only have 10 unique species, we'll use the mean across species

# Mean sapwood stoichiometry
# (other tissues: "Bark" "Sapwood" "Heartwood" "Wood" "WoodAndBark")

temp <- data[, c("species", "TissueType", "CN", "CP")]
temp <- temp[temp$TissueType == "Sapwood", ]

temp <- temp %>%
  group_by(species) %>%
  mutate(CN_sapwood = mean(as.numeric(CN), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(CP_sapwood = mean(as.numeric(CP), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "TissueType", "CN_sapwood", "CP_sapwood")]
temp <- unique(temp)

mean(temp$CN_sapwood)
sd(temp$CN_sapwood)
mean(temp$CP_sapwood)
sd(temp$CP_sapwood)

data$CN_mean[data$TissueType == "Sapwood"] <- mean(temp$CN_sapwood)
data$CN_mean_SD[data$TissueType == "Sapwood"] <- sd(temp$CN_sapwood)
data$CP_mean[data$TissueType == "Sapwood"] <- mean(temp$CP_sapwood)
data$CP_mean_SD[data$TissueType == "Sapwood"] <- sd(temp$CP_sapwood)

# Can repeat code above for additional tissues

# Create summary file, based on data_taxa and add stoichiometric ratios to it

summary <- data_taxa

# Write stem stoichiometric ratios to summary

summary$CN_sapwood_mean <- NA
summary$CN_sapwood_mean_SD <- NA
summary$CP_sapwood_mean <- NA
summary$CP_sapwood_mean_SD <- NA

summary$CN_sapwood_mean <-
  round(unique(data$CN_mean[data$TissueType == "Sapwood"]), 2)
summary$CN_sapwood_mean_SD <-
  round(unique(data$CN_mean_SD[data$TissueType == "Sapwood"]), 2)
summary$CP_sapwood_mean <-
  round(unique(data$CP_mean[data$TissueType == "Sapwood"]), 2)
summary$CP_sapwood_mean_SD <-
  round(unique(data$CP_mean_SD[data$TissueType == "Sapwood"]), 2)

# Stem lignin content (expressed as a fraction of stem carbon mass)

# According to White et al., 2000
# (https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)
# the mean stem (dead wood) lignin content is 23% for deciduous broadleaf forest

stem_lignin_percentage <- 23

# Still need to correct it to go from dry weight to carbon mass
# We'll use the mean sapwood carbon content (45.9%) across PFTs
mean(data$C_total[data$TissueType == "Sapwood"])
# We'll also use 62.5% carbon content of lignin (Muddasar et al., 2024)

stem_lignin_C_percentage <- stem_lignin_percentage * 0.625
stem_lignin_C_of_stem_C <- stem_lignin_C_percentage / 45.9

# Add to summary

summary$stem_lignin <- stem_lignin_C_of_stem_C

################################################################################

# Leaf stoichiometry and lignin content

# Note that the model separates "normal" leaves and "senesced" leaves
# Here we first focus on the normal leaves (ak foliage), then we calculate
# stoichiometry for senesced leaves. For lignin content values are the same.

both_tree_functional_traits <- read_excel(
  "../../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

data <- both_tree_functional_traits

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:724, ]
names(data)

# Replace "." by a space in the species name

data <- data %>%
  mutate(species = str_replace_all(species, fixed("."), " "))

# Seperate genus from species into its own column

data <- data %>%
  mutate(genus = word(species, 1))

data <- data[, c(1:9, 86, 10:85)]

##########

names(data)

temp <- data[,
  c(
    "species",
    "C_perc",
    "N_perc",
    "total_P_mg.g",
    "lignin_recalcitrants_perc",
    "dry_weight_g_mean"
  )
]

colnames(temp) <- c(
  "species",
  "C_total",
  "N_total",
  "P_total",
  "lignin",
  "dry_weight"
)

temp$C_total <- as.numeric(temp$C_total)
temp$N_total <- as.numeric(temp$N_total)
temp$P_total <- as.numeric(temp$P_total)
temp$lignin <- as.numeric(temp$lignin)
temp$dry_weight <- as.numeric(temp$dry_weight)

# Convert to % in order to match unit of C_total and N_total
temp$P_total <- temp$P_total * 0.1

###

# Convert leaf lignin content from dry weight basis to carbon basis
# According to Muddasar et al., 2024 (https://doi.org/10.1016/j.mtsust.2024.100990)
# lignin has 60-65% carbon content (average = 62.5%)
# So, first convert lignin content from dry weight to carbon weight
# Then calculate lignin carbon mass using 62.5% lignin carbon content

temp$lignin_g <- (temp$lignin / 100) * temp$dry_weight
temp$lignin_C_g <- temp$lignin_g * 0.625
temp$leaf_C_g <- (temp$C_total / 100) * temp$dry_weight
temp$lignin_C_of_leaf_C <- temp$lignin_C_g / temp$leaf_C_g

# Use lignin_C_of_leaf_C as the new lignin content (expressed as fraction of
# leaf carbon mass)
temp$lignin <- temp$lignin_C_of_leaf_C
temp <- temp[, c(1:5)]

###

temp <- na.omit(temp)

temp$CN_leaf <- temp$C_total / temp$N_total
temp$CP_leaf <- temp$C_total / temp$P_total

# Mean leaf stoichiometry and lignin content

temp <- temp %>%
  group_by(species) %>%
  mutate(CN_leaf_mean = mean(as.numeric(CN_leaf), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(CP_leaf_mean = mean(as.numeric(CP_leaf), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(lignin_leaf_mean = mean(as.numeric(lignin), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "CN_leaf_mean", "CP_leaf_mean", "lignin_leaf_mean")]
temp <- unique(temp)

data$CN_leaf_mean <- NA
data$CP_leaf_mean <- NA
data$lignin_leaf_mean <- NA

leaf_ratios <- unique(temp$species)

for (id in leaf_ratios) {
  data$CN_leaf_mean[data$species == id] <- temp$CN_leaf_mean[temp$species == id]
  data$CP_leaf_mean[data$species == id] <- temp$CP_leaf_mean[temp$species == id]
  data$lignin_leaf_mean[data$species == id] <- temp$lignin_leaf_mean[
    temp$species == id
  ]
}

# Because the ratios are calculated for each species, this allows calculation of
# mean PFT values using the PFT species classification

mean(temp$CN_leaf_mean)
mean(temp$CP_leaf_mean)
mean(temp$lignin_leaf_mean)

##########

# Link leaf stoichiometry dataset to base PFT species classification

# Match by species first
data1 <- left_join(
  data,
  PFT_species_classification_base,
  by = c("species" = "taxa_name")
)

# Match by genus only for rows where PFT is still NA
data2 <- left_join(
  data,
  PFT_species_classification_base,
  by = c("genus" = "taxa_name")
)

# Combine: take PFT and PFT_name from species match if available,
# otherwise from genus match
data$pft_name <- ifelse(!is.na(data1$pft_name), data1$pft_name, data2$pft_name)

##########

# Calculate PFT leaf stoichiometry

names(data)

plot_data <- data[, c(
  "location",
  "forest_type",
  "sample_code",
  "pft_name",
  "species",
  "CN_leaf_mean",
  "CP_leaf_mean",
  "lignin_leaf_mean"
)]

plot_data <- na.omit(plot_data)
unique(plot_data$pft_name)

plot_data$forest_type <- as.factor(plot_data$forest_type)

# CN_leaf_mean

ggplot(
  plot_data,
  aes(
    x = sample_code,
    y = CN_leaf_mean,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "CN_leaf_mean") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = CN_leaf_mean,
    color = as.factor(forest_type)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "CN_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(pft_name) %>%
  summarise(
    Mean_CN_leaf_mean = mean(CN_leaf_mean, na.rm = TRUE),
    SD_CN_leaf_mean = sd(CN_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Note: mean across all species was 26.06

# Write to summary

summary$CN_leaf_mean <- NA
summary$CN_leaf_mean_SD <- NA

summary$CN_leaf_mean[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$pft_name == "understory"] <-
  round(summary_stats[4, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$pft_name == "understory"] <-
  round(summary_stats[4, "SD_CN_leaf_mean"], 2)

# CP_leaf_mean

ggplot(
  plot_data,
  aes(
    x = sample_code,
    y = CP_leaf_mean,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "CP_leaf_mean") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = CP_leaf_mean,
    color = as.factor(forest_type)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "CP_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(pft_name) %>%
  summarise(
    Mean_CP_leaf_mean = mean(CP_leaf_mean, na.rm = TRUE),
    SD_CP_leaf_mean = sd(CP_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Note: mean across all species was 506.15

# Write to summary

summary$CP_leaf_mean <- NA
summary$CP_leaf_mean_SD <- NA

summary$CP_leaf_mean[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$pft_name == "understory"] <-
  round(summary_stats[4, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$pft_name == "understory"] <-
  round(summary_stats[4, "SD_CP_leaf_mean"], 2)

# lignin_leaf_mean

ggplot(
  plot_data,
  aes(
    x = sample_code,
    y = lignin_leaf_mean,
    color = as.factor(pft_name)
  )
) +
  geom_point() +
  labs(x = "Individual", y = "lignin_leaf_mean") +
  theme_minimal()

ggplot(
  plot_data,
  aes(
    x = as.factor(pft_name),
    y = lignin_leaf_mean,
    color = as.factor(forest_type)
  )
) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "lignin_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(pft_name) %>%
  summarise(
    Mean_lignin_leaf_mean = mean(lignin_leaf_mean, na.rm = TRUE),
    SD_lignin_leaf_mean = sd(lignin_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Mean across all species was 25.08

# Write to summary

summary$lignin_leaf_mean <- NA
summary$lignin_leaf_mean_SD <- NA

summary$lignin_leaf_mean[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$pft_name == "emergent"] <-
  round(summary_stats[1, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$pft_name == "overstory"] <-
  round(summary_stats[2, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$pft_name == "pioneer"] <-
  round(summary_stats[3, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$pft_name == "understory"] <-
  round(summary_stats[4, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$pft_name == "understory"] <-
  round(summary_stats[4, "SD_lignin_leaf_mean"], 2)

# Now calculate stoichiometry for senesced leaves, using the nutrient resorption
# efficiency for N (50.1%) and P (56.5%) in evergreen broadleaf forest,
# as presented in Han et al. (2013; https://doi.org/10.1371/journal.pone.0083366)

N_resorption_efficiency <- 50.1 / 100
P_resorption_efficiency <- 56.5 / 100

# Now add two new variables to summary and derive senesced CN and CP ratio

summary$CN_senesced_leaf_mean <-
  as.numeric(summary$CN_leaf_mean) / (1 - N_resorption_efficiency)

summary$CP_senesced_leaf_mean <-
  as.numeric(summary$CP_leaf_mean) / (1 - P_resorption_efficiency)

# Also add in senesced leaf ligin, but use the same value as for foliage

summary$lignin_senesced_leaf_mean <-
  summary$lignin_leaf_mean

################################################################################

# Propagule reproductive tissue stoichiometry (fruits and seeds)

# The first approach is to use the data from Kitayama et al., 2015
# Here they provide element concentrations for fruits/flowers combined
# for a range of forests on Mount Kinabalu, Borneo

kitayama_litter_stoichiometry <- read_excel(
  "../../../../data/primary/plant/traits_data/kitayama_2015_element_concentrations_of_litter_fractions.xlsx",
  sheet = "Sheet1",
  col_names = FALSE
)

colnames(kitayama_litter_stoichiometry) <- kitayama_litter_stoichiometry[2, ]

kitayama_litter_stoichiometry_C <- kitayama_litter_stoichiometry[
  c(28:36),
  c(1, 2, 3)
]
colnames(kitayama_litter_stoichiometry_C) <- c(
  "site",
  "leaf_C",
  "reproductive_organ_C"
)
kitayama_litter_stoichiometry_N <- kitayama_litter_stoichiometry[
  c(15:23),
  c(1, 2, 3)
]
colnames(kitayama_litter_stoichiometry_N) <- c(
  "site",
  "leaf_N",
  "reproductive_organ_N"
)
kitayama_litter_stoichiometry_P <- kitayama_litter_stoichiometry[
  c(3:11),
  c(1, 2, 3)
]
colnames(kitayama_litter_stoichiometry_P) <- c(
  "site",
  "leaf_P",
  "reproductive_organ_P"
)

# Merge together

kitayama_litter_stoichiometry <- kitayama_litter_stoichiometry_C %>%
  left_join(kitayama_litter_stoichiometry_N, by = "site") %>%
  left_join(kitayama_litter_stoichiometry_P, by = "site")

kitayama_litter_stoichiometry$leaf_C <-
  as.numeric(kitayama_litter_stoichiometry$leaf_C)
kitayama_litter_stoichiometry$reproductive_organ_C <-
  as.numeric(kitayama_litter_stoichiometry$reproductive_organ_C)
kitayama_litter_stoichiometry$leaf_N <-
  as.numeric(kitayama_litter_stoichiometry$leaf_N)
kitayama_litter_stoichiometry$reproductive_organ_N <-
  as.numeric(kitayama_litter_stoichiometry$reproductive_organ_N)
kitayama_litter_stoichiometry$leaf_P <-
  as.numeric(kitayama_litter_stoichiometry$leaf_P)
kitayama_litter_stoichiometry$reproductive_organ_P <-
  as.numeric(kitayama_litter_stoichiometry$reproductive_organ_P)

# Calculate stoichiometric ratios
# Note that leaf stoichiometry is also calculated here, so that it can be
# compared with our other measure of leaf stoichiometry

kitayama_litter_stoichiometry$reproductive_organ_CN <-
  kitayama_litter_stoichiometry$reproductive_organ_C /
  kitayama_litter_stoichiometry$reproductive_organ_N
kitayama_litter_stoichiometry$reproductive_organ_CP <-
  kitayama_litter_stoichiometry$reproductive_organ_C /
  kitayama_litter_stoichiometry$reproductive_organ_P

kitayama_litter_stoichiometry$leaf_CN <-
  kitayama_litter_stoichiometry$leaf_C / kitayama_litter_stoichiometry$leaf_N
kitayama_litter_stoichiometry$leaf_CP <-
  kitayama_litter_stoichiometry$leaf_C / kitayama_litter_stoichiometry$leaf_P

# Note that values for leaf stoichiometry are higher than our PFT specific ratios,
# particularly for CP. This suggests lower nitrogen and phosphorus for the same
# amount of carbon. Keep this in mind when comparing with Ichie's approach below.

# Here is where we'd need to make a choice on which plots to use from Kitayama
# They have sedimentary sites (S-XX), ultrabasic sites (U-XX)
# and quaternary sedimentary sites (Q-XX)
# The number (XX) stands for the plot elevation (i.e., altitude; m)

# Overall mean
mean(kitayama_litter_stoichiometry$reproductive_organ_CN)
mean(kitayama_litter_stoichiometry$reproductive_organ_CP)

# Below I take the average of "hill dipterocarp rain forest", "lower montane
# rain forest" and "upper montane rain forest", both on the sedimentary and
# ultrabasic sites

mean(
  kitayama_litter_stoichiometry$reproductive_organ_CN[
    kitayama_litter_stoichiometry$site %in%
      c("S-700", "S-1700", "S-2700", "U-700", "U-1700", "U-2700")
  ]
)
mean(
  kitayama_litter_stoichiometry$reproductive_organ_CP[
    kitayama_litter_stoichiometry$site %in%
      c("S-700", "S-1700", "S-2700", "U-700", "U-1700", "U-2700")
  ]
)

# Add to summary

summary$reproductive_organ_CN <-
  mean(
    kitayama_litter_stoichiometry$reproductive_organ_CN[
      kitayama_litter_stoichiometry$site %in%
        c("S-700", "S-1700", "S-2700", "U-700", "U-1700", "U-2700")
    ]
  )
summary$reproductive_organ_CP <-
  mean(
    kitayama_litter_stoichiometry$reproductive_organ_CP[
      kitayama_litter_stoichiometry$site %in%
        c("S-700", "S-1700", "S-2700", "U-700", "U-1700", "U-2700")
    ]
  )

# Note that here reproductive organs includes everything (so flowers, fruits,
# seeds, etc.).
# Also note that this approach provides averages across different types of forest,
# albeit on distinct soils.

###

# The second approach is to use the data from Ichie et al., 2005

# The Ichie paper does not have supplementary information, so I extract the data
# manually from the paper (DOI: https://doi.org/10.1017/S0266467404002214)
# The paper focuses on one species (Dipterocarpus tempehes) and has detailed
# info on mass, number and stoichiometry for different developmental stages of
# reproductive tissues. The advantage here is that they separate fruits and flowers
# To calculate fruit stoichiometric ratios, the values for mature fruit are used

mature_fruit_C_percentage <- 50.62 # mean with SD of 0.44
mature_fruit_N_percentage <- 0.79 # mean with SD of 0.14
mature_fruit_P_percentage <- 0.61 # mean with SD of 0.11

mature_fruit_CN <- mature_fruit_C_percentage / mature_fruit_N_percentage
mature_fruit_CP <- mature_fruit_C_percentage / mature_fruit_P_percentage

# Note that the CP ratio here is much lower than the one by Kitayama

# Add to summary

summary$mature_fruit_CN <- mature_fruit_CN
summary$mature_fruit_CP <- mature_fruit_CP

###

# Thoughts on both approaches:
# There seems to be quite a large difference in the CP ratio between the two
# approaches, and I'm not sure which one is the best
# Also, when comparing Kitayama values for leaf stoichiometry with our PFT values,
# Kitayama values appear to be quite a bit higher (so less nutrients per carbon)
# The one based on Kitayama is more general (i.e., different species and sites)
# but is less detailed than the one based on Ichie with regards to different
# tissue types

# Worth noting is that Kitayama's data has measurements for litterfall of
# both leaf and reproductive tissues, so this could be used to define the ratio
# between foliage mass and reproductive tissue mass (see SI for carbon mass)
# Because of this, it may be better to choose Kitayama derived stoichiometric
# values for reproductive tissue (and not use the ones derived from Ichie)

# Note that when using the ratio derived from Kitayama's data we do not have
# different ratios for propagule and non-propagules, which is not ideal

# Note that we'll likely use Ichie to determine the ratio between non-propagule
# and propagule mass

# Add mature fruit and seed carbon mass based on:
# mature fruit C mass % of Dipterocarpus tempehes from Ichie
# mature fruit dry weight of Dipterocarpus tempehes from Ichie
# seed dry weight of Dipterocarpus tempehes from Nakagawa and Nakashizuka (2004)
# (DOI https://doi.org/10.1079/SSR2004181)

mature_fruit_dry_mass <- 8.04 # in grams, with SD of 0.98 (see Ichie)
mature_fruit_C_mass <- mature_fruit_dry_mass * mature_fruit_C_percentage / 100

seed_dry_mass <- 2.33 # in grams, with SD of 0.88 (see Nakagawa and Nakashizuka)
seed_C_mass <- seed_dry_mass * mature_fruit_C_percentage / 100

# Add seed lignin content (the fraction of reproductive tissue carbon that is
# captured in lignin)

# Convert seed lignin content from dry weight basis to carbon basis
# According to Muddasar et al., 2024 (https://doi.org/10.1016/j.mtsust.2024.100990)
# lignin has 60-65% carbon content (average = 62.5%)
# So, first convert lignin content from dry weight to carbon weight
# Then calculate lignin carbon mass using 62.5% lignin carbon content

seed_lignin_percentage <- 14.4 # with SD of 3.2 (see Nakagawa and Nakashizuka)

seed_lignin_g <- (seed_lignin_percentage / 100) * seed_dry_mass
seed_lignin_C_g <- seed_lignin_g * 0.625
seed_C_g <- (mature_fruit_C_percentage / 100) * seed_dry_mass
lignin_C_of_seed_C <- seed_lignin_C_g / seed_C_g

# Add to summary

summary$mature_fruit_C_mass <- mature_fruit_C_mass
summary$seed_C_mass <- seed_C_mass
summary$seed_lignin <- lignin_C_of_seed_C

################################################################################

# Non-propagule reproductive tissue stoichiometry (flowers)

# For flowers the same approach is used as described for fruit stoichiometry above
# i.e., based on the data from Ichie et al., 2005
# To calculate flower stoichiometry, the following tissue stages are averaged:
# flower bud, corolla appearing from flower bud, just before flowering, open flower

flower_C_percentage <- (49.16 + 49.42 + 49.13 + 48.71) / 4 # See paper for SD
flower_N_percentage <- (0.86 + 1.11 + 0.92 + 1.11) / 4 # See paper for SD
flower_P_percentage <- (0.88 + 1.05 + 0.84 + 0.85) / 4 # See paper for SD

flower_CN <- flower_C_percentage / flower_N_percentage
flower_CP <- flower_C_percentage / flower_P_percentage

# Note that the CP ratio here is also much lower than the one by Kitayama

# Add to summary

summary$flower_CN <- flower_CN
summary$flower_CP <- flower_CP

################################################################################

# Fine root stoichiometry

# Fine root stoichiometry is obtained from Imai et al., 2010
# (https://doi.org/10.1017/S0266467410000350)
# These data are for mixed dipterocarp lowland tropical rain forest in Sabah

fine_root_C_percentage <- 45.2 # SD = 4.4
fine_root_N_percentage <- 1.38 # SD = 0.32
fine_root_P_percentage <- 0.052 # SD = 0.004

fine_root_CN <- fine_root_C_percentage / fine_root_N_percentage
fine_root_CP <- fine_root_C_percentage / fine_root_P_percentage

# Fine root lignin content (expressed as fraction of fine root carbon mass)

# According to White et al., 2000
# (https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)
# the mean fine root lignin content is 22% across all biomes
# There is a lack of data for this parameter, so we'll use this mean for now

fine_root_lignin_percentage <- 22

# Still need to correct it to go from dry weight to carbon mass
# We'll use the fine_root_C_percentage (45.2%) from Imai et al., 2010 (see above)
# We'll also use 62.5% carbon content of lignin (Muddasar et al., 2024)

lignin_C_percentage <- fine_root_lignin_percentage * 0.625
fine_root_lignin_C_of_root_C <- lignin_C_percentage / 45.2

# Add to summary

summary$fine_root_CN <- fine_root_CN
summary$fine_root_CP <- fine_root_CP
summary$fine_root_lignin <- fine_root_lignin_C_of_root_C

################################################################################

# Clean up summary

backup <- summary
summary <- backup

summary$CN_leaf_mean <- as.numeric(summary$CN_leaf_mean)
summary$CP_leaf_mean <- as.numeric(summary$CP_leaf_mean)
summary$lignin_leaf_mean <- as.numeric(summary$lignin_leaf_mean)
summary$CN_senesced_leaf_mean <- as.numeric(summary$CN_senesced_leaf_mean)
summary$CP_senesced_leaf_mean <- as.numeric(summary$CP_senesced_leaf_mean)
summary$lignin_senesced_leaf_mean <- as.numeric(
  summary$lignin_senesced_leaf_mean
)

names(summary)

summary <- summary[, c(
  "pft_name",
  "CN_sapwood_mean",
  "CP_sapwood_mean",
  "stem_lignin",
  "CN_leaf_mean",
  "CP_leaf_mean",
  "lignin_leaf_mean",
  "CN_senesced_leaf_mean",
  "CP_senesced_leaf_mean",
  "lignin_senesced_leaf_mean",
  "reproductive_organ_CN",
  "reproductive_organ_CP",
  "mature_fruit_CN",
  "mature_fruit_CP",
  "mature_fruit_C_mass",
  "seed_C_mass",
  "seed_lignin",
  "flower_CN",
  "flower_CP",
  "fine_root_CN",
  "fine_root_CP",
  "fine_root_lignin"
)]

summary <- unique(summary)
rownames(summary) <- 1:nrow(summary)

# Change variable names to match those used in the VE
names(summary)

colnames(summary) <- c(
  "pft_name",
  "deadwood_c_n_ratio",
  "deadwood_c_p_ratio",
  "stem_lignin",
  "foliage_c_n_ratio",
  "foliage_c_p_ratio",
  "leaf_lignin",
  "leaf_turnover_c_n_ratio",
  "leaf_turnover_c_p_ratio",
  "senesced_leaf_lignin",
  "plant_reproductive_tissue_turnover_c_n_ratio",
  "plant_reproductive_tissue_turnover_c_p_ratio",
  "mature_fruit_c_n_ratio",
  "mature_fruit_c_p_ratio",
  "mature_fruit_c_mass",
  "carbon_mass_per_propagule",
  "plant_reproductive_tissue_lignin",
  "flower_c_n_ratio",
  "flower_c_p_ratio",
  "root_turnover_c_n_ratio",
  "root_turnover_c_p_ratio",
  "root_lignin"
)

# Write CSV file

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  summary,
  "../../../../data/derived/plant/input_data/data_library/stoichiometry_maliau.csv",
  row.names = FALSE
)
