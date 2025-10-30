#| ---
#| title: T model parameterisation
#|
#| description: |
#|     This script focuses on updating the base values for the parameters in
#|     the T model to values more closely aligned with the SAFE project.
#|     The script works with multiple datasets and calculates values for the
#|     T model, ideally at PFT level. Species are linked to their PFT by working
#|     with the output of the PFT species classification base script.
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
#|   - name: inagawa_nutrients_wood_density.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.8158811
#|       Tree census data from the SAFE Project 2011–2020.
#|       Nutrients and wood density in coarse root, trunk and branches in
#|       Bornean tree species.
#|   - name: both_tree_functional_traits.xlsx
#|     path: data/primary/plant/traits_data
#|     description: |
#|       https://doi.org/10.5281/zenodo.3247631
#|       Functional traits of tree species in old-growth and selectively
#|       logged forest.
#|
#| output_files:
#|   - name: t_model_parameters.csv
#|     path: data/derived/plant/traits_data
#|     description: |
#|       This CSV file contains a summary of updated T model parameters for each PFT.
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|     - stringr
#|
#| usage_notes: |
#|   This script is intended to run entirely from start to finish in order to
#|   preserve the flow and links between different datasets, so that the final
#|   output file contains all necessary parts. The units are the same as the
#|   ones in Li et al. (2014) unless specified otherwise in the script.
#|   A summary of the unit for each variable can also be found at the end of
#|   this script. Variable names have been matched with those used by the VE.
#| ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)
library(stringr)

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


##########

# From here, we start gathering T model parameters to replace/update the ones
# from Li et al. (2014): DOI https://doi.org/10.5194/bg-11-6711-2014

# Initial slope of height–diameter relationship

plot_data <- data_taxa[, c(
  "Block", "Plot", "PlotID", "logging", "TagStem_latest", "PFT", "Genus",
  "Species", "TaxaName", "HeightTotal_m_2011", "DBH2011_mm_clean",
  "CanopyRadiusNorth_cm_2011", "CanopyRadiusEast_cm_2011",
  "CanopyRadiusSouth_cm_2011", "CanopyRadiusWest_cm_2011", "HeightBranch_m_2011"
)]

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)
plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)
plot_data$CanopyRadiusNorth_cm_2011 <- as.numeric(plot_data$CanopyRadiusNorth_cm_2011)
plot_data$CanopyRadiusEast_cm_2011 <- as.numeric(plot_data$CanopyRadiusEast_cm_2011)
plot_data$CanopyRadiusSouth_cm_2011 <- as.numeric(plot_data$CanopyRadiusSouth_cm_2011)
plot_data$CanopyRadiusWest_cm_2011 <- as.numeric(plot_data$CanopyRadiusWest_cm_2011)
plot_data$HeightBranch_m_2011 <- as.numeric(plot_data$HeightBranch_m_2011)

plot_data$logging <- as.factor(plot_data$logging)

# Note that measurements of height, dbh and crown radius are linked per row
# So, even though crown radius is not required for height-diameter relationship,
# using na.omit on the next line is OK.
# Also note that a lot of rows have missing values, figure out why they were not
# measured (maybe trees were dead?). If trees were actually there, they also
# need to be included for stem distribution later on.

plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$crown_radius <- rowMeans(cbind(
  plot_data$CanopyRadiusNorth_cm_2011,
  plot_data$CanopyRadiusEast_cm_2011,
  plot_data$CanopyRadiusSouth_cm_2011,
  plot_data$CanopyRadiusWest_cm_2011
))

plot_data$crown_circular_area <- pi * ((plot_data$crown_radius / 100)^2)
# Converted to meters
plot_data$crown_ellipsoidal_area <- 0.25 * (
  pi * 2 * plot_data$crown_radius / 100 *
    (plot_data$HeightTotal_m_2011 - plot_data$HeightBranch_m_2011)
)
plot_data$crown_projected_area <- plot_data$crown_ellipsoidal_area

plot_data$DBH2011_m <- plot_data$DBH2011_mm_clean / 1000 # Scale DBH to meters

###

# Checking crown projected area (for comparison with Pyrealm graphs)

ggplot(plot_data, aes(
  x = DBH2011_m, y = crown_projected_area, color =
    factor(PFT)
)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ exp(x), se = FALSE) + # Exponential fit
  ylim(0, 300) + # Limit y-axis to 300
  labs(x = "DBH 2011 (m)", y = "Crown projected area (m²)", color = "PFT") +
  theme_minimal()

###

# Fitting the asymptotic height-diameter model
# Nonlinear model: H = Hm * (1 - exp(-a * D / Hm))

# PFT 1

plot(HeightTotal_m_2011 ~ DBH2011_m, data = plot_data[plot_data$PFT == "1", ])

nls_model_1 <- nls(HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$PFT == "1", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_1)
coef_1 <- coef(nls_model_1) # nolint
coef_1 # nolint
Hm_1 <- coef_1["Hm"] # nolint
a_1 <- coef_1["a"] # nolint

ggplot(plot_data[plot_data$PFT == "1", ], aes(
  x = DBH2011_m,
  y = HeightTotal_m_2011,
  color = logging
)) +
  geom_point() +
  stat_function(
    fun = function(D) { # nolint
      coef(nls_model_1)["Hm"] *
        (1 - exp(-coef(nls_model_1)["a"] * D / coef(nls_model_1)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)", y = "Height (m)",
    title = "Height-Diameter Relationship PFT1"
  )

data_taxa$Hm <- NA
data_taxa$Hm_SE <- NA
data_taxa$a <- NA
data_taxa$a_SE <- NA

data_taxa$Hm[data_taxa$PFT == "1"] <- Hm_1
data_taxa$a[data_taxa$PFT == "1"] <- a_1
data_taxa$Hm_SE[data_taxa$PFT == "1"] <-
  round(summary(nls_model_1)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$PFT == "1"] <-
  round(summary(nls_model_1)$coefficients["a", "Std. Error"], 2)

# PFT 2

plot(HeightTotal_m_2011 ~ DBH2011_m, data = plot_data[plot_data$PFT == "2", ])

nls_model_2 <- nls(HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$PFT == "2", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_2)
coef_2 <- coef(nls_model_2)
coef_2
Hm_2 <- coef_2["Hm"] # nolint
a_2 <- coef_2["a"]

ggplot(
  plot_data[plot_data$PFT == "2", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) { # nolint
      coef(nls_model_2)["Hm"] *
        (1 - exp(-coef(nls_model_2)["a"] * D / coef(nls_model_2)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)", y = "Height (m)",
    title = "Height-Diameter Relationship PFT2"
  )

data_taxa$Hm[data_taxa$PFT == "2"] <- Hm_2
data_taxa$a[data_taxa$PFT == "2"] <- a_2
data_taxa$Hm_SE[data_taxa$PFT == "2"] <-
  round(summary(nls_model_2)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$PFT == "2"] <-
  round(summary(nls_model_2)$coefficients["a", "Std. Error"], 2)

# PFT 3

plot(HeightTotal_m_2011 ~ DBH2011_m, data = plot_data[plot_data$PFT == "3", ])

nls_model_3 <- nls(HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$PFT == "3", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_3)
coef_3 <- coef(nls_model_3)
coef_3
Hm_3 <- coef_3["Hm"] # nolint
a_3 <- coef_3["a"]

ggplot(
  plot_data[plot_data$PFT == "3", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) { # nolint
      coef(nls_model_3)["Hm"] *
        (1 - exp(-coef(nls_model_3)["a"] * D / coef(nls_model_3)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)", y = "Height (m)",
    title = "Height-Diameter Relationship PFT3"
  )

data_taxa$Hm[data_taxa$PFT == "3"] <- Hm_3
data_taxa$a[data_taxa$PFT == "3"] <- a_3
data_taxa$Hm_SE[data_taxa$PFT == "3"] <-
  round(summary(nls_model_3)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$PFT == "3"] <-
  round(summary(nls_model_3)$coefficients["a", "Std. Error"], 2)

# PFT 4 (low data availability for height measurements)

plot(HeightTotal_m_2011 ~ DBH2011_m, data = plot_data[
  plot_data$PFT == "4",
])

nls_model_4 <- nls(HeightTotal_m_2011 ~ Hm * (1 - exp(-a * DBH2011_m / Hm)),
  data = plot_data[plot_data$PFT == "4", ],
  start = list(Hm = 40, a = 116), # Starting guesses for Hm and a
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_4)
coef_4 <- coef(nls_model_4)
coef_4
Hm_4 <- coef_4["Hm"] # nolint
a_4 <- coef_4["a"]

ggplot(
  plot_data[plot_data$PFT == "4", ],
  aes(x = DBH2011_m, y = HeightTotal_m_2011, color = logging)
) +
  geom_point() +
  stat_function(
    fun = function(D) { # nolint
      coef(nls_model_4)["Hm"] *
        (1 - exp(-coef(nls_model_4)["a"] * D / coef(nls_model_4)["Hm"]))
    },
    color = "blue"
  ) +
  labs(
    x = "Diameter (m)", y = "Height (m)",
    title = "Height-Diameter Relationship PFT 4"
  )

data_taxa$Hm[data_taxa$PFT == "4"] <- Hm_4
data_taxa$a[data_taxa$PFT == "4"] <- a_4
data_taxa$Hm_SE[data_taxa$PFT == "4"] <-
  round(summary(nls_model_4)$coefficients["Hm", "Std. Error"], 2)
data_taxa$a_SE[data_taxa$PFT == "4"] <-
  round(summary(nls_model_4)$coefficients["a", "Std. Error"], 2)

##########

# Initial ratio of crown area to stem cross-sectional area

# PFT 1

backup <- plot_data
plot_data <- backup[backup$PFT == "1", ]

plot_data$piDH4a <- pi * plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 / (4 * a_1)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_1 <- a_1

nls_model_1 <- nls(
  crown_projected_area ~ pi *
    c * DBH2011_m * HeightTotal_m_2011 / (4 * a_1),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_1)
coef_1 <- coef(nls_model_1)
coef_1
c_1 <- coef_1["c"]

plot_data$predicted_crown_area <- predict(nls_model_1, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)", y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship PFT1"
  )

data_taxa$c <- NA
data_taxa$c_SE <- NA
data_taxa$c[data_taxa$PFT == "1"] <- c_1
data_taxa$c_SE[data_taxa$PFT == "1"] <-
  round(summary(nls_model_1)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li method)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_1) / (4 * a_1)) *
  plot_data$DBH2011_m * plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(x = "Ac (m2)", y = "Crown projected area (m2)", title = "Crown area PFT1")

##########

# PFT 2

plot_data <- backup[backup$PFT == "2", ]

# Removed outliers
plot_data <- plot_data[plot_data$crown_projected_area < 90, ]

plot_data$piDH4a <- pi * plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 / (4 * a_2)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_2 <- a_2

nls_model_2 <- nls(
  crown_projected_area ~ pi * c *
    DBH2011_m * HeightTotal_m_2011 / (4 * a_2),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_2)
coef_2 <- coef(nls_model_2)
coef_2
c_2 <- coef_2["c"]

plot_data$predicted_crown_area <- predict(nls_model_2, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)", y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship PFT2"
  )

data_taxa$c[data_taxa$PFT == "2"] <- c_2
data_taxa$c_SE[data_taxa$PFT == "2"] <-
  round(summary(nls_model_2)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_2) / (4 * a_2)) *
  plot_data$DBH2011_m * plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(x = "Ac (m2)", y = "Crown projected area (m2)", title = "Crown area PFT2")

##########

# PFT 3

plot_data <- backup[backup$PFT == "3", ]

plot_data$piDH4a <- pi * plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 / (4 * a_3)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_3 <- a_3

nls_model_3 <- nls(
  crown_projected_area ~ pi *
    c * DBH2011_m * HeightTotal_m_2011 / (4 * a_3),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_3)
coef_3 <- coef(nls_model_3)
coef_3
c_3 <- coef_3["c"]

plot_data$predicted_crown_area <- predict(nls_model_3, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)", y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship PFT3"
  )

data_taxa$c[data_taxa$PFT == "3"] <- c_3
data_taxa$c_SE[data_taxa$PFT == "3"] <-
  round(summary(nls_model_3)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_3) / (4 * a_3)) *
  plot_data$DBH2011_m * plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(x = "Ac (m2)", y = "Crown projected area (m2)", title = "Crown area PFT3")

##########

# PFT 4

plot_data <- backup[backup$PFT == "4", ]

plot_data$piDH4a <- pi * plot_data$DBH2011_m *
  plot_data$HeightTotal_m_2011 / (4 * a_4)
plot(crown_projected_area ~ piDH4a, data = plot_data)
plot_data$a_4 <- a_4

nls_model_4 <- nls(
  crown_projected_area ~ pi *
    c * DBH2011_m * HeightTotal_m_2011 / (4 * a_4),
  data = plot_data,
  start = list(c = 400), # Starting guesses c
  control = nls.control(maxiter = 100)
) # Increase iterations if needed
summary(nls_model_4)
coef_4 <- coef(nls_model_4)
coef_4
c_4 <- coef_4["c"]

plot_data$predicted_crown_area <- predict(nls_model_4, newdata = plot_data)

ggplot(plot_data, aes(x = piDH4a, y = crown_projected_area, color = logging)) +
  geom_point() + # scatterplot of data points
  geom_line(aes(y = predicted_crown_area), color = "blue") + # fitted line
  labs(
    x = "piDH/4a (m2)", y = "Crown projected area (m2)",
    title = "Crown-Diameter Relationship PFT4"
  )

data_taxa$c[data_taxa$PFT == "4"] <- c_4
data_taxa$c_SE[data_taxa$PFT == "4"] <-
  round(summary(nls_model_4)$coefficients["c", "Std. Error"], 2)

###

# Comparing both values for projected crown area (i.e., ellipsoidal and Li values)

plot_data$Ac <- NA
plot_data$Ac <- ((pi * c_4) / (4 * a_4)) *
  plot_data$DBH2011_m * plot_data$HeightTotal_m_2011

summary(lm(plot_data$crown_projected_area ~ plot_data$Ac))

ggplot(plot_data, aes(x = Ac, y = crown_projected_area, color = logging)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(x = "Ac (m2)", y = "Crown projected area (m2)", title = "Crown area PFT4")

##########

# Create summary (in the next part we will add more traits to this)

summary <- data_taxa

backup <- summary

##########

# Create some overview plots

# Figures for total tree height (HeightTotal_m_2011)

data <- data_taxa

names(data)

plot_data <- data[, c(
  "Block", "Plot", "PlotID",
  "logging", "TagStem_latest", "PFT",
  "TaxaName", "HeightTotal_m_2011"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)

ggplot(plot_data, aes(
  x = TagStem_latest, y = HeightTotal_m_2011,
  color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "Height total 2011 (m)") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = HeightTotal_m_2011,
  color = as.factor(logging)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean Height total 2011 (m)") +
  theme_minimal()

##########

# Figures for DBH (DBH2011_mm_clean)

data <- data_taxa

names(data)

plot_data <- data[, c(
  "Block", "Plot", "PlotID", "logging",
  "TagStem_latest", "PFT", "TaxaName", "DBH2011_mm_clean"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)

ggplot(plot_data, aes(
  x = TagStem_latest, y = DBH2011_mm_clean,
  color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "DBH 2011 (mm)") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = DBH2011_mm_clean,
  color = as.factor(logging)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean DBH 2011 (mm)") +
  theme_minimal()

################################################################################

# Calculate sapwood carbon content (needed to convert wood density later on)

# Load wood nutrients data and clean up a bit

inagawa_nutrients_wood_density <- read_excel(
  "../../../data/primary/plant/traits_data/inagawa_nutrients_wood_density.xlsx",
  sheet = "Nutrients",
  col_names = FALSE
)

data <- inagawa_nutrients_wood_density

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:427, ]
names(data)

data <- data[, c("Species", "TissueType", "C_total")]
colnames(data) <- c("species", "TissueType", "C_total")

data$C_total <- as.numeric(data$C_total)

# Because we only have 10 unique species, we'll use the mean across species

temp <- data[, c("species", "TissueType", "C_total")]
unique(temp$TissueType)
temp <- temp[temp$TissueType == "Sapwood", ]

temp <- temp %>%
  group_by(species) %>%
  mutate(C_total_mean = mean(as.numeric(C_total), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "TissueType", "C_total_mean")]
temp <- unique(temp)

mean(temp$C_total_mean) # Use 45.9% carbon content for sapwood later in calculations

################################################################################

# More traits (wood density and SLA)

both_tree_functional_traits <- read_excel(
  "../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

data <- both_tree_functional_traits

max(nrow(data))
colnames(data) <- data[7, ]
data <- data[8:724, ]
names(data)

##########

# Replace "." by a space in the species name

data <- data %>%
  mutate(species = str_replace_all(species, fixed("."), " "))

# Seperate genus from species into its own column

data <- data %>%
  mutate(genus = word(species, 1))

data <- data[, c(1:9, 86, 10:85)]

##########

# Link dataset to PFT species classification dataset

# Match by species first
data1 <- left_join(data, PFT_species_classification_base,
  by = c("species" = "TaxaName")
)

# Match by genus only for rows where PFT is still NA
data2 <- left_join(data, PFT_species_classification_base,
  by = c("genus" = "TaxaName")
)

# Combine: take PFT and PFT_name from species match if available,
# otherwise from genus match
data$PFT <- ifelse(!is.na(data1$PFT), data1$PFT, data2$PFT)
data$PFT_name <- ifelse(!is.na(data1$PFT_name), data1$PFT_name, data2$PFT_name)

##########

# Wood density (WD_NB)

plot_data <- data[, c(
  "location", "forest_type", "sample_code",
  "PFT", "PFT_name", "species", "WD_NB"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$WD_NB <- as.numeric(plot_data$WD_NB)
plot_data$forest_type <- as.factor(plot_data$forest_type)

# Convert WD to carbon content

plot_data$WD_NB <- plot_data$WD_NB * 1000
# Convert WD from g cm-3 to kg m-3
plot_data$WD_NB <- plot_data$WD_NB * 0.459
# Account for 45.9% carbon content (see earlier calculation)

ggplot(plot_data, aes(x = sample_code, y = WD_NB, color = as.factor(PFT))) +
  geom_point() +
  labs(x = "Individual", y = "Wood density (kg C m-3)") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = WD_NB,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean Wood density (kg C m-3)") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_WD_NB = mean(WD_NB, na.rm = TRUE),
    SD_WD_NB = sd(WD_NB, na.rm = TRUE)
  )

print(summary_stats)

# Write to summary

summary$WD_NB <- NA
summary$WD_NB_SD <- NA

summary$WD_NB[summary$PFT == "1"] <- round(summary_stats[1, "Mean_WD_NB"], 2)
summary$WD_NB_SD[summary$PFT == "1"] <- round(summary_stats[1, "SD_WD_NB"], 2)
summary$WD_NB[summary$PFT == "2"] <- round(summary_stats[2, "Mean_WD_NB"], 2)
summary$WD_NB_SD[summary$PFT == "2"] <- round(summary_stats[2, "SD_WD_NB"], 2)
summary$WD_NB[summary$PFT == "3"] <- round(summary_stats[3, "Mean_WD_NB"], 2)
summary$WD_NB_SD[summary$PFT == "3"] <- round(summary_stats[3, "SD_WD_NB"], 2)
summary$WD_NB[summary$PFT == "4"] <- round(summary_stats[4, "Mean_WD_NB"], 2)
summary$WD_NB_SD[summary$PFT == "4"] <- round(summary_stats[4, "SD_WD_NB"], 2)

##########

# SLA (SLA_mm2.mg_mean)

plot_data <- data[, c(
  "location", "forest_type", "sample_code",
  "PFT", "species", "SLA_mm2.mg_mean", "C_perc"
)]
plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$forest_type <- as.factor(plot_data$forest_type)
plot_data$SLA_mm2.mg_mean <- as.numeric(plot_data$SLA_mm2.mg_mean)
plot_data$C_perc <- as.numeric(plot_data$C_perc)
plot_data$C_perc <- plot_data$C_perc / 100 # Convert to decimal

plot_data$SLA_mm2.mg_mean <- plot_data$SLA_mm2.mg_mean /
  plot_data$C_perc # Convert using carbon content

ggplot(plot_data, aes(
  x = sample_code,
  y = SLA_mm2.mg_mean, color = as.factor(PFT)
)) +
  geom_point() +
  labs(x = "Individual", y = "SLA (mm2 mg-1 C)") +
  theme_minimal()

ggplot(plot_data, aes(
  x = as.factor(PFT), y = SLA_mm2.mg_mean,
  color = as.factor(forest_type)
)) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.6) +
  stat_summary(fun = "mean", geom = "point", size = 4, color = "black") +
  labs(x = "PFT", y = "Mean SLA (mm2 mg-1 C)") +
  theme_minimal()

summary_stats <- plot_data %>%
  group_by(PFT) %>%
  summarise(
    Mean_SLA_mm2.mg_mean = mean(SLA_mm2.mg_mean, na.rm = TRUE),
    SD_SLA_mm2.mg_mean = sd(SLA_mm2.mg_mean, na.rm = TRUE)
  )

print(summary_stats)

# Write to summary

summary$SLA <- NA
summary$SLA_SD <- NA

summary$SLA[summary$PFT == "1"] <-
  round(summary_stats[1, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$PFT == "1"] <-
  round(summary_stats[1, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$PFT == "2"] <-
  round(summary_stats[2, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$PFT == "2"] <-
  round(summary_stats[2, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$PFT == "3"] <-
  round(summary_stats[3, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$PFT == "3"] <-
  round(summary_stats[3, "SD_SLA_mm2.mg_mean"], 2)
summary$SLA[summary$PFT == "4"] <-
  round(summary_stats[4, "Mean_SLA_mm2.mg_mean"], 2)
summary$SLA_SD[summary$PFT == "4"] <-
  round(summary_stats[4, "SD_SLA_mm2.mg_mean"], 2)

backup <- summary

################################################################################

# Calculate the number of trees and species within PFT
# This step is primarily used as a quality/robustness check of the data

summary <- backup

names(summary)
summary <- summary[, c(
  "PFT", "PFT_name", "Family", "Genus", "Species", "TaxaName",
  "HeightTotal_m_2011", "Hm", "Hm_SE", "a", "a_SE", "c", "c_SE",
  "WD_NB", "WD_NB_SD", "SLA", "SLA_SD", "TagStem_latest"
)]
summary <- summary[order(
  summary$PFT, summary$Family,
  summary$Genus, summary$Species,
  summary$HeightTotal_m_2011
), ]

summary$TaxaNames <- NA
summary$Trees <- NA

summary$TaxaNames[summary$PFT == "1"] <-
  length(unique(summary$TaxaName[summary$PFT == "1"]))
summary$TaxaNames[summary$PFT == "2"] <-
  length(unique(summary$TaxaName[summary$PFT == "2"]))
summary$TaxaNames[summary$PFT == "3"] <-
  length(unique(summary$TaxaName[summary$PFT == "3"]))
summary$TaxaNames[summary$PFT == "4"] <-
  length(unique(summary$TaxaName[summary$PFT == "4"]))

summary$Trees[summary$PFT == "1"] <-
  length(unique(summary$TagStem_latest[summary$PFT == "1"]))
summary$Trees[summary$PFT == "2"] <-
  length(unique(summary$TagStem_latest[summary$PFT == "2"]))
summary$Trees[summary$PFT == "3"] <-
  length(unique(summary$TagStem_latest[summary$PFT == "3"]))
summary$Trees[summary$PFT == "4"] <-
  length(unique(summary$TagStem_latest[summary$PFT == "4"]))

# Clean up summary

summary <- summary[, c(
  "PFT", "PFT_name", "Family", "Genus", "Species", "TaxaName",
  "TaxaNames", "Trees", "HeightTotal_m_2011", "Hm", "Hm_SE",
  "a", "a_SE", "c", "c_SE",
  "WD_NB", "WD_NB_SD", "SLA", "SLA_SD"
)]
summary <- summary[order(
  summary$PFT, summary$Family, summary$Genus,
  summary$Species, summary$HeightTotal_m_2011
), ]

names(summary)
summary <- summary[, c(
  "PFT", "PFT_name", "Hm", "Hm_SE", "a", "a_SE", "c", "c_SE",
  "WD_NB", "WD_NB_SD", "SLA", "SLA_SD", "TaxaNames", "Trees"
)]

summary <- unique(summary)
summary <- na.omit(summary)
summary <- summary[order(summary$PFT), ]
rownames(summary) <- 1:nrow(summary) # nolint

summary$WD_NB <- as.numeric(summary$WD_NB)
summary$WD_NB_SD <- as.numeric(summary$WD_NB_SD)
summary$SLA <- as.numeric(summary$SLA)
summary$SLA_SD <- as.numeric(summary$SLA_SD)

################################################################################

# Below we add the remaining T model parameters. Most of these are not PFT
# specific (for now).

#####

# Leaf area index
# LAI is assumed to be constant across PFTs and within the crown/canopy
# The value for LAI is based on Pfeifer et al. (2016)
# (DOI https://doi.org/10.1016/j.rse.2016.01.014)
# This paper has mean values for primary forest, lightly logged, twice logged,
# salvage logged and oil palm plantation
# It also provides SD as measure of uncertainty (not included here atm)

summary$leaf_area_index <- 4.43

#####

# Light extinction coefficient
# Value is taken from White et al. (2000)
# (DOI https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2),
# The value used is the one reported for rain forest by Waring and Schlesinger (1985)

summary$light_extinction_coefficient <- 0.6

#####

# Leaf turnover
# Value based on Anderson et al. (1983)
# (DOI; https://doi.org/10.2307/2259731)
# The value used here is for dipterocarp forest, but paper also has values for
# alluvial forest, heath forest and forest over limestone
# Turnover time (unit = years) is calculated as the inverse of turnover per year

summary$turnover_leaf <- 1 / 1.7

# Reproductive organ turnover
# The same approach and data is used as for leaf turnover

summary$turnover_reproductive_organ <- 1 / 10

# Fine root turnover
# Value based on Huaraca Huasco et al. (2021)
# (DOI https://doi.org/10.1111/gcb.15677)
# Value calculated as the mean root residence time based on 4 plots (Table 4)
# (DAN-04 and DAN-05 from Danum, MLA-01 and MLA-02 from Maliau)

summary$turnover_fine_root <- mean(c(0.63, 1.76, 1.50, 1.79))

#####

# Fine root specific respiration
# Value based on Yan and Zhao (2007)
# (DOI http://dx.doi.org/10.1016/S1872-2032(07)60056-0)
# Value for tropical rain forest tree is used (Table 2)

summary$respiration_fine_root <- (1.5 * 10^-3) * 365

# Leaf specific respiration
# Same approach and data used as for fine root specific respiration

summary$respiration_leaf <- (2.0 * 10^-3) * 365

# Wood specific respiration
# Same approach and data used as for fine root and leaf specific respiration

summary$respiration_wood <- (1.0 * 10^-3) * 365

#####

# Yield factor
# Value based on Yan and Zhao (2007)
# (DOI http://dx.doi.org/10.1016/S1872-2032(07)60056-0)
# Yield factor calculated from growth respiration coefficient (rg) using the
# formula: 1/(1+rg) where rg = 0.25

summary$yield_factor <- (1 / (1 + 0.25))

#####

# Fine root mass to foliage area ratio
# There are 2 main datasets used here:
# -the data from Kenzo et al. (2015)
# (DOI http://dx.doi.org/10.1007/s10310-014-0465-y)
# -the data from Niiyama et al. (2010)
# (DOI http://dx.doi.org/10.1017/S0266467410000040)

# Both of these papers have data on foliage mass and fine root mass
# However, fine root mass needs to be expressed on carbon mass basis
# So, the dry weight mass of fine roots needs to be corrected for carbon content
# To do this, we'll use the mean carbon content for based on Imai et al. (2010)
# (DOI https://doi.org/10.1017/S0266467410000350) for fine roots: 45.2%.

# As a first approach we can focus on the data from Kenzo et al. (2015)
# Here, we can use leaf and fine root mass and LMA (combined with Imai's fine root
# carbon content) to define a ratio that is (mostly) tracked within 1 study system.

# As a second approach we could focus on getting an average ratio between fine
# root mass and foliage mass, which is then linked to the SLA of each PFT
# Note that PFT SLA values will first need to be converted back to dry weight mass
# using the foliar carbon percentage (found in both_tree_functional_traits)
# or instead use the uncorrected PFT SLA values still stored in plot_data.
# This approach is similar to the one that Li et al. (2014) used
# I think it makes sense to assume that there is more variability in the conversion
# from foliage mass to area than in the ratio between fine root and foliage mass.
# If we then average the ratio between fine root and foliage mass across studies
# we can capture most of this variability across studies/systems.

#####

# First approach: Kenzo et al (2015)
# Data extracted from paper directly
# For fine root mass, values below and above 10 cm depth are combined

kenzo_data <- data.frame(
  site = c("Sabal", "Balai Ringin"),
  leaf_dry_mass_big_trees = c(5.1, 5.5),
  leaf_dry_mass_small_trees = c(2.5, 1.6),
  fine_root_total_dry_mass = c(26.8, 5.8),
  leaf_mass_per_area_big_trees = c(155.6, 155.6),
  leaf_mass_per_area_small_trees = c(73.3, 73.3)
)

# Note that Sabal is logged and Balai Ringin is protected
# So, preferable we'd use the Balai Ringin values, however, the root mass seems
# very low compared to Sabal, and other studies (like Niiyama)

# Convert the leaf dry mass from megagrams per hectare to grams per hectare
kenzo_data$leaf_dry_mass_big_trees <- kenzo_data$leaf_dry_mass_big_trees * 1000000
kenzo_data$leaf_dry_mass_small_trees <- kenzo_data$leaf_dry_mass_small_trees * 1000000

# Use LMA to find the total leaf area (m2 per hectare)
kenzo_data$leaf_area_big_trees <-
  kenzo_data$leaf_dry_mass_big_trees / kenzo_data$leaf_mass_per_area_big_trees
kenzo_data$leaf_area_small_trees <-
  kenzo_data$leaf_dry_mass_small_trees / kenzo_data$leaf_mass_per_area_small_trees

# Combine leaf area of big and small trees to get total leaf area
kenzo_data$total_leaf_area <-
  kenzo_data$leaf_area_big_trees + kenzo_data$leaf_area_small_trees

# Correct fine root dry mass for carbon content (45.2%)
kenzo_data$fine_root_total_carbon_mass <-
  kenzo_data$fine_root_total_dry_mass * 45.2 / 100

# Convert fine root carbon mass from Mg per hectare to kg per hectare
kenzo_data$fine_root_total_carbon_mass <-
  kenzo_data$fine_root_total_carbon_mass * 1000

# Calculate the ratio of fine root carbon mass divided by leaf area
kenzo_data$fine_root_carbon_foliage_area <-
  kenzo_data$fine_root_total_carbon_mass / kenzo_data$total_leaf_area

print(kenzo_data$fine_root_carbon_foliage_area)

#####

# Second approach: obtaining a mean ratio between foliage and fine root dry mass
# and then linking this to PFT specific SLA values

# Extract mean dry mass ratio directly from Niiyama et al. (2010) paper
# Add rows for each PFT in the model

niiyama_data <- data.frame(
  PFT_name = c("emergent", "overstory", "understory", "pioneer"),
  leaf_dry_mass = c(5.7, 5.7, 5.7, 5.7),
  fine_root_dry_mass = c(13.3, 13.3, 13.3, 13.3)
)

# Get PFT specific SLA values (not corrected for carbon content)
# These data are stored per PFT in "data" (see earlier in this script)
# The unit of SLA is mm2 mg-1

names(data)
pft_sla_data <- data[, c("PFT_name", "SLA_mm2.mg_mean")]
pft_sla_data <- na.omit(pft_sla_data)
pft_sla_data$SLA_mm2.mg_mean <- as.numeric(pft_sla_data$SLA_mm2.mg_mean)
pft_sla_data$specific_leaf_area_pft <- NA

pft_sla_data$specific_leaf_area_pft[pft_sla_data$PFT_name == "emergent"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$PFT_name == "emergent"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$PFT_name == "overstory"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$PFT_name == "overstory"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$PFT_name == "understory"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$PFT_name == "understory"])
pft_sla_data$specific_leaf_area_pft[pft_sla_data$PFT_name == "pioneer"] <-
  mean(pft_sla_data$SLA_mm2.mg_mean[pft_sla_data$PFT_name == "pioneer"])

pft_sla_data <- pft_sla_data[, c("PFT_name", "specific_leaf_area_pft")]
pft_sla_data <- unique(pft_sla_data)

# Calculate the corresponding leaf area for the leaf dry mass in niiyama_data
# using the PFT specific SLA values. We'll use the PFT specific SLA values
# stored in "data" as these are also based on dry mass (not carbon corrected).
# This is fine as we are only interested in the leaf area here.

# Add PFT SLA values to niiyama data
niiyama_data <- left_join(niiyama_data, pft_sla_data, by = "PFT_name")

# Convert foliage dry mass unit Mg/ha to mg/ha to match SLA weight units
niiyama_data$leaf_dry_mass <- niiyama_data$leaf_dry_mass * 10^9

# Calculate foliage area (with unit mm2 ha-1)
niiyama_data$leaf_area <-
  niiyama_data$leaf_dry_mass * niiyama_data$specific_leaf_area_pft

# Convert mm2 to m2
niiyama_data$leaf_area <- niiyama_data$leaf_area / 10^6

# Convert fine root dry mass to carbon mass using 45.2% carbon content (Imai et al.)
# The unit then becomes Mg C per hectare
niiyama_data$fine_root_carbon_mass <- niiyama_data$fine_root_dry_mass * 45.2 / 100

# Convert Mg C ha-1 to Kg C ha-1
niiyama_data$fine_root_carbon_mass <- niiyama_data$fine_root_carbon_mass * 1000

# Calculate ratio of fine root carbon mass to foliage area (kg C m-2)
niiyama_data$fine_root_carbon_foliage_area <-
  niiyama_data$fine_root_carbon_mass / niiyama_data$leaf_area

print(niiyama_data$fine_root_carbon_foliage_area)
mean(niiyama_data$fine_root_carbon_foliage_area)

# Note that these ratios are very close to the mean cross both Kenzo and Niiyama
# So I think we can use this second approach, using PFT specific values, as it
# works with well studied dipterocarp plots and seems to capture the variability
# across different plots well.

# Subset niiyama_data with ratio and add to summary

niiyama_data <- niiyama_data[, c("PFT_name", "fine_root_carbon_foliage_area")]

summary <- left_join(summary, niiyama_data, by = "PFT_name")

################################################################################

# Prep summary output again, check variable names, etc.

names(summary)

summary <- summary[, c(
  "PFT_name", "Hm", "a", "c", "WD_NB", "SLA", "leaf_area_index",
  "light_extinction_coefficient", "turnover_leaf",
  "turnover_reproductive_organ", "turnover_fine_root",
  "respiration_fine_root", "respiration_leaf",
  "respiration_wood", "yield_factor",
  "fine_root_carbon_foliage_area"
)]

colnames(summary) <- c(
  "PFT_name", "Hm", "a", "c", "WD", "SLA", "LAI",
  "LEC", "turnover_leaf", "turnover_RT", "turnover_root",
  "respiration_root", "respiration_leaf", "respiration_wood",
  "yield_factor", "zeta"
)

# Below I change the variable names to match those used by the model
# and also provide an overview of the units between parentheses

# PFT_name is name
# Hm is h_max (m)
# a is a_hd (-)
# c is ca_ratio (-)
# WD is rho_s (kg C m-3)
# SLA is sla (m2 kg-1 C)
# LAI is lai (-)
# LEC is par_ext (-)
# turnover_leaf is tau_f (years)
# turnover_RT is tau_rt (years)
# turnover_root is tau_r (years)
# respiration_root is resp_r (year-1)
# respiration_leaf is resp_f (year-1)
# respiration_wood is resp_s (year-1)
# yield_factor is yld (-)
# zeta is zeta (kg C m-2)

colnames(summary) <- c(
  "name", "h_max", "a_hd", "ca_ratio", "rho_s", "sla", "lai",
  "par_ext", "tau_f", "tau_rt", "tau_r",
  "resp_r", "resp_f", "resp_s",
  "yld", "zeta"
)

################################################################################

# Write CSV file

write.csv(
  summary,
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  row.names = FALSE
)
