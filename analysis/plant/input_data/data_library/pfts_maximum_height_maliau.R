#| ---
#| title: pfts_maximum_height_maliau
#|
#| description: |
#|     This script assigns plant functional types (PFTs) to the remaining taxa
#|     in the SAFE tree census dataset that were not assigned a PFT in
#|     pfts_maliau. These remaining taxa are classified based on their maximum
#|     height relative to the PFT maximum height values in the T model
#|     parameters. The output of this script combines the base PFT
#|     classification with the additional maximum-height-based assignments.
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
#|       Data includes measurements of DBH and estimates of tree height for
#|       all stems, fruiting and flowering estimates, estimates of epiphyte
#|       and liana cover, and taxonomic IDs.
#|   - name: pfts_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains the base list of taxa and their assigned PFT.
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains a summary of updated T model parameters for each
#|       plant functional type used in the Maliau data library workflow.
#|
#| output_files:
#|   - name: pfts_maximum_height_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       This CSV file contains an updated list of taxa and their respective
#|       PFT. It contains both the base PFT classification from pfts_maliau and
#|       additional assignments for previously unclassified taxa based on their
#|       maximum height relative to PFT maximum height thresholds. Taxon maximum
#|       height is also included in the output file.
#|     variables:
#|       - name: PFT_final
#|         type: integer
#|         units: dimensionless
#|         description: |
#|           Numeric plant functional type code after applying the
#|           maximum-height-based classification.
#|           1 = emergent, 2 = overstory, 3 = pioneer, 4 = understory.
#|         citation: ""
#|         doi: ""
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Unclassified taxa are assigned to PFTs using observed maximum height thresholds from the derived T model output."
#|       - name: PFT_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Human-readable plant functional type label.
#|           One of: emergent, overstory, pioneer, understory.
#|         citation: ""
#|         doi: ""
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Labels are derived from the final numeric PFT assignments after height-based reassignment."
#|       - name: TaxaName
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Full taxon name as recorded in the SAFE tree census dataset.
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Taxon names are taken directly from the SAFE census input file."
#|       - name: TaxaLevel
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Taxonomic resolution of the identification (e.g. species, genus).
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Taxonomic resolution is inherited from the SAFE census input file."
#|       - name: Species
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Species epithet component of the taxon name, where available.
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Species epithets are taken directly from the SAFE census input file and may be blank for higher-level identifications."
#|       - name: Genus
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Genus component of the taxon name.
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Genus names are taken directly from the SAFE census input file."
#|       - name: Family
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant family as recorded in the SAFE tree census dataset.
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Family names are taken directly from the SAFE census input file."
#|       - name: maximum_height
#|         type: numeric
#|         units: m
#|         description: |
#|           Estimated maximum height for each taxon, derived from the tallest
#|           observed individual in the filtered SAFE tree census dataset.
#|         citation: ""
#|         doi: "10.5281/zenodo.14882506"
#|         url: ""
#|         origin: "SAFE Project, Sabah, Malaysia"
#|         biome: "tropical"
#|         vegetation_type: "lowland tropical rain forest"
#|         site_condition: "old-growth and selectively logged"
#|         date: "2011-2020"
#|         assumptions: "Maximum height is taken as the tallest observed individual per taxon in the filtered SAFE census data."
#|
#| package_dependencies:
#|   - readxl
#|   - dplyr
#|   - ggplot2
#|   - tidyr
#|
#| usage_notes: |
#|   This script is intended to run after pfts_maliau and t_model_maliau have
#|   generated the base PFT classification and T model parameters. If the base
#|   PFT species classification is updated in the future, pfts_maliau as well as
#|   t_model_maliau should be updated prior to running this script, because the
#|   output of this script relies on the PFT maximum height values.
#| ---

# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)

# Load SAFE tree census data and clean up

tree_census_11_20 <- read_excel(
  "../../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

data <- tree_census_11_20

max(nrow(data))
colnames(data) <- data[10, ]
data <- data[11:40511, ]
names(data)

# Load base PFT classification and clean up

pfts_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pfts_maliau.csv",
  header = TRUE
)

pfts_maliau <- pfts_maliau[, c("PFT", "PFT_name", "TaxaName")]
pfts_maliau <- unique(pfts_maliau)

# Add PFT and PFT_name to data based on TaxaName and call it data_taxa

data_taxa <- left_join(data, pfts_maliau, by = "TaxaName")

# Give all other trees PFT = 0

data_taxa$PFT[!data_taxa$PFT %in% c(1, 2, 3, 4)] <- 0
unique(data_taxa$PFT)

# Give plots a logging indicator

data_taxa$logging <- NA
data_taxa$logging[
  data_taxa$Block %in%
    c(
      "LFE",
      "LF1",
      "LF2",
      "LF3"
    )
] <- "logged"
data_taxa$logging[
  data_taxa$Block %in%
    c(
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "VJR",
      "OG1",
      "OG2",
      "OG3"
    )
] <- "unlogged"
data_taxa$logging[
  data_taxa$Block %in%
    c(
      "OP1",
      "OP2",
      "OP3"
    )
] <- "oil_palm"

unique(data_taxa$logging)

data_taxa <- data_taxa[
  data_taxa$Block %in%
    c(
      "LFE",
      "LF1",
      "LF2",
      "LF3",
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "VJR",
      "OG1",
      "OG2",
      "OG3"
    ),
]

##########

# Plot height and dbh for each PFT

plot_data <- data_taxa

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)
plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)
plot_data$logging <- as.factor(plot_data$logging)
plot_data$DBH2011_m <- plot_data$DBH2011_mm_clean / 1000

names(plot_data)

ggplot(
  plot_data,
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = as.factor(PFT))
) +
  geom_point() +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship"
  )

##########

# Calculate maximum height for each TaxaName

plot_data$maximum_height <- NA
plot_data$maximum_height_Mahayani <- NA

# Note maximum_height_Mahayani refers to the method used by Mahayani et al. (2022)
# where they used the tallest five percent of trees to estimate the average
# maximum tree height (https://doi.org/10.1016/j.foreco.2021.119948).
# At the moment, this method is retained in the script to allow comparison
# before deciding which one to use.

names(plot_data)
temp <- plot_data[, c(
  "TagStem_latest",
  "Family",
  "Genus",
  "Species",
  "TaxaName",
  "TaxaLevel",
  "PFT",
  "HeightTotal_m_2011",
  "maximum_height",
  "maximum_height_Mahayani",
  "DBH2011_m"
)]
temp <- temp[temp$TaxaLevel %in% c("species", "genus"), ]
temp <- drop_na(temp, TaxaName)

# Note that the step below removes many trees without height measurements.
# Although this part of the script does not calculate stem density, it is good
# to keep this in mind when using these data elsewhere.
temp <- drop_na(temp, HeightTotal_m_2011)

temp <- temp[
  order(
    temp$PFT,
    temp$Family,
    temp$Genus,
    temp$Species,
    temp$HeightTotal_m_2011
  ),
]

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
      (1 -
        exp(
          -0.05 *
            temp$DBH2011_m[
              temp$TaxaName == id &
                temp$HeightTotal_m_2011 >= height_threshold
            ] *
            100
        )),
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
      (1 -
        exp(
          -0.05 *
            temp$DBH2011_m[
              temp$TaxaName == id &
                temp$HeightTotal_m_2011 >= height_threshold
            ] *
            100
        )),
    na.rm = TRUE
  )
}

summary(lm(temp$maximum_height ~ temp$maximum_height_Mahayani))
plot(temp$maximum_height ~ temp$maximum_height_Mahayani)
abline(lm(temp$maximum_height ~ temp$maximum_height_Mahayani))
abline(a = 0, b = 1, col = "red", lty = 2)

# Test out with second maximum height
# temp$maximum_height <- temp$maximum_height_Mahayani

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

# Load t_model_maliau so that we can access the PFT maximum height values

t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

# Reassign taxa where PFT = 0 based on maximum height into PFT 1, 2, 3 or 4

h_max_overstory <- t_model_maliau$h_max[
  t_model_maliau$name == "overstory"
]
h_max_understory <- t_model_maliau$h_max[
  t_model_maliau$name == "understory"
]

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
# so no further adjustment is needed here

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
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "overstory"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "emergent"],
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
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "overstory"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "pioneer"],
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
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "pioneer"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "understory"],
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
    yintercept = t_model_maliau$h_max[t_model_maliau$name == "understory"],
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
  "PFT_final",
  "PFT_name",
  "TaxaName",
  "TaxaLevel",
  "Species",
  "Genus",
  "Family",
  "maximum_height"
)]

data_taxa$PFT_name[data_taxa$PFT_final == "1"] <- "emergent"
data_taxa$PFT_name[data_taxa$PFT_final == "2"] <- "overstory"
data_taxa$PFT_name[data_taxa$PFT_final == "3"] <- "pioneer"
data_taxa$PFT_name[data_taxa$PFT_final == "4"] <- "understory"

data_taxa <- na.omit(data_taxa)
data_taxa <- unique(data_taxa)

data_taxa <- data_taxa[
  order(
    data_taxa$PFT_final,
    data_taxa$Family,
    data_taxa$Genus,
    data_taxa$TaxaName
  ),
]

# Write CSV file

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  data_taxa,
  "../../../../data/derived/plant/input_data/data_library/pfts_maximum_height_maliau.csv",
  row.names = FALSE
)
