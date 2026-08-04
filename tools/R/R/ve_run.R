#| ---
#| title: Run the Virtual Ecosystem in R
#|
#| description: |
#|     The function in this script imports ve_run_cli from virtual_ecosystem.entry_points
#|     to run VE directly from R.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|
#| package_dependencies:
#|     - reticulate (R)
#|     - virtual_ecosystem (Python)
#|
#| usage_notes: See function documentation below.
#| ---

#' Run the Virtual Ecosystem in R
#'
#' @param args A concatenated string of arguments. For example,
#'   \code{ve_run --install-example /usr/abc} can be replicated by calling
#'   \code{ve_run_cli(c('--install-example', '/usr/abc/'))}
#' @param venv Optional path to a virtual environment where ve_run is installed.
#'
#' @returns An integer indicating success (0) or failure (1). Output and logs
#'   are saved to the paths specified in `args`
#'
#' @examples
#'   config_path <- "data/scenarios/maliau/maliau_2/config"
#'   out_path <- "data/scenarios/maliau/maliau_2/out"
#'   args <- c(
#'     config_path,
#'     "--out",
#'     out_path,
#'     "--logfile",
#'     paste0(out_path, "/logfile.log"),
#'     "--config",
#'     "core.debug.truncate_run_at_update=4"
#'   )
#'   ve_run(args)

ve_run <- function(args, venv = NULL) {
  if (!is.null(venv)) {
    # use virtual environment if specified
    reticulate::use_virtualenv(venv)
  }

  # import the ve_run_cli function from VE
  ve_run_cli <- reticulate::import("virtual_ecosystem.entry_points")$ve_run_cli

  # run VE
  ve_run_cli(args)
}
