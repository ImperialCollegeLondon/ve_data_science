#| ---
#| title: Estimating fungal-to-bacteria ratio from SAFE data
#|
#| description: |
#|     This R script estimates fungal-to-bacteria ratio from SAFE data
#|
#| virtual_ecosystem_module:
#|   - Soil
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: SAFE_Dataset.xlsx
#|     path: data/primary/soil/fungal_bacteria_ratio
#|     description: |
#|       Soil and litter chemistry, soil microbial communities and
#|       litter decomposition from tropical forest and oil palm dataset by
#|       Elias Dafydd et al. from SAFE; downloaded from
#|       https://doi.org/10.5281/zenodo.3929632
#|
#| output_files:
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes: |
#|   In the future, it is possible to get a numerically more accurate ratio
#|   using bootstrap values from the point estimate AND covariances of the
#|   predict function.
#| ---

library(tidyverse)
library(readxl)
library(glmmTMB)



# Data --------------------------------------------------------------------

# subplot coordinates
coord <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 2
  ) %>%
  filter(Type == "Carbon Subplot") %>%
  rename(location_name = `Location name`)

soil <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 3,
    skip = 9
  ) %>%
  rename(moisture = `gravimetric moisture content`)

# PLFA concentrations containing fungal:bacterial ratio
plfa <-
  read_xlsx("data/primary/soil/fungal_bacteria_ratio/SAFE_Dataset.xlsx",
    sheet = 5,
    skip = 9
  ) %>%
  # convert to long-format to model fungi and bacteria as groups
  select(Plot, location_name, Fungal_PLFA, Bacteria_PLFA) %>%
  pivot_longer(
    cols = ends_with("_PLFA"),
    names_to = "Group",
    names_pattern = "(.*)_PLFA",
    values_to = "PLFA"
  ) %>%
  mutate(Group = as.factor(Group))

# combine data
dat <-
  plfa %>%
  # join soil variables
  left_join(soil) %>%
  # join spatial coordinates and convert to glmmTMB-compatible class
  left_join(coord) %>%
  mutate(
    pos = numFactor(Longitude, Latitude),
    # dummy grouping variable for spatial modelling
    group = factor(1)
  )

# scale the covariates for model convergence and ease of interpretation
# also log-transform soil nutrients that are very skewed
dat_scaled <-
  dat %>%
  mutate_at(vars(soil_N, soil_C, soil_P), log) %>%
  mutate_at(
    vars(moisture, soil_pH, soil_N, soil_C, soil_P),
    ~ as.numeric(scale(.))
  )




# Model -------------------------------------------------------------------

# the soil nutrients (N, C and P) are highly collinear with one another
# more importantly, they are highly collinear with soil moisture
# so I only included soil pH and moisture in the model (which are not very
# correlated with one another)
mod <- glmmTMB(
  PLFA ~ 0 + Group * (soil_pH + moisture) +
    (1 | Plot_ID),
  dispformula = ~ 0 + Group,
  family = lognormal(link = "log"),
  data = dat_scaled
)

summary(mod)

# predict fungal and bacterial biomass (in terms of PLFA)
newdat <- data.frame(
  Group = unique(plfa$Group),
  soil_pH = 0,
  moisture = 0,
  Plot_ID = NA
)
yhat <-
  predict(mod,
    newdata = newdat,
    allow.new.levels = TRUE,
    type = "response",
    cov.fit = TRUE
  )

# calculate (predicted) fungal-to-bacterial ratio using their predicted biomass
yhat$fit[1] / yhat$fit[2]
