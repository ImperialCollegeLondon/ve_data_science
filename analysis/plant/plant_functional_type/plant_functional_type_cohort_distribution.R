#' ---
#' title: Plant functional type cohort distribution
#'
#' description: |
#'     This script calculates the PFT cohort distribution using the SAFE tree
#'     census dataset. It provides an output file that contains the number of
#'     individuals per DBH class for each PFT.
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
#'   - name: tree_census_11_20.xlsx
#'     path: ../../../data/primary/plant/tree_census
#'     description: |
#'       https://doi.org/10.5281/zenodo.14882506
#'       Tree census data from the SAFE Project 2011–2020.
#'       Data includes measurements of DBH and estimates of tree height for all
#'       stems, fruiting and flowering estimates,
#'       estimates of epiphyte and liana cover, and taxonomic IDs.
#'   - name: plant_functional_type_species_classification_maximum_height.csv
#'     path: ../../../data/derived/plant/plant_functional_type
#'     description: |
#'       This CSV file contains an updated list of species and their respective PFT.
#'       It contains a) the base PFT species classification and b) for the remaining
#'       species their PFT is assigned based on their maximum height relative to
#'       the PFT maximum height. Species maximum height is also included in the
#'       output file.
#'
#' output_files:
#'   - name: plant_functional_type_cohort_distribution.csv
#'     path: ../../../data/derived/plant/plant_functional_type
#'     description: |
#'       This CSV file contains the number of individuals per DBH class for each PFT.
#'
#' package_dependencies:
#'     - readxl
#'     - dplyr
#'     - ggplot2
#'     - tidyr
#'
#' usage_notes: |
#'   This script applies the PFT species classification to the SAFE census dataset
#'   in order to get the respective cohort distribution. However, the same approach
#'   can be applied to different census datasets and other PFT species classifications.
#' ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)

# Load SAFE tree census data and clean up a bit

tree_census_11_20 <- read_excel(
  "../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

data <- tree_census_11_20

max(nrow(data))
colnames(data) <- data[10, ]
data <- data[11:40511, ]
names(data)

# Load PFT species classification maximum height and clean up a bit

PFT_species_classification_maximum_height <- read.csv( # nolint
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_maximum_height.csv", # nolint
  header = TRUE
)

PFT_species_classification_maximum_height <- PFT_species_classification_maximum_height[ # nolint
  ,
  c("PFT_final", "PFT_name", "TaxaName")
]
PFT_species_classification_maximum_height <- unique(PFT_species_classification_maximum_height) # nolint

# Add PFT_final and PFT_name to data based on TaxaName and call it data_taxa

data_taxa <- left_join(data, PFT_species_classification_maximum_height, by = "TaxaName")

####################

# Subset to relevant columns and prepare for next step,
# which is to place individuals into dbh classes per PFT

backup <- data_taxa
data_taxa <- backup

data_taxa <- data_taxa[, c(
  "Block", "Plot", "PlotID", "TagStem_latest",
  "Family", "Genus", "Species", "TaxaName",
  "TaxaLevel", "PFT_final", "PFT_name", "HeightTotal_m_2011",
  "DBH2011_mm_clean"
)]

data_taxa$HeightTotal_m_2011 <- as.numeric(data_taxa$HeightTotal_m_2011)
data_taxa$DBH2011_mm_clean <- as.numeric(data_taxa$DBH2011_mm_clean)

# Ideally, we would base our cohort distribution on:
# - multiple plots
# - all trees within each plot are included (i.e., all trees have a PFT)

# Issues: missing trees within certain plots
# Trees without PFT are currently given PFT_final value of "0"
# and a PFT_name of "unknown"
# Note that this number is quite substantial, and I don't have an immediate
# solution to account for this in the cohort distribution.
# Missing values can have multiple reasons, but they are mostly related to the
# lack of identification and/or height measurements for that TaxaName.
# Also note that trees below a certain DBH were not measured during the census,
# and so are not included here.

data_taxa$PFT_final[!(data_taxa$PFT_final %in% c(1, 2, 3, 4))] <- "0"
data_taxa$PFT_name[data_taxa$PFT_final == "0"] <- "unknown"

ggplot(data_taxa, aes(x = TagStem_latest, y = HeightTotal_m_2011, color = PFT_final)) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

ggplot(data_taxa, aes(x = TagStem_latest, y = DBH2011_mm_clean, color = PFT_final)) +
  geom_point() +
  labs(x = "TreeID", y = "DBH (mm)")

# Note that the trees with PFT 0 have height and DBH values but are actually
# not assigned into one of our PFTs.
# This is likely because their taxonomic data was not at species/genus level
# At the moment, these trees will be excluded from the cohort distribution,
# unless we change the abovementioned issue.

# Additionally, the code below demonstrates the amount of trees that have no
# height and DBH values, and because of this these trees will also be excluded
# from the cohort distribution.

##########

# Save log of trees without PFT to see where data is missing
# (i.e., is it concentrated in certain plots?)
data_taxa_without_PFT <- data_taxa[data_taxa$PFT_final == "0", ] # nolint

# Before NA removal:
nrow(data_taxa)
# After NA removal:
nrow(data_taxa_without_PFT)
# The difference is the amount of trees with PFT, across all plots
nrow(data_taxa) - nrow(data_taxa_without_PFT)

plot(as.factor(data_taxa_without_PFT$Block),
  xlab = "Block", ylab = "Trees without PFT"
)
# OG1, OG2 and OG3 seem relatively good to use
# A-F have quite a lot of missing values

# Remove trees without PFT assigned
data_taxa_with_PFT <- drop_na(data_taxa, PFT_final) # nolint

plot(as.factor(data_taxa_with_PFT$Block),
  xlab = "Block", ylab = "Trees with PFT"
)

##########

# Note that B and E have most trees measured and seem best for logged plots
# OG1, OG2, OG3 seem the best option to base our "intact forest" cohort distribution on
# Calculate cohort distribution for these 3 plots and look at the variability

# Block OG1 contains several plots, which are not connected to each other
# Each plot (e.g., OG1_711) is 25mx25m

#####

# Having caveated the uncertainties related to missing trees, we now continue
# working with the data we have and focus on OG plots.
# Note that if these missing trees are within an acceptable range, we can also
# use the distribution of PFT individuals and relate that to stem density.

data_taxa <- drop_na(data_taxa, DBH2011_mm_clean)

data_taxa <- data_taxa[data_taxa$Block %in% c("OG1", "OG2", "OG3"), ]

ggplot(data_taxa, aes(x = TagStem_latest, y = HeightTotal_m_2011, color = PFT_final)) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

ggplot(data_taxa, aes(x = TagStem_latest, y = DBH2011_mm_clean, color = PFT_final)) +
  geom_point() +
  labs(x = "TreeID", y = "DBH (mm)")

#####

check <- data_taxa[data_taxa$Block %in% c("OG1", "OG2", "OG3"), ]
plot(as.factor(check$Block),
  xlab = "Block", ylab = "Trees in OG blocks"
)
unique(check$PlotID)

OG1_plots <- length(unique(check$Plot[check$Block == "OG1"])) # 9 # nolint
OG2_plots <- length(unique(check$Plot[check$Block == "OG2"])) # 9 # nolint
OG3_plots <- length(unique(check$Plot[check$Block == "OG3"])) # 9 # nolint

OG1_area <- 9 * (25 * 25) # m2 # nolint
OG2_area <- 9 * (25 * 25) # m2 # nolint
OG3_area <- 9 * (25 * 25) # m2 # nolint

# Use something else than TagStem_latest (may not be most accurate
# option available, e.g. account for dead trees)

OG1_trees <- length(unique(check$TagStem_latest[check$Block == "OG1"])) # nolint
OG2_trees <- length(unique(check$TagStem_latest[check$Block == "OG2"])) # nolint
OG3_trees <- length(unique(check$TagStem_latest[check$Block == "OG3"])) # nolint

OG1_density <- OG1_trees / OG1_area * 10000 # from trees per m2 to per hectare # nolint
OG2_density <- OG2_trees / OG2_area * 10000 # from trees per m2 to per hectare # nolint
OG3_density <- OG3_trees / OG3_area * 10000 # from trees per m2 to per hectare # nolint

# Mean OG tree density per hectare
mean(c(OG1_density, OG2_density, OG3_density))
# Compare to 410-444-535-478-427-600 from Kenzo, Slik,
# Mills, Saner papers (especially Slik appendix, many locations)

# Note that missing DBH values in other plots may potentially
# be filled by looking across multiple years or by using MaxDBH_mm

#####

# Narrow down to DBH for each PFT

names(data_taxa)
data_taxa <- data_taxa[
  ,
  c(
    "Block", "Plot", "PlotID", "TagStem_latest",
    "PFT_final", "PFT_name", "HeightTotal_m_2011", "DBH2011_mm_clean"
  )
]

# Use dividers of 0.1 m (100 mm)
# Assign each tree into one of these DBH classes
# The value for dbh represents the upper limit of the dbh class

data_taxa$dbh <- NA

data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 0.0 &
    data_taxa$DBH2011_mm_clean <= 100
] <- 100
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 100 &
    data_taxa$DBH2011_mm_clean <= 200
] <- 200
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 200 &
    data_taxa$DBH2011_mm_clean <= 300
] <- 300
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 300 &
    data_taxa$DBH2011_mm_clean <= 400
] <- 400
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 400 &
    data_taxa$DBH2011_mm_clean <= 500
] <- 500
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 500 &
    data_taxa$DBH2011_mm_clean <= 600
] <- 600
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 600 &
    data_taxa$DBH2011_mm_clean <= 700
] <- 700
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 700 &
    data_taxa$DBH2011_mm_clean <= 800
] <- 800
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 800 &
    data_taxa$DBH2011_mm_clean <= 900
] <- 900
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 900 &
    data_taxa$DBH2011_mm_clean <= 1000
] <- 1000
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1000 &
    data_taxa$DBH2011_mm_clean <= 1100
] <- 1100
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1100 &
    data_taxa$DBH2011_mm_clean <= 1200
] <- 1200
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1200 &
    data_taxa$DBH2011_mm_clean <= 1300
] <- 1300
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1300 &
    data_taxa$DBH2011_mm_clean <= 1400
] <- 1400
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1400 &
    data_taxa$DBH2011_mm_clean <= 1500
] <- 1500
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1500 &
    data_taxa$DBH2011_mm_clean <= 1600
] <- 1600
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1600 &
    data_taxa$DBH2011_mm_clean <= 1700
] <- 1700
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1700 &
    data_taxa$DBH2011_mm_clean <= 1800
] <- 1800
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1800 &
    data_taxa$DBH2011_mm_clean <= 1900
] <- 1900
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1900 &
    data_taxa$DBH2011_mm_clean <= 2000
] <- 2000

# Prepare data_taxa for saving

names(data_taxa)
data_taxa <- data_taxa[
  ,
  c("Block", "Plot", "PlotID", "TagStem_latest", "PFT_final", "PFT_name", "dbh")
]
colnames(data_taxa) <- c(
  "Block", "Plot", "PlotID", "TagStem_latest", "PFT_final",
  "PFT_name", "DBH_class"
)

data_taxa <- data_taxa[
  order(
    data_taxa$Block, data_taxa$Plot,
    data_taxa$PFT_final, data_taxa$DBH_class
  ),
]

maxrows <- nrow(data_taxa)
rownames(data_taxa) <- c(1:maxrows)

# Subset and convert dbh to m

data_taxa <- data_taxa[, c("Block", "Plot", "PlotID", "PFT_final", "DBH_class")]
data_taxa$DBH_class <- data_taxa$DBH_class / 1000

# Save file

write.csv(
  data_taxa,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution.csv", # nolint
  row.names = FALSE
)

################################################################################

# Exploring the variability in PFT cohort distribution across plots

data_taxa <- read.csv("../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution.csv") # nolint
data <- data_taxa
names(data)

data$Block <- as.factor(data$Block)
data$PlotID <- as.factor(data$PlotID)
data$PFT_final <- as.factor(data$PFT_final)

plots <- unique(data$PlotID)
plots

length(unique(plots)) # 27
25 * 25 * 27 # total area
nrow(data) / (25 * 25 * 27) # average stem density of 0.05 per m2
nrow(data) / (25 * 25 * 27) * 10000 # average stem density per hectare

# Plots

# Plot using OG1, OG2 and OG3 - split up per Block (expressed as proportion %)
ggplot(data, aes(x = Block, fill = PFT_final)) +
  geom_bar(position = "fill") + # Normalizes counts within each PlotID
  scale_y_continuous(labels = scales::percent_format()) + # Shows y-axis as percentages
  labs(
    title = "Proportion of PFTs within Plots",
    x = "Block",
    y = "Proportion",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

# Same figure but absolute stack
ggplot(data, aes(x = Block, fill = PFT_final)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Block by PFT",
    x = "Block",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

# Same figure but bars not stacked
ggplot(data, aes(x = Block, fill = PFT_final)) + # Use PFT to differentiate the bars
  geom_bar(stat = "count", position = "dodge") +
  labs(
    title = "Number of Trees per Block by PFT",
    x = "Block",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

##########

# Plot using OG1, OG2 and OG3 - split up per PlotID (expressed as proportion %)
ggplot(data, aes(x = PlotID, fill = PFT_final)) +
  geom_bar(position = "fill") + # Normalizes counts within each PlotID
  scale_y_continuous(labels = scales::percent_format()) + # Shows y-axis as percentages
  labs(
    title = "Proportion of PFTs within Plots",
    x = "Plot ID",
    y = "Proportion",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

# Same figure but absolute stack
ggplot(data, aes(x = PlotID, fill = PFT_final)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Plot by PFT",
    x = "Plot ID",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

##########

# Barplot per DBH (should rescale this to per hectare and compare against other studies)

names(data)

ggplot(data, aes(x = DBH_class, fill = PFT_final)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Plot by PFT",
    x = "DBH",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()
