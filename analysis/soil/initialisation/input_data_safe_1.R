library(tidyverse)
library(readxl)
library(RcppTOML)
library(sf)
library(terra)
library(autoFRK)
library(CBFM)
library(RNetCDF)
library(glmmTMB)
library(biogas)
library(lubridate)
library(hms)
source("tools/R/convert_df_to_nc.R")

set.seed(20260703)


# Soil metadata ---------------------------------------------------------

soil_meta <- parseTOML("data/scenarios/maliau/soil_litter_metadata.toml")
soil_meta <- soil_meta$soil


# SAFE site metadata ----------------------------------------------------

safe <-
  parseTOML("data/derived/site/safe/safe_grid_definition.toml") |>
  pluck("Scenario") |>
  pluck("safe_1")

# total number of grids
n_sim <- with(maliau, cell_nx * cell_ny)
