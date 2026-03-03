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
library(glmmTMB)


# Data --------------------------------------------------------------------

sayer <- 
  read_csv(
    "data/primary/soil/nutrient/SayerEtAl2021_GLiMP_SoilCN_Fractions.csv"
  ) 

bulk <- 
  sayer %>% 
  filter(frac == "total") %>% 
  select(treatm:bulkD, C_total = mgCgsoilBD, N_total = mgNgsoilBD)

frac <- 
  sayer %>% 
  filter(frac != "total") %>% 
  group_by(treatm, block, plot, class) %>% 
  summarise(C = sum(mgCgsoilBD),
            N = sum(mgNgsoilBD)) %>% 
  left_join(bulk)
  



# Model -------------------------------------------------------------------

mod_C <- glmmTMB(
  C ~ 0 + class + treatm + (1 | block),
  offset = log(C_total),
  family = lognormal,
  data = frac
)
summary(mod_C)

mod_N <- glmmTMB(
  N ~ 0 + class + treatm + (1 | block),
  offset = log(N_total),
  family = lognormal,
  data = frac
)
summary(mod_N)
