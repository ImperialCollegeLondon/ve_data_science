#' ---
#' title: Updating T model parameters
#'
#' description: |
#'     This script focuses on updating the base values for the parameters in
#'     the T model to values more closely aligned with the SAFE project.
#'     The script works with multiple datasets and calculates values for the
#'     T model, ideally at PFT level. Species are linked to their PFT by working
#'     with the output of the PFT species classification base script.
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
#'   - name: plant_functional_type_species_classification_base.csv
#'     path: ../../../data/derived/plant/plant_functional_type
#'     description: |
#'       This CSV file contains a list of species and their respective PFT.
#'       This CSV file can be loaded when working with other datasets
#'       (particularly those related to updating T model parameters).
#'       In a follow up script, the remaining species that have not been assigned
#'       a PFT yet will be assigned into one based on
#'       their species maximum height relative to the PFT maximum height.
#'   - name: inagawa_nutrients_wood_density.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'       https://doi.org/10.5281/zenodo.8158811
#'       Tree census data from the SAFE Project 2011–2020.
#'       Nutrients and wood density in coarse root, trunk and branches in
#'       Bornean tree species.
#'   - name: both_tree_functional_traits.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'       https://doi.org/10.5281/zenodo.3247631
#'       Functional traits of tree species in old-growth and selectively
#'       logged forest.
#'
#' output_files:
#'   - name: t_model_parameters.csv
#'     path: ../../../data/derived/plant/traits_data/t_model_parameters.csv
#'     description: |
#'       This CSV file contains a summary of updated T model parameters for each PFT.
#'
#' package_dependencies:
#'     - readxl
#'     - dplyr
#'     - ggplot2
#'     - stringr
#'
#' usage_notes: |
#'   This script is intended to run entirely from start to finish in order to
#'   preserve the flow and links between different datasets, so that the final
#'   output file contains all necessary parts. The units are the same as the
#'   ones in Li et al. (2014) unless specified otherwise in the script.
#'   It might be a good idea to include the units in the summary output file.
#' ---


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

# Note that measurements of height, dbh and crown radius are linked per row
# So, even though crown radius is not required for height-diameter relationship,
# using na.omit on the next line is OK.
# Also note that a lot of rows have missing values, figure out why they were not
# measured (maybe trees were dead?). If trees were actually there, they also
# need to be included for stem distribution later on.

plot_data <- na.omit(plot_data)
unique(plot_data$PFT)

plot_data$HeightTotal_m_2011 <- as.numeric(plot_data$HeightTotal_m_2011)
plot_data$DBH2011_mm_clean <- as.numeric(plot_data$DBH2011_mm_clean)
plot_data$CanopyRadiusNorth_cm_2011 <- as.numeric(plot_data$CanopyRadiusNorth_cm_2011)
plot_data$CanopyRadiusEast_cm_2011 <- as.numeric(plot_data$CanopyRadiusEast_cm_2011)
plot_data$CanopyRadiusSouth_cm_2011 <- as.numeric(plot_data$CanopyRadiusSouth_cm_2011)
plot_data$CanopyRadiusWest_cm_2011 <- as.numeric(plot_data$CanopyRadiusWest_cm_2011)
plot_data$HeightBranch_m_2011 <- as.numeric(plot_data$HeightBranch_m_2011)

plot_data$logging <- as.factor(plot_data$logging)

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

plot(HeightTotal_m_2011 ~ DBH2011_m, data = plot_data[plot_data$PFT == "4", ])

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

# Decide whether or not to remove "outlier" above 200 here

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

# With all: c is 1151.012
# With "outlier" removed: c is 738.982

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

# Leaf area index
# LAI is assumed to be constant across PFTs and within the crown/canopy
# The value for LAI is based on Pfeifer et al. (2016)
# (DOI https://doi.org/10.1016/j.rse.2016.01.014)
# This paper has mean values for primary forest, lightly logged, twice logged,
# salvage logged and oil palm plantation
# It also provides SD as measure of uncertainty (not included here atm)

summary$leaf_area_index <- 4.43

#

################################################################################

# Write CSV file

write.csv(
  summary,
  "../../../data/derived/plant/traits_data/t_model_parameters.csv",
  row.names = FALSE
)
