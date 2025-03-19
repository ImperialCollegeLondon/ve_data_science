#' ---
#' title: Plant functional type species classification base
#'
#' description: |
#'     This script classifies species into plant functional types (PFTs).
#'     At the moment, these PFTs only contain trees.
#'     This classification is predominantly based on the one provided by
#'     Kohler and Huth (1998; DOI https://doi.org/10.1016/S0304-3800(98)00066-0)
#'     and contains the following PFTs:
#'     -emergent trees
#'     -overstory trees
#'     -understory trees
#'     -pioneer trees
#'     For the understory PFT, the species list is expanded by also including
#'     the species listed in group 9 (small shade trees) in
#'     Phillips et al. (2000; DOI https://doi.org/10.1016/S0378-1127(00)00666-6).
#'     This combined PFT species classification is then applied to the
#'     SAFE census dataset.
#'     The output of this script generates a CSV file containing a list of
#'     species and their respective PFT.
#'     This CSV file can then be loaded when working with other datasets
#'     (particularly those related to updating T model parameters).
#'     In a follow up script, the remaining species that have not been assigned
#'     a PFT yet will be assigned into one based on their species maximum height
#'     relative to the PFT maximum height.
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
#'
#' output_files:
#'   - name: plant_functional_type_species_classification_base.csv
#'     path: ../../../data/derived/plant/plant_functional_type
#'     description: |
#'       This CSV file contains a list of species and their respective PFT.
#'       This CSV file can be loaded when working with other datasets
#'       (particularly those related to updating T model parameters).
#'       In a follow up script, the remaining species that have not been assigned
#'       a PFT yet will be assigned into one based on
#'       their species maximum height relative to the PFT maximum height.
#'
#' package_dependencies:
#'     - readxl
#'
#' usage_notes: |
#'   If PFT species classification is updated in the future,
#'   this script should be the starting point.
#'   File directories still need to be converted to relative paths.
#' ---


# Load packages

library(readxl)

# Load SAFE tree census data

tree_census_11_20 <- read_excel(
  "../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

# Clean dataset and create subset based on species classification

data <- tree_census_11_20

max(nrow(data))
colnames(data) <- data[10, ]
data <- data[11:40511, ]
names(data)

##########

data_taxa <- data[data$TaxaName %in% c(
  "Dipterocarpus caudiferus", "Dryobalanops lanceolata",
  "Heritiera simplicifolia", "Hopea nervosa", "Pentace laxiflora"
) |
  data$Genus %in% c(
    "Parashorea", "Shorea", "Artocarpus", "Parartocarpus",
    "Pentace", "Castanopsis", "Ganua", "Madhuca", "Palaquium",
    "Payena", "Macaranga", "Eugenia", "Hydnocarpus",
    "Gonystylus", "Madhuca", "Kayea"
  ), ]

unique(data_taxa$TaxaName)

##########

# Assign plant functional type number to correct taxa

# 1 is emergent
# 2 is overstory
# 3 is pioneer
# 4 is understory

data_taxa$PFT <- NA

data_taxa$PFT[data_taxa$Genus %in%
  c(
    "Parashorea", "Shorea", "Artocarpus",
    "Parartocarpus", "Pentace", "Castanopsis"
  )] <- 1
data_taxa$PFT[data_taxa$Genus %in%
  c(
    "Ganua", "Madhuca", "Palaquium", "Payena"
  )] <- 2
data_taxa$PFT[data_taxa$Genus %in%
  c(
    "Macaranga"
  )] <- 3
data_taxa$PFT[data_taxa$Genus %in%
  c(
    "Eugenia", "Hydnocarpus"
  )] <- 4

# For group 4, also added species from group 9 from
# Phillips et al. (2002) (small shade trees)
data_taxa$PFT[data_taxa$Genus %in%
  c(
    "Gonystylus", "Madhuca", "Kayea"
  )] <- 4

data_taxa$PFT[data_taxa$TaxaName %in%
  c(
    "Dipterocarpus caudiferus", "Dryobalanops lanceolata",
    "Heritiera simplicifolia"
  )] <- 1
data_taxa$PFT[data_taxa$TaxaName %in%
  c(
    "Shorea xanthophylla", "Hopea nervosa",
    "Pentace laxiflora"
  )] <- 2

unique(data_taxa$PFT)

##########

# Prepare final format of data_taxa

data_taxa <- data_taxa[, c(
  "Family", "Genus", "Species",
  "TaxaName", "TaxaLevel", "PFT"
)]
data_taxa <- unique(data_taxa)

data_taxa$PFT_name <- NA
data_taxa$PFT_name[data_taxa$PFT == "1"] <- "emergent"
data_taxa$PFT_name[data_taxa$PFT == "2"] <- "overstory"
data_taxa$PFT_name[data_taxa$PFT == "3"] <- "pioneer"
data_taxa$PFT_name[data_taxa$PFT == "4"] <- "understory"

data_taxa$PFT_name <- as.character(data_taxa$PFT_name)

data_taxa <- data_taxa[, c(
  "PFT", "PFT_name",
  "TaxaName", "TaxaLevel", "Species",
  "Genus", "Family"
)]
data_taxa <- data_taxa[order(
  data_taxa$PFT, data_taxa$Family,
  data_taxa$Genus
), ]

# Write CSV file

write.csv(
  data_taxa,
  file = file.path(
    "..", "..", "..", "data", "derived", "plant", "plant_functional_type",
    "plant_functional_type_species_classification_base.csv"
  ),
  row.names = FALSE
)
