#| ---
#| title: Descriptive name of the script
#|
#| description: |
#|     Brief description of what the script does, its main purpose, and any important
#|     scientific context. Keep it concise but informative.
#|
#|     This can include multiple paragraphs.
#|
#| virtual_ecosystem_module: [Animal, Plant, Abiotic, Soil, None]
#|
#| author:
#|   - David Orme
#|
#| status: final or wip
#|
#| input_files:
#|   - name: Input file name
#|     path: Full file path on shared drive
#|     description: |
#|       Source (short citation) and a brief explanation of what this input file
#|       contains and its use case in this script
#|
#| output_files:
#|   - name: Output file name
#|     path: Full file path on shared drive
#|     description: |
#|       What the output file contains and its significance, are they used in any other
#|       scripts?
#|
#| package_dependencies:
#|     - tools
#|
#| usage_notes: |
#|   Any known issues or bugs? Future plans for script/extensions or improvements
#|   planned that should be noted?
#| ---

library(tidyverse)
library(readxl)
library(mvtnorm)
library(mclust)


chem_leaf <-
  read_xlsx("data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 3,
    skip = 7
  ) %>%
  # convert lignin from mass/mass to g C/g C
  # the lignin C content = 62.5% comes from
  # Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
  mutate(lignin = lignin_recalcitrants * 0.625 / C_perc) %>%
  select(
    litter_type,
    C.N, C.P, lignin,
  )

chem_leaf_mat <- as.matrix(chem_leaf[, -1])
rownames(chem_leaf_mat) <- chem_leaf$litter_type

mod_chem <- mvn("Ellipsoidal", chem_leaf_mat)

n_sim <- 1000
sim_chem <-
  rmvnorm(
    n_sim,
    mod_chem$parameters$mean,
    mod_chem$parameters$variance$Sigma
  )
colnames(sim_chem) <- colnames(chem_leaf_mat)

decay_param <- read_csv("data/derived/litter/turnover/decay_parameters.csv")

logitfM <- decay_param$value[decay_param$Parameter == "logitfM"]
sN <- decay_param$value[decay_param$Parameter == "sN"]
sP <- decay_param$value[decay_param$Parameter == "sP"]

sim_chem_df <-
  as_tibble(sim_chem) %>%
  mutate(fm = plogis(
    logitfM - lignin * (sN * C.N + sP * C.P)
  ))

n_sim_pool <- 1000
n_ratio <- numeric(n_sim_pool)
p_ratio <- numeric(n_sim_pool)
lignin_ratio <- numeric(n_sim_pool)

for (i in seq_len(n_sim_pool)) {
  pool <- rbinom(length(sim_chem_df$fm), 1, sim_chem_df$fm)
  pool_CN <- tapply(sim_chem_df$C.N, pool, mean)
  pool_CP <- tapply(sim_chem_df$C.P, pool, mean)
  pool_L <- tapply(sim_chem_df$lignin, pool, mean)

  n_ratio[i] <- pool_CN[1] / pool_CN[2]
  p_ratio[i] <- pool_CP[1] / pool_CP[2]
  lignin_ratio[i] <- pool_L[1] / pool_L[2]
}
