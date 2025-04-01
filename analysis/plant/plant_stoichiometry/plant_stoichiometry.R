#' ---
#' title: Plant stoichiometry
#'
#' description: |
#'     This script focuses on collecting stoichiometric ratios for each of the
#'     biomass pools in the plant model (leaves, wood, roots, flowers, seeds, fruits).
#'     The script works with multiple datasets and ideally calculates the ratios
#'     at PFT level. Species are linked to their PFT by working with the output
#'     of the PFT species classification base script.
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
#'
#' output_files:
#'   - name: plant_stoichiometry.csv
#'     path: ../../../data/derived/plant/traits_data/plant_stoichiometry.csv
#'     description: |
#'       This CSV file contains a summary of stoichiometric ratios for different
#'       biomass pools for each PFT.
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
data$NP <- data$N_total / data$P_total

##########

# Because we only have 10 unique species, we'll use the mean across species

# Mean sapwood stoichiometry
# (other tissues: "Bark" "Sapwood" "Heartwood" "Wood" "WoodAndBark")

temp <- data[, c("species", "TissueType", "CN", "CP", "NP")]
temp <- temp[temp$TissueType == "Sapwood", ]

temp <- temp %>%
  group_by(species) %>%
  mutate(CN_sapwood = mean(as.numeric(CN), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(CP_sapwood = mean(as.numeric(CP), na.rm = TRUE)) %>%
  ungroup()

temp <- temp %>%
  group_by(species) %>%
  mutate(NP_sapwood = mean(as.numeric(NP), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "TissueType", "CN_sapwood", "CP_sapwood", "NP_sapwood")]
temp <- unique(temp)

mean(temp$CN_sapwood)
sd(temp$CN_sapwood)
mean(temp$CP_sapwood)
sd(temp$CP_sapwood)
mean(temp$NP_sapwood)
sd(temp$NP_sapwood)

data$CN_mean[data$TissueType == "Sapwood"] <- mean(temp$CN_sapwood)
data$CN_mean_SD[data$TissueType == "Sapwood"] <- sd(temp$CN_sapwood)
data$CP_mean[data$TissueType == "Sapwood"] <- mean(temp$CP_sapwood)
data$CP_mean_SD[data$TissueType == "Sapwood"] <- sd(temp$CP_sapwood)
data$NP_mean[data$TissueType == "Sapwood"] <- mean(temp$NP_sapwood)
data$NP_mean_SD[data$TissueType == "Sapwood"] <- sd(temp$NP_sapwood)

# Check with David which other tissue types need stoichiometric ratio's
# Can repeat code above for other tissues

# Create summary file, based on data_taxa and add stoichiometric ratios to it

summary <- data_taxa

# Write stem stoichiometric ratios to summary

summary$CN_sapwood_mean <- NA
summary$CN_sapwood_mean_SD <- NA
summary$CP_sapwood_mean <- NA
summary$CP_sapwood_mean_SD <- NA
summary$NP_sapwood_mean <- NA
summary$NP_sapwood_mean_SD <- NA

summary$CN_sapwood_mean <-
  round(unique(data$CN_mean[data$TissueType == "Sapwood"]), 2)
summary$CN_sapwood_mean_SD <-
  round(unique(data$CN_mean_SD[data$TissueType == "Sapwood"]), 2)
summary$CP_sapwood_mean <-
  round(unique(data$CP_mean[data$TissueType == "Sapwood"]), 2)
summary$CP_sapwood_mean_SD <-
  round(unique(data$CP_mean_SD[data$TissueType == "Sapwood"]), 2)
summary$NP_sapwood_mean <-
  round(unique(data$NP_mean[data$TissueType == "Sapwood"]), 2)
summary$NP_sapwood_mean_SD <-
  round(unique(data$NP_mean_SD[data$TissueType == "Sapwood"]), 2)

################################################################################

# Leaf stoichiometry

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
temp <- data[, c("species", "C_perc", "N_perc", "total_P_mg.g")]
colnames(temp) <- c("species", "C_total", "N_total", "P_total")

temp$C_total <- as.numeric(temp$C_total)
temp$N_total <- as.numeric(temp$N_total)
temp$P_total <- as.numeric(temp$P_total)

temp$P_total <- temp$P_total * 0.1
# Convert to % in order to match unit of C_total and N_total

temp <- na.omit(temp)

temp$CN_leaf <- temp$C_total / temp$N_total
temp$CP_leaf <- temp$C_total / temp$P_total
temp$NP_leaf <- temp$N_total / temp$P_total

# Mean leaf stoichiometry

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
  mutate(NP_leaf_mean = mean(as.numeric(NP_leaf), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "CN_leaf_mean", "CP_leaf_mean", "NP_leaf_mean")]
temp <- unique(temp)

data$CN_leaf_mean <- NA
data$CP_leaf_mean <- NA
data$NP_leaf_mean <- NA

leaf_ratios <- unique(temp$species)

for (id in leaf_ratios) {
  data$CN_leaf_mean[data$species == id] <- temp$CN_leaf_mean[temp$species == id]
  data$CP_leaf_mean[data$species == id] <- temp$CP_leaf_mean[temp$species == id]
  data$NP_leaf_mean[data$species == id] <- temp$NP_leaf_mean[temp$species == id]
}

# Because the ratios are calculated for each species, this allows calculation of
# mean PFT values using the PFT species classification

# Check with David if we also want to use the mean across species (i.e., to remain
# a consistent approach similar to woody stoichiometry) or if it's fine to proceed
# with PFT specific values.

mean(temp$CN_leaf_mean)
mean(temp$CP_leaf_mean)
mean(temp$NP_leaf_mean)

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
  "NP_leaf_mean"
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

# NP_leaf_mean

ggplot(plot_data, aes(
  x = sample_code,
  y = NP_leaf_mean, color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "NP_leaf_mean") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = NP_leaf_mean,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "NP_leaf_mean") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_NP_leaf_mean = mean(NP_leaf_mean, na.rm = TRUE),
    SD_NP_leaf_mean = sd(NP_leaf_mean, na.rm = TRUE)
  )

print(summary_stats) # Mean across all species was 19.65

# Write to summary

summary$NP_leaf_mean <- NA
summary$NP_leaf_mean_SD <- NA

summary$NP_leaf_mean[summary$PFT == "1"] <-
  round(summary_stats[1, "Mean_NP_leaf_mean"], 2)
summary$NP_leaf_mean_SD[summary$PFT == "1"] <-
  round(summary_stats[1, "SD_NP_leaf_mean"], 2)
summary$NP_leaf_mean[summary$PFT == "2"] <-
  round(summary_stats[2, "Mean_NP_leaf_mean"], 2)
summary$NP_leaf_mean_SD[summary$PFT == "2"] <-
  round(summary_stats[2, "SD_NP_leaf_mean"], 2)
summary$NP_leaf_mean[summary$PFT == "3"] <-
  round(summary_stats[3, "Mean_NP_leaf_mean"], 2)
summary$NP_leaf_mean_SD[summary$PFT == "3"] <-
  round(summary_stats[3, "SD_NP_leaf_mean"], 2)
summary$NP_leaf_mean[summary$PFT == "4"] <-
  round(summary_stats[4, "Mean_NP_leaf_mean"], 2)
summary$NP_leaf_mean_SD[summary$PFT == "4"] <-
  round(summary_stats[4, "SD_NP_leaf_mean"], 2)

################################################################################

# Root stoichiometry



################################################################################

# Flower stoichiometry



################################################################################

# Seed stoichiometry



################################################################################

# Fruit stoichiometry



################################################################################

# Clean up summary

names(summary)
summary <- summary[, c(
  1, 2, 4:15
)]
summary <- unique(summary)
rownames(summary) <- 1:nrow(summary) # nolint

summary$CN_sapwood_mean <- as.numeric(summary$CN_sapwood_mean)
summary$CN_sapwood_mean_SD <- as.numeric(summary$CN_sapwood_mean_SD)
summary$CP_sapwood_mean <- as.numeric(summary$CP_sapwood_mean)
summary$CP_sapwood_mean_SD <- as.numeric(summary$CP_sapwood_mean_SD)
summary$NP_sapwood_mean <- as.numeric(summary$NP_sapwood_mean)
summary$NP_sapwood_mean_SD <- as.numeric(summary$NP_sapwood_mean_SD)
summary$CN_leaf_mean <- as.numeric(summary$CN_leaf_mean)
summary$CN_leaf_mean_SD <- as.numeric(summary$CN_leaf_mean_SD)
summary$CP_leaf_mean <- as.numeric(summary$CP_leaf_mean)
summary$CP_leaf_mean_SD <- as.numeric(summary$CP_leaf_mean_SD)
summary$NP_leaf_mean <- as.numeric(summary$NP_leaf_mean)
summary$NP_leaf_mean_SD <- as.numeric(summary$NP_leaf_mean_SD)

# Write CSV file

write.csv(
  summary,
  "../../../data/derived/plant/traits_data/plant_stoichiometry.csv",
  row.names = FALSE
)
