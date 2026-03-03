#| ---
#| title: Plant functional type cohort distribution dobert
#|
#| description: |
#|     This script calculates the Plant Functional Type (PFT) cohort distribution
#|     by applying the classification obtained from Dobert et al., 2017 to the
#|     SAFE tree census dataset. The script processes data from old-growth (OG)
#|     plots to generate a CSV file with the number of individuals per Diameter
#|     at Breast Height (DBH) class for each PFT. It first compiles a list of
#|     all trees across the three OG plots and then converts this to individuals
#|     per hectare for standardised comparison.
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
#|   - name: tree_census_11_20.xlsx
#|     path: data/primary/plant/tree_census
#|     description: |
#|       https://doi.org/10.5281/zenodo.14882506
#|       Tree census data from the SAFE Project 2011–2020.
#|       Data includes measurements of DBH and estimates of tree height for all
#|       stems, fruiting and flowering estimates,
#|       estimates of epiphyte and liana cover, and taxonomic IDs.
#|   - name: plant_functional_type_species_classification_dobert.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains a list of species and their respective PFT,
#|       based on the species maximum height relative to the PFT maximum height,
#|       as well as their fruit, dispersal and pollination type.
#|   - name: t_model_parameters.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of updated T model parameters, as well
#|       as additional PFT traits for leaf and sapwood stoichiometry derived
#|       from the same datasets.
#|
#| output_files:
#|   - name: plant_functional_type_cohort_distribution_dobert.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains an overview of the individuals in OG plots per
#|       DBH class for each PFT.
#|   - name: plant_functional_type_cohort_distribution_per_hectare_dobert.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains the number of individuals per DBH class for each PFT,
#|       standardised as a count per hectare.
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|     - tidyr
#|
#| usage_notes: |
#|   This script applies the PFT species classification obtained from Dobert
#|   to the SAFE census dataset in order to get the respective cohort distribution.
#|   However, the same approach can be applied to different census datasets and
#|   other PFT species classifications.
#| ---


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

# Load PFT species classification Dobert and clean up a bit

PFT_species_classification_dobert <- read.csv( # nolint
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_dobert.csv", # nolint
  header = TRUE
)

PFT_species_classification_dobert <- PFT_species_classification_dobert[ # nolint
  ,
  c("PFT_name", "TaxaName")
]
PFT_species_classification_dobert <- unique(PFT_species_classification_dobert) # nolint

# Add PFT_name to data based on TaxaName and call it data_taxa

data_taxa <- left_join(data, PFT_species_classification_dobert, by = "TaxaName")

# Subset to relevant columns

data_taxa <- data_taxa[, c(
  "Block", "Plot", "PlotID", "TagStem_latest",
  "Family", "Genus", "Species", "TaxaName",
  "TaxaLevel", "PFT_name", "HeightTotal_m_2011",
  "DBH2011_mm_clean"
)]

data_taxa$HeightTotal_m_2011 <- as.numeric(data_taxa$HeightTotal_m_2011)
data_taxa$DBH2011_mm_clean <- as.numeric(data_taxa$DBH2011_mm_clean)

# Ideally, we would base our cohort distribution on:
# - multiple plots
# - all trees within each plot are included (i.e., all trees have a PFT)

# Subset to OG plots and remove trees without data
data_taxa <- data_taxa[data_taxa$Block %in% c("OG1", "OG2", "OG3"), ]
data_taxa <- data_taxa[!data_taxa$TaxaLevel == "indet", ]

# Need to add PFT to genus level individuals
# Reload PFT_species_classification_dobert
# Aim to get 1 PFT per genus
# Then fill the gaps in data_taxa based on genus PFT from Dobert

PFT_species_classification_dobert <- read.csv( # nolint
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_dobert.csv", # nolint
  header = TRUE
)

# The goal here is to obtain a PFT for individuals that:
# - either have TaxaLevel = genus
# - are species in SAFE cenus data that are not captured at species level in
# Dobert (i.e., match for genus but no match for species)

# If an individual in SAFE census has TaxaLevel=genus, then:
# take the unique PFT_name of the individuals where genus maximum height
# matches the limits of PFT maximum height from the t_model_parameters

# Load t_model_parameters to get access to PFT max height values
t_model_parameters <- read.csv(
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  header = TRUE
)

# Calculate PFT_genus
data_taxa$PFT_genus <- NA

# Define genera for which PFT_genus may need to be calculated
temp <- PFT_species_classification_dobert %>%
  group_by(Genus) %>%
  filter(n_distinct(PFT_name) >= 2) %>%
  ungroup()

genus <- unique(temp$Genus)

# Note that genera outside of this list should have only 1 PFT per genus,
# which means that individuals with missing PFT in data_taxa should be able to
# get filled using unique(PFT_name). We'll verify this after we've added the
# genus PFT obtained from Dobert

# Note that the loop below fails when there are no individuals within that PFT
# For example, below there are no emergent trees for Elaeocarpus and the loop fails
# An easy way around this is to define genus that needs to be adjusted for each
# PFT loop (so subset genus and create e.g., genus_emergent)
# Then repeat this process for overstory and understory
# For pioneers, manually overwrite for Macaranga genus
# Note that in some cases the SAFE census data has different species not
# contained within the genus in Dobert, and sometimes these species have lower
# heights (e.g., heights corresponding to understory)
# In these rare cases: manually assign PFT_genus as the most conservative PFT
# recorded for that genus in Dobert (in the order: understory>overstory>emergent)

print(genus)

# Antidesma, Croton, Elaeocarpus, Garcinia, Madhuca and Memecylon
# removed because not recorded in SAFE census OG plots

genus_emergent <- c(
  "Aglaia", "Baccaurea", "Chionanthus",
  "Diospyros", "Hydnocarpus", "Knema",
  "Mallotus", "Microcos", "Nephelium",
  "Polyalthia", "Vatica", "Xanthophyllum"
)

# For emergent: Ficus causes issues (which is why it is not included in
# genus_emergent). We'll manually correct for this later on.

for (i in genus_emergent) {
  data_taxa$PFT_genus[
    data_taxa$Genus == i &
      data_taxa$HeightTotal_m_2011 > t_model_parameters$h_max[
        t_model_parameters$name == "overstory"
      ]
  ] <-
    unique(PFT_species_classification_dobert$PFT_name[
      PFT_species_classification_dobert$Genus == i &
        PFT_species_classification_dobert$maximum_height > t_model_parameters$h_max[
          t_model_parameters$name == "overstory"
        ]
    ])
  print(i)
}

# Manual corrections still to be made (do this after all loops are done):
# Ficus: no emergent heights in data_taxa, assign remaining trees as understory
# Knema: no emergent heights in data_taxa, assign remaining trees as overstory

# Repeat step above for other PFTs

genus_overstory <- c(
  "Aglaia", "Baccaurea", "Chionanthus",
  "Diospyros", "Ficus", "Hydnocarpus", "Knema",
  "Mallotus", "Nephelium",
  "Polyalthia", "Vatica", "Xanthophyllum"
)

# For overstory: Microcos causes issues

for (i in genus_overstory) {
  data_taxa$PFT_genus[
    data_taxa$Genus == i &
      data_taxa$HeightTotal_m_2011 < t_model_parameters$h_max[
        t_model_parameters$name == "overstory"
      ] &
      data_taxa$HeightTotal_m_2011 > t_model_parameters$h_max[
        t_model_parameters$name == "understory"
      ]
  ] <-
    unique(PFT_species_classification_dobert$PFT_name[
      PFT_species_classification_dobert$Genus == i &
        PFT_species_classification_dobert$maximum_height < t_model_parameters$h_max[
          t_model_parameters$name == "overstory"
        ] &
        PFT_species_classification_dobert$maximum_height > t_model_parameters$h_max[
          t_model_parameters$name == "understory"
        ]
    ])
  print(i)
}

# Manual corrections still to be made (do this after all loops are done):
# Microcos: no overstory PFT in Dobert (only understory and emergent), so
# manually classify trees with data_taxa height below understory limit as
# understory and those above the limit as emergent

# Repeat step above for other PFTs

genus_understory <- c(
  "Aglaia", "Baccaurea",
  "Diospyros", "Ficus",
  "Mallotus", "Microcos", "Nephelium",
  "Polyalthia", "Xanthophyllum"
)

# For understory: Chionanthus, Hydnocarpus, Knema, Vatica cause issues

for (i in genus_understory) {
  data_taxa$PFT_genus[
    data_taxa$Genus == i &
      data_taxa$HeightTotal_m_2011 < t_model_parameters$h_max[
        t_model_parameters$name == "understory"
      ]
  ] <-
    unique(PFT_species_classification_dobert$PFT_name[
      PFT_species_classification_dobert$Genus == i &
        PFT_species_classification_dobert$maximum_height < t_model_parameters$h_max[
          t_model_parameters$name == "understory"
        ]
    ])
  print(i)
}

# Manual corrections still to be made (do this after all loops are done):
# Chionanthus: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
# Hydnocarpus: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
# Knema: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
# Vatica: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory

# Add pioneer PFT to data_taxa
data_taxa$PFT_genus[data_taxa$Genus == "Macaranga"] <-
  unique(PFT_species_classification_dobert$PFT_name[
    PFT_species_classification_dobert$Genus == "Macaranga"
  ])

#####

# Make manual corrections (by looking at both data_taxa and Dobert):

# Ficus: no emergent heights in data_taxa, assign remaining trees as understory
data_taxa$PFT_genus[data_taxa$Genus == "Ficus" & is.na(data_taxa$PFT_genus)] <-
  "understory_biotic_dry_biotic"
# Knema: no emergent heights in data_taxa, assign remaining trees as overstory
data_taxa$PFT_genus[data_taxa$Genus == "Knema" & is.na(data_taxa$PFT_genus)] <-
  "overstory_biotic_dry_biotic"

# Microcos: no overstory PFT in Dobert (only understory and emergent), so
# manually classify trees with data_taxa height below understory limit as
# understory and those above the limit as emergent
data_taxa$PFT_genus[data_taxa$Genus == "Microcos" & is.na(data_taxa$PFT_genus)] <-
  "emergent_biotic_fleshy_biotic"

# Chionanthus: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
data_taxa$PFT_genus[data_taxa$Genus == "Chionanthus" & is.na(data_taxa$PFT_genus)] <-
  "overstory_biotic_fleshy_biotic"
# Hydnocarpus: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
data_taxa$PFT_genus[data_taxa$Genus == "Hydnocarpus" & is.na(data_taxa$PFT_genus)] <-
  "overstory_biotic_dry_biotic"
# Knema: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
# Already done by loop!
# Vatica: no understory PFT in Dobert (only understory and emergent), so
# manually classify trees as overstory
data_taxa$PFT_genus[data_taxa$Genus == "Vatica" & is.na(data_taxa$PFT_genus)] <-
  "overstory_biotic_dry_abiotic"

#####

# Note that there are still a lot of species without PFT
# As mentioned earlier, we will now calculate the most conservative genus PFT for
# each species based on Dobert, and then use this genus PFT to fill in the missing
# PFT for species belonging to genus from Dobert
# Note that we take the most conservative PFT, without looking at individual's
# height or dbh (as heights can span multiple PFTs within genus)

# So, at this point we want to get a PFT_genus for all species that do not have
# a PFT_name, and do not have a PFT_genus from Dobert
# And we want to assign the most conservative PFT available in Dobert for that
# genus

genus_all <- unique(data_taxa$Genus[
  is.na(data_taxa$PFT_name) & is.na(data_taxa$PFT_genus)
])

# Remove genera from genus_all if they do not occur in Dobert
genus_all <- genus_all[genus_all %in% PFT_species_classification_dobert$Genus]

for (i in genus_all) {
  vals <- unique(PFT_species_classification_dobert$PFT_name[
    PFT_species_classification_dobert$Genus == i
  ])
  print(paste(i, paste(vals, collapse = ", ")))
}

# Now add the PFT_name from above to PFT_genus_all for genus in "genus_all"
# Make sure to only do this for species within this genus where PFT_genus in
# data_taxa is NA (otherwise we would overwrite what we calculated earlier)

data_taxa$PFT_genus_all <- NA

individuals_all <- unique(data_taxa$TagStem_latest[
  is.na(data_taxa$PFT_name) & is.na(data_taxa$PFT_genus) &
    data_taxa$Genus %in% genus_all
])

for (i in individuals_all) {
  j <- unique(data_taxa$Genus[data_taxa$TagStem_latest == i]) # nolint
  print(j)
  data_taxa$PFT_genus_all[data_taxa$TagStem_latest == i] <-
    unique(PFT_species_classification_dobert$PFT_name[
      PFT_species_classification_dobert$Genus == j
    ])
}

# Now add PFT_genus to PFT_name where PFT_name is lacking
# Note that PFT genus can only be accepted when there is no PFT_name,
# because PFT genus has a lower "resolution" than PFT_name
data_taxa$PFT_name[is.na(data_taxa$PFT_name)] <-
  data_taxa$PFT_genus[is.na(data_taxa$PFT_name)]

# Then repeat this step but add PFT_genus_all to PFT_name for the remaining NA's
data_taxa$PFT_name[is.na(data_taxa$PFT_name)] <-
  data_taxa$PFT_genus_all[is.na(data_taxa$PFT_name)]

##########

# Save log of trees without PFT to see where data is missing
# (i.e., is it concentrated in certain plots?)
data_taxa_without_PFT <- data_taxa[is.na(data_taxa$PFT_name), ] # nolint

# Before NA removal:
nrow(data_taxa)
# After NA removal:
nrow(data_taxa_without_PFT)
# The difference is the amount of trees with PFT, across all plots
nrow(data_taxa) - nrow(data_taxa_without_PFT)

plot(as.factor(data_taxa_without_PFT$Block),
  xlab = "Block", ylab = "Trees without PFT"
)

plot(
  as.factor(data_taxa_without_PFT$PlotID[data_taxa_without_PFT$Block
    %in% c("OG1", "OG2", "OG3")]), # nolint
  xlab = "PlotID", ylab = "Trees without PFT"
)

# Remove trees without PFT assigned
data_taxa_with_PFT <- drop_na(data_taxa, PFT_name) # nolint

plot(as.factor(data_taxa_with_PFT$Block),
  xlab = "Block", ylab = "Trees with PFT"
)

plot(
  as.factor(data_taxa_with_PFT$PlotID[data_taxa_with_PFT$Block
    %in% c("OG1", "OG2", "OG3")]), # nolint
  xlab = "PlotID", ylab = "Trees with PFT"
)

##########

data_taxa <- drop_na(data_taxa, DBH2011_mm_clean)

data_taxa <- data_taxa[data_taxa$Block %in% c("OG1", "OG2", "OG3"), ]

ggplot(data_taxa, aes(x = TagStem_latest, y = HeightTotal_m_2011, color = PFT_name)) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

ggplot(data_taxa, aes(x = TagStem_latest, y = DBH2011_mm_clean, color = PFT_name)) +
  geom_point() +
  labs(x = "TreeID", y = "DBH (mm)")

#####

# The section below explores stem density to get an idea of the
# representativeness of the OG plots relative to the literature

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

# Mean OG tree density per hectare (536)
mean(c(OG1_density, OG2_density, OG3_density))
# Compare to 410-444-535-478-427-600 from Kenzo, Slik,
# Mills, Saner papers (especially Slik appendix, many locations)

#####

# Narrow down to DBH for each PFT

names(data_taxa)
data_taxa <- data_taxa[
  ,
  c(
    "Block", "Plot", "PlotID", "TagStem_latest",
    "PFT_name", "HeightTotal_m_2011", "DBH2011_mm_clean"
  )
]

# Use dividers of 0.1 m (100 mm)
# Assign each tree into one of these DBH classes
# The value for dbh represents the midpoint of the dbh class

data_taxa$dbh <- NA

data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 0.0 &
    data_taxa$DBH2011_mm_clean <= 100
] <- 50
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 100 &
    data_taxa$DBH2011_mm_clean <= 200
] <- 150
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 200 &
    data_taxa$DBH2011_mm_clean <= 300
] <- 250
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 300 &
    data_taxa$DBH2011_mm_clean <= 400
] <- 350
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 400 &
    data_taxa$DBH2011_mm_clean <= 500
] <- 450
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 500 &
    data_taxa$DBH2011_mm_clean <= 600
] <- 550
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 600 &
    data_taxa$DBH2011_mm_clean <= 700
] <- 650
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 700 &
    data_taxa$DBH2011_mm_clean <= 800
] <- 750
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 800 &
    data_taxa$DBH2011_mm_clean <= 900
] <- 850
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 900 &
    data_taxa$DBH2011_mm_clean <= 1000
] <- 950
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1000 &
    data_taxa$DBH2011_mm_clean <= 1100
] <- 1050
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1100 &
    data_taxa$DBH2011_mm_clean <= 1200
] <- 1150
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1200 &
    data_taxa$DBH2011_mm_clean <= 1300
] <- 1250
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1300 &
    data_taxa$DBH2011_mm_clean <= 1400
] <- 1350
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1400 &
    data_taxa$DBH2011_mm_clean <= 1500
] <- 1450
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1500 &
    data_taxa$DBH2011_mm_clean <= 1600
] <- 1550
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1600 &
    data_taxa$DBH2011_mm_clean <= 1700
] <- 1650
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1700 &
    data_taxa$DBH2011_mm_clean <= 1800
] <- 1750
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1800 &
    data_taxa$DBH2011_mm_clean <= 1900
] <- 1850
data_taxa$dbh[
  data_taxa$DBH2011_mm_clean > 1900 &
    data_taxa$DBH2011_mm_clean <= 2000
] <- 1950

max(data_taxa$DBH2011_mm_clean)
# Note that more classes will need to be added if DBH exceeds 2000 mm

# Prepare data_taxa for saving

names(data_taxa)
data_taxa <- data_taxa[
  ,
  c("Block", "Plot", "PlotID", "TagStem_latest", "PFT_name", "dbh")
]
colnames(data_taxa) <- c(
  "Block", "Plot", "PlotID", "TagStem_latest",
  "PFT_name", "DBH_class"
)

data_taxa <- data_taxa[
  order(
    data_taxa$Block, data_taxa$Plot,
    data_taxa$PFT_name, data_taxa$DBH_class
  ),
]

maxrows <- nrow(data_taxa)
rownames(data_taxa) <- c(1:maxrows)

# Subset and convert dbh to m

data_taxa <- data_taxa[, c("Block", "Plot", "PlotID", "PFT_name", "DBH_class")]
data_taxa$DBH_class <- data_taxa$DBH_class / 1000

# This cohort distribution is not standardised per hectare yet (see continued below)
# This version is saved for plotting and exploration (see bottom of this script)

write.csv(
  data_taxa,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_dobert.csv", # nolint
  row.names = FALSE
)

################################################################################

# Standardising OG cohort distribution per hectare

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

total_OG_area <- OG1_area + OG2_area + OG3_area # m2 # nolint

data_taxa$total_OG_area <- total_OG_area

data_taxa <- data_taxa %>%
  group_by(PFT_name, DBH_class) %>%
  mutate(plant_cohorts_n = n()) %>%
  ungroup()

# Calculate the count of individuals with (un)known PFTs

data_taxa$PFT_known <-
  nrow(data_taxa[na.omit(data_taxa$PFT_name), ])
data_taxa$PFT_unknown <-
  nrow(data_taxa[is.na(data_taxa$PFT_name), ])
data_taxa$PFT_total <- data_taxa$PFT_known + data_taxa$PFT_unknown

# Correct plant_cohorts_n for trees with unknown PFT by evenly distributing trees
# with unknown PFT across the known PFTs

data_taxa$plant_cohorts_n_corrected <-
  (data_taxa$plant_cohorts_n / data_taxa$PFT_known) * data_taxa$PFT_total

###

before <- data_taxa[, c("PFT_name", "DBH_class", "plant_cohorts_n")]
after <- data_taxa[, c("PFT_name", "DBH_class", "plant_cohorts_n_corrected")]
before <- unique(before)
after <- unique(after)

sum(before$plant_cohorts_n)
sum(after$plant_cohorts_n_corrected[!is.na(after$PFT_name)]) # nolint

after_check <-
  data_taxa[, c("PFT_name", "DBH_class", "plant_cohorts_n", "plant_cohorts_n_corrected")] # nolint
data_taxa$plant_cohorts_n_corrected[is.na(data_taxa$PFT_name)] <- 0

###

# Remove original plant_cohorts_n and rename plant_cohorts_n_corrected to
# plant_cohorts_n, then remove the rows with unknown PFT

data_taxa$plant_cohorts_n <- data_taxa$plant_cohorts_n_corrected
data_taxa <- data_taxa[, c(1:10)]
data_taxa <- data_taxa[!is.na(data_taxa$PFT_name), ]

# Divide plant_cohorts_n by total_OG_area to get individuals per m2
# Then multiply by 10000 to get cohort distribution per hectare

data_taxa$plant_cohorts_n <- data_taxa$plant_cohorts_n / data_taxa$total_OG_area
data_taxa$plant_cohorts_n <- data_taxa$plant_cohorts_n * 10000

# Clean up summary

data_taxa <-
  data_taxa[
    ,
    c("plant_cohorts_n", "PFT_name", "DBH_class")
  ]
data_taxa <- unique(data_taxa)

data_taxa <- data_taxa[
  order(
    data_taxa$PFT_name, data_taxa$DBH_class
  ),
]

# Rename variables to match VE
names(data_taxa)
colnames(data_taxa) <- c("plant_cohorts_n", "plant_cohorts_pft", "plant_cohorts_dbh")

# Quick check of total stem density per hectare (to compare with literature)
# Original stem density from SAFE census data was 558 per hectare
# After distributing trees with unknown PFT across PFTs, the stem density is 538

sum(data_taxa$plant_cohorts_n)

# Save cohort distribution on a per hectare basis

write.csv(
  data_taxa,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_per_hectare_dobert.csv", # nolint
  row.names = FALSE
)

################################################################################

# Exploring the variability in PFT cohort distribution across plots

data_taxa <- read.csv("../../../data/derived/plant/plant_functional_type/plant_functional_type_cohort_distribution_dobert.csv") # nolint
data <- data_taxa
names(data)

data$Block <- as.factor(data$Block)
data$PlotID <- as.factor(data$PlotID)

plots <- unique(data$PlotID)
plots

length(unique(plots)) # 27
25 * 25 * 27 # total area
nrow(data) / (25 * 25 * 27) # average stem density of 0.05 per m2
nrow(data) / (25 * 25 * 27) * 10000 # average stem density per hectare

# Plots

# Plot using OG1, OG2 and OG3 - split up per Block (expressed as proportion %)
ggplot(data, aes(x = Block, fill = PFT_name)) +
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
ggplot(data, aes(x = Block, fill = PFT_name)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Block by PFT",
    x = "Block",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

# Same figure but bars not stacked
ggplot(data, aes(x = Block, fill = PFT_name)) + # Use PFT to differentiate the bars
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
ggplot(data, aes(x = PlotID, fill = PFT_name)) +
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
ggplot(data, aes(x = PlotID, fill = PFT_name)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Plot by PFT",
    x = "Plot ID",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()

##########

# Barplot per DBH

names(data)

ggplot(data, aes(x = DBH_class, fill = PFT_name)) +
  geom_bar(position = "stack") + # Stacked bars show absolute counts
  labs(
    title = "Number of Trees per Plot by PFT",
    x = "DBH",
    y = "Number of Trees",
    fill = "Plant Functional Type"
  ) +
  theme_minimal()
