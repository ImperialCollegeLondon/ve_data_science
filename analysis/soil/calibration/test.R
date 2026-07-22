# Virtual Ecosystem calibration workflow (OUTLINE)
# ------------------------------------------------
# Purpose:
#   Sketch a staged calibration script using `calibrar::calibrate()`.
#   This file is intentionally incomplete and contains TODO markers.
#
# What this outline covers:
#   1) Define model runner wrapper
#   2) Load observed data via calibration_setup() / calibration_data()
#   3) Build objective function via calibration_objFn() (or manually)
#   4) Declare parameters, bounds, and phase activation plan
#   5) Choose method(s) and control settings
#   6) Optional parallel setup
#   7) Run calibration via calibrate()
#   8) Post-calibration diagnostics (coef, summary, plots)
#   9) Save artifacts for reproducibility
#
# NOTE:
#   This is a planning scaffold, not a fully working script.
#
# CALIBRAR WORKFLOW OVERVIEW:
#   calibration_setup(file)  -> setup object describing variables, transforms, penalties
#   calibration_data(setup)  -> named list of observed data arrays
#   calibration_objFn(...)   -> wraps run_model() into a scalar objective function
#   calibrate(par, fn, ...)  -> runs sequential multi-phase optimisation
#   coef(fit)                -> extracts best-fit parameters (prefer over fit$par)
#   summary(fit1, fit2, ...) -> compare multiple runs side-by-side

# ================================================================
# 0) Packages and global options
# ================================================================

library(calibrar)

# TODO: set project paths in one place (config-driven preferred)
# e.g.,
# model_dir <- "path/to/virtual_ecosystem"
# data_dir  <- "path/to/observations"
# out_dir   <- "path/to/calibration_outputs"

# TODO: choose a reproducibility seed for stochastic model behavior
# set.seed(####)

# ================================================================
# 1) Define model runner wrapper
# ================================================================

# Goal:
#   Wrap one VE simulation call so calibrar can evaluate candidate parameter sets.
#
# Requirements for this function:
#   - Input: parameter set (vector or list)
#   - Side effects: run VE model (external executable, API, or in-R function)
#   - Output: simulated quantities aligned with observation targets
#   - Robustness: return NA/Inf-safe result on model failure

run_virtual_ecosystem <- function(par, scenario = "baseline") {
  # TODO: map `par` into VE config format expected by your model
  # TODO: write temporary config / inject params
  # TODO: execute VE model run
  # TODO: read model outputs (time series / spatial summaries)

  # rough placeholder return structure (replace with real outputs)
  sim <- list(
    # TODO: e.g., soil_carbon = numeric_vector,
    # TODO: e.g., soil_moisture = numeric_vector
  )

  return(sim)
}


# ================================================================
# 2) Load observed data and calibration setup
# ================================================================

# calibrar provides a structured path via:
#   calibration_setup(file)  -- reads a CSV/YAML setup file describing each
#                               calibration variable: name, weight, transform,
#                               penalty type, etc.
#   calibration_data(setup)  -- reads observed data files described in the
#                               setup and returns a named list of arrays

# TODO: create a calibration setup file (CSV or list) for VE variables
# setup <- calibration_setup(file = file.path(data_dir, "ve_calibration_setup.csv"))

# TODO: load observed data arrays described by setup
# observed <- calibration_data(setup = setup, path = data_dir)

# If not using calibration_setup/calibration_data, build the observed list manually:
# observed <- list(
#   soil_carbon   = ...,  # numeric vector / array aligned to model output
#   soil_moisture = ...
# )

# TODO: harmonize units, time index, and spatial aggregation to match VE outputs

# ================================================================
# 3) Define objective function
# ================================================================

# NOTE: calibrar also provides calibration_objFn() to build the objective
#   automatically from a setup file + observed data. Its documentation is still
#   maturing — revisit once it is more stable.

# Writing the objective function manually (the approach used here):
#
# Rules:
#   - par must be the first argument
#   - must return a single finite scalar (smaller = better)
#   - handle model failures gracefully (return large penalty, not NA/Inf)
#
# The loss function (how mismatch between sim and observed is measured) is
# your choice. Common options:
#   MSE  — mean((sim - obs)^2)          sensitive to large deviations
#   MAE  — mean(abs(sim - obs))          more robust to outliers
#   RMSE — sqrt(mean((sim - obs)^2))     same units as observations
#
# When combining multiple variables into one scalar, scale each term first
# (e.g. divide by variance or range) so no single variable dominates.

objective_ve <- function(par, observed, scenario = "baseline") {
  sim <- tryCatch(
    run_virtual_ecosystem(par = par, scenario = scenario),
    error = function(e) NULL
  )

  if (is.null(sim)) {
    return(1e12) # penalty for failed model run
  }

  # TODO: compute mismatch terms between sim and observed
  # TODO: scale each term (e.g. divide by variance or range) before combining
  # TODO: add any penalty terms (e.g. prior constraints on parameters)

  # rough placeholder:
  # err_carbon <- mean((sim$soil_carbon - observed$soil_carbon)^2, na.rm = TRUE)
  # err_moist  <- mean((sim$soil_moisture - observed$soil_moisture)^2, na.rm = TRUE)
  # loss <- 0.7 * err_carbon + 0.3 * err_moist

  loss <- NA_real_ # TODO: replace

  if (!is.finite(loss)) {
    return(1e12)
  }

  return(loss)
}


# ================================================================
# 4) Declare parameters, bounds, and phase activation plan
# ================================================================

# Strategy:
#   - Start with most identifiable/high-impact parameters in early phase(s)
#   - Add more uncertain/coupled parameters in later phases
#   - Use negative phase values for fixed parameters

# TODO: replace names/values with VE-relevant parameters
par_start <- c(
  k_decomp_fast = NA_real_,
  k_decomp_slow = NA_real_,
  q10_resp = 2.0,
  field_capacity = NA_real_,
  wilting_point = 0.20
)

lower <- c(
  k_decomp_fast = 0.0001,
  k_decomp_slow = 0.00001,
  q10_resp = 1.1,
  field_capacity = 0.10,
  wilting_point = 0.05
)

upper <- c(
  k_decomp_fast = 0.50,
  k_decomp_slow = 0.05,
  q10_resp = 3.5,
  field_capacity = 0.65,
  wilting_point = 0.40
)

# Example phase plan:
#   1 = active in phase 1
#   2 = becomes active in phase 2
#  -1 = fixed (never calibrated)
phases <- c(
  k_decomp_fast = 1,
  k_decomp_slow = 2,
  q10_resp = 1,
  field_capacity = 2,
  wilting_point = -1
)

# TODO: verify names and lengths are fully aligned
# stopifnot(length(par_start) == length(lower), ...)

# ================================================================
# 5) Choose optimization method(s) and control settings
# ================================================================

# METHOD SELECTION NOTES (from calibrar docs):
#   - Default when replicates = 1: Rvmmin (gradient-based, fast for smooth objectives)
#   - Default when replicates > 1: AHR-ES (evolutionary, handles stochastic objectives)
#   - 'LBFGSB3' often performs well but has a low default maxit (100); increase it.
#   - You can pass a vector of methods, one per phase:
#       method = c("CG", "Rvmmin")  # cheap global search in phase 1, precise in phase 2
#   - CG is cheap per function evaluation and can provide a good warm start for Rvmmin.

# TODO: choose method(s). Options include:
#   Deterministic: "Rvmmin", "LBFGSB3", "L-BFGS-B", "CG", "Nelder-Mead", "hjn", "nlm"
#   Heuristic:     "AHR-ES", "CMA-ES", "DE", "genSA", "soma", "PSO"
#   Per-phase vec: c("CG", "Rvmmin")  -- one entry per distinct phase number

# WARNING: a 'converged' status does not always mean a good solution was found.
#   Always check whether the final objective value is plausible, and consider
#   running multiple algorithms and comparing with summary().

control_cal <- list(
  maxit = 2000, # default 100 is often too low; increase for complex models
  trace = 1
  # eps   = sqrt(.Machine$double.eps),  # tighter gradient tolerance
  # factr = sqrt(.Machine$double.eps)   # tighter function-value tolerance (LBFGSB3)
  # TODO: add method-specific controls as needed
)

# ================================================================
# 6) Optional parallel setup (only if useful for expensive runs)
# ================================================================

# NOTE:
#   calibrar does not auto-create clusters; user sets up parallel context.
#   Keep this block optional; overhead can outweigh gains for cheap objective calls.

# TODO: uncomment/adapt if parallel needed
# library(parallel)
# ncores <- max(1L, parallel::detectCores() - 1L)
# cl <- parallel::makeCluster(ncores)
# on.exit(parallel::stopCluster(cl), add = TRUE)

# ================================================================
# 7) Run calibration (primary call to calibrate())
# ================================================================

# A) Single-phase, single method (simplest starting point)
# calib_fit <- calibrate(
#   par     = par_start,
#   fn      = obj,          # or objective_ve if using manual objective
#   observed = observed,    # forwarded to fn via ...
#   lower   = lower,
#   upper   = upper,
#   control = control_cal
# )

# B) Multi-phase, single method
# calib_fit <- calibrate(
#   par     = par_start,
#   fn      = obj,
#   observed = observed,
#   lower   = lower,
#   upper   = upper,
#   phases  = phases,
#   control = control_cal
# )

# C) Multi-phase, per-phase methods (e.g. cheap global search -> precise local)
#    Pass a vector with one method per distinct phase number.
# calib_fit <- calibrate(
#   par     = par_start,
#   fn      = obj,
#   observed = observed,
#   lower   = lower,
#   upper   = upper,
#   phases  = phases,
#   method  = c("CG", "Rvmmin"),  # phase 1: CG, phase 2: Rvmmin
#   control = control_cal
# )

# D) Stochastic model (replicates > 1 triggers AHR-ES by default)
#    replicates can be a scalar or a vector with one value per phase.
# calib_fit <- calibrate(
#   par        = par_start,
#   fn         = obj,
#   observed   = observed,
#   lower      = lower,
#   upper      = upper,
#   phases     = phases,
#   replicates = c(1, 3),  # cheap in phase 1, more robust in phase 2
#   control    = control_cal
# )

# TIP: run multiple algorithms and compare; results can differ substantially.
# calib_fit2 <- calibrate(par = par_start, fn = obj, observed = observed,
#                         lower = lower, upper = upper, phases = phases,
#                         method = "Rvmmin", control = control_cal)

# ================================================================
# 8) Post-calibration diagnostics
# ================================================================

# Use coef() to extract the best-fit parameter list (idiomatic calibrar)
# best_par <- coef(calib_fit)

# Use summary() to compare multiple runs side-by-side (method, elapsed,
# objective value, function/gradient counts, and selected parameter values)
# summary(calib_fit, calib_fit2, show_par = 1:3)

# TODO: inspect convergence status -- a 'converged' message is not proof
#   of a global optimum; always check whether the objective value is reasonable.
# print(calib_fit)

# TODO: re-run VE with best_par and compare simulated vs observed visually
# sim_best <- run_virtual_ecosystem(par = best_par, scenario = "baseline")
# TODO: plot sim_best$variable vs observed$variable for each calibration target

# TODO: compute holdout / validation metrics if withheld data are available

# ================================================================
# 9) Save artifacts for reproducibility
# ================================================================

# TODO: persist complete calibration object
# saveRDS(calib_fit, file.path(out_dir, "calib_fit_YYYYMMDD.rds"))

# TODO: write tidy parameter table / diagnostics summary
# readr::write_csv(...)

# TODO: snapshot run metadata
# - git commit hash
# - VE model version
# - data version IDs
# - seed
# - method/control/phases/replicates settings

# ================================================================
# 10) Next TODOs (for user to fill)
# ================================================================

# TODO [HIGH]: Implement `run_virtual_ecosystem()` end-to-end.
# TODO [HIGH]: Finalize objective scaling/weighting across target variables.
# TODO [MED]: Replace placeholder parameter set with VE process-informed priors.
# TODO [MED]: Decide deterministic vs stochastic strategy and replicates schedule.
# TODO [MED]: Add validation split (sites/periods) to avoid overfitting.
# TODO [LOW]: Add lightweight plotting for fit diagnostics per target variable.
