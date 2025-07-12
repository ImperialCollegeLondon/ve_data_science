#' ---
#' title: Estimating litter stocks from SAFE data
#'
#' description: |
#'     This R script estimates litter stocks (leaf, wood, reproductive)
#'     from SAFE data
#'
#' VE_module: Litter
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: wip
#'
#' input_files:
#'   - name: Ewers_LeafLitter.xlsx
#'     path: data/primary/litter/
#'     description: |
#'       Wet and dry weight of leaf litterfall at SAFE vegetation plots by
#'       Robert Ewers; downloaded from https://zenodo.org/records/1198587
#'
#' output_files:
#'   - name: NA
#'     path: NA
#'     description: |
#'       NA
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'
#' usage_notes: |
#'   NA
#'
#' ---

library(tidyverse)
library(readxl)



# Data --------------------------------------------------------------------

# SAFE has multiple litter dynamics datasets
# so the first step is to harmonise them into a single dataset
# the target is a dataframe at least with columns initial litter weight,
# final litter weight, and time lapsed

# Plowman et al. (2018) https://zenodo.org/records/1220270
turner19 <-
  read_xlsx("data/primary/litter/template_Plowman.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  select(
    Plot_ID,
    location_name,
    Pretreatment,
    leaf_N,
    leaf_P,
    leaf_C,
    lig_rec
  ) %>%
  pivot_longer(
    cols = c(leaf_N, leaf_P, leaf_C, lig_rec),
    names_to = "chemical",
    values_to = "concentration"
  )






# Model -------------------------------------------------------------------
