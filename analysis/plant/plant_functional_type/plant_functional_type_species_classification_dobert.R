#| ---
#| title: Plant functional type species classification dobert
#|
#| description: |
#|     This script classifies species (read: TaxaNames) into
#|     a PFT based on their species maximum height relative to the PFT maximum
#|     height, as well as their fruit, dispersal and pollination type.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#|
#| input_files:
#|   - name: dobert_2017_species_trait_data.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a set of traits (e.g., maximum height, fruit,
#|       dispersal, pollination type, etc.) for each species, measured across the
#|       SAFE project and Maliau.
#|   - name: t_model_parameters.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of updated T model parameters, as well
#|       as additional PFT traits for leaf and sapwood stoichiometry derived
#|       from the same datasets.
#|
#| output_files:
#|   - name: plant_functional_type_species_classification_dobert.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains a list of species and their respective PFT,
#|       based on the species maximum height relative to the PFT maximum height,
#|       as well as their fruit, dispersal and pollination type.
#|   - name: dobert_2017_species_trait_data_PFT.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains the data from Dobert et al. (2017), but narrowed
#|       down to each of the PFTs in
#|       plant_functional_type_species_classification_dobert.csv - it is saved so
#|       that it can be used in other scripts without having to do the entire
#|       pre-processing and linking to PFTs again.
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|     - tidyr
#|
#| usage_notes: |
#|   If PFT species classification is updated in the future, the base script as
#|   well as the t_model_parameters script will need to be updated prior to
#|   running this script (because the output of this script relies heavily on
#|   the PFT maximum height).
#| ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)

# Load Dobert et al. (2017) dataset and clean up a bit

dobert_2017_species_trait_data <- read.csv(
  "../../../data/primary/plant/traits_data/dobert_2017_species_trait_data.csv",
  header = TRUE
)

# Convert abbreviations using info in Dobert et al., 2017 Supplementary Information

# Column headings:
# species.code: Unique code for each plant taxa
# family: Plant family name
# genus: Plant genus name
# species: Plant species name or unique identifier where species indeterminate
# species.name: The genus and species name
# tree: Distinction between tree (yes), no tree (no) or indeterminate (na)
# woody: Distinction between woody (yes), non-woody (no) or indeterminate (na)
# origin: Distinction between native (n) and exotic (e) plant species
# pgf: Plant growth form: A = fern, B = graminoid, C = forb, D = herbaceous
# climber, E = herbaceous shrub, F = tree sapling, G = woody climber, H = woody
# shrub, na = indeterminate
# height: Maximum plant height (m)
# sla: Specific leaf area (m2.kg-1)
# wood.dens: Wood density (g.cm-3)
# dispersal: Predominant dispersal mode: J = animal, K = ant, L = ballistic,
# M = bat, N = bird, O = primate, P = water, Q = wind, na = indeterminate
# fruit: The type of fruit: R = achene, S = berry, T = berry-like, U = capsule,
# V = caryopsis, W = drupe, X = follicle, Y = legume, Z = nut, a = samara,
# b = schizocarp, na = indeterminate
# seed: The number of seeds per fruit: 1 = 1, 2 = <4, 3 = <10, 4 = >10
# reproduction: The reproduction strategy: s = seed, v = vegetative, sv = seed or
# vegetative, na = indeterminate
# lifehistory: The lifehistory strategy: a = annual, abp = annual or biennial or
# perennial, ap = annual or perennial, p = perennial, na = indeterminate
# pollination: The pollination syndrome: c = bat, d = bee, e = beetle, f = bird,
# g = butterfly, h = entomophilous.broad, i = entomophilous.narrow, j = fly,
# k = moth, l = passive, m = self, n = thrip, o = wasp, p = wind, na = indeterminate

# First narrow down to trees
dobert_2017_species_trait_data <-
  dobert_2017_species_trait_data[dobert_2017_species_trait_data$tree == "yes", ]

# Remove columns tree, woody, origin and pgf
dobert_2017_species_trait_data <-
  dobert_2017_species_trait_data[, c(1:5, 10:18)]

# Summarise dispersal type into biotic and abiotic
unique(dobert_2017_species_trait_data$dispersal)

# "animal","ant","bat","bird","primate" = "biotic"
# "ballistic","water","wind" = "abiotic"

dobert_2017_species_trait_data$dispersal[
  dobert_2017_species_trait_data$dispersal %in% c(
    "J", "K", "M", "N", "O"
  )
] <- "biotic"
dobert_2017_species_trait_data$dispersal[
  dobert_2017_species_trait_data$dispersal %in% c(
    "L", "P", "Q"
  )
] <- "abiotic"
dobert_2017_species_trait_data$dispersal[
  dobert_2017_species_trait_data$dispersal == "na"
] <- NA

# Summarise fruit type into fleshy and dry fruit
unique(dobert_2017_species_trait_data$fruit)

# "berry","berry-like","drupe" = "fleshy"
# "achene","capsule","caryopsis","follicle","legume","nut","samara",
# "schizocarp" = "dry" # nolint

dobert_2017_species_trait_data$fruit[
  dobert_2017_species_trait_data$fruit %in% c(
    "S", "T", "W"
  )
] <- "fleshy"
dobert_2017_species_trait_data$fruit[
  dobert_2017_species_trait_data$fruit %in% c(
    "R", "U", "V", "X", "Y", "Z", "a", "b"
  )
] <- "dry"
dobert_2017_species_trait_data$fruit[
  dobert_2017_species_trait_data$fruit == "na"
] <- NA

# Summarise pollination type into biotic and abiotic
unique(dobert_2017_species_trait_data$pollination)

# "bat","bee","beetle","bird","butterfly","entomophilous.broad",
# "entomophilous.narrow","fly","moth","thrip","wasp" = "biotic"
# "passive","self","wind" = "abiotic"

dobert_2017_species_trait_data$pollination[
  dobert_2017_species_trait_data$pollination %in% c(
    "c", "d", "e", "f", "g", "h", "i", "j", "k", "n", "o"
  )
] <- "biotic"
dobert_2017_species_trait_data$pollination[
  dobert_2017_species_trait_data$pollination %in% c(
    "l", "m", "p"
  )
] <- "abiotic"
dobert_2017_species_trait_data$pollination[
  dobert_2017_species_trait_data$pollination == "na"
] <- NA

# Remove columns seed, reproduction and lifehistory
dobert_2017_species_trait_data <-
  dobert_2017_species_trait_data[, c(1:10, 14)]

# Change variable type of height to numeric
dobert_2017_species_trait_data$height <-
  as.numeric(dobert_2017_species_trait_data$height)

# Correct NA in height column
dobert_2017_species_trait_data$height[
  dobert_2017_species_trait_data$height == "na"
] <- NA

# Remove rows with NA
dobert_2017_species_trait_data <- na.omit(dobert_2017_species_trait_data)

# Rearrange order of columns
dobert_2017_species_trait_data <- dobert_2017_species_trait_data[, c(1:8, 11, 10, 9)]

###

# Assign main PFT based on species maximum height relative to PFT max height
# Load t_model_parameters so that we can access the PFT maximum height values
# - emergent (41.74810)
# - overstory (27.92075) and pioneer (20.66937)
# - understory (16.50659)

t_model_parameters <- read.csv(
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  header = TRUE
)

dobert_2017_species_trait_data$PFT_main <- NA

dobert_2017_species_trait_data$PFT_main[
  dobert_2017_species_trait_data$height > t_model_parameters$h_max[
    t_model_parameters$name == "overstory"
  ]
] <- "emergent"
dobert_2017_species_trait_data$PFT_main[
  dobert_2017_species_trait_data$height > t_model_parameters$h_max[
    t_model_parameters$name == "understory"
  ] &
    dobert_2017_species_trait_data$height < t_model_parameters$h_max[
      t_model_parameters$name == "overstory"
    ]
] <- "overstory"
dobert_2017_species_trait_data$PFT_main[
  dobert_2017_species_trait_data$height < t_model_parameters$h_max[
    t_model_parameters$name == "understory"
  ]
] <- "understory"

###

# Now create "subPFTs":
# - pioneer as part of overstory trees (individuals of Macaranga genus)
# - subPFTs based on Dobert data on pollination, dispersal and fruit type
dobert_2017_species_trait_data$PFT_sub <- NA

# For now, create a description of the new subPFTs
# We'll use this description for now, but this will likely be refined/adjusted
# depending on discussion with the needs of the animal model
dobert_2017_species_trait_data$PFT_sub <-
  paste(dobert_2017_species_trait_data$PFT_main,
    dobert_2017_species_trait_data$pollination,
    dobert_2017_species_trait_data$fruit,
    dobert_2017_species_trait_data$dispersal,
    sep = "_"
  )

# Overwrite the pioneer individuals for Macaranga genus
dobert_2017_species_trait_data$PFT_sub[
  dobert_2017_species_trait_data$genus == "Macaranga"
] <-
  paste("pioneer",
    dobert_2017_species_trait_data$pollination[
      dobert_2017_species_trait_data$genus == "Macaranga"
    ],
    dobert_2017_species_trait_data$fruit[
      dobert_2017_species_trait_data$genus == "Macaranga"
    ],
    dobert_2017_species_trait_data$dispersal[
      dobert_2017_species_trait_data$genus == "Macaranga"
    ],
    sep = "_"
  )

###

# Check variable types and change if necessary
dobert_2017_species_trait_data$height <-
  as.numeric(dobert_2017_species_trait_data$height)
dobert_2017_species_trait_data$sla <-
  as.numeric(dobert_2017_species_trait_data$sla)
dobert_2017_species_trait_data$wood.dens <-
  as.numeric(dobert_2017_species_trait_data$wood.dens)

# Save plant_functional_type_species_classification_dobert
# Get same variables as maximum_height output
# PFT_final, PFT_name, TaxaName, TaxaLevel, Species, Genus, Family, maximum_height
plant_functional_type_species_classification_dobert <- # nolint
  dobert_2017_species_trait_data[
    ,
    c(
      "PFT_sub", "species.name", "species", "genus",
      "family", "height"
    )
  ]

colnames(plant_functional_type_species_classification_dobert) <- # nolint
  c("PFT_name", "TaxaName", "Species", "Genus", "Family", "maximum_height")

# Write CSV file
write.csv(
  plant_functional_type_species_classification_dobert,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_dobert.csv", # nolint
  row.names = FALSE
)

###

# Now also save dobert_2017_species_trait_data_PFT so that it can be used for
# other scripts
dobert_2017_species_trait_data_PFT <- # nolint
  dobert_2017_species_trait_data[, c(1:11, 13)]

names(dobert_2017_species_trait_data_PFT)

colnames(dobert_2017_species_trait_data_PFT) <- # nolint
  c(
    "Species_code", "Family", "Genus", "Species", "TaxaName", "maximum_height",
    "sla", "wood_density", "Pollination", "Fruit", "Dispersal", "PFT_name"
  )

# Write CSV file
write.csv(
  dobert_2017_species_trait_data_PFT,
  "../../../data/derived/plant/traits_data/dobert_2017_species_trait_data_PFT.csv", # nolint
  row.names = FALSE
)
