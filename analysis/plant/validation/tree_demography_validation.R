#| ---
#| title: Tree demography validation
#|
#| description: |
#|     This script focuses on validating the tree demography outputs from the
#|     VE simulation for the Maliau scenario.
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
#|   - name: tree_census_11_20.xlsx
#|     path: data/primary/plant/tree_census
#|     description: |
#|       https://doi.org/10.5281/zenodo.14882506
#|       Tree census data from the SAFE Project 2011–2020.
#|       Data includes measurements of DBH and estimates of tree height for all
#|       stems, fruiting and flowering estimates,
#|       estimates of epiphyte and liana cover, and taxonomic IDs.
#|   - name: plant_functional_type_species_classification_base.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains a list of species and their respective PFT.
#|   - name: plants_cohort_data.csv
#|     path: data/scenarios/maliau/maliau_1\out
#|     description: |
#|       Plant cohort data obtained from VE simulation.
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
#|   This script can be used for different simulations, just need to change the
#|   name/path of the plants_cohort_data.csv file - and also change the number
#|   of rows in plants_cohort_data that are seen as setup rows.
#| ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)

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

# Add PFT and PFT_name to data based on TaxaName and call it data_taxa

data_taxa <- left_join(data, PFT_species_classification_base, by = "TaxaName")

# Give plots a logging indicator

data_taxa$logging <- NA
data_taxa$logging[data_taxa$Block %in%
  c(
    "LFE", "LF1", "LF2", "LF3"
  )] <- "logged"
data_taxa$logging[data_taxa$Block %in%
  c(
    "A", "B", "C", "D", "E", "F", "VJR", "OG1",
    "OG2", "OG3"
  )] <- "unlogged"
data_taxa$logging[data_taxa$Block %in%
  c(
    "OP1", "OP2", "OP3"
  )] <- "oil_palm"

unique(data_taxa$logging)

data_taxa <- data_taxa[data_taxa$Block %in%
  c(
    "LFE", "LF1", "LF2", "LF3", "A", "B", "C", "D",
    "E", "F", "VJR", "OG1", "OG2", "OG3"
  ), ]

# Load plants cohort data
# Note that the name/path need to be updated depending on which simulation is used

plants_cohort_data <- read.csv( # nolint
  "../../../data/scenarios/maliau/maliau_1/out/plants_cohort_data.csv", # nolint
  header = TRUE
)

names(plants_cohort_data)

plants_cohort_data <-
  plants_cohort_data[, c(
    "cohort_id", "n_individuals", "dbh",
    "time_index", "pft_names", "cell_id"
  )]

# Subset to desired number of cells (substantially speeds up processing)
# The code works for all cells but this takes very long to run

plants_cohort_data <- plants_cohort_data[plants_cohort_data$cell_id %in% c(0:10), ]

# check how many unique cohorts in the simulation

cohort_id <- unique(plants_cohort_data$cohort_id)
length(cohort_id)

# For timestep = 0 need to use the values for setup to calculate the difference
# with timestep = 0 (at the end of the timestep) to get mortality and recruits
# So first calculate this, then remove the setup rows, then loop for t=1,2,..,max

# for each cohort calculate mortality as n at t minus n at t-1.
# If this value is negative it means this amount of n died
# Note that this value can never be positive (new recruits are always given a
# new cohort_id - and so are never merged into existing cohorts)

plants_cohort_data$setup <- "no"

# Here need to manually check how many setup rows there are
# Basically check within time_index = 0 where cell_id resets to 0
# For all cell_id's the setup rows are 85000, which is 2500 cells * 34 unique
# cohorts per cell (e.g., cell_id = 0)
# However, this takes very long to run, so for now just use cell_id 0:10 example
# plants_cohort_data$setup[1:85000] <- "yes" # nolint

plants_cohort_data$setup[1:374] <- "yes"

plants_cohort_data$mortality <- 0

# Widely used formula (Sheil et al. 1995) for annual mortality

# First need to calculate mortality per cohort in first timestep
# Need to use the individuals from setup as initial n individuals

for (j in unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == 0])) {
  plants_cohort_data$mortality[
    plants_cohort_data$time_index == 0 & plants_cohort_data$cohort_id == j
  ] <-
    plants_cohort_data$n_individuals[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "yes"
    ] -
    plants_cohort_data$n_individuals[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "no"
    ]
}

# Do the same for recruits
# Take unique cohorts where setup = "no" that only occurred here for t=0 but not
# for setup = "yes"
# These cohorts are the new recruits

initial_cohorts_setup <-
  unique(plants_cohort_data$cohort_id[plants_cohort_data$setup == "yes"])
initial_cohorts_t0 <- unique(plants_cohort_data$cohort_id[
  plants_cohort_data$setup == "no" & plants_cohort_data$time_index == 0
])
recruits_cohorts_t0 <- setdiff(initial_cohorts_t0, initial_cohorts_setup)
plants_cohort_data$recruits[
  plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
] <-
  plants_cohort_data$n_individuals[
    plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
  ]

# Only now the setup rows can be deleted

plants_cohort_data <- plants_cohort_data[plants_cohort_data$setup == "no", ]

for (j in unique(plants_cohort_data$cohort_id)) {
  for (i in 1:max(plants_cohort_data$time_index)) {
    plants_cohort_data$mortality[
      plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
    ] <-
      plants_cohort_data$n_individuals[
        plants_cohort_data$time_index == (i - 1) & plants_cohort_data$cohort_id == j
      ] -
      plants_cohort_data$n_individuals[
        plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
      ]
  }
}

# Do the same for recruits

for (i in 1:max(plants_cohort_data$time_index)) {
  initial_cohorts_t <-
    unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == i])
  initial_cohorts_t_previous <-
    unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == (i - 1)])

  recruits_cohorts <- setdiff(initial_cohorts_t, initial_cohorts_t_previous)
  plants_cohort_data$recruits[
    plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
  ] <-
    plants_cohort_data$n_individuals[
      plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
    ]
}

# Replace NA in recruits with 0
plants_cohort_data$recruits[is.na(plants_cohort_data$recruits)] <- 0

#####

# Now calculate mortality rate per timestep per cell_id
# Do this for each cohort and for total stem density
# Only do this where n_individuals > 0 as cannot divide by 0
# So far this only applies to when all individuals died during setup
for (i in unique(plants_cohort_data$time_index)) {
  plants_cohort_data$mortality_rate[plants_cohort_data$time_index == i & plants_cohort_data$n_individuals > 0] <- # nolint
    plants_cohort_data$mortality[plants_cohort_data$time_index == i & plants_cohort_data$n_individuals > 0] / # nolint
      plants_cohort_data$n_individuals[plants_cohort_data$time_index == i & plants_cohort_data$n_individuals > 0] # nolint
}

plants_cohort_data$mortality_rate[plants_cohort_data$n_individuals == 0 & plants_cohort_data$mortality > 0] <- 1 # nolint
plants_cohort_data$mortality_rate[plants_cohort_data$n_individuals == 0 & plants_cohort_data$mortality == 0] <- 0 # nolint

# Here need to subset per cell_id
for (j in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$mortality_rate_total[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j] <- # nolint
      sum(plants_cohort_data$mortality[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j]) / # nolint
        sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j]) # nolint
  }
}

# Convert monthly mortality probability to yearly to compare with input data
# mortality probability (note: cannot just multiply by 12)
plants_cohort_data$mortality_rate_annual <-
  1 - (1 - plants_cohort_data$mortality_rate)^12
plants_cohort_data$mortality_rate_total_annual <-
  1 - (1 - plants_cohort_data$mortality_rate_total)^12

# At cohort level mortality is higher than expected
# This is likely elevated when cohort individuals is smaller
plot(mortality_rate_annual ~ time_index,
  data = plants_cohort_data[plants_cohort_data$mortality_rate_annual > 0, ]
)
abline(h = 0.1)
mean_CI <- Rmisc::CI(plants_cohort_data$mortality_rate_annual[
  plants_cohort_data$mortality_rate_annual > 0
], ci = 0.95)
print(c(mean_CI[1], mean_CI[2], mean_CI[3]))
abline(h = mean_CI[2], col = "red")
abline(h = mean_CI[1], col = "red", lty = "dashed")
abline(h = mean_CI[3], col = "red", lty = "dashed")

# At total level mortality is slightly lower than expected based on input (0.0159)
plot(mortality_rate_total_annual ~ time_index,
  data = plants_cohort_data[plants_cohort_data$mortality_rate_total_annual > 0, ]
)
abline(h = 0.1)
mean_CI <- Rmisc::CI(plants_cohort_data$mortality_rate_total_annual[
  plants_cohort_data$mortality_rate_total_annual > 0
], ci = 0.95)
print(c(mean_CI[1], mean_CI[2], mean_CI[3]))
abline(h = mean_CI[2], col = "red")
abline(h = mean_CI[1], col = "red", lty = "dashed")
abline(h = mean_CI[3], col = "red", lty = "dashed")

###

# Now calculate recruitment rates
# Recruitment rate depends on success of regeneration from soil seedbank
# as well as success to survive initial seedling stage
# To validate recruits per timestep, convert recruits to recruitment_rate_annual
# Then compare this to existing studies

# Calculate recruitment relative to total stem density
for (j in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$recruitment_rate_total[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j] <- # nolint
      sum(plants_cohort_data$recruits[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j]) / # nolint
        sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j]) # nolint
  }
}

plot(plants_cohort_data$recruitment_rate_total ~ plants_cohort_data$time_index)

# Convert recruits to annual values
plants_cohort_data$recruits_annual <-
  plants_cohort_data$recruits * 12

plot(plants_cohort_data$recruits_annual ~ plants_cohort_data$time_index)

# Now sum across PFTs to get total annual recruitment per cell
for (j in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$recruits_total_annual[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j] <- # nolint
      sum(plants_cohort_data$recruits_annual[plants_cohort_data$time_index == i & plants_cohort_data$cell_id == j]) # nolint
  }
}

#####

# Compare this to recruitment for Danum Valley (Lingenfelder and Newbery, 2009)
# Need to check what counts as a recruit (already passed the seedling stage?)

recruits_1996 <- 295
recruits_2001 <- 157

recruitment_rate_total_1996 <- 295 / 2158
recruitment_rate_total_2001 <- 157 / 2078

# Compare to VE:
# Recruitment in VE seems too low, but this may be caused by the seedbank being
# too low (see issue #246)

# Also note that VE recruitment technically represents germinated seeds
# There is no selection filter to account for seedling/sapling mortality
# The same mortality probability of adult trees is used for seedlings

unique(plants_cohort_data$recruits_total_annual)
mean(unique(plants_cohort_data$recruits_total_annual))

unique(plants_cohort_data$recruitment_rate_total)
mean(unique(plants_cohort_data$recruitment_rate_total))

##########

# To do:

# - compare mean (+-95% CI) mortality_rate_total_annual with validation data
# - compare mean (+-95% CI) recruits_annual with validation data
# - compare mean (+-95% CI) recruitment_rate_total with validation data

# Need to write out the units in the script (cell area = 10000 m2)

##########

# Check tree census to see if mortality can be calculated

names(data_taxa)

unique(data_taxa$PFT_name)
pft <- c("emergent", "pioneer", "understory", "overstory")

data <- data_taxa
data <- data[
  ,
  c(
    "Block", "TagStem_latest", "FirstRecord_year_IND",
    "Dead_year_IND", "PFT_name"
  )
]

data <- data[data$Block %in% c("OG1", "OG2", "OG3"), ]

# total area for OG1, OG2 and OG3 combined = 3 times (9 * (25 * 25)) m2
# so total = 16875 m2

# calculate mean mortality across the 3 plots for each census period
# 2014, 2015, 2016, 2017, 2019
unique(data$FirstRecord_year_IND)
unique(data$Dead_year_IND)

# subset to trees that were recorded in 2011
data <- data[data$FirstRecord_year_IND == "2011", ]

###

# Note that by subsetting to 2011 we can only calculate the mortality across
# periods for these 2011 trees. There will also be mortality for trees that
# were recorded after 2011 but we do not take these into account.
# So, the mortality rate for different periods is to get an average mortality
# rate across years.

# 2011-2014
dead <- length(data$TagStem_latest[data$Dead_year_IND == "2014"])
dead
total <- length(data$TagStem_latest)
total

data$mortality_2011_2014 <- 1 - (((total - dead) / total)^(1 / 4))
unique(data$mortality_2011_2014) # annual probability of mortality per year

# 2011-2015
dead <- length(data$TagStem_latest[data$Dead_year_IND %in% c("2014", "2015")])
dead
total <- length(data$TagStem_latest)
total

data$mortality_2011_2015 <- 1 - (((total - dead) / total)^(1 / 5))
unique(data$mortality_2011_2015) # annual probability of mortality per year

# 2011-2016
dead <- length(data$TagStem_latest[data$Dead_year_IND %in% c("2014", "2015", "2016")])
dead
total <- length(data$TagStem_latest)
total

data$mortality_2011_2016 <- 1 - (((total - dead) / total)^(1 / 6))
unique(data$mortality_2011_2016) # annual probability of mortality per year

# 2011-2017
dead <- length(data$TagStem_latest[
  data$Dead_year_IND %in% c("2014", "2015", "2016", "2017")
])
dead
total <- length(data$TagStem_latest)
total

data$mortality_2011_2017 <- 1 - (((total - dead) / total)^(1 / 7))
unique(data$mortality_2011_2017) # annual probability of mortality per year

# 2011-2019
dead <- length(data$TagStem_latest[
  data$Dead_year_IND %in% c("2014", "2015", "2016", "2017", "2019")
])
dead
total <- length(data$TagStem_latest)
total

data$mortality_2011_2019 <- 1 - (((total - dead) / total)^(1 / 9))
unique(data$mortality_2011_2019) # annual probability of mortality per year

# calculate mean

names(data)

rates <- c(
  unique(data$mortality_2011_2014),
  unique(data$mortality_2011_2015),
  unique(data$mortality_2011_2016),
  unique(data$mortality_2011_2017),
  unique(data$mortality_2011_2019)
)
rates
mean_CI <- Rmisc::CI(rates, ci = 0.95)
print(c(mean_CI[1], mean_CI[2], mean_CI[3]))

# Compare this value with the value for mortality_rate_total_annual
Rmisc::CI(
  plants_cohort_data$mortality_rate_total_annual[
    plants_cohort_data$mortality_rate_total_annual > 0
  ],
  ci = 0.95
)

# Note that cell_id's / timesteps where mortality_rate_total_annual = 0 should
# not be excluded when calculating the mean, so use the mean calculated below

names(plants_cohort_data)
temp <- plants_cohort_data[, c("cell_id", "time_index", "mortality_rate_total_annual")]
temp <- unique(temp)

Rmisc::CI(
  temp$mortality_rate_total_annual,
  ci = 0.95
)

# Note that the VE simulation used the mortality probability (0.0159) and this
# seems to match Maliau census data very well when mortality_rate_total_annual
# = 0 is excluded
# However, when mortality_rate_total_annual = 0 is included then the mean
# mortality is 0.01268095 (which matches the mortality probability but is
# lower than the calculated mortality from the Maliau census dataset)
