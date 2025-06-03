#' ---
#' title: Plant allocation to reproductive tissues
#'
#' description: |
#'     This script focuses on calculating the ratio that allows to derive
#'     reproductive tissue carbon mass from foliage carbon mass.
#'     It also calculates the ratio to separate reproductive tissue carbon mass
#'     into propagule (fruits/seeds) and non-propagule (flowers) carbon mass.
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
#'     Measured components of total carbon budget at the SAFE project.
#'     Values with standard errors for each 1-ha carbon plots for 11 plots
#'     investigated across a logging gradient from unlogged old-growth to
#'     heavily logged.
#'   - name: both_tree_functional_traits.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'     https://doi.org/10.5281/zenodo.3247631
#'     Functional traits of tree species in old-growth and selectively
#'     logged forest.
#'   - name: kitayama_2015_element_concentrations_of_litter_fractions.xlsx
#'     path: ../../../data/primary/plant/traits_data
#'     description: |
#'     https://doi.org/10.1111/1365-2745.12379
#'     Element concentrations of litter fractions.
#'
#' output_files:
#'   - name: plant_reproductive_tissue_allocation.csv
#'     path: ../../../data/derived/plant/reproductive_tissue_allocation/reproductive_tissue_allocation.csv # nolint
#'     description: |
#'       This CSV file contains a summary of the ratios needed to calculate
#'       reproductive tissue allocation, and to separate propagules from non-
#'       propagules.
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
# Note that this ratio is based on data from litter fall studies. By calculating
# the ratio this way, it is assumed that the relationship between how much falls
# to the ground and how much is present in the tree is preserved.

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

#####

# Before continuing, first need to correct for carbon mass in leaf and
# reproductive tissues.
# For leaf carbon mass, we'll use data from the same plots
# For reproductive tissue carbon mass we have two main options:
# A: use the mean carbon content for reproductive tissues obtained from
# Kitayama et al. (2015; DOI http://dx.doi.org/10.1111/1365-2745.12379).
# B: use the mean carbon content of fruits and flower combined from
# Aoyagi et al. (2018; DOI https://doi.org/10.1007/s11284-018-1642-9)

# Load leaf carbon content dataset and calculate mean for each plot
# Note that in theory we could apply the PFT species classification here to
# calculate the PFT specific leaf carbon content, but I think for now a mean
# value across plots is fine, as the rest of reproductive allocation does not
# work on a PFT basis (it actually works on plot basis for the first approach).
both_tree_functional_traits <- read_excel(
  "../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

both_data <- both_tree_functional_traits
max(nrow(both_data))
colnames(both_data) <- both_data[7, ]
both_data <- both_data[8:724, ]
names(both_data)

# Note that this dataset has logged and old-growth plots

both_data <- both_data[
  , c(
    "forest_type", "forestplots_name", "branch_type", "tree_id", "C_perc"
  )
]

both_data$C_perc <- as.numeric(both_data$C_perc)
both_data <- na.omit(both_data)
mean(both_data$C_perc)
mean(both_data$C_perc[both_data$forest_type == "OG"])
mean(both_data$C_perc[both_data$forest_type == "SL"])

# Check the variability

plot(both_data$C_perc ~ as.factor(both_data$forestplots_name))
abline(h = 44.70894)
abline(h = 44.10732, col = "red")
abline(h = 45.20412, col = "blue")

# Add mean leaf carbon content to safe_carbon_balance_components (called data)
# Separate for old growth and selectively logged plots
data$leaf_C_perc[data$ForestType == "Old-growth"] <-
  mean(both_data$C_perc[both_data$forest_type == "OG"])
data$leaf_C_perc[data$ForestType == "Logged"] <-
  mean(both_data$C_perc[both_data$forest_type == "SL"])

# Load Kitayama litter nutrient concentrations dataset and calculate mean
# reproductive organ litter carbon content across the different plots.

kitayama_litter_stoichiometry <- read_excel(
  "../../../data/primary/plant/traits_data/kitayama_2015_element_concentrations_of_litter_fractions.xlsx", # nolint
  sheet = "Sheet1",
  col_names = FALSE
)

colnames(kitayama_litter_stoichiometry) <- kitayama_litter_stoichiometry[2, ]

kitayama_litter_stoichiometry_C <- # nolint
  kitayama_litter_stoichiometry[c(28:36), c(1, 2, 3)]
colnames(kitayama_litter_stoichiometry_C) <- # nolint
  c("site", "leaf_C", "reproductive_organ_C")

kitayama_litter_stoichiometry_C$leaf_C <- # nolint
  as.numeric(kitayama_litter_stoichiometry_C$leaf_C)
kitayama_litter_stoichiometry_C$reproductive_organ_C <- # nolint
  as.numeric(kitayama_litter_stoichiometry_C$reproductive_organ_C)

# Save mean reproductive carbon content separately in case we want to use it
# to correct for carbon mass in other approaches in this script.

kitayama_mean_C_percentage <- # nolint
  mean(kitayama_litter_stoichiometry_C$reproductive_organ_C / 1000) * 100
print(kitayama_mean_C_percentage)

# Add to safe_carbon_balance (called data)

data$reproductive_organ_C_perc_kitayama <- kitayama_mean_C_percentage

# Next we calculate the carbon content for reproductive tissues obtained from
# Aoyagi, which focuses on dipterocarp forests
# The carbon content is extracted directly from the paper by calculating the
# average across fruits and flowers (Table 3)

data$fruit_and_flower_C_perc_aoyagi <- ((464 + 452) / 2) / 10

#####

# Return to working with data (copy of safe_carbon_balance)

data$CanopyNPP_Leaf <- as.numeric(data$CanopyNPP_Leaf)
data$CanopyNPP_Reproductive <- as.numeric(data$CanopyNPP_Reproductive)

# Correct CanopyNPP_Leaf and CanopyNPP_Reproductive for its carbon mass
# A: Kitayama C perc reproductive tissues
data$CanopyNPP_Leaf_C <- data$CanopyNPP_Leaf * data$leaf_C_perc / 100
data$CanopyNPP_Reproductive_C_kitayama <-
  data$CanopyNPP_Reproductive * data$reproductive_organ_C_perc_kitayama / 100

# Calculate the (carbon corrected) ratio
data$reproductive_to_leaf_ratio_C_kitayama <-
  data$CanopyNPP_Reproductive_C_kitayama / data$CanopyNPP_Leaf_C

mean(data$reproductive_to_leaf_ratio_C_kitayama)
mean(data$reproductive_to_leaf_ratio_C_kitayama[data$ForestType == "Old-growth"])
mean(data$reproductive_to_leaf_ratio_C_kitayama[data$ForestType == "Logged"])

# B: Aoyagi C perc reproductive tissues
data$CanopyNPP_Leaf_C <- data$CanopyNPP_Leaf * data$leaf_C_perc / 100
data$CanopyNPP_Reproductive_C_aoyagi <-
  data$CanopyNPP_Reproductive * data$fruit_and_flower_C_perc_aoyagi / 100

# Calculate the (carbon corrected) ratio
data$reproductive_to_leaf_ratio_C_aoyagi <-
  data$CanopyNPP_Reproductive_C_aoyagi / data$CanopyNPP_Leaf_C

mean(data$reproductive_to_leaf_ratio_C_aoyagi)
mean(data$reproductive_to_leaf_ratio_C_aoyagi[data$ForestType == "Old-growth"])
mean(data$reproductive_to_leaf_ratio_C_aoyagi[data$ForestType == "Logged"])

# Decide which plots to use (logged/unlogged, SAFE, Danum, etc.)

# Create summary and write ratio to summary

summary <- data.frame(
  approach = c("1"),
  source = c("safe_carbon_balance_components"),
  reproductive_to_leaf_ratio_C =
    mean(data$reproductive_to_leaf_ratio_C_kitayama[data$ForestType == "Old-growth"]),
  notes =
    c("old growth, litter fall from SAFE, leaf carbon from same plots,
      reproductive tissue carbon from Kitayama")
)

summary[2, ] <-
  c(
    "1",
    "safe_carbon_balance_components",
    mean(data$reproductive_to_leaf_ratio_C_kitayama[data$ForestType == "Logged"]),
    "selectively logged, litter fall from SAFE, leaf carbon from same plots,
      reproductive tissue carbon from Kitayama"
  )

summary[3, ] <-
  c(
    "1",
    "safe_carbon_balance_components",
    mean(data$reproductive_to_leaf_ratio_C_aoyagi[data$ForestType == "Old-growth"]),
    "old growth, litter fall from SAFE, leaf carbon from same plots,
      reproductive tissue carbon from Aoyagi"
  )

summary[4, ] <-
  c(
    "1",
    "safe_carbon_balance_components",
    mean(data$reproductive_to_leaf_ratio_C_aoyagi[data$ForestType == "Logged"]),
    "selectively logged, litter fall from SAFE, leaf carbon from same plots,
      reproductive tissue carbon from Aoyagi"
  )

#####

# Approach 2: Kitayama et al. (2015; DOI http://dx.doi.org/10.1111/1365-2745.12379)

# Extract data from paper (Table 2)
kitayama_data <- data.frame(
  site = c(
    "S-700", "S-1700", "S-2700", "S-3100",
    "U-700", "U-1700", "U-2700", "U-3100",
    "Q-1700"
  ),
  leaf_mean = c(6403, 5107, 2929, 4848, 6027, 4131, 4676, 1236, 5450),
  leaf_sd = c(749, 723, 491, 1041, 886, 626, 605, 368, 792),
  reproductive_mean = c(731, 400, 381, 291, 1413, 243, 117, 128, 612),
  reproductive_sd = c(448, 216, 195, 98, 1091, 129, 74, 115, 379)
)

# Correct for carbon content using the dataframe we loaded earlier on the
# litter nutrient concentration by Kitayama.
kitayama_data <-
  left_join(kitayama_data, kitayama_litter_stoichiometry_C, by = "site")

kitayama_data$leaf_C <- kitayama_data$leaf_C / 10
kitayama_data$reproductive_organ_C <- kitayama_data$reproductive_organ_C / 10

kitayama_data$leaf_mean_C <-
  kitayama_data$leaf_mean * kitayama_data$leaf_C / 100
kitayama_data$reproductive_mean_C <-
  kitayama_data$reproductive_mean * kitayama_data$reproductive_organ_C / 100

# Then calculate the carbon corrected ratio
kitayama_data$reproductive_to_leaf_ratio <-
  kitayama_data$reproductive_mean_C / kitayama_data$leaf_mean_C

mean(kitayama_data$reproductive_to_leaf_ratio)

# Decide which plots to focus on, if we want a general relationship then keep all
# Alternatively we could focus on particular altitudes or soil type

# Aoyagi also use Kitayama's data, where S-700 and U-700 are dipterocarp forest,
# and S-1700 and U-1700 are montane forest

mean(kitayama_data$reproductive_to_leaf_ratio[
  kitayama_data$site %in% c("S-700", "U-700")
])
mean(kitayama_data$reproductive_to_leaf_ratio[
  kitayama_data$site %in% c("S-1700", "U-1700")
])

# Write ratio to summary

summary[5, ] <-
  c(
    "2",
    "kitayama",
    mean(kitayama_data$reproductive_to_leaf_ratio[
      kitayama_data$site %in% c("S-700", "U-700")
    ]),
    "dipterocarp forest"
  )

summary[6, ] <-
  c(
    "2",
    "kitayama",
    mean(kitayama_data$reproductive_to_leaf_ratio[
      kitayama_data$site %in% c("S-1700", "U-1700")
    ]),
    "lower montane forest"
  )

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

# Note that for the Kitayama data Aoyagi used plots S-700 and U-700 for dipterocarp
# forest, and plots S-1700 and U-1700 for montane forest, at least for the leaf
# mass data. It is not clear where they got the reproductive tissue mass from
# as the values are not the same as in the Kitayama paper.
# I think they may have had access to an additional dataset, as the original
# Kitayama paper also does not present data for mast vs non-mast.

# Also note that in this approach I used the mean of the range presented by
# Aoyagi, which seems less accurate to me than when the ratio was calculated
# directly from the values presented by Kitayama.
# Hence, I think the Aoyagi paper is mostly relevant for the difference between
# mast and non-mast years, but we'd need access to that additional dataset to
# verify where the data came from.

# Add carbon content for fruits/flowers and leaves (Table 3)
aoyagi_data$fruit_and_flower_C_perc <- ((464 + 452) / 2) / 10
aoyagi_data$leaf_C_perc <- 482 / 10

aoyagi_data$dry_mass_fruit_and_flower <-
  as.numeric(aoyagi_data$dry_mass_fruit_and_flower)
aoyagi_data$dry_mass_leaf <-
  as.numeric(aoyagi_data$dry_mass_leaf)

# Correct for carbon content
aoyagi_data$fruit_and_flower_C_mass <-
  aoyagi_data$dry_mass_fruit_and_flower * aoyagi_data$fruit_and_flower_C_perc / 100
aoyagi_data$leaf_C_mass <-
  aoyagi_data$dry_mass_leaf * aoyagi_data$leaf_C_perc / 100

aoyagi_data$reproductive_to_leaf_ratio <-
  aoyagi_data$fruit_and_flower_C_mass / aoyagi_data$leaf_C_mass

# Write ratio to summary

summary[7, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[1, 10],
    "aoyagi, dipterocarp forest, mast"
  )
summary[8, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[2, 10],
    "aoyagi, dipterocarp forest, non-mast"
  )
summary[9, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[3, 10],
    "kitayama, dipterocarp forest, mast"
  )
summary[10, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[4, 10],
    "kitayama, dipterocarp forest, non-mast"
  )
summary[11, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[5, 10],
    "kitayama, montane forest, mast"
  )
summary[12, ] <-
  c(
    "3",
    "aoyagi",
    aoyagi_data[6, 10],
    "kitayama, montane forest, non-mast"
  )

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

# Correct for carbon content in leaves and reproductive organs
# Since the paper does not have values for carbon content, we'll use the same
# carbon content as reported for dipterocarp forest by Aoyagi (see above).
anderson_data$reproductive_organs_C_perc <- ((464 + 452) / 2) / 10
anderson_data$leaves_C_perc <- 482 / 10

# Correct for carbon content and calculate ratio
anderson_data$reproductive_organs_C <-
  anderson_data$reproductive_organs * anderson_data$reproductive_organs_C_perc / 100
anderson_data$leaves_C <-
  anderson_data$leaves * anderson_data$leaves_C_perc / 100

anderson_data$reproductive_to_leaf_ratio <-
  anderson_data$reproductive_organs_C / anderson_data$leaves_C

# Decide which plots to use and whether to use litter ratio or standing crop ratio
# Standing crop ratio is much lower

mean(anderson_data$reproductive_to_leaf_ratio[
  anderson_data$vegetation == "dipterocarp forest"
])
mean(anderson_data$reproductive_to_leaf_ratio[
  anderson_data$vegetation == "alluvial forest"
])

# Write ratio to summary

summary[13, ] <-
  c(
    "4",
    "anderson",
    anderson_data[1, 9],
    "alluvial forest"
  )
summary[14, ] <-
  c(
    "4",
    "anderson",
    anderson_data[2, 9],
    "dipterocarp forest"
  )

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

# Correct for carbon content using the values from Aoyagi (see above)
proctor_data$reproductive_organs_C_perc <- ((464 + 452) / 2) / 10
proctor_data$leaves_C_perc <- 482 / 10

proctor_data$reproductive_organs_C <-
  proctor_data$reproductive_organs * proctor_data$reproductive_organs_C_perc / 100
proctor_data$leaves_C <-
  proctor_data$leaves * proctor_data$leaves_C_perc / 100

proctor_data$reproductive_to_leaf_ratio <-
  proctor_data$reproductive_organs / proctor_data$leaves

mean(proctor_data$reproductive_to_leaf_ratio)

# Write ratio to summary

summary[15, ] <-
  c(
    "5",
    "proctor",
    mean(proctor_data$reproductive_to_leaf_ratio),
    "montane forest, could select specific altitudes"
  )

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

# Correct for carbon content
# Use values from Aoyagi (see above)
dent_data$reproductive_organs_C_perc <- ((464 + 452) / 2) / 10
dent_data$leaves_C_perc <- 482 / 10

dent_data$reproductive_organs_C <-
  dent_data$reproductive_organs * dent_data$reproductive_organs_C_perc / 100
dent_data$leaves_C <-
  dent_data$leaves * dent_data$leaves_C_perc / 100

dent_data$reproductive_to_leaf_ratio <-
  dent_data$reproductive_organs / dent_data$leaves

mean(dent_data$reproductive_to_leaf_ratio) # seems rather low compared to rest

# Write ratio to summary

summary[16, ] <-
  c(
    "6",
    "dent",
    dent_data[1, 8],
    "alluvial forest"
  )

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

# Write ratio to summary

summary[17, ] <-
  c(
    "propagule litter carbon percentage",
    "ichie",
    unique(ichie_data$fruit_allocation_litter),
    "dipterocarp forest"
  )
summary[18, ] <-
  c(
    "non-propagule litter carbon percentage",
    "ichie",
    unique(ichie_data$flower_allocation_litter),
    "dipterocarp forest"
  )
summary[19, ] <-
  c(
    "propagule live organ carbon percentage",
    "ichie",
    unique(ichie_data$fruit_allocation_live_organ),
    "dipterocarp forest"
  )
summary[20, ] <-
  c(
    "non-propagule live organ carbon percentage",
    "ichie",
    unique(ichie_data$flower_allocation_live_organ),
    "dipterocarp forest"
  )

################################################################################

# Save summary output file

write.csv(
  summary,
  "../../../data/derived/plant/reproductive_tissue_allocation/reproductive_tissue_allocation.csv", # nolint
  row.names = FALSE
)
