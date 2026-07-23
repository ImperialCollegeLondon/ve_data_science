library(calibrar)
box::use(tools/R/ve_run[ve_run])


# Model function ---------------------------------------------------------

run_model <- function(par, ...) {
  venv <- ".venv"
  config_path <- "data/scenarios/maliau/maliau_2/config"
  out_path <- "data/scenarios/maliau/maliau_2/out"
  args <- c(
    config_path,
    "--out",
    out_path,
    "--logfile",
    paste0(out_path, "/logfile.log"),
    "--config",
    "core.debug.truncate_run_at_update=4"
  )
  ve_run(args, venv)

  # read VE output
  return(out)
}


# Objective function -----------------------------------------------------

obj <- function(par, x, y) {
  y_sim <- apply(x, 1, linear, par = par)
  out <- sum((y_sim - y)^2)
  return(out)
}


# Validation data --------------------------------------------------------
# This is the observed data / response variables

# Calibration ------------------------------------------------------------

# set.seed(880820)

# initial values
start <- list(intercept = 0, slope = rep(0, N))

# parameter bounds
lower <- relist(rep(-10, N + 1), skeleton = start)
upper <- relist(rep(+10, N + 1), skeleton = start)

# optimisation
opt <- calibrate(
  par = start,
  fn = obj,
  x = x,
  y = y,
  lower = lower,
  upper = upper
)
coef(opt)
