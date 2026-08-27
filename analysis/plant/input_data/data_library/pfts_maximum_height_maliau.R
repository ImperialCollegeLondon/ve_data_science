#| ---
#| title: pfts_maximum_height_maliau
#|
#| description: |
#|     This script assigns plant functional types (pfts) to the remaining taxa
#|     in the SAFE tree census dataset that were not assigned a PFT in
#|     pfts_maliau. These remaining taxa are classified based on their maximum
#|     height relative to the pft maximum height.
#|     The output of this script combines the base pft classification with the
#|     additional maximum-height-based assignments.
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
#|       A CSV file containing the plant functional type classification for taxa
#|       in the tree census. The file includes taxa_name and pft_name columns
#|       linking each taxon to its assigned plant functional type (PFT).
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T model parameters by pft.
#|
#| output_files:
#|   - name: pfts_maximum_height_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file containing an updated list of taxa and their respective
#|       pft. It contains both the base pft classification from pfts_maliau and
#|       additional assignments for previously unclassified taxa based on their
#|       maximum height relative to pft maximum height thresholds. Taxon maximum
#|       height is also included in the output file.
#|     variables:
#|       - name: pft_name_h_max_taxa
#|         type: character
#|         units: dimensionless
#|         description: |
#|           The name of the plant functional type (pft) a species is assigned to.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Remaining taxa are assigned a pft based on pft maximum height, using 2011 data across all plots."
#|       - name: pft_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type name.
#|         references:
#|           - citation: "pfts_maliau.csv"
#|             doi: null
#|             url: null
#|             origin: null
#|             biome: null
#|             vegetation_type: null
#|             site_condition: null
#|             date: null
#|         assumptions: |
#|           PFT names are inherited from pfts_maliau.csv and identify the plant
#|           functional type associated with each output record.
#|       - name: taxa_name
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Taxonomic info to finest resolution available.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: taxa_level
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Taxonomic level identified to.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: species
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Species level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: genus
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Genus level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: family
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Family level ID.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: null
#|       - name: h_max_taxa
#|         type: numeric
#|         units: m
#|         description: |
#|           Estimated maximum height for each taxa.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth and selectively logged"
#|             date: "2011-2020"
#|         assumptions: "Maximum height is taken as the tallest observed individual per taxa, using 2011 data across all plots."
#|
#| package_dependencies:
#|   - readxl
#|   - dplyr
#|   - ggplot2
#|   - tidyr
#|
#| usage_notes: |
#|   This script is intended to run after pfts_maliau and t_model_maliau have
#|   generated the base pft classification and T model parameters.
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

colnames(tree_census_11_20) <- tree_census_11_20[10, ]
tree_census_11_20 <- tree_census_11_20[11:max(nrow(tree_census_11_20)), ]
names(tree_census_11_20)

# Load base PFT classification and clean up

pfts_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pfts_maliau.csv",
  header = TRUE
)

pfts_maliau <- pfts_maliau[, c("pft_name", "taxa_name")]
pfts_maliau <- unique(pfts_maliau)

# Note that taxa_name in the original tree_census_11_20 is still called TaxaName

names(tree_census_11_20)[names(tree_census_11_20) == "TaxaName"] <- "taxa_name"

# Add PFT and PFT_name to data based on TaxaName and call it data_taxa

data_taxa <- left_join(tree_census_11_20, pfts_maliau, by = "taxa_name")

# Give all other trees pft_name = unknown

data_taxa$pft_name[
  !data_taxa$pft_name %in% c("emergent", "overstory", "pioneer", "understory")
] <- "unknown"
unique(data_taxa$pft_name)

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
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_point() +
  labs(
    x = "Diameter (m)",
    y = "Height (m)",
    title = "Height-Diameter Relationship"
  )

##########

# Calculate maximum height for each taxa_name

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
  "taxa_name",
  "TaxaLevel",
  "pft_name",
  "HeightTotal_m_2011",
  "maximum_height",
  "maximum_height_Mahayani",
  "DBH2011_m"
)]
temp <- temp[temp$TaxaLevel %in% c("species", "genus"), ]
temp <- drop_na(temp, taxa_name)

# Note that the step below removes many trees without height measurements.
# Although this part of the script does not calculate stem density, it is good
# to keep this in mind when using these data elsewhere.
temp <- drop_na(temp, HeightTotal_m_2011)

temp <- temp[
  order(
    temp$pft_name,
    temp$Family,
    temp$Genus,
    temp$Species,
    temp$HeightTotal_m_2011
  ),
]

taxa_names_species <- unique(temp$taxa_name[temp$TaxaLevel == "species"])
taxa_names_genus <- unique(temp$taxa_name[temp$TaxaLevel == "genus"])

for (id in taxa_names_species) {
  temp$maximum_height[temp$taxa_name == id] <-
    max(temp$HeightTotal_m_2011[temp$taxa_name == id], na.rm = TRUE)
}

for (id in taxa_names_genus) {
  temp$maximum_height[temp$taxa_name == id] <-
    max(temp$HeightTotal_m_2011[temp$Genus == id], na.rm = TRUE)
}

##########

for (id in taxa_names_species) {
  height_threshold <- quantile(
    temp$HeightTotal_m_2011[temp$taxa_name == id],
    0.95,
    na.rm = TRUE
  )
  temp$maximum_height_Mahayani[temp$taxa_name == id] <- mean(
    temp$HeightTotal_m_2011[
      temp$taxa_name == id &
        temp$HeightTotal_m_2011 >= height_threshold
    ] /
      (1 -
        exp(
          -0.05 *
            temp$DBH2011_m[
              temp$taxa_name == id &
                temp$HeightTotal_m_2011 >= height_threshold
            ] *
            100
        )),
    na.rm = TRUE
  )
}

for (id in taxa_names_genus) {
  height_threshold <- quantile(
    temp$HeightTotal_m_2011[temp$taxa_name == id],
    0.95,
    na.rm = TRUE
  )
  temp$maximum_height_Mahayani[temp$taxa_name == id] <- mean(
    temp$HeightTotal_m_2011[
      temp$taxa_name == id &
        temp$HeightTotal_m_2011 >= height_threshold
    ] /
      (1 -
        exp(
          -0.05 *
            temp$DBH2011_m[
              temp$taxa_name == id &
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

# PFT = emergent
ggplot(
  temp[temp$pft_name == "emergent", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = emergent")

# PFT = overstory
ggplot(
  temp[temp$pft_name == "overstory", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = overstory")

# PFT = pioneer
ggplot(
  temp[temp$pft_name == "pioneer", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = pioneer")

# PFT = understory
ggplot(
  temp[temp$pft_name == "understory", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = understory")

# PFT = unknown
ggplot(
  temp[temp$pft_name == "unknown", ],
  aes(x = Genus, y = HeightTotal_m_2011, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Height (m)", title = "PFT = unknown")

# Now repeat but using maximum height

# PFT = emergent
ggplot(
  temp[temp$pft_name == "emergent", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = emergent")

# PFT = overstory
ggplot(
  temp[temp$pft_name == "overstory", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = overstory")

# PFT = pioneer
ggplot(
  temp[temp$pft_name == "pioneer", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = pioneer")

# PFT = understory
ggplot(
  temp[temp$pft_name == "understory", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = understory")

# PFT = unknown
ggplot(
  temp[temp$pft_name == "unknown", ],
  aes(x = Genus, y = maximum_height, color = Genus)
) +
  geom_point() +
  labs(x = "Genus", y = "Maximum height (m)", title = "PFT = unknown")

##########

# Load t_model_maliau so that we can access the pft maximum height values

t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

# Reassign taxa where PFT = 0 based on maximum height into PFT 1, 2, 3 or 4

h_max_overstory <- t_model_maliau$h_max[
  t_model_maliau$pft_name == "overstory"
]

h_max_understory <- t_model_maliau$h_max[
  t_model_maliau$pft_name == "understory"
]

temp$pft_name[
  temp$pft_name == "unknown" &
    temp$maximum_height > h_max_overstory
] <- "emergent"

temp$pft_name[
  temp$pft_name == "unknown" &
    temp$maximum_height <= h_max_overstory &
    temp$maximum_height > h_max_understory
] <- "overstory"

# Note that for pioneers we only rely on the assigned species, and make no
# further adjustments here

temp$pft_name[
  temp$pft_name == "unknown" &
    temp$maximum_height <= h_max_understory
] <- "understory"

# Inspect

ggplot(
  temp,
  aes(x = pft_name, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_point() +
  labs(x = "PFT", y = "Height (m)")

# PFT = emergent
ggplot(
  temp[temp$pft_name == "emergent", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$pft_name == "overstory"],
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$pft_name == "emergent"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT = overstory
ggplot(
  temp[temp$pft_name == "overstory", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$pft_name == "overstory"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT = pioneer
ggplot(
  temp[temp$pft_name == "pioneer", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$pft_name == "pioneer"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

# PFT = understory
ggplot(
  temp[temp$pft_name == "understory", ],
  aes(x = TagStem_latest, y = HeightTotal_m_2011, color = as.factor(pft_name))
) +
  geom_hline(
    yintercept = t_model_maliau$h_max[t_model_maliau$pft_name == "understory"],
    linetype = "dashed"
  ) +
  geom_point() +
  labs(x = "TreeID", y = "Height (m)")

##########

# Add pft based on maximum height to original data_taxa

temp <- temp[, c("taxa_name", "pft_name", "maximum_height")]
temp <- unique(temp)

taxa_names_final <- unique(temp$taxa_name)
data_taxa$pft_name_h_max_taxa <- NA
data_taxa$h_max_taxa <- NA

for (id in taxa_names_final) {
  data_taxa$pft_name_h_max_taxa[data_taxa$taxa_name == id] <- temp$pft_name[
    temp$taxa_name == id
  ]
  data_taxa$h_max_taxa[data_taxa$taxa_name == id] <-
    temp$maximum_height[temp$taxa_name == id]
}

####################

# Prepare data_taxa for saving

data_taxa <- data_taxa[, c(
  "pft_name_h_max_taxa",
  "pft_name",
  "taxa_name",
  "TaxaLevel",
  "Species",
  "Genus",
  "Family",
  "h_max_taxa"
)]

# Exclude rows where pft_name_h_max_taxa is NA and pft_name is unknown

data_taxa <-
  data_taxa[
    !(is.na(data_taxa$pft_name_h_max_taxa) & data_taxa$pft_name == "unknown"),
  ]

# Where pft_name_h_max_taxa is NA replace it with known pft_name

data_taxa$pft_name_h_max_taxa <- ifelse(
  is.na(data_taxa$pft_name_h_max_taxa),
  data_taxa$pft_name,
  data_taxa$pft_name_h_max_taxa
)

# As safety check, remove rows where pft_name_h_max_taxa is now unknown

data_taxa <- data_taxa[data_taxa$pft_name_h_max_taxa != "unknown", ]

data_taxa <- unique(data_taxa)

data_taxa <- data_taxa[
  order(
    data_taxa$pft_name_h_max_taxa,
    data_taxa$Family,
    data_taxa$Genus,
    data_taxa$taxa_name
  ),
]

# Rename columns

colnames(data_taxa) <- c(
  "pft_name_h_max_taxa",
  "pft_name",
  "taxa_name",
  "taxa_level",
  "species",
  "genus",
  "family",
  "h_max_taxa"
)

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
