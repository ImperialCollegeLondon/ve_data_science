#| ---
#| title: Models to predict belowground litter nutrient composition for Maliau
#|
#| description: |
#|     This script uses previously inferred litter decay parameters to split
#|     belowground litter nutrients into structural and metabolic pools. It
#|     combines root stoichiometry and root nutrient resorption to estimate
#|     root *litter* stoichiometry.
#|
#| virtual_ecosystem_module: Litter
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: decay_parameters.csv
#|     path: data/derived/litter/turnover
#|     description: |
#|         Litter decay parameters to split field-collected litter into
#|         structural and metabolic pools
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|
#| usage_notes: |
#|     The simulated belowground nutrient values at the end of this script
#|     is more of an example procedure at the moment; to be finalised when we
#|     finalise the Maliau soil and litter initial data.
#| ---

library(tidyverse)


# Parameters --------------------------------------------------------------

# Fitted litter decay parameters from a previous PR (#104)
# they are used to split litter into structural and metabolic pools
decay_param <- read_csv("data/derived/litter/turnover/decay_parameters.csv")
logitfM <- decay_param$value[decay_param$Parameter == "logitfM"]
sN <- decay_param$value[decay_param$Parameter == "sN"]
sP <- decay_param$value[decay_param$Parameter == "sP"]

# Ratio of structural vs metabolic C:N and C:P (r in the CENTURY model)
# this is from Kirschbaum and Paul (2002) Soil Biology and Biochemistry
# Since the structural and metabolic pools are abstract pools (unfortunately)
# there is no reason to modify this abstract ratio
r_century <- 5


# Fine root stoichiometry -------------------------------------------------

# This section is mostly adapted from Arne Scheire's code stored
# in analysis/plant/plant_stoichiometry/plant_stoichiometry.R

# Fine root stoichiometry is obtained from Imai et al., 2010
# (https://doi.org/10.1017/S0266467410000350)
# These data are for mixed dipterocarp lowland tropical rain forest in Sabah
# means and SDs are in unit [%]

C_mean <- 45.2
C_sd <- 4.4
N_mean <- 1.38
N_sd <- 0.32
P_mean <- 0.052
P_sd <- 0.004

# Lignin: according to White et al., 2000
# (https://doi.org/10.1175/1087-3562(2000)004%3C0003:PASAOT%3E2.0.CO;2)
# the mean fine root lignin content is 22% across all biomes
# There is a lack of data for this parameter, so we'll use this mean for now
# also in unit [%]

lignin_mean <- 22
lignin_sd <- 7.3


# Root resorption efficiency ----------------------------------------------

# as green roots become belowground litter, they resorb N and P
# so we need to calculate litter N and P from fine root N and P above
# the following are root nutrient resorption efficiency [%] from Wang et al. (2025)
# https://doi.org/10.1111/nph.70001

N_resorption_mean <- 19.45
N_resorption_sd <- 1.46
P_resorption_mean <- 24.74
P_resorption_sd <- 2.10
