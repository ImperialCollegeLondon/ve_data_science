library(tidyverse)
library(arrow)
library(calibrar)
# library(parallel)
source("tools/R/R/ve_run.R")
source("tools/R/R/valdb.R")

# ncores <- detectCores() - 2 # number of cores to be used
# cl <- makeCluster(ncores)

# Model function ---------------------------------------------------------

# Function to run VE on selected parameters to be calibrated
run_model <- function(par, ...) {
  # define scenario config and out paths
  scenario_path <- "data/scenarios/maliau/maliau_2"
  config_path <- c(
    file.path(scenario_path, "config/data_config.toml"),
    file.path(scenario_path, "config/abiotic_simple_config.toml"),
    file.path(scenario_path, "config/animal_config.toml"),
    file.path(scenario_path, "config/hydrology_config.toml"),
    file.path(scenario_path, "config/litter_config.toml"),
    file.path(scenario_path, "config/plant_config.toml"),
    file.path(scenario_path, "config/soil_config.toml")
  )
  out_folder <- "out_calibrate"
  out_path <- file.path(scenario_path, out_folder)
  if (!dir.exists(out_path)) {
    dir.create(out_path, recursive = TRUE)
  }
  withr::defer(unlink(out_path, recursive = TRUE, force = TRUE))

  # collect calibration parameters to be modified in the config
  pars_calibrate <-
    par |>
    imap(\(group_vals, group_name) {
      group_vals |>
        imap(\(val, param_name) {
          c("--config", paste0(group_name, ".constants.", param_name, "=", val))
        }) |>
        unlist(use.names = FALSE)
    }) |>
    unlist(use.names = FALSE)

  # paste the VE args together
  # debug.truncate_run_at_update is for testing purpose
  args <- c(
    config_path,
    "--out",
    out_path,
    "--logfile",
    file.path(out_path, "logfile.log")
  )

  # run VE
  ve_run(args)

  # Read the validation database
  db_path <- "data/derived/soil/validation/database"
  validation_database <- open_dataset(db_path) |> collect()

  # Combine the validation database with VE outputs
  zarr_path <- file.path(scenario_path, out_folder, "model_data.zarr")
  config_path <- file.path(
    scenario_path,
    out_folder,
    "compiled_configuration.toml"
  )
  join_ve_outputs(validation_database, zarr_path, config_path)

  # clean up memory
  gc()
}


# Objective function -----------------------------------------------------

# obj() mustn't return NA

obj <- function(par) {
  sim <- run_model(par)
  y <- sim$value_canonical
  y_sim <- sim$value_VE_q50
  loss <- sum((y_sim - y)^2)
  return(loss)
}


# Calibration ------------------------------------------------------------

# set.seed(880820)

# initial values
start <- list(
  soil = list(litter_leaching_fraction_carbon = 0.0015)
)

# parameter bounds
lower <- list(litter_leaching_fraction_carbon = 0.0001)
upper <- list(litter_leaching_fraction_carbon = 0.0100)

# optimisation
opt <- calibrate(
  par = start,
  fn = obj,
  lower = lower,
  upper = upper
  # control = list(parallel = TRUE, ncores = ncores)
)

# stopCluster(cl) # close the parallel connections

out_dir <- "data/derived/soil/calibration"
if (!dir.exists(out_dir)) {
  dir.create(out_dir)
}
write_rds(opt, file.path(out_dir, "opt_test.rds"))
