library(mirai)
library(tidyverse)
library(arrow)

out_path <- "data/scenarios/sensitivity_soil_litter/out"
out_files <- list.files(out_path, "all_continuous_data.nc", recursive = TRUE)

daemons(128)
merged <- map(
  out_files,
  in_parallel(
    \(out_file) {
      require(tidyverse)
      require(reshape2)
      require(tidync)
      source("tools/R/get_all_variables.R")

      tidync(file.path(out_path, out_file)) |>
        get_all_variables() |>
        melt() |>
        mutate(
          scenario = sub("/.*", "", out_file),
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
    out_path = out_path
  )
) |>
  list_rbind()
daemons(0)

write_parquet(merged, file.path(out_path, "all_continuous_data_merged.parquet"))
