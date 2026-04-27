#| ---
#| title: Plant functional type cohort distribution Maliau 10x10
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
#|   - name: plant_functional_type_cohort_distribution_Maliau_10x10.csv
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
print("Grid cells = 10 x 10 = 100")
print("Each cell is a square with area = 10000 m2")
print("This means we do not need to rescale the cohort data from 10000 m2")
print("Then multiply the base cohort distribution by 100, one for each cell")

# Load base cohort distribution per hectare
base_cohort_distribution <- read.csv(
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_per_hectare.csv"
)

# Add individuals with dbh <10 cm (as these are not included in the Maliau census)
# Use the value reported in Kenzo et al. (2015) for Balai Ringin site,
# DOI: https://doi.org/10.1007/s10310-014-0465-y
# then distribute these across 3 dbh classes following the size distribution in
# Lee et al. (2002), then spread evenly across PFTs.
# DOI: https://www.jstor.org/stable/43594474

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

# Now add these to base_cohort_distribution (and distribute these across PFTs)
# Note that for primary forest we only spread the seedlings across
# emergent, overstory and understory but not pioneer because of the findings by
# Miyamoto et al. (2024; DOI https://doi.org/10.3759/tropics.MS23-09)
# that reported 0 recruits for pioneers in Maliau
final_row <- nrow(base_cohort_distribution)

base_cohort_distribution[final_row + 1, ] <- c(
  trees_1_2 / 3,
  "emergent",
  dbh_1_2
)
base_cohort_distribution[final_row + 2, ] <- c(
  trees_1_2 / 3,
  "overstory",
  dbh_1_2
)
base_cohort_distribution[final_row + 3, ] <- c(
  trees_1_2 / 3,
  "understory",
  dbh_1_2
)
# base_cohort_distribution[final_row+x, ] <- c(0, "pioneer", dbh_1_2)

base_cohort_distribution[final_row + 4, ] <- c(
  trees_2_5 / 3,
  "emergent",
  dbh_2_5
)
base_cohort_distribution[final_row + 5, ] <- c(
  trees_2_5 / 3,
  "overstory",
  dbh_2_5
)
base_cohort_distribution[final_row + 6, ] <- c(
  trees_2_5 / 3,
  "understory",
  dbh_2_5
)
# base_cohort_distribution[final_row+x, ] <- c(0, "pioneer", dbh_2_5)

base_cohort_distribution[final_row + 7, ] <- c(
  trees_5_10 / 3,
  "emergent",
  dbh_5_10
)
base_cohort_distribution[final_row + 8, ] <- c(
  trees_5_10 / 3,
  "overstory",
  dbh_5_10
)
base_cohort_distribution[final_row + 9, ] <- c(
  trees_5_10 / 3,
  "understory",
  dbh_5_10
)
# base_cohort_distribution[final_row+x, ] <- c(0, "pioneer", dbh_5_10)

# Note that above we technically account for all seedlings/saplings with a dbh
# between 1 and 10 cm dbh. Currently, the cohort distribution also has a
# dbh class of 10 cm with very few individuals. This is because the Maliau
# census data had a lower dbh limit of 10 cm, and therefore these few individuals
# are likely sporadic recordings that were close to (but below) this lower limit.
# Because the approach above accounts for all seedlings/saplings below dbh 10 cm,
# I think we can exclude the dbh class of 10 cm from the Maliau census data.
# If we do not exlude them, then we'd be "counting them twice" since they
# should already be included in the seedling/sapling density reported by Kenzo et al.

base_cohort_distribution <-
  base_cohort_distribution[base_cohort_distribution$plant_cohorts_dbh != 0.1, ]

# Reorder by dbh within PFT
base_cohort_distribution <-
  base_cohort_distribution[
    order(
      base_cohort_distribution$plant_cohorts_pft,
      base_cohort_distribution$plant_cohorts_dbh
    ),
  ]

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
# base_cohort_distribution$plant_cohorts_n_scaled <- # only used when scaling
#  base_cohort_distribution$plant_cohorts_n / 10000 * 8100 # only used when scaling
base_cohort_distribution$plant_cohorts_n_scaled <- # replace this line with the one above when scaling
  base_cohort_distribution$plant_cohorts_n

# Round up/down as decimal individuals do not exist
base_cohort_distribution$plant_cohorts_n_scaled_rounded <-
  round(base_cohort_distribution$plant_cohorts_n_scaled)

# Subset columns and correct for amount of cells (start counting from 0)
base_cohort_distribution <-
  base_cohort_distribution[, c(
    "plant_cohorts_cell_id",
    "plant_cohorts_n_scaled_rounded",
    "plant_cohorts_pft",
    "plant_cohorts_dbh"
  )]

cell_id <- 1:99 # we start from 1 here because the first cohort (0) is the base

for (i in cell_id) {
  base_x <-
    base_cohort_distribution[
      base_cohort_distribution$plant_cohorts_cell_id == 0,
    ]
  base_x$plant_cohorts_cell_id <- i
  base_cohort_distribution <-
    rbind(base_cohort_distribution, base_x)
}

# Final colnames
colnames(base_cohort_distribution) <-
  c(
    "plant_cohorts_cell_id",
    "plant_cohorts_n",
    "plant_cohorts_pft",
    "plant_cohorts_dbh"
  )

# Save scaled cohort distribution
write.csv(
  base_cohort_distribution,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_Maliau_10x10.csv",
  row.names = FALSE
)
