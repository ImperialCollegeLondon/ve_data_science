
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
