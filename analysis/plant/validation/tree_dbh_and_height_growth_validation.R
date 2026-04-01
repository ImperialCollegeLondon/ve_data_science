#| ---
#| title: Tree dbh and height growth validation
#|
#| description: |
#|     This script focuses on validating the tree growth outputs (dbh and height)
#|     from the VE simulation for the Maliau scenario.
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
    "cohort_id", "n_individuals", "dbh", "stem_height", "delta_dbh",
    "time_index", "pft_names", "cell_id"
  )]

# Subset to desired number of cells (substantially speeds up processing)
# The code works for all cells but this takes very long to run

plants_cohort_data <- plants_cohort_data[plants_cohort_data$cell_id %in% c(0:10), ]

# check how many unique cohorts in the simulation

cohort_id <- unique(plants_cohort_data$cohort_id)
length(cohort_id)

plants_cohort_data$setup <- "no"

# Here need to manually check how many setup rows there are
# Basically check within time_index = 0 where cell_id resets to 0
# For all cell_id's the setup rows are 85000, which is 2500 cells * 34 unique
# cohorts per cell (e.g., cell_id = 0)
# However, this takes very long to run, so for now just use cell_id 0:10 example
# plants_cohort_data$setup[1:85000] <- "yes" # nolint

plants_cohort_data$setup[1:374] <- "yes"

# Calculate change in dbh and height from setup to end of first timestep (0)

# Preferably, this should be done per PFT and should distinguish between different
# sizes (so either for each cohort, or e.g. trees above dbh = 0.1 m)

# As a first test, follow the approach by Newbery and Lingenfelder (2009) who
# measured stem relative growth (mm m-1 year-1) over all individuals over all species
# Note that the study above uses girth at breast height, not diameter, so convert
# the reported values to dbh later on when comparing to dbh growth from VE outputs.
# It looks like the RGR values are already converted to DBH growth.

for (j in unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == 0])) {
  plants_cohort_data$dbh_growth[
    plants_cohort_data$time_index == 0 & plants_cohort_data$cohort_id == j
  ] <-
    (plants_cohort_data$dbh[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "no"
    ] - plants_cohort_data$dbh[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "yes"
    ]) * 12 # Convert to yearly values

  plants_cohort_data$relative_dbh_growth[
    plants_cohort_data$time_index == 0 & plants_cohort_data$cohort_id == j
  ] <-
    (((plants_cohort_data$dbh[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "no"
    ] - plants_cohort_data$dbh[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "yes"
    ]) * 1000) / # Convert to mm values
      plants_cohort_data$dbh[ # nolint
        plants_cohort_data$time_index == 0 & # nolint
          plants_cohort_data$cohort_id == j & # nolint
          plants_cohort_data$setup == "yes"
      ]) * 12 # Convert to yearly values # nolint
}

# Do the same for recruits (they do not have setup values so assume dbh_growth
# to be equal to the dbh value
# Take unique cohorts where setup = "no" that only occurred here for t=0 but not
# for setup = "yes"
# These cohorts are the new recruits

initial_cohorts_setup <-
  unique(plants_cohort_data$cohort_id[plants_cohort_data$setup == "yes"])
initial_cohorts_t0 <- unique(plants_cohort_data$cohort_id[
  plants_cohort_data$setup == "no" & plants_cohort_data$time_index == 0
])
recruits_cohorts_t0 <- setdiff(initial_cohorts_t0, initial_cohorts_setup)
plants_cohort_data$dbh_growth[
  plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
] <-
  (plants_cohort_data$dbh[
    plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
  ]) * 12 # Convert to yearly values
# Note relative growth for recruits cannot be calculated (cannot divide by 0)

# Note that the above can be replaced by:
# - multiplying delta_dbh * 12 (to get yearly dbh growth)
# - multiplying delta_dbh by 1000 to get mm, then divide by dbh (m) then multiply
#   by 12 to get relative dbh growth (mm m-1 year-1)
# However, this is not possible for the first timestep (as delta_dbh values = NA)
# Therefore, I'll leave the script as it is

# Now repeat the above for height_growth

for (j in unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == 0])) {
  plants_cohort_data$height_growth[
    plants_cohort_data$time_index == 0 & plants_cohort_data$cohort_id == j
  ] <-
    (plants_cohort_data$stem_height[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "no"
    ] - plants_cohort_data$stem_height[
      plants_cohort_data$time_index == 0 &
        plants_cohort_data$cohort_id == j & # nolint
        plants_cohort_data$setup == "yes"
    ]) * 12 # Convert to yearly values
}

# Do the same for recruits (they do not have setup values so assume all height
# gain occurred within that timestep
# Take unique cohorts where setup = "no" that only occurred here for t=0 but not
# for setup = "yes"
# These cohorts are the new recruits

initial_cohorts_setup <-
  unique(plants_cohort_data$cohort_id[plants_cohort_data$setup == "yes"])
initial_cohorts_t0 <- unique(plants_cohort_data$cohort_id[
  plants_cohort_data$setup == "no" & plants_cohort_data$time_index == 0
])
recruits_cohorts_t0 <- setdiff(initial_cohorts_t0, initial_cohorts_setup)
plants_cohort_data$height_growth[
  plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
] <-
  (plants_cohort_data$stem_height[
    plants_cohort_data$cohort_id %in% recruits_cohorts_t0 & plants_cohort_data$time_index == 0 # nolint
  ]) * 12 # Convert to yearly values

#####

# Only now the setup rows can be deleted

plants_cohort_data <- plants_cohort_data[plants_cohort_data$setup == "no", ]

# Now calculate dbh_growth, relative_dbh_growth and height_growth for all other
# non-setup rows
# Remember to convert to yearly values

for (j in unique(plants_cohort_data$cohort_id)) {
  for (i in 1:max(plants_cohort_data$time_index)) {
    plants_cohort_data$dbh_growth[
      plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
    ] <-
      (plants_cohort_data$dbh[
        plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
      ] - plants_cohort_data$dbh[
        plants_cohort_data$time_index == (i - 1) & plants_cohort_data$cohort_id == j
      ]) * 12 # Convert to yearly values

    plants_cohort_data$relative_dbh_growth[
      plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
    ] <-
      (((plants_cohort_data$dbh[
        plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
      ] - plants_cohort_data$dbh[
        plants_cohort_data$time_index == (i - 1) & plants_cohort_data$cohort_id == j
      ]) * 1000) / # Convert to mm values
        plants_cohort_data$dbh[ # nolint
          plants_cohort_data$time_index == (i - 1) & plants_cohort_data$cohort_id == j
        ]) * 12 # Convert to yearly values

    plants_cohort_data$height_growth[
      plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
    ] <-
      (plants_cohort_data$stem_height[
        plants_cohort_data$time_index == i & plants_cohort_data$cohort_id == j
      ] - plants_cohort_data$stem_height[
        plants_cohort_data$time_index == (i - 1) & plants_cohort_data$cohort_id == j
      ]) * 12 # Convert to yearly values
  }
}

# Do the same for recruits
# Note: relative_dbh_growth cannot be calculated for recruits (cannot divide by 0)

for (i in 1:max(plants_cohort_data$time_index)) {
  initial_cohorts_t <-
    unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == i])
  initial_cohorts_t_previous <-
    unique(plants_cohort_data$cohort_id[plants_cohort_data$time_index == (i - 1)])
  recruits_cohorts <- setdiff(initial_cohorts_t, initial_cohorts_t_previous)

  plants_cohort_data$dbh_growth[
    plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
  ] <-
    (plants_cohort_data$dbh[
      plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
    ]) * 12 # Convert to yearly values

  plants_cohort_data$height_growth[
    plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
  ] <-
    (plants_cohort_data$stem_height[
      plants_cohort_data$cohort_id %in% recruits_cohorts & plants_cohort_data$time_index == i # nolint
    ]) * 12 # Convert to yearly values
}

#####

# Now calculate the mean for all (>10cm gbh) and small (10 to <50cm gbh)
# Note this is gbh, not dbh, so convert gbh thresholds to dbh
# Note that for now I will use dbh_growth, since the values for relative_dbh_growth
# are too unrealistic for now, so just plot the dbh_growth to get an idea of how
# this fluctuates over time

# Note that absolute growth rates are available for small trees in
# Lingenfelder and Newbery (2009) Table 5

# diameter equals gbh divided by pi, then divide by 100 to convert to m
(10 / pi) / 100
(50 / pi) / 100

Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.03183099
], ci = 0.95)

Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.1591549
], ci = 0.95)

# Now do the same but for each PFT

# emergent
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.03183099 &
    plants_cohort_data$pft_names == "emergent"
], ci = 0.95)
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.1591549 &
    plants_cohort_data$pft_names == "emergent"
], ci = 0.95)

# overstory
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.03183099 &
    plants_cohort_data$pft_names == "overstory"
], ci = 0.95)
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.1591549 &
    plants_cohort_data$pft_names == "overstory"
], ci = 0.95)

# understory
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.03183099 &
    plants_cohort_data$pft_names == "understory"
], ci = 0.95)
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.1591549 &
    plants_cohort_data$pft_names == "understory"
], ci = 0.95)

# pioneer
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.03183099 &
    plants_cohort_data$pft_names == "pioneer"
], ci = 0.95)
Rmisc::CI(plants_cohort_data$dbh_growth[
  plants_cohort_data$dbh > 0.1591549 &
    plants_cohort_data$pft_names == "pioneer"
], ci = 0.95)

##########

# Check tree census to see if dbh growth can be calculated

names(data_taxa)

unique(data_taxa$PFT_name)
pft <- c("emergent", "pioneer", "understory", "overstory")

data <- data_taxa
data <- data[
  ,
  c(
    "Block", "TagStem_latest", "FirstRecord_year_IND",
    "Dead_year_IND", "PFT_name",
    "DBH2011_mm_clean", "DBH2012_mm_clean", "DBH2012B_mm_clean", "DBH2013_mm_clean",
    "DBH2014_mm_clean", "DBH2014B_mm_clean", "DBH2015_mm_clean", "DBH2016_mm_clean",
    "DBH2017_mm_clean", "DBH2018_mm_clean", "DBH2019_mm_clean", "DBH2020_mm_clean",
    "Date_2011", "Date_2012", "Date_2012B", "Date_2013", "Date_2014", "Date_2014B",
    "Date_2015", "Date_2016", "Date_2017", "Date_2018", "Date_2019", "Date_2020"
  )
]

# Convert date columns to numeric

data$Date_2011 <- as.numeric(data$Date_2011)
data$Date_2012 <- as.numeric(data$Date_2012)
data$Date_2012B <- as.numeric(data$Date_2012B)
data$Date_2013 <- as.numeric(data$Date_2013)
data$Date_2014 <- as.numeric(data$Date_2014)
data$Date_2014B <- as.numeric(data$Date_2014B)
data$Date_2015 <- as.numeric(data$Date_2015)
data$Date_2016 <- as.numeric(data$Date_2016)
data$Date_2017 <- as.numeric(data$Date_2017)
data$Date_2018 <- as.numeric(data$Date_2018)
data$Date_2019 <- as.numeric(data$Date_2019)
data$Date_2020 <- as.numeric(data$Date_2020)

# Focus on OG plots only

data <- data[data$Block %in% c("OG1", "OG2", "OG3"), ]

# total area for OG1, OG2 and OG3 combined = 3 times (9 * (25 * 25)) m2
# so total = 16875 m2

# Subset to trees present in 2011

data <- data[data$FirstRecord_year_IND == "2011", ]

# Will exclude trees that died between 2011-2020 for now
# This is easier but it also makes sense that trees that died may already have
# reduced growth rates prior to the year of death
# Check if sample size is sufficient, if not remove trees only during specific
# time period.

data <- data[data$Dead_year_IND == "NA", ]

# Now calculate dbh_growth for different periods, but standardise to year-1
# Again, split this up according to dbh size classes
# Use the same approach as earlier

# See Newbery and Lingenfelder (2009)
# diameter equals gbh divided by pi, then divide by 100 to convert to m
(10 / pi) / 100
(50 / pi) / 100

names(data)

data$DBH2011_mm_clean <- as.numeric(data$DBH2011_mm_clean)
data$DBH2014_mm_clean <- as.numeric(data$DBH2014_mm_clean)
data$DBH2015_mm_clean <- as.numeric(data$DBH2015_mm_clean)
data$DBH2016_mm_clean <- as.numeric(data$DBH2016_mm_clean)
data$DBH2017_mm_clean <- as.numeric(data$DBH2017_mm_clean)
data$DBH2019_mm_clean <- as.numeric(data$DBH2019_mm_clean)

#####
# 2011 - 2014 (GOOD)
data$period_length <- data$Date_2014 - data$Date_2011

data$dbh_growth_11_14 <-
  (data$DBH2014_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365
unique(data$dbh_growth_11_14)
mean(data$dbh_growth_11_14, na.rm = TRUE)

data$relative_dbh_growth_11_14 <-
  ((data$DBH2014_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365) / (data$DBH2011_mm_clean / 1000) # nolint
unique(data$relative_dbh_growth_11_14)
mean(data$relative_dbh_growth_11_14, na.rm = TRUE)

Rmisc::CI(data$dbh_growth_11_14[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$dbh_growth_11_14)
], ci = 0.95)
Rmisc::CI(data$dbh_growth_11_14[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$dbh_growth_11_14)
], ci = 0.95)

Rmisc::CI(data$relative_dbh_growth_11_14[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$relative_dbh_growth_11_14)
], ci = 0.95)
Rmisc::CI(data$relative_dbh_growth_11_14[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$relative_dbh_growth_11_14)
], ci = 0.95)

#####
# 2011 - 2015 (GOOD)
data$period_length <- data$Date_2015 - data$Date_2011

data$dbh_growth_11_15 <-
  (data$DBH2015_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365
unique(data$dbh_growth_11_15)
mean(data$dbh_growth_11_15, na.rm = TRUE)

data$relative_dbh_growth_11_15 <-
  ((data$DBH2015_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365) / (data$DBH2011_mm_clean / 1000) # nolint
unique(data$relative_dbh_growth_11_15)
mean(data$relative_dbh_growth_11_15, na.rm = TRUE)

Rmisc::CI(data$dbh_growth_11_15[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$dbh_growth_11_15)
], ci = 0.95)
Rmisc::CI(data$dbh_growth_11_15[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$dbh_growth_11_15)
], ci = 0.95)

Rmisc::CI(data$relative_dbh_growth_11_15[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$relative_dbh_growth_11_15)
], ci = 0.95)
Rmisc::CI(data$relative_dbh_growth_11_15[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$relative_dbh_growth_11_15)
], ci = 0.95)

#####
# 2011 - 2016 (GOOD)
data$period_length <- data$Date_2016 - data$Date_2011

data$dbh_growth_11_16 <-
  (data$DBH2016_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365
unique(data$dbh_growth_11_16)
mean(data$dbh_growth_11_16, na.rm = TRUE)

data$relative_dbh_growth_11_16 <-
  ((data$DBH2016_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365) / (data$DBH2011_mm_clean / 1000) # nolint
unique(data$relative_dbh_growth_11_16)
mean(data$relative_dbh_growth_11_16, na.rm = TRUE)

Rmisc::CI(data$dbh_growth_11_16[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$dbh_growth_11_16)
], ci = 0.95)
Rmisc::CI(data$dbh_growth_11_16[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$dbh_growth_11_16)
], ci = 0.95)

Rmisc::CI(data$relative_dbh_growth_11_16[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$relative_dbh_growth_11_16)
], ci = 0.95)
Rmisc::CI(data$relative_dbh_growth_11_16[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$relative_dbh_growth_11_16)
], ci = 0.95)

#####
# 2011 - 2017 (GOOD)
data$period_length <- data$Date_2017 - data$Date_2011

data$dbh_growth_11_17 <-
  (data$DBH2017_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365
unique(data$dbh_growth_11_17)
mean(data$dbh_growth_11_17, na.rm = TRUE)

data$relative_dbh_growth_11_17 <-
  ((data$DBH2017_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365) / (data$DBH2011_mm_clean / 1000) # nolint
unique(data$relative_dbh_growth_11_17)
mean(data$relative_dbh_growth_11_17, na.rm = TRUE)

Rmisc::CI(data$dbh_growth_11_17[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$dbh_growth_11_17)
], ci = 0.95)
Rmisc::CI(data$dbh_growth_11_17[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$dbh_growth_11_17)
], ci = 0.95)

Rmisc::CI(data$relative_dbh_growth_11_17[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$relative_dbh_growth_11_17)
], ci = 0.95)
Rmisc::CI(data$relative_dbh_growth_11_17[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$relative_dbh_growth_11_17)
], ci = 0.95)

#####
# 2011 - 2019 (GOOD)
data$period_length <- data$Date_2019 - data$Date_2011

data$dbh_growth_11_19 <-
  (data$DBH2019_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365
unique(data$dbh_growth_11_19)
mean(data$dbh_growth_11_19, na.rm = TRUE)

data$relative_dbh_growth_11_19 <-
  ((data$DBH2019_mm_clean - data$DBH2011_mm_clean) / data$period_length * 365) / (data$DBH2011_mm_clean / 1000) # nolint
unique(data$relative_dbh_growth_11_19)
mean(data$relative_dbh_growth_11_19, na.rm = TRUE)

Rmisc::CI(data$dbh_growth_11_19[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$dbh_growth_11_19)
], ci = 0.95)
Rmisc::CI(data$dbh_growth_11_19[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$dbh_growth_11_19)
], ci = 0.95)

Rmisc::CI(data$relative_dbh_growth_11_19[
  data$DBH2011_mm_clean > (0.03183099 * 1000) &
    !is.na(data$relative_dbh_growth_11_19)
], ci = 0.95)
Rmisc::CI(data$relative_dbh_growth_11_19[
  data$DBH2011_mm_clean > (0.1591549 * 1000) &
    !is.na(data$relative_dbh_growth_11_19)
], ci = 0.95)

#####

# Now, for the periods with good growth data in Maliau census dataset,
# calculate the growth during those periods

# This is slightly different from the approach above (above we calculated the
# mean growth rate from 2011 to 201x). What we do here is calculate mean growth
# for shorter periods (1-2 years) which should track the climate-growth
# relationship more closely

# We will then compare the growth in specific periods with the corresponding
# growth for the timesteps in the VE outputs

# Periods to focus on:
# 2011 - 2014 (already calculated, see above)
# 2014 - 2015
# 2015 - 2016
# 2016 - 2017
# 2017 - 2019

# Note that preferably we'd look at this per PFT, but the available tree per
# growth period is rather low

data$dbh_growth_14_15 <- data$DBH2015_mm_clean - data$DBH2014_mm_clean
unique(data$dbh_growth_14_15)
mean(data$dbh_growth_14_15, na.rm = TRUE)

data$dbh_growth_15_16 <- data$DBH2016_mm_clean - data$DBH2015_mm_clean
unique(data$dbh_growth_15_16)
mean(data$dbh_growth_15_16, na.rm = TRUE)

data$dbh_growth_16_17 <- data$DBH2017_mm_clean - data$DBH2016_mm_clean
unique(data$dbh_growth_16_17)
mean(data$dbh_growth_16_17, na.rm = TRUE)

data$dbh_growth_17_19 <- data$DBH2019_mm_clean - data$DBH2017_mm_clean
unique(data$dbh_growth_17_19)
mean(data$dbh_growth_17_19, na.rm = TRUE)

#####

# Then compare relative_dbh_growth from VE outputs with relative_dbh_growth_11_14
# (and other time periods) from SAFE tree census dataset, as well as with the
# values in the Newbery and Lingenfelder (2009) paper

# Note: rerun this script / analysis with the full Maliau simulation data,
# so that we can compare growth in specific years (i.e., during drought years)

# Once we have the results from the full run, plot VE dbh growth for the periods
# with good Maliau census growth data (see above for periods)
# This way we can test dbh growth more detailed compared to just using the mean
