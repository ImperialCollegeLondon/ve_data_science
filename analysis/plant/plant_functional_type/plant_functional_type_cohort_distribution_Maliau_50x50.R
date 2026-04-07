#| ---
#| title: Plant functional type cohort distribution Maliau 50x50
#|
#| description: |
#|     This script loads the PFT cohort distribution per hectare and scales it
#|     according to the grid used in a particular model run. In this case,
#|     the grid is based on the info in Maliau site definition.
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
#|   - name: plant_functional_type_cohort_distribution_per_hectare.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains the number of individuals per DBH class for each PFT,
#|       standardised as a count per hectare.
#|
#| output_files:
#|   - name: plant_functional_type_cohort_distribution_Maliau_50x50.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains an overview of the individuals per
#|       DBH class for each PFT, for each cell.
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|     - tidyr
#|
#| usage_notes: |
#|   This script can be copied and adjusted if the grid changes.
#| ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)

# Extract grid info from sites definition
print("Grid cells = 50 x 50 = 2500")
print("Each cell is a square with area = 10000 m2")
print("This means we do not need to rescale the cohort data from 10000 m2")
print("Then multiply the base cohort distribution by 2500, one for each cell")

# Load base cohort distribution per hectare
base_cohort_distribution <- read.csv("../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_per_hectare.csv") # nolint

# Add individuals with dbh <10 cm (as these are not included in the Maliau census)
# Use the value reported in Kenzo et al. (2015) for Balai Ringin site,
# then distribute these across 3 dbh classes following the size distribution in
# Lee et al. (2002), then spread evenly across PFTs.

dbh_1_2 <- (((2 - 1) / 2) + 1) / 100
dbh_2_5 <- (((5 - 2) / 2) + 2) / 100
dbh_5_10 <- (((10 - 5) / 2) + 5) / 100

total_percent <- 41.15 + 37.59 + 12.11

percent_1_2 <- 41.15 / total_percent * 100
percent_2_5 <- 37.59 / total_percent * 100
percent_5_10 <- 12.11 / total_percent * 100

kenzo_trees_below_10 <- 5000

trees_1_2 <- kenzo_trees_below_10 * percent_1_2 / 100
trees_2_5 <- kenzo_trees_below_10 * percent_2_5 / 100
trees_5_10 <- kenzo_trees_below_10 * percent_5_10 / 100

# Now add these to base_cohort_distribution (and spread evenly across PFTs)
nrow(base_cohort_distribution)

base_cohort_distribution[32, ] <- c(trees_1_2 / 4, "emergent", dbh_1_2)
base_cohort_distribution[33, ] <- c(trees_1_2 / 4, "overstory", dbh_1_2)
base_cohort_distribution[34, ] <- c(trees_1_2 / 4, "understory", dbh_1_2)
base_cohort_distribution[35, ] <- c(trees_1_2 / 4, "pioneer", dbh_1_2)

base_cohort_distribution[36, ] <- c(trees_2_5 / 4, "emergent", dbh_2_5)
base_cohort_distribution[37, ] <- c(trees_2_5 / 4, "overstory", dbh_2_5)
base_cohort_distribution[38, ] <- c(trees_2_5 / 4, "understory", dbh_2_5)
base_cohort_distribution[39, ] <- c(trees_2_5 / 4, "pioneer", dbh_2_5)

base_cohort_distribution[40, ] <- c(trees_5_10 / 4, "emergent", dbh_5_10)
base_cohort_distribution[41, ] <- c(trees_5_10 / 4, "overstory", dbh_5_10)
base_cohort_distribution[42, ] <- c(trees_5_10 / 4, "understory", dbh_5_10)
base_cohort_distribution[43, ] <- c(trees_5_10 / 4, "pioneer", dbh_5_10)

# Reorder by dbh within PFT
base_cohort_distribution <-
  base_cohort_distribution[order(
    base_cohort_distribution$plant_cohorts_pft,
    base_cohort_distribution$plant_cohorts_dbh
  ), ]

# Change to numeric
base_cohort_distribution$plant_cohorts_n <-
  as.numeric(base_cohort_distribution$plant_cohorts_n)
base_cohort_distribution$plant_cohorts_dbh <-
  as.numeric(base_cohort_distribution$plant_cohorts_dbh)

# Add plant_cohorts_cell_id, start counting from 0
base_cohort_distribution$plant_cohorts_cell_id <- 0
base_cohort_distribution$plant_cohorts_cell_id <-
  as.integer(base_cohort_distribution$plant_cohorts_cell_id)

# Scale plant_cohorts_n from 10000 to 8100
# base_cohort_distribution$plant_cohorts_n_scaled <- # only used when scaling # nolint
#  base_cohort_distribution$plant_cohorts_n / 10000 * 8100 # only used when scaling # nolint
base_cohort_distribution$plant_cohorts_n_scaled <- # replace this line with the one above when scaling # nolint
  base_cohort_distribution$plant_cohorts_n

# Round up/down as decimal individuals do not exist
base_cohort_distribution$plant_cohorts_n_scaled_rounded <-
  round(base_cohort_distribution$plant_cohorts_n_scaled)

# Subset columns and correct for amount of cells (start counting from 0)
base_cohort_distribution <-
  base_cohort_distribution[, c(
    "plant_cohorts_cell_id", "plant_cohorts_n_scaled_rounded",
    "plant_cohorts_pft", "plant_cohorts_dbh"
  )]

cell_id <- 1:2499 # we start from 1 here because the first cohort (0) is the base

for (i in cell_id) {
  base_x <-
    base_cohort_distribution[base_cohort_distribution$plant_cohorts_cell_id == 0, ]
  base_x$plant_cohorts_cell_id <- i
  base_cohort_distribution <-
    rbind(base_cohort_distribution, base_x)
}

# Final colnames
colnames(base_cohort_distribution) <-
  c(
    "plant_cohorts_cell_id", "plant_cohorts_n",
    "plant_cohorts_pft", "plant_cohorts_dbh"
  )

# Save scaled cohort distribution
write.csv(
  base_cohort_distribution,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_Maliau_50x50.csv", # nolint
  row.names = FALSE
)
