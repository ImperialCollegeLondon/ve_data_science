#| ---
#| title: Tree nutrient uptake validation
#|
#| description: |
#|     This script focuses on validating the tree nutrient uptake outputs
#|     (nitrogen and phosphorus) from the VE simulation for the Maliau scenario.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#|
#| input_files:
#|   - name: all_continuous_data.nc
#|     path: data/scenarios/maliau/maliau_1/out
#|     description: |
#|       All continuous data obtained from VE simulation.
#|   - name: SAFE_CarbonBalanceComponents.xlsx
#|     path: data/primary/plant/carbon_balance_components
#|     description: |
#|       https://doi.org/10.5281/zenodo.7307449
#|       Measured components of total carbon budget at the SAFE project.
#|       Values with standard errors for each 1-ha carbon plots for 11 plots
#|       investigated across a logging gradient from unlogged old-growth to
#|       heavily logged.
#|   - name: both_tree_functional_traits.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.3247631
#|       Functional traits of tree species in old-growth and selectively
#|       logged forest.
#|   - name: inagawa_nutrients_wood_density.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.8158811
#|       Tree census data from the SAFE Project 2011–2020.
#|       Nutrients and wood density in coarse root, trunk and branches in
#|       Bornean tree species.
#|
#| output_files:
#|   - name: xx
#|     path: xx
#|     description: |
#|       xx
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|
#| usage_notes: |
#|   This script can be used for different simulations.
#| ---


# Load packages ----------------------------------------------------------------

library(readxl)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(reshape2)
library(lubridate)
library(stringr)

# Load data --------------------------------------------------------------------

# Load all continuous NetCDF data
all_continuous_data <-
  nc_open("../../../data/scenarios/maliau/maliau_1/out/all_continuous_data.nc")

# Look at dims
names(all_continuous_data$dim)

time_index <- ncvar_get(all_continuous_data, "time_index")
cell_id <- ncvar_get(all_continuous_data, "cell_id")
element <- ncvar_get(all_continuous_data, "element")
pft <- ncvar_get(all_continuous_data, "pft")
layers <- ncvar_get(all_continuous_data, "layers")

groundwater_layers <- all_continuous_data$dim$groundwater_layers$vals
# string9 <- all_continuous_data$dim$string9$vals # nolint

# Look at vars
names(all_continuous_data$var)

# Define layer_color for plotting later on
cell_color <- hcl.colors(length(cell_id), palette = "Zissou 1")
cell_color <- setNames(cell_color, as.character(cell_id))

element_color <- hcl.colors(length(element), palette = "Zissou 1")
element_color <- setNames(element_color, as.character(element))

pft_color <- hcl.colors(length(pft), palette = "Zissou 1")
pft_color <- setNames(pft_color, as.character(pft))

layer_color <- hcl.colors(length(layers), palette = "Zissou 1")
layer_color <- setNames(layer_color, as.character(layers))

groundwater_layer_color <-
  hcl.colors(length(groundwater_layers), palette = "Zissou 1")
groundwater_layer_color <-
  setNames(groundwater_layer_color, as.character(groundwater_layers))

###

# Extract nutrient uptake variables

names(all_continuous_data$var)

# plant_ammonium_uptake
plant_ammonium_uptake <-
  ncvar_get(all_continuous_data, "plant_ammonium_uptake")
sapply(all_continuous_data$var[["plant_ammonium_uptake"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(plant_ammonium_uptake) <- list(
  cell_id = cell_id,
  time_index = time_index
)

plant_ammonium_uptake[1, ]

# Convert to long format
plant_ammonium_uptake_long <- # nolint
  melt(plant_ammonium_uptake, value.name = "plant_ammonium_uptake")

# Subset to cell_id = 0:10 only
plant_ammonium_uptake_long <- # nolint
  plant_ammonium_uptake_long[plant_ammonium_uptake_long$cell_id %in% c(0:10), ]

# Note that the unit of plant_ammonium_uptake is kg N m-2 day-1
# so convert this value later on to match the validation dataset

# plant_nitrate_uptake
plant_nitrate_uptake <-
  ncvar_get(all_continuous_data, "plant_nitrate_uptake")
sapply(all_continuous_data$var[["plant_nitrate_uptake"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(plant_nitrate_uptake) <- list(
  cell_id = cell_id,
  time_index = time_index
)

plant_nitrate_uptake[1, ]

# Convert to long format
plant_nitrate_uptake_long <- # nolint
  melt(plant_nitrate_uptake, value.name = "plant_nitrate_uptake")

# Subset to cell_id = 0:10 only
plant_nitrate_uptake_long <- # nolint
  plant_nitrate_uptake_long[plant_nitrate_uptake_long$cell_id %in% c(0:10), ]

# Note that the unit of plant_nitrate_uptake is kg N m-2 day-1
# so convert this value later on to match the validation dataset

# plant_phosphorus_uptake
plant_phosphorus_uptake <-
  ncvar_get(all_continuous_data, "plant_phosphorus_uptake")
sapply(all_continuous_data$var[["plant_phosphorus_uptake"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(plant_phosphorus_uptake) <- list(
  cell_id = cell_id,
  time_index = time_index
)

plant_phosphorus_uptake[1, ]

# Convert to long format
plant_phosphorus_uptake_long <- # nolint
  melt(plant_phosphorus_uptake, value.name = "plant_phosphorus_uptake")

# Subset to cell_id = 0:10 only
plant_phosphorus_uptake_long <- # nolint
  plant_phosphorus_uptake_long[plant_phosphorus_uptake_long$cell_id %in% c(0:10), ]

# Note that the unit of plant_phosphorus_uptake is kg N m-2 day-1
# so convert this value later on to match the validation dataset

#####

# Load SAFE carbon balance components dataset and clean up a bit

safe_carbon <- read_excel(
  "../../../data/primary/plant/carbon_balance_components/SAFE_CarbonBalanceComponents.xlsx", # nolint
  sheet = "Data",
  col_names = FALSE
)

max(nrow(safe_carbon))
colnames(safe_carbon) <- safe_carbon[6, ]
safe_carbon <- safe_carbon[7:17, ]
names(safe_carbon)

safe_carbon[, 6:65] <- lapply(safe_carbon[, 6:65], as.numeric)

#####

# Load Both et al. (20XX) dataset to get access to Maliau mean stoichiometry

both_tree_functional_traits <- read_excel(
  "../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

data <- both_tree_functional_traits

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:724, ]
names(data)

# Subset to Maliau OG plots

data <- data[data$forestplots_name %in% c("MLA-01", "MLA-02"), ]

# Replace "." by a space in the species name

data <- data %>%
  mutate(species = str_replace_all(species, fixed("."), " "))

# Seperate genus from species into its own column

data <- data %>%
  mutate(genus = word(species, 1))

data <- data[, c(1:9, 86, 10:85)]

##########

names(data)
temp <- data[
  , c(
    "species", "C_perc", "N_perc", "total_P_mg.g", "dry_weight_g_mean"
  )
]
colnames(temp) <- c(
  "species", "C_total", "N_total", "P_total", "dry_weight"
)

temp$C_total <- as.numeric(temp$C_total)
temp$N_total <- as.numeric(temp$N_total)
temp$P_total <- as.numeric(temp$P_total)
temp$dry_weight <- as.numeric(temp$dry_weight)

# Convert to % in order to match unit of C_total and N_total
temp$P_total <- temp$P_total * 0.1

###

temp <- na.omit(temp)

temp$CN_leaf <- temp$C_total / temp$N_total
temp$CP_leaf <- temp$C_total / temp$P_total

# Mean leaf stoichiometry

temp <- temp %>%
  group_by(species) %>%
  mutate(CN_leaf_mean = mean(as.numeric(CN_leaf), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(CP_leaf_mean = mean(as.numeric(CP_leaf), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "CN_leaf_mean", "CP_leaf_mean")]
temp <- unique(temp)

data$CN_leaf_mean <- NA
data$CP_leaf_mean <- NA

leaf_ratios <- unique(temp$species)

for (id in leaf_ratios) {
  data$CN_leaf_mean[data$species == id] <- temp$CN_leaf_mean[temp$species == id]
  data$CP_leaf_mean[data$species == id] <- temp$CP_leaf_mean[temp$species == id]
}

# Because the ratios are calculated for each species, this allows calculation of
# mean PFT values using the PFT species classification

mean_CN_leaf <-
  mean(temp$CN_leaf_mean) # 25.80867 is mean CN ratio for foliage (not senesced)
mean_CP_leaf <-
  mean(temp$CP_leaf_mean) # 513.8291 is mean CP ratio for foliage (not senesced)

#####

# Load Inagawa (2023) wood nutrients data and clean up a bit

inagawa_nutrients_wood_density <- read_excel(
  "../../../data/primary/plant/traits_data/inagawa_nutrients_wood_density.xlsx",
  sheet = "Nutrients",
  col_names = FALSE
)

data <- inagawa_nutrients_wood_density

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:427, ]
names(data)

data <- data[, c(
  "Species", "SamplingPoint", "TissueType",
  "C_total", "N_total", "P_total"
)]
colnames(data) <- c(
  "species", "SamplingPoint", "TissueType",
  "C_total", "N_total", "P_total"
)

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

# Use sapwood ratio because new growth = sapwood (not heartwood)
# For sapwood, use trunk middle (TM) sampling location and sapwood tissue type
# Note that these ratios are almost identical to the input data, the slight
# differences are because VE input data is adjusted to PFT species classification
mean_CN_sapwood <-
  mean(data$CN[data$TissueType == "Sapwood"]) # 1074.128 is mean CN ratio for sapwood
mean_CP_sapwood <-
  mean(data$CP[data$TissueType == "Sapwood"]) # 9257.064 is mean CP ratio for sapwood

# For branches, use middle and bottom branch (BM and BB) sampling location and
# wood tissue type
mean_CN_branch <-
  mean(data$CN[data$TissueType == "Wood" & data$SamplingPoint %in% c("BM", "BB")]) # 625.847 is mean CN ratio for branches # nolint
mean_CP_branch <-
  mean(data$CP[data$TissueType == "Wood" & data$SamplingPoint %in% c("BM", "BB")]) # 4985.189 is mean CP ratio for branches # nolint

# For coarse roots, use CR sampling location and wood tissue type
mean_CN_coarse_root <-
  mean(data$CN[data$TissueType == "Wood" & data$SamplingPoint == "CR"]) # 691.499 is mean CN ratio for coarse roots # nolint
mean_CP_coarse_root <-
  mean(data$CP[data$TissueType == "Wood" & data$SamplingPoint == "CR"]) # 6546.33 is mean CP ratio for coarse roots # nolint

#####

# Note that ideally we would also calculate CN and CP ratios for reproductive
# tissues, as these are also measured in the SAFE carbon dataset
# However, we do not have accurate stoichiometry for reproductive tissues at Maliau
# Therefore, there would be a lot of uncertainty as to how much N and P is required
# to grow these tissues
# So, for nutrient uptake validation, I think we need to accept that this validation
# script does not accurately validate reproductive tissues

# For now, I guess we could use the same stoichiometric ratios as the VE input data
# However, reproductive tissues will change a lot in the VE with ongoing PR's
# So fow now ignore reproductive tissues in this script

### ----------------------------------------------------------------------------

# To validate the nutrient uptake by trees in the VE, we will compare the outputs
# for nitrogen (plant_ammonium_uptake and plant_nitrate_uptake) and phosphorus
# (plant_phosphorus_uptake) with the study by Inagawa (2021).
# As mentioned earlier, we exclude reproductive tissues for now.

# In their study, Inagawa calculates nutrient uptake as:
# uptake = requirement - resorption (see page 218)

# We can calculate uptake using equation 3, using the following data:
# - NPP canopy = CanopyNPP_Leaf from Riuta et al. (2018)
# - CN ratio for leaf (from Both et al., 2019)
# - a 50% foliar nitrogen and phosphorus resorption, reported by Inagawa (2021)
#
# - NPP wood = WoodyNPP_Total (stem + coarse roots + branches) from Riuta et al. (2018)
# - CN ratio's for sapwood, coarse roots and branches (from Inagawa et al., 2023)
# - no resorption assumed from the wood, coarse roots or branches
#
# - NPP fine roots = FineRootNPP from Riuta et al. (2018)
# - CN ratio for fine roots from Imai et al. (2010)
# - no resorption assumed from the fine roots

# Fine root stoichiometry is obtained from Imai et al., 2010
# (https://doi.org/10.1017/S0266467410000350)
# These data are for mixed dipterocarp lowland tropical rain forest in Sabah

fine_root_C_percentage <- 45.2 # SD = 4.4 # nolint
fine_root_N_percentage <- 1.38 # SD = 0.32 # nolint
fine_root_P_percentage <- 0.052 # SD = 0.004 # nolint

mean_CN_fine_root <- fine_root_C_percentage / fine_root_N_percentage
mean_CP_fine_root <- fine_root_C_percentage / fine_root_P_percentage

#####

# As a second approach, we use the total % resorption for N and P (see table 5.3
# on page 236). This calculates the total requirement across leaf, wood and roots
# and then assumes resorption of (36.58-37.73) % for N and (35.21-35.55) % for P

##########

# First approach
# We use equation 3 from Inagawa (2021):

# uptake = requirement - resorption # nolint

# NITROGEN
# N requirement

req_canopy_N <- (mean(safe_carbon$CanopyNPP_Leaf[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CN_leaf # unit = Mg N ha-1 year-1 # nolint

req_woody_N_wood <- (mean(safe_carbon$WoodyNPP_Stem[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CN_sapwood # unit = Mg N ha-1 year-1 # nolint
req_woody_N_coarse_root <- (mean(safe_carbon$WoodyNPP_CoarseRoot[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CN_coarse_root # unit = Mg N ha-1 year-1 # nolint
req_woody_N_branch <- (mean(safe_carbon$WoodyNPP_BranchTurnover[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CN_branch # unit = Mg N ha-1 year-1 # nolint
req_woody_N <- req_woody_N_wood + req_woody_N_coarse_root + req_woody_N_branch

req_fine_roots_N <- (mean(safe_carbon$FineRootNPP[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CN_fine_root # unit = Mg N ha-1 year-1 # nolint

# N resorption

res_canopy_N <- 0.5 * req_canopy_N # unit = Mg N ha-1 year-1

# N uptake

uptake_N <- (req_canopy_N - res_canopy_N) + req_woody_N + req_fine_roots_N # unit = Mg N ha-1 year-1 # nolint

# Convert to same units as Inagawa (2021), being kg N ha-1 year-1
# Compare this value to Figure 5.2 (page 226)

uptake_N * 1000 # 122.2661 kg N ha-1 year-1

# We can see that our estimate is quite a bit lower (122 vs 200)
# Note that our approach above doesn't take into account some tissues:
# - CanopyNPP_Twig
# - CanopyNPP_Reproductive
# - CanopyNPP_Miscellaneous
# - CanopyNPP_Herbivory

# Compare with CanopyNPP_Total to see how much we're missing (about 22%)

1 - (mean(safe_carbon$CanopyNPP_Leaf[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / # nolint
  (mean(safe_carbon$CanopyNPP_Total[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) # nolint

# Note: we also do not know what CN ratio Inagawa used for each tissue type

##########

# PHOSPHORUS
# P requirement

req_canopy_P <- (mean(safe_carbon$CanopyNPP_Leaf[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CP_leaf # unit = Mg N ha-1 year-1 # nolint

req_woody_P_wood <- (mean(safe_carbon$WoodyNPP_Stem[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CP_sapwood # unit = Mg N ha-1 year-1 # nolint
req_woody_P_coarse_root <- (mean(safe_carbon$WoodyNPP_CoarseRoot[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CP_coarse_root # unit = Mg N ha-1 year-1 # nolint
req_woody_P_branch <- (mean(safe_carbon$WoodyNPP_BranchTurnover[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CP_branch # unit = Mg N ha-1 year-1 # nolint
req_woody_P <- req_woody_P_wood + req_woody_P_coarse_root + req_woody_P_branch

req_fine_roots_P <- (mean(safe_carbon$FineRootNPP[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / mean_CP_fine_root # unit = Mg N ha-1 year-1 # nolint

# P resorption

res_canopy_P <- 0.5 * req_canopy_P # unit = Mg N ha-1 year-1

# P uptake

uptake_P <- (req_canopy_P - res_canopy_P) + req_woody_P + req_fine_roots_P # unit = Mg N ha-1 year-1 # nolint

# Convert to same units as Inagawa (2021), being kg N ha-1 year-1
# Compare this value to Figure 5.2 (page 226)

uptake_P * 1000 # 6.344 kg P ha-1 year-1

# We can see that our estimate matches Inagawa pretty well (6.344 vs 7)
# Note that our approach above doesn't take into account some tissues:
# - CanopyNPP_Twig
# - CanopyNPP_Reproductive
# - CanopyNPP_Miscellaneous
# - CanopyNPP_Herbivory

# Compare with CanopyNPP_Total to see how much we're missing (about 22%)

1 - (mean(safe_carbon$CanopyNPP_Leaf[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) / # nolint
  (mean(safe_carbon$CanopyNPP_Total[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])) # nolint

# Note: we also do not know what CP ratio Inagawa used for each tissue type

##########

# Note that the above calculations basically just implement the reasoning by
# Inagawa, the results do not have to be identical per se because we will be
# comparing slightly different tissue pools in the VE

##########

# Second approach

# Recap:

# As a second approach, we use the total % resorption for N and P (see table 5.3
# on page 236). This calculates the total requirement across leaf, wood and roots
# and then assumes resorption of (36.58-37.73) % for N and (35.21-35.55) % for P

# Still use uptake = requirement - resorption
# The requirement to grow the tissues is the same as the first approach
# but we'll use a general resorption % across all tissues

# N uptake

total_req_N <- req_canopy_N + req_woody_N + req_fine_roots_N

total_res_N <- ((36.58 + 37.73) / 2) / 100

total_uptake_N <- total_req_N - (total_req_N * total_res_N) # unit = Mg N ha-1 year-1

# Convert to same units as Inagawa (2021), being kg N ha-1 year-1
# Compare this value to Figure 5.2 (page 226)

total_uptake_N * 1000 # 133.6538 kg N ha-1 year-1

# P uptake

total_req_P <- req_canopy_P + req_woody_P + req_fine_roots_P

total_res_P <- ((35.21 + 35.55) / 2) / 100

total_uptake_P <- total_req_P - (total_req_P * total_res_P) # unit = Mg P ha-1 year-1

# Convert to same units as Inagawa (2021), being kg P ha-1 year-1
# Compare this value to Figure 5.2 (page 226)

total_uptake_P * 1000 # 7.033873 kg P ha-1 year-1

###

# Compare both approaches

uptake_N * 1000 # 122.2661 kg N ha-1 year-1
uptake_P * 1000 # 6.344 kg P ha-1 year-1

total_uptake_N * 1000 # 133.6538 kg N ha-1 year-1
total_uptake_P * 1000 # 7.033873 kg P ha-1 year-1

### ----------------------------------------------------------------------------

# Now that we have our validation data to compare, calculate the total N and P
# uptake from the VE
# For nitrogen, sum both ammonium and nitrate
# Then convert nitrogen and phosphorus uptake rates from kg m-2 day-1 to Mg ha-1 year-1

# Note that currently the outputs of VE have nutrient uptake = 0
# This is driven by extremely low transpiration

###

# Calculate VE nutrient uptake in kg per cell (1 hectare) per year (12 timesteps)

# VE nutrient uptake
# Merge all nutrients together

VE_nutrient_uptake <- plant_ammonium_uptake_long

VE_nutrient_uptake <- merge(
  plant_ammonium_uptake_long,
  plant_nitrate_uptake_long
)

VE_nutrient_uptake$plant_nitrogen_uptake <-
  VE_nutrient_uptake$plant_ammonium_uptake + VE_nutrient_uptake$plant_nitrate_uptake

VE_nutrient_uptake <- merge(
  VE_nutrient_uptake,
  plant_phosphorus_uptake_long
)

# Convert to new units kg per hectare per year

VE_nutrient_uptake$plant_nitrogen_uptake <-
  VE_nutrient_uptake$plant_nitrogen_uptake * 10000 * 12

VE_nutrient_uptake$plant_phosphorus_uptake <-
  VE_nutrient_uptake$plant_phosphorus_uptake * 10000 * 12

# Calculate mean N and P uptake and compare to uptake_N and uptake_P calculated
# earlier

mean(VE_nutrient_uptake$plant_nitrogen_uptake, na.rm = TRUE) # unit is kg N ha-1 year-1 # nolint
mean(VE_nutrient_uptake$plant_phosphorus_uptake, na.rm = TRUE) # unit is kg P ha-1 year-1 # nolint

##########

# Future ideas:

# - compare uptake with requirement and resorption (similar to Inagawa, 2021)
