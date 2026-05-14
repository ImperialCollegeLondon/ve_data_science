library(tidyverse)
library(reshape2)
library(tidync)
library(futurize)
source("tools/R/get_all_variables.R")

plan(future.batchtools::batchtools_torque)

out_path <- "data/scenarios/sensitivity_soil_litter/out"
out_files <- list.files(out_path, "all_continuous_data.nc", recursive = TRUE)

merged <- map(
  out_files[1:2],
  \(file) {
    tidync(file.path(out_path, file)) |>
      get_all_variables() |>
      melt() |>
      mutate(
        scenario = sub("/.*", "", file),
        value = as.numeric(value)
      ) |>
      filter(!is.na(value)) |>
      unite(
        "variable",
        L1,
        element,
        layers,
        groundwater_layers,
        pft,
        na.rm = TRUE,
        remove = TRUE
      ) |>
      select(-cell_id)
  },
  .progress = TRUE
) |>
  futurize() |>
  list_rbind()

write_csv(merged, file.path(out_path, "all_continuous_data_merged.nc"))
