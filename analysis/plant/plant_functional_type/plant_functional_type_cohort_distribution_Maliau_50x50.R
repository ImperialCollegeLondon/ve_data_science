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
print("Grid cells = 50 x 50 = 250")
print("Each cell is a square with area = 8100 m2")
print("This means we need to scale the cohort data from 10000 m2 to 8100 m2")
print("Then multiply the base cohort distribution by 250, one for each cell")

# Load base cohort distribution per hectare
base_cohort_distribution <- read.csv("../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_per_hectare.csv") # nolint

# Add plant_cohorts_cell_id, start counting from 0
base_cohort_distribution$plant_cohorts_cell_id <- 0
base_cohort_distribution$plant_cohorts_cell_id <-
  as.integer(base_cohort_distribution$plant_cohorts_cell_id)

# Scale plant_cohorts_n from 10000 to 8100
base_cohort_distribution$plant_cohorts_n_scaled <-
  base_cohort_distribution$plant_cohorts_n / 10000 * 8100

# Round up/down as decimal individuals do not exist
base_cohort_distribution$plant_cohorts_n_scaled_rounded <-
  round(base_cohort_distribution$plant_cohorts_n_scaled)

# Subset columns and correct for amount of cells (start counting from 0)
base_cohort_distribution <-
  base_cohort_distribution[, c(
    "plant_cohorts_cell_id", "plant_cohorts_n_scaled_rounded",
    "plant_cohorts_pft", "plant_cohorts_dbh"
  )]

cell_id <- 1:249 # we start from 1 here because the first cohort (0) is the base

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
