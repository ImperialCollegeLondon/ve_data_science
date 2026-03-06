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



decay_param <- read_csv("data/derived/litter/turnover/decay_parameters.csv")
logitfM <- decay_param$value[decay_param$Parameter == "logitfM"]
sN <- decay_param$value[decay_param$Parameter == "sN"]
sP <- decay_param$value[decay_param$Parameter == "sP"]

# Ratio of structural vs metabolic C:N and C:P (r in the CENTURY model)
# this is from Kirschbaum and Paul (2002) Soil Biology and Biochemistry
# Since the structural and metabolic pools are abstract pools (unfortunately)
# there is no reason to modify this abstract ratio
r_century <- 5




litter <-
  read_xlsx("data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 3,
    skip = 7
  ) |>
  # convert lignin from mass/mass to g C/g C
  # the lignin C content = 62.5% comes from
  # Martin et al. (2021) DOI: 10.1038/s41467-021-21149-9
  mutate(lignin = lignin_recalcitrants * 0.625 / C_perc) |>
  select(
    litter_type,
    C.N, C.P, lignin,
  ) |>
  # calculate metabolic fraction
  mutate(fm = plogis(
    logitfM - lignin * (sN * C.N + sP * C.P)
  )) |>
  # calculate metabolic and structural nutrients
  # see rearranged equation on the litter theory documentation
  # nolint https://virtual-ecosystem.readthedocs.io/en/latest/virtual_ecosystem/theory/soil/litter_theory.html#split-of-nutrient-inputs-between-pools
  mutate(
    C.N_metabolic = C.N / (r_century + fm * (1 - r_century)),
    C.P_metabolic = C.P / (r_century + fm * (1 - r_century)),
    C.N_structural = r_century * C.N_metabolic,
    C.P_structural = r_century * C.P_metabolic)
