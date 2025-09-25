library(tidyverse)
library(readxl)
library(autoFRK)
library(CBFM)


# Data --------------------------------------------------------------------

location <-
  read_xlsx("data/primary/soil/nutrient/50-ha_soil_data.xlsx", sheet = 2)

soil <-
  read_xlsx(
    "data/primary/soil/nutrient/50-ha_soil_data.xlsx",
    sheet = 3,
    skip = 10
  ) %>%
  mutate_at(vars(soil_pH_water:Mehlich_Ca_Mg), as.numeric) %>%
  left_join(location, by = join_by("sample_ID" == "Location name"))

soil_vars <-
  c(
    "soil_pH_water",
    "RB_PO4",
    "RB_NH4",
    "RB_NO3",
    "Al_mg_kg",
    "Ca_mg_kg",
    "Fe_mg_kg",
    "K_mg_kg",
    "Mg_mg_kg",
    "Mn_mg_kg",
    "Na_mg_kg"
  )
soil_mat <- as.matrix(soil[, soil_vars])
soil_mat[, -1] <- log(soil_mat[, -1])
rownames(soil_mat) <- soil$sample_ID

# TODO check if NA can pass model
complete_cases <-
  complete.cases(soil_mat) &
    apply(soil_mat, 1, function(x) all(is.finite(x))) # nolint

soil_mat <- soil_mat[complete_cases, ]


# Model -------------------------------------------------------------------

# Set up spatial basis functions for CBFM
# Number of spatial basis functions to use
num_basis <- 25

# basis functions
basis_func <-
  mrts(soil[complete_cases, c("Longitude", "Latitude")], num_basis) %>%
  as.matrix() %>%
  # Remove the first intercept column
  {
    .[, -(1)]
  }

# Fit CBFM
tic <- proc.time()
fitcbfm <-
  CBFM(
    y = soil_mat,
    formula = ~1,
    data = soil[complete_cases, ],
    B_space = basis_func,
    family = gaussian(),
    control = list(trace = 1)
  )
toc <- proc.time()
toc - tic

summary(fitcbfm) %>%
  str()

corrplot::corrplot(corB(fitcbfm), order = "FPC")


# Prediction --------------------------------------------------------------

dat_new <-
  soil %>%
  data_grid(
    X = maliau$cell_x_centres / 1000,
    Y = maliau$cell_y_centres / 1000
  )
