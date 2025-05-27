#' ---
#' title: Plant allocation to reproductive tissues
#'
#' description: |
#'     This script focuses on calculating the ratios that allow to derive
#'     reproductive tissue from foliage mass, and to separate reproductive
#'     tissues into (non) propagule mass (i.e., fruits/seeds, flowers).
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
#'   - name: SAFE_CarbonBalanceComponents.xlsx
#'     path: ../../../data/primary/plant/carbon_balance_components
#'     description: |
#'     https://doi.org/10.5281/zenodo.7307449
#'     Measured components of total carbon budget at SAFE project,
#'     values, with standard errors, for each 1-ha carbon plots for 11 plots
#'     investigated across a logging gradient from unlogged old-growth to
#'     heavily logged.
#'
#' output_files:
#'   - name: plant_reproductive_tissue_allocation.csv
#'     path: ../../../data/derived/plant/reproductive_tissue_allocation/plant_reproductive_tissue_allocation.csv # nolint
#'     description: |
#'       This CSV file contains a summary of the ratios needed to calculate
#'       reproductive tissue allocation.
#'
#' package_dependencies:
#'     - readxl
#'     - dplyr
#'     - ggplot2
#'
#' usage_notes: |
#' ---


# Load packages

library(readxl)
library(dplyr)
library(ggplot2)

# Calculating the ratio between foliage mass and reproductive tissue mass
# This ratio is based on data from litter fall studies.

#####

# Approach 1: SAFE carbon balance components

# Load SAFE carbon balance components dataset and clean up a bit

safe_carbon_balance_components <- read_excel(
  "../../../data/primary/plant/carbon_balance_components/SAFE_CarbonBalanceComponents.xlsx", # nolint
  sheet = "Data",
  col_names = FALSE
)

data <- safe_carbon_balance_components

max(nrow(data))
colnames(data) <- data[6, ]
data <- data[7:17, ]
names(data)

data <- data[
  ,
  c(
    "ForestType", "SAFEPlotName", "PlotName", "ForestPlotsCode",
    "CanopyNPP_Leaf", "CanopyNPP_Reproductive"
  )
]

data$CanopyNPP_Leaf <- as.numeric(data$CanopyNPP_Leaf)
data$CanopyNPP_Reproductive <- as.numeric(data$CanopyNPP_Reproductive)

# Dataset has SE as measure of uncertainty (not used here)

data$reproductive_to_leaf_ratio <- data$CanopyNPP_Reproductive / data$CanopyNPP_Leaf

mean(data$reproductive_to_leaf_ratio)
mean(data$reproductive_to_leaf_ratio[data$ForestType == "Old-growth"])

# Decide which plots to use (logged/unlogged, SAFE, Danum, etc.)

#####

# Approach 2: Kitayama et al. (2015; DOI http://dx.doi.org/10.1111/1365-2745.12379)

# Extract data from paper (Table 2)
kitayama_data <- data.frame(
  site = c(
    "S 700", "S 1700", "S 2700", "S 3100",
    "U 700", "U 1700", "U 2700", "U 3100",
    "Q 1700"
  ),
  leaf_mean = c(6403, 5107, 2929, 4848, 6027, 4131, 4676, 1236, 5450),
  leaf_sd = c(749, 723, 491, 1041, 886, 626, 605, 368, 792),
  reproductive_mean = c(731, 400, 381, 291, 1413, 243, 117, 128, 612),
  reproductive_sd = c(448, 216, 195, 98, 1091, 129, 74, 115, 379)
)

kitayama_data$reproductive_to_leaf_ratio <-
  kitayama_data$reproductive_mean / kitayama_data$leaf_mean

mean(kitayama_data$reproductive_to_leaf_ratio)

#####

# Approach 3: Aoyagi et al. (2018; DOI https://doi.org/10.1007/s11284-018-1642-9)

# Extract data from paper (Table 2), focusing on tropical forests and only
# where both leaf and reproductive data is available
aoyagi_data <- data.frame(
  site = c("this study"),
  vegetation = c("dipterocarp forest"),
  masting = c("mast"),
  dry_mass_fruit_and_flower = c(980),
  dry_mass_leaf = c(5760)
)

# Add rows for each study

aoyagi_data[2, ] <-
  c(
    "this study", "dipterocarp forest", "non-mast",
    mean(c(55, 231)), mean(c(5252, 6856))
  )
aoyagi_data[3, ] <-
  c(
    "kitayama_2015", "dipterocarp forest", "mast",
    mean(c(1165, 2918)), mean(c(6027, 6402))
  )
aoyagi_data[4, ] <-
  c(
    "kitayama_2015", "dipterocarp forest", "non-mast",
    mean(c(278, 684)), mean(c(6027, 6402))
  )
aoyagi_data[5, ] <-
  c(
    "kitayama_2015", "montane forest", "mast",
    mean(c(464, 727)), mean(c(4130, 5106))
  )
aoyagi_data[6, ] <-
  c(
    "kitayama_2015", "montane forest", "non-mast",
    mean(c(190, 301)), mean(c(4130, 5106))
  )

aoyagi_data$dry_mass_fruit_and_flower <-
  as.numeric(aoyagi_data$dry_mass_fruit_and_flower)
aoyagi_data$dry_mass_leaf <-
  as.numeric(aoyagi_data$dry_mass_leaf)

aoyagi_data$reproductive_to_leaf_ratio <-
  aoyagi_data$dry_mass_fruit_and_flower / aoyagi_data$dry_mass_leaf

# Calculate difference mast and non-mast year (for exploration)
# This could potentially be a way to implement masting into the model

aoyagi_data$ratio_mast_to_non_mast[aoyagi_data$site == "this study"] <-
  aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "this study" &
    aoyagi_data$masting == "mast"] / # nolint
    aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "this study" & # nolint
      aoyagi_data$masting == "non-mast"] # nolint

aoyagi_data$ratio_mast_to_non_mast[aoyagi_data$site == "kitayama_2015" &
  aoyagi_data$vegetation == "dipterocarp forest"] <- # nolint
  aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "kitayama_2015" &
    aoyagi_data$vegetation == "dipterocarp forest" & # nolint
    aoyagi_data$masting == "mast"] /
    aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "kitayama_2015" & # nolint
      aoyagi_data$vegetation == "dipterocarp forest" & # nolint
      aoyagi_data$masting == "non-mast"]

aoyagi_data$ratio_mast_to_non_mast[aoyagi_data$site == "kitayama_2015" &
  aoyagi_data$vegetation == "montane forest"] <- # nolint
  aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "kitayama_2015" &
    aoyagi_data$vegetation == "montane forest" & # nolint
    aoyagi_data$masting == "mast"] /
    aoyagi_data$reproductive_to_leaf_ratio[aoyagi_data$site == "kitayama_2015" & # nolint
      aoyagi_data$vegetation == "montane forest" & # nolint
      aoyagi_data$masting == "non-mast"]
#####

# Approach 4: Anderson et al. (1983; DOI https://doi.org/10.2307/2259731)

# Extract data from paper (Table 6), focusing on both input to soil per year
# and standing crop, for alluvial and dipterocarp forest

anderson_data <- data.frame(
  source = c("litter input to soil"),
  vegetation = c("alluvial forest"),
  leaves = c(6.6),
  reproductive_organs = c(0.4)
)

anderson_data[2, ] <-
  c("litter input to soil", "dipterocarp forest", 5.4, 0.3)
anderson_data[3, ] <-
  c("litter input to soil", "heath forest", 5.6, 0.3)
anderson_data[4, ] <-
  c("litter input to soil", "forest over limestone", 7.3, 0.1)

anderson_data[5, ] <-
  c("standing crop", "alluvial forest", 3.8, 0.06)
anderson_data[6, ] <-
  c("standing crop", "dipterocarp forest", 3.2, 0.03)
anderson_data[7, ] <-
  c("standing crop", "heath forest", 3.9, 0.03)
anderson_data[8, ] <-
  c("standing crop", "forest over limestone", 4.2, 0.01)

anderson_data$leaves <- as.numeric(anderson_data$leaves)
anderson_data$reproductive_organs <- as.numeric(anderson_data$reproductive_organs)

anderson_data$reproductive_to_leaf_ratio <-
  anderson_data$reproductive_organs / anderson_data$leaves

# Decide which plots to use and whether to use litter ratio or standing crop ratio
# Standing crop ratio is much lower

mean(anderson_data$reproductive_to_leaf_ratio[
  anderson_data$vegetation == "dipterocarp forest"
])
mean(anderson_data$reproductive_to_leaf_ratio[
  anderson_data$vegetation == "alluvial forest"
])

#####

# Approach 5: Proctor et al. (1989; DOI https://doi.org/10.2307/2260752)

# Extract data from paper (Table 6)

proctor_data <- data.frame(
  altitude = c(280),
  leaves = c(3.86),
  reproductive_organs = c(0.21)
)

proctor_data[2, ] <- c(330, 4.50, 0.16)
proctor_data[3, ] <- c(480, 3.44, 0.18)
proctor_data[4, ] <- c(610, 4.13, 0.07)
proctor_data[5, ] <- c(790, 3.66, 0.11)
proctor_data[6, ] <- c(870, 3.32, 0.08)

proctor_data$reproductive_to_leaf_ratio <-
  proctor_data$reproductive_organs / proctor_data$leaves

mean(proctor_data$reproductive_to_leaf_ratio)

#####

# Approach 6: Dent et al. (2006; https://doi.org/10.1007/s11104-006-9108-1)

# Extract data from paper (Table 2)

dent_data <- data.frame(
  vegetation = c("alluvial"),
  leaves = c(6.7),
  reproductive_organs = c(0.039)
)

dent_data[2, ] <-
  c("sandstone ridge", 5.6, 0.087)
dent_data[3, ] <-
  c("sandstone valley", 5.3, 0.059)
dent_data[4, ] <-
  c("heath", 4.5, 0.025)

dent_data$leaves <- as.numeric(dent_data$leaves)
dent_data$reproductive_organs <- as.numeric(dent_data$reproductive_organs)

dent_data$reproductive_to_leaf_ratio <-
  dent_data$reproductive_organs / dent_data$leaves

mean(dent_data$reproductive_to_leaf_ratio) # seems rather low compared to rest

################################################################################
################################################################################

# Calculating the ratio between propagule and non propagule carbon mass

# Approach 1: Ichie et al. (2005; DOI https://www.jstor.org/stable/4092073)
# Summarise all tissues belonging to flowers, and all tissues belonging to fruits
# Correct the dry weight mass for % C content first
# Then calculate the ratio

# Extract data from paper (Table 2; SD is available)
ichie_data <- data.frame(
  tissue_type = c("flower"),
  developmental_stage = c("flower bud"),
  dry_mass = c(0.08),
  carbon_percentage = c(49.16),
  litter_mass = c(6.5),
  live_organ_mass = c(24.0)
)

ichie_data[2, ] <-
  c("flower", "corolla appearing from flower bud", 0.13, 49.42, 0.8, 28.3)
ichie_data[3, ] <-
  c("flower", "just before flowering", 0.16, 49.13, 2.9, 34.4)
ichie_data[4, ] <-
  c("flower", "open flower", 0.17, 48.71, 19.9, 32)
ichie_data[5, ] <-
  c("fruit", "immature fruit 0 1 cm", 0.17, 49.74, 3.0, 12.5)
ichie_data[6, ] <-
  c("fruit", "immature fruit 1 2 cm", 0.65, 51.01, 8.3, 36)
ichie_data[7, ] <-
  c("fruit", "mature fruit 2 cm", 8.04, 50.62, 345.5, 345.5)

ichie_data$dry_mass <- as.numeric(ichie_data$dry_mass)
ichie_data$carbon_percentage <- as.numeric(ichie_data$carbon_percentage)
ichie_data$litter_mass <- as.numeric(ichie_data$litter_mass)
ichie_data$live_organ_mass <- as.numeric(ichie_data$live_organ_mass)

ichie_data$litter_carbon_mass <-
  ichie_data$litter_mass * (ichie_data$carbon_percentage / 100)
ichie_data$live_organ_carbon_mass <-
  ichie_data$live_organ_mass * (ichie_data$carbon_percentage / 100)

ichie_data$flower_litter_carbon_mass <-
  sum(ichie_data$litter_carbon_mass[ichie_data$tissue_type == "flower"])
ichie_data$fruit_litter_carbon_mass <-
  sum(ichie_data$litter_carbon_mass[ichie_data$tissue_type == "fruit"])

ichie_data$flower_live_organ_carbon_mass <-
  sum(ichie_data$live_organ_carbon_mass[ichie_data$tissue_type == "flower"])
ichie_data$fruit_live_organ_carbon_mass <-
  sum(ichie_data$live_organ_carbon_mass[ichie_data$tissue_type == "fruit"])

# Calculate ratio (i.e., which percentage is flowers, which is fruits)

ichie_data$flower_allocation_litter <-
  ichie_data$flower_litter_carbon_mass /
    (ichie_data$flower_litter_carbon_mass + ichie_data$fruit_litter_carbon_mass) # nolint
ichie_data$fruit_allocation_litter <-
  ichie_data$fruit_litter_carbon_mass /
    (ichie_data$flower_litter_carbon_mass + ichie_data$fruit_litter_carbon_mass) # nolint

ichie_data$flower_allocation_live_organ <-
  ichie_data$flower_live_organ_carbon_mass /
    (ichie_data$flower_live_organ_carbon_mass + ichie_data$fruit_live_organ_carbon_mass) # nolint
ichie_data$fruit_allocation_live_organ <-
  ichie_data$fruit_live_organ_carbon_mass /
    (ichie_data$flower_live_organ_carbon_mass + ichie_data$fruit_live_organ_carbon_mass) # nolint

# Have another look at the paper and see if we want to use the ratio based on
# litter or live organ
