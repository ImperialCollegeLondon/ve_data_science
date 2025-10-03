#| ---
#| title: Calculate the C:N and C:P ratios of fungal fruiting body (sporocarp)
#|
#| description: |
#|     This R script estimates the C, N and P mass fraction from a global
#|     dataset and then estimates the C:N and C:P ratio of fruiting body.
#|
#| virtual_ecosystem_module: Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: Sporocarp+chemistry.xlsx
#|     path: data/primary/soil/fungi_stoichiometry
#|     description: |
#|       Saprotrophic and ectomycorrhizal fungal sporocarp stoichiometry
#|       across temperate rainforests by Kranabetter et al. (2018)
#|       https://doi.org/10.1111/nph.15380; downloaded from
#|       https://doi.org/10.5061/dryad.1d92k70
#|
#| output_files:
#|   - name: CN_CP_ratio.csv
#|     path: data/derived/soil/fungi_stoichiometry
#|     description: |
#|       Estimated C:N and C:P ratio for fungal fruiting body
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|     The dataset covers only saprotrophic and EM fungi, but I think they are
#|     good enough for us at this stage. There are not a lot of stoichiometry
#|     specifically for the fruiting body in the literature.
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)


# Data --------------------------------------------------------------------

sporocarp <-
  read_excel(
    "data/primary/soil/fungi_stoichiometry/Sporocarp+chemistry.xlsx",
    range = "A5:G151"
  ) %>%
  rename(C = `%...5`, N = `%...6`, P = `%...7`) %>%
  mutate_at(vars(C, N, P), ~ . / 100)


# Model -------------------------------------------------------------------

# separate models for C, N and P
mod_C <- glmmTMB(
  C ~ 1 + (1 | Guild) + (1 | Plot) + (1 | `Site type`),
  family = beta_family(),
  data = sporocarp
)

mod_N <- glmmTMB(
  N ~ 1 + (1 | Guild) + (1 | Plot) + (1 | `Site type`),
  family = beta_family(),
  data = sporocarp
)

mod_P <- glmmTMB(
  P ~ 1 + (1 | Guild) + (1 | Plot) + (1 | `Site type`),
  family = beta_family(),
  data = sporocarp
)

# calculate C:N and C:P from estimated mean C, N and P
C_est <- plogis(fixef(mod_C)$cond)
N_est <- plogis(fixef(mod_N)$cond)
P_est <- plogis(fixef(mod_P)$cond)

CN_est <- C_est / N_est
CP_est <- C_est / P_est

# save output
write_csv(
  tibble(CN = CN_est, CP = CP_est),
  "data/derived/soil/fungi_stoichiometry/CN_CP_ratio.csv"
)
