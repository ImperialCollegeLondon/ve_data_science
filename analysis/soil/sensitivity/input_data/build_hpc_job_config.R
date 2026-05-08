library(toml)
library(purrr)

common_config_paths <- list()

site_directory <- "/rds/projects/virtual_rainforest/live/ve_data_science/data/scenarios/sensitivity_soil_litter"

config_list_dir <- "data/scenarios/sensitivity_soil_litter/config"
config_list_paths <- list.dirs(
  config_list_dir,
  full.names = FALSE,
  recursive = FALSE
)

jobs <-
  config_list_paths |>
  map(\(x) {
    list(
      config_paths = list(paste0(config_list_dir, "/", x)),
      name = paste0("run_", x),
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
