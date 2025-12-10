#| ---
#| title: Plant functional type species classification maximum height
#|
#| description: |
#|     This script classifies the remaining species (read: TaxaNames) that have
#|     not been assigned a PFT yet (i.e., outside the base classification) into
#|     a PFT based on their species maximum height relative to the PFT maximum
#|     height.
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
#|   - name: t_model_parameters.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of updated T model parameters, as well
#|       as additional PFT traits for leaf and sapwood stoichiometry derived
#|       from the same datasets.
#|
#| output_files:
#|   - name: plant_functional_type_species_classification_maximum_height.csv
#|     path: data/derived/plant/plant_functional_type
#|     description: |
#|       This CSV file contains an updated list of species and their respective PFT.
#|       It contains a) the base PFT species classification and b) for the remaining
#|       species their PFT is assigned based on their maximum height relative to
#|       the PFT maximum height. Species maximum height is also included in the
#|       output file.
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

# Give all other trees PFT = 0

data_taxa$PFT[!data_taxa$PFT %in% c(1, 2, 3, 4)] <- 0
unique(data_taxa$PFT)

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


##########

# Plot height and dbh for each PFT

plot_data <- data_taxa

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)
plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)
plot_data$logging <- as.factor(plot_data$logging)
plot_data$DBH2011_m <- plot_data$DBH2011_mm_clean / 1000 # Scale DBH to meters

names(plot_data)

ggplot(plot_data, aes(x = DBH2011_m, y = HeightTotal_m_2011, color = as.factor(PFT))) +
  geom_point() +
  labs(x = "Diameter (m)", y = "Height (m)", title = "Height-Diameter Relationship")

##########

# Calculate maximum height for each TaxaName

plot_data$maximum_height <- NA
plot_data$maximum_height_Mahayani <- NA
# Note maximum_height_Mahayani refers to the method used by Mahayani et al. (2022)
# where they used the tallest five percent of trees to estimate the average
# maximum tree height (https://doi.org/10.1016/j.foreco.2021.119948).
# At the moment, I'm leaving this method in the script to allow comparison
# before we decide which one to use.

names(plot_data)
temp <- plot_data[, c(
  "TagStem_latest", "Family", "Genus", "Species",
  "TaxaName", "TaxaLevel", "PFT", "HeightTotal_m_2011",
  "maximum_height", "maximum_height_Mahayani", "DBH2011_m"
)]
temp <- temp[temp$TaxaLevel %in% c("species", "genus"), ]
temp <- drop_na(temp, TaxaName)
# Note that the step below removes a lot of trees without height measurements
# Although this part of the script does not calculate stem density (it focuses on
# assigning species/genus into PFTs), it's good to keep this in mind when
# calculating stem density.
temp <- drop_na(temp, HeightTotal_m_2011)
temp <- temp[order(
  temp$PFT, temp$Family, temp$Genus,
  temp$Species, temp$HeightTotal_m_2011
), ]
taxa_names_species <- unique(temp$TaxaName[temp$TaxaLevel == "species"])
taxa_names_genus <- unique(temp$TaxaName[temp$TaxaLevel == "genus"])

for (id in taxa_names_species) {
  temp$maximum_height[temp$TaxaName == id] <-
    max(temp$HeightTotal_m_2011[temp$TaxaName == id], na.rm = TRUE)
}

for (id in taxa_names_genus) {
  temp$maximum_height[temp$TaxaName == id] <-
    max(temp$HeightTotal_m_2011[temp$Genus == id], na.rm = TRUE)
}

##########

for (id in taxa_names_species) {
  height_threshold <- quantile(
    temp$HeightTotal_m_2011[temp$TaxaName == id],
    0.95,
    na.rm = TRUE
  )
  temp$maximum_height_Mahayani[temp$TaxaName == id] <- mean(
    temp$HeightTotal_m_2011[
      temp$TaxaName == id &
        temp$HeightTotal_m_2011 >= height_threshold
    ] /
      (
        1 - exp(
          -0.05 * temp$DBH2011_m[
            temp$TaxaName == id &
              temp$HeightTotal_m_2011 >= height_threshold
          ] * 100
        )
      ),
    na.rm = TRUE
  )
}

for (id in taxa_names_genus) {
  height_threshold <- quantile(
    temp$HeightTotal_m_2011[temp$TaxaName == id],
    0.95,
    na.rm = TRUE
  )
  temp$maximum_height_Mahayani[temp$TaxaName == id] <- mean(
    temp$HeightTotal_m_2011[
      temp$TaxaName == id &
        temp$HeightTotal_m_2011 >= height_threshold
    ] /
      (1 - exp(
        -0.05 * temp$DBH2011_m[
          temp$TaxaName == id &
            temp$HeightTotal_m_2011 >= height_threshold
        ] * 100
      )),
    na.rm = TRUE
  )
}

summary(lm(temp$maximum_height ~ temp$maximum_height_Mahayani))
plot(temp$maximum_height ~ temp$maximum_height_Mahayani)
abline(lm(temp$maximum_height ~ temp$maximum_height_Mahayani))
abline(a = 0, b = 1, col = "red", lty = 2)

# Test out with second maximum height
# temp$maximum_height <- temp$maximum_height_Mahayani # nolint

##########

# For each PFT, plot trees with their height

# PFT 1
ggplot(
  temp[temp$PFT == "1", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = 1")

# PFT 2
ggplot(
  temp[temp$PFT == "2", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = 2")

# PFT 3
ggplot(
  temp[temp$PFT == "3", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = 3")

# PFT 4
ggplot(
  temp[temp$PFT == "4", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = 4")

# PFT 0
ggplot(
  temp[temp$PFT == "0", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = 0")

# Now repeat but using maximum height

# PFT 1
ggplot(
  temp[temp$PFT == "1", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = 1")

# PFT 2
ggplot(
  temp[temp$PFT == "2", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = 2")

# PFT 3
ggplot(
  temp[temp$PFT == "3", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = 3")

# PFT 4
ggplot(
  temp[temp$PFT == "4", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = 4")

# PFT 0
ggplot(
  temp[temp$PFT == "0", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = 0")

##########

# Load t_model_parameters so that we can access the PFT maximum height values

t_model_parameters <- read.csv(
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  header = TRUE
)

# Reassign species where PFT = 0 based on maximum height into PFT 1, 2, 3 or 4

h_max_overstory <- t_model_parameters$h_max[t_model_parameters$name == "overstory"]
h_max_understory <- t_model_parameters$h_max[t_model_parameters$name == "understory"]

temp$PFT[
  temp$PFT == 0 &
    temp$maximum_height > h_max_overstory
] <- 1

temp$PFT[
  temp$PFT == 0 &
    temp$maximum_height <= h_max_overstory &
    temp$maximum_height > h_max_understory
] <- 2

# Note that for pioneers, all Macaranga species already have PFT 3,
# so no further adjustment needed here

temp$PFT[
  temp$PFT == 0 &
    temp$maximum_height <= h_max_understory
] <- 4

# Inspect

ggplot(temp, aes(x = PFT, y = HeightTotal_m_2011, color = as.factor(PFT))) +
  geom_point() +
  labs(x = "PFT", y = "Height (m)")

# PFT 1
ggplot(
  temp[temp$PFT == "1", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(PFT))
) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "2"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "1"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT 2
ggplot(
  temp[temp$PFT == "2", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(PFT))
) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "2"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "3"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT 3
ggplot(
  temp[temp$PFT == "3", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(PFT))
) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "3"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "4"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT 4
ggplot(
  temp[temp$PFT == "4", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(PFT))
) +
  geom_hline(
    yintercept = t_model_parameters$Hm[t_model_parameters$PFT == "4"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

##########

# Add PFT based on maximum height to original data_taxa

temp <- temp[, c("TaxaName", "PFT", "maximum_height")]
temp <- unique(temp)

taxa_names_final <- unique(temp$TaxaName)
data_taxa$PFT_final <- NA
data_taxa$maximum_height <- NA

for (id in taxa_names_final) {
  data_taxa$PFT_final[data_taxa$TaxaName == id] <- temp$PFT[temp$TaxaName == id]
  data_taxa$maximum_height[data_taxa$TaxaName == id] <-
    temp$maximum_height[temp$TaxaName == id]
}

####################

# Prepare data_taxa for saving

data_taxa <- data_taxa[, c(
  "PFT_final", "PFT_name", "TaxaName",
  "TaxaLevel", "Species", "Genus", "Family",
  "maximum_height"
)]

data_taxa$PFT_name[data_taxa$PFT_final == "1"] <- "emergent"
data_taxa$PFT_name[data_taxa$PFT_final == "2"] <- "overstory"
data_taxa$PFT_name[data_taxa$PFT_final == "3"] <- "pioneer"
data_taxa$PFT_name[data_taxa$PFT_final == "4"] <- "understory"

data_taxa <- na.omit(data_taxa)
data_taxa <- unique(data_taxa)

data_taxa <- data_taxa[order(
  data_taxa$PFT_final, data_taxa$Family,
  data_taxa$Genus, data_taxa$TaxaName
), ]

# Write CSV file

write.csv(
  data_taxa,
  "../../../data/derived/plant/plant_functional_type/plant_functional_type_species_classification_maximum_height.csv", # nolint
  row.names = FALSE
)
