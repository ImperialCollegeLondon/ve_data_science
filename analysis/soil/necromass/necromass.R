#| ---
#| title: Estimate soil necromass C, N and P
#|
#| description: |
#|     The R function estimates soil necromass C, N and P stocks using amino
#|     sugar biomarkers measured at Pasoh forest reserve, Malaysia. First we
#|     estimate the C pool, and then scale it to get N and P pools using
#|     microbe stoichiometry. The original data included primary forest,
#|     secondary forest, oil palm, and rubber plantation.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: li_et_al_2023.csv
#|     path: data/primary/soil/necromass/
#|     description: |
#|         Data extracted from Figure 3 from Li et al. (2023), using the script
#|         analysis/soil/necromass/data_extract_li_et_al_2023.R
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - biogas
#|
#| usage_notes:
#| ---

library(tidyverse)
library(biogas)

# function to calculate necromass from total soil carbon
extract_necromass <- function(type) {
  # Data extracted from Fig. 3 in Li et al. (2023)
  # https://doi.org/10.1016/j.scitotenv.2023.163204
  data <-
    read_csv("data/derived/soil/necromass/li_et_al_2023.csv") |>
    filter(forest_type == type)

  # amino sugar content in mg / g SOC
  amino_sugar_mean <- data$animo_sugar_SOC

  # Percentage of each amino sugar in rainforest (RF) soils
  # converted to proportions
  p_GluN <- data$GluN_SOC / 100
  p_GalN <- data$GalN_SOC / 100
  p_MurN <- data$MurN_SOC / 100

  # carbon content of each amino sugar
  C_GluN <- molMass("C6") / molMass("C6H13NO5")
  C_GalN <- molMass("C6") / molMass("C6H13NO5")
  C_MurN <- molMass("C9") / molMass("C9H17NO7")

  # carbon content of amino sugar in rainforest (RF) soils
  C_amino_sugar <- p_GluN * C_GluN + p_GalN * C_GalN + p_MurN * C_MurN

  # necromass using amino sugar as a proxy
  # convert to kg necromass / kg SOC
  necromass <- amino_sugar_mean / 1e3

  # necromass C
  necromass_C <- necromass * C_amino_sugar

  # necromass N and P based on microbial stoichiometry, following C:N:P = 60:7:1
  # Cleveland and Liptzin (2007) https://doi.org/10.1007/s10533-007-9132-0
  necromass_N <- necromass_C / 60 * 7
  necromass_P <- necromass_C / 60

  # These necromass C, N and P are in kg / kg SOC, so in the post-hoc prediction
  # we will scale them off the predicted SOC (~ TOC in tropical-forest data)

  return(c(C = necromass_C, N = necromass_N, P = necromass_P))
}
