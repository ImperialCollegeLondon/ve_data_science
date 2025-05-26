#' ---
#' title: Plant stoichiometry
#'
#' description: |
#'     This script focuses on collecting stoichiometric ratios and lignin content
#'     for each of the biomass pools in the plant model (leaves, sapwood, roots,
#'     reproductive tissue, flowers, fruits, seeds).
#'     The script works with multiple datasets and ideally calculates the ratios
#'     at PFT level. Species are linked to their PFT by working with the output
#'     of the PFT species classification base script.
#'     If PFT specific values are not available, values for tropical rain forests
#'     in Sabah are aimed for.
#'
#' VE_module: Plant
#'
#' author:
#'   - name: Arne Scheire
#'
#' status: final
#'
#'
#' input_files:
#'   - name: plant_functional_type_species_classification_base.csv
#'     path: ../../../data/derived/plant/plant_functional_type
#'     description: |
#'       This CSV file contains a list of species and their respective PFT.
#'       This CSV file can be loaded when working with other datasets
#'       (particularly those related to updating T model parameters).
#'       In a follow up script, the remaining species that have not been assigned
#'       a PFT yet will be assigned into one based on
#'       their species maximum height relative to the PFT maximum height.
#'   - name: inagawa_nutrients_wood_density.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'       https://doi.org/10.5281/zenodo.8158811
#'       Tree census data from the SAFE Project 2011–2020.
#'       Nutrients and wood density in coarse root, trunk and branches in
#'       Bornean tree species.
#'   - name: both_tree_functional_traits.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'       https://doi.org/10.5281/zenodo.3247631
#'       Functional traits of tree species in old-growth and selectively
#'       logged forest.
#'   - name: kitayama_2015_element_concentrations_of_litter_fractions.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'       https://doi.org/10.1111/1365-2745.12379
#'       Element concentrations of litter fractions.
#'
#' output_files:
#'   - name: plant_stoichiometry.csv
#'     path: ../../../data/derived/plant/traits_data/plant_stoichiometry.csv
#'     description: |
#'       This CSV file contains a summary of stoichiometric ratios and lignin
#'       content for different biomass pools for each PFT.
#'
#' package_dependencies:
#'     - readxl
#'     - dplyr
#'     - ggplot2
#'     - stringr
#'
#' usage_notes: |
#'   This script can be expanded when additional biomass pools are added to the model.
#' ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(stringr)

# Load PFT species classification base and clean up a bit

PFT_species_classification_base <- read.csv( # nolint
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_base.csv", # nolint
  header = TRUE
)

PFT_species_classification_base <- PFT_species_classification_base[ # nolint
  ,
  c("PFT", "PFT_name", "TaxaName")
]
PFT_species_classification_base <- unique(PFT_species_classification_base) # nolint

data_taxa <- PFT_species_classification_base

################################################################################

# Stem stoichiometry

# Load wood nutrients data and clean up a bit

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

# Stem lignin content

# According to White et al., 2000
# (https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)
# the mean stem (dead wood) lignin content is 23% for deciduous broadleaf forest

stem_lignin_percentage <- 23

# Still need to correct it to go from dry weight to carbon mass
# We'll use the mean sapwood carbon content (45.9%) across PFTs
mean(data$C_total[data$TissueType == "Sapwood"])
# We'll also use 62.5% carbon content of lignin (Muddasar et al., 2024)

stem_lignin_C_percentage <- stem_lignin_percentage * 0.625 # nolint
stem_lignin_C_of_stem_C <- (stem_lignin_C_percentage / 45.9) * 100 # nolint

# Add to summary

summary$stem_lignin <- stem_lignin_C_of_stem_C

################################################################################

# Leaf stoichiometry and lignin content

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
    "species", "C_perc", "N_perc", "total_P_mg.g",
    "lignin_recalcitrants_perc", "dry_weight_g_mean"
  )
]
colnames(temp) <- c(
  "species", "C_total", "N_total", "P_total",
  "lignin", "dry_weight"
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
temp$lignin_C_of_leaf_C <- (temp$lignin_C_g / temp$leaf_C_g) * 100

# Use lignin_C_of_leaf_C as the new lignin content
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
  data$lignin_leaf_mean[data$species == id] <- temp$lignin_leaf_mean[temp$species == id]
}

# Because the ratios are calculated for each species, this allows calculation of
# mean PFT values using the PFT species classification

# Check with David if we also want to use the mean across species (i.e., to remain
# a consistent approach similar to woody stoichiometry) or if it's fine to proceed
# with PFT specific values.

mean(temp$CN_leaf_mean)
mean(temp$CP_leaf_mean)
mean(temp$lignin_leaf_mean)

##########

# Link leaf stoichiometry dataset to base PFT species classification

# Match by species first
data1 <- left_join(data, PFT_species_classification_base,
  by = c("species" = "TaxaName")
)

# Match by genus only for rows where PFT is still NA
data2 <- left_join(data, PFT_species_classification_base,
  by = c("genus" = "TaxaName")
)

# Combine: take PFT and PFT_name from species match if available,
# otherwise from genus match
data$PFT <- ifelse(!is.na(data1$PFT), data1$PFT, data2$PFT)
data$PFT_name <- ifelse(!is.na(data1$PFT_name), data1$PFT_name, data2$PFT_name)

##########

# Calculate PFT leaf stoichiometry

names(data)

plot_data <- data[, c(
  "location", "forest_type", "sample_code", "PFT",
  "PFT_name", "species", "CN_leaf_mean", "CP_leaf_mean",
  "lignin_leaf_mean"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$forest_type <- as.factor(plot_data$forest_type)

# CN_leaf_mean

ggplot(plot_data, aes(
  x = sample_code, y = CN_leaf_mean,
  color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "CN_leaf_mean") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = CN_leaf_mean,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "CN_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_CN_leaf_mean = mean(CN_leaf_mean, na.rm = TRUE),
    SD_CN_leaf_mean = sd(CN_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Note: mean across all species was 26.06

# Write to summary

summary$CN_leaf_mean <- NA
summary$CN_leaf_mean_SD <- NA

summary$CN_leaf_mean[summary$PFT == "1"] <-
  round(summary_stats[1, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$PFT == "1"] <-
  round(summary_stats[1, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$PFT == "2"] <-
  round(summary_stats[2, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$PFT == "2"] <-
  round(summary_stats[2, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$PFT == "3"] <-
  round(summary_stats[3, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$PFT == "3"] <-
  round(summary_stats[3, "SD_CN_leaf_mean"], 2)
summary$CN_leaf_mean[summary$PFT == "4"] <-
  round(summary_stats[4, "Mean_CN_leaf_mean"], 2)
summary$CN_leaf_mean_SD[summary$PFT == "4"] <-
  round(summary_stats[4, "SD_CN_leaf_mean"], 2)

# CP_leaf_mean

ggplot(plot_data, aes(
  x = sample_code, y = CP_leaf_mean,
  color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "CP_leaf_mean") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = CP_leaf_mean,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "CP_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_CP_leaf_mean = mean(CP_leaf_mean, na.rm = TRUE),
    SD_CP_leaf_mean = sd(CP_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Note: mean across all species was 506.15

# Write to summary

summary$CP_leaf_mean <- NA
summary$CP_leaf_mean_SD <- NA

summary$CP_leaf_mean[summary$PFT == "1"] <-
  round(summary_stats[1, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$PFT == "1"] <-
  round(summary_stats[1, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$PFT == "2"] <-
  round(summary_stats[2, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$PFT == "2"] <-
  round(summary_stats[2, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$PFT == "3"] <-
  round(summary_stats[3, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$PFT == "3"] <-
  round(summary_stats[3, "SD_CP_leaf_mean"], 2)
summary$CP_leaf_mean[summary$PFT == "4"] <-
  round(summary_stats[4, "Mean_CP_leaf_mean"], 2)
summary$CP_leaf_mean_SD[summary$PFT == "4"] <-
  round(summary_stats[4, "SD_CP_leaf_mean"], 2)

# lignin_leaf_mean

ggplot(plot_data, aes(
  x = sample_code,
  y = lignin_leaf_mean, color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "lignin_leaf_mean") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = lignin_leaf_mean,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "lignin_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_lignin_leaf_mean = mean(lignin_leaf_mean, na.rm = TRUE),
    SD_lignin_leaf_mean = sd(lignin_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Mean across all species was 25.08

# Write to summary

summary$lignin_leaf_mean <- NA
summary$lignin_leaf_mean_SD <- NA

summary$lignin_leaf_mean[summary$PFT == "1"] <-
  round(summary_stats[1, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$PFT == "1"] <-
  round(summary_stats[1, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$PFT == "2"] <-
  round(summary_stats[2, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$PFT == "2"] <-
  round(summary_stats[2, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$PFT == "3"] <-
  round(summary_stats[3, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$PFT == "3"] <-
  round(summary_stats[3, "SD_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean[summary$PFT == "4"] <-
  round(summary_stats[4, "Mean_lignin_leaf_mean"], 2)
summary$lignin_leaf_mean_SD[summary$PFT == "4"] <-
  round(summary_stats[4, "SD_lignin_leaf_mean"], 2)

################################################################################

# Propagule reproductive tissue stoichiometry (fruits and seeds)

# The first approach is to use the data from Kitayama et al., 2015
# Here they provide element concentrations for fruits/flowers combined
# for a range of forests on Mount Kinabalu, Borneo

kitayama_litter_stoichiometry <- read_excel(
  "../../../data/primary/plant/traits_data/kitayama_2015_element_concentrations_of_litter_fractions.xlsx", # nolint
  sheet = "Sheet1",
  col_names = FALSE
)

colnames(kitayama_litter_stoichiometry) <- kitayama_litter_stoichiometry[2, ]

kitayama_litter_stoichiometry_C <- kitayama_litter_stoichiometry[c(28:36), c(1, 2, 3)] # nolint
colnames(kitayama_litter_stoichiometry_C) <- c("site", "leaf_C", "reproductive_organ_C") # nolint
kitayama_litter_stoichiometry_N <- kitayama_litter_stoichiometry[c(15:23), c(1, 2, 3)] # nolint
colnames(kitayama_litter_stoichiometry_N) <- c("site", "leaf_N", "reproductive_organ_N") # nolint
kitayama_litter_stoichiometry_P <- kitayama_litter_stoichiometry[c(3:11), c(1, 2, 3)] # nolint
colnames(kitayama_litter_stoichiometry_P) <- c("site", "leaf_P", "reproductive_organ_P") # nolint

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
  kitayama_litter_stoichiometry$reproductive_organ_C / kitayama_litter_stoichiometry$reproductive_organ_N # nolint
kitayama_litter_stoichiometry$reproductive_organ_CP <-
  kitayama_litter_stoichiometry$reproductive_organ_C / kitayama_litter_stoichiometry$reproductive_organ_P # nolint

kitayama_litter_stoichiometry$leaf_CN <-
  kitayama_litter_stoichiometry$leaf_C / kitayama_litter_stoichiometry$leaf_N
kitayama_litter_stoichiometry$leaf_CP <-
  kitayama_litter_stoichiometry$leaf_C / kitayama_litter_stoichiometry$leaf_P

# Note that values for leaf stoichiometry are higher than our PFT specific ratios

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

###

# The second approach is to use the data from Ichie et al., 2005

# The Ichie paper does not have supplementary information, so I extract the data
# manually from the paper (DOI: https://doi.org/10.1017/S0266467404002214)
# The paper focuses on one species (Dipterocarpus tempehes) and has detailed
# info on mass, number and stoichiometry for different developmental stages of
# reproductive tissues. The advantage here is that they separate fruits and flowers
# To calculate fruit stoichiometric ratios, the values for mature fruit are used

mature_fruit_C_percentage <- 50.62 # mean with SD of 0.44 # nolint
mature_fruit_N_percentage <- 0.79 # mean with SD of 0.14 # nolint
mature_fruit_P_percentage <- 0.61 # mean with SD of 0.11 # nolint

mature_fruit_CN <- mature_fruit_C_percentage / mature_fruit_N_percentage # nolint
mature_fruit_CP <- mature_fruit_C_percentage / mature_fruit_P_percentage # nolint

# Note that the CP ratio here is much lower than the one by Kitayama

# Add to summary

summary$mature_fruit_CN <- mature_fruit_CN
summary$mature_fruit_CP <- mature_fruit_CP

###

# Thoughts om both approaches:
# There seems to be quite a large difference in the CP ratio between the two
# approaches, and I'm not sure which one is the best
# Also, when comparing Kitayama values for leaf stoichiometry with our PFT values,
# Kitayama values appear to be quite a bit higher
# The one based on Kitayama is more general (i.e., different species and sites)
# but is less detailed than the one based on Ichie with regards to different
# tissue types

# Worth noting is that Kitayama's data has measurements for litterfall of
# both leaf and reproductive tissues, so this could be used to define the ratio
# between foliage mass and reproductive tissue mass (see SI for carbon mass)
# Because of this, it may be better to choose Kitayama derived stoichiometric
# values for reproductive tissue (and not use the ones derived from Ichie)

# Note that we'll likely use Ichie to determine the ratio between non-propagule
# and propagule mass

# Add mature fruit and seed carbon mass based on:
# mature fruit C mass % of Dipterocarpus tempehes from Ichie
# mature fruit dry weight of Dipterocarpus tempehes from Ichie
# seed dry weight of Dipterocarpus tempehes from Nakagawa and Nakashizuka (2004)

mature_fruit_dry_mass <- 8.04 # in grams, with SD of 0.98 (see Ichie)
mature_fruit_C_mass <- mature_fruit_dry_mass * mature_fruit_C_percentage / 100 # nolint

seed_dry_mass <- 2.33 # in grams, with SD of 0.88 (see Nakagawa and Nakashizuka)
seed_C_mass <- seed_dry_mass * mature_fruit_C_percentage / 100 # nolint

# Add seed lignin content (the percentage of reproductive tissue that is lignin)

# Convert seed lignin content from dry weight basis to carbon basis
# According to Muddasar et al., 2024 (https://doi.org/10.1016/j.mtsust.2024.100990)
# lignin has 60-65% carbon content (average = 62.5%)
# So, first convert lignin content from dry weight to carbon weight
# Then calculate lignin carbon mass using 62.5% lignin carbon content

seed_lignin_percentage <- 14.4 # with SD of 3.2 (see Nakagawa and Nakashizuka)

seed_lignin_g <- (seed_lignin_percentage / 100) * seed_dry_mass
seed_lignin_C_g <- seed_lignin_g * 0.625 # nolint
seed_C_g <- (mature_fruit_C_percentage / 100) * seed_dry_mass # nolint
lignin_C_of_seed_C <- (seed_lignin_C_g / seed_C_g) * 100 # nolint

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

flower_C_percentage <- (49.16 + 49.42 + 49.13 + 48.71) / 4 # See paper for SD # nolint
flower_N_percentage <- (0.86 + 1.11 + 0.92 + 1.11) / 4 # See paper for SD # nolint
flower_P_percentage <- (0.88 + 1.05 + 0.84 + 0.85) / 4 # See paper for SD # nolint

flower_CN <- flower_C_percentage / flower_N_percentage # nolint
flower_CP <- flower_C_percentage / flower_P_percentage # nolint

# Note that the CP ratio here is also much lower than the one by Kitayama

# Add to summary

summary$flower_CN <- flower_CN
summary$flower_CP <- flower_CP

################################################################################

# Fine root stoichiometry

# Fine root stoichiometry is obtained from Imai et al., 2010
# (https://doi.org/10.1017/S0266467410000350)
# These data are for mixed dipterocarp lowland tropical rain forest in Sabah

fine_root_C_percentage <- 45.2 # SD = 4.4 # nolint
fine_root_N_percentage <- 1.38 # SD = 0.32 # nolint
fine_root_P_percentage <- 0.052 # SD = 0.004 # nolint

fine_root_CN <- fine_root_C_percentage / fine_root_N_percentage # nolint
fine_root_CP <- fine_root_C_percentage / fine_root_P_percentage # nolint

# Fine root lignin content

# According to White et al., 2000
# (https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)
# the mean fine root lignin content is 22% across all biomes
# There is a lack of data for this parameter, so we'll use this mean for now

fine_root_lignin_percentage <- 22

# Still need to correct it to go from dry weight to carbon mass
# We'll use the fine_root_C_percentage (45.2%) from Imai et al., 2010 (see above)
# We'll also use 62.5% carbon content of lignin (Muddasar et al., 2024)

lignin_C_percentage <- fine_root_lignin_percentage * 0.625 # nolint
fine_root_lignin_C_of_root_C <- (lignin_C_percentage / 45.2) * 100 # nolint

# Add to summary

summary$fine_root_CN <- fine_root_CN
summary$fine_root_CP <- fine_root_CP
summary$fine_root_lignin <- fine_root_lignin_C_of_root_C

################################################################################

# Clean up summary

backup <- summary
summary <- backup

names(summary)
summary <- summary[, c(
  2, 4, 6, 8, 9, 11, 13, 15:26
)]
summary <- unique(summary)
rownames(summary) <- 1:nrow(summary) # nolint

summary$CN_leaf_mean <- as.numeric(summary$CN_leaf_mean)
summary$CP_leaf_mean <- as.numeric(summary$CP_leaf_mean)
summary$lignin_leaf_mean <- as.numeric(summary$lignin_leaf_mean)

# Write CSV file

write.csv(
  summary,
  "../../../data/derived/plant/traits_data/plant_stoichiometry.csv",
  row.names = FALSE
)
