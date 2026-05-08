library(toml)
library(purrr)

common_config_paths <- list()

site_directory <- "/rds/projects/virtual_rainforest/live/ve_data_science/data/scenarios/sensitivity_soil_litter"

config_list_paths <- list.dirs(
  "data/scenarios/sensitivity_soil_litter/config",
  recursive = FALSE
)

jobs <-
  config_list_paths |>
  imap(\(x, idx) {
    list(
      config_paths = list(x),
      name = paste0("sensitivity_run_", idx),
      repeats = 1,
      config = list()
    )
  })

list(
  common_config_paths = common_config_paths,
  site_directory = site_directory,
  jobs = jobs
) |>
  write_toml() |>
  writeLines(con = "data/scenarios/sensitivity_soil_litter/job_config.toml")
