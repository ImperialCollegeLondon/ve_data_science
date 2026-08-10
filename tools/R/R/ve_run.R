#| ---
#| title: Run the Virtual Ecosystem in R
#|
#| description: |
#|     The function in this script runs `ve_run` via `uv run` from R,
#|     matching the repository's uv-based Python workflow.
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
#|     - uv (CLI)
#|
#| usage_notes: |
#|     Requires `uv` on PATH and runs `ve_run` via
#|     `uv run --group <group> ve_run ...` from the repository root.
#| ---

#' Run the Virtual Ecosystem in R
#'
#' @param args A character vector of command-line arguments passed to
#'   \code{ve_run}. For example,
#'   \code{ve_run --install-example /usr/abc} can be replicated by calling
#'   \code{ve_run(c('--install-example', '/usr/abc/'))}.
#' @param group uv dependency group used with \code{uv run --group}. Defaults
#'   to \code{"dev-pinned"}.
#'
#' @returns An integer exit status from the \code{uv run} command
#'   (0 = success, non-zero = failure).
#'
#' @examples
#'   # Run `uv sync --group dev-pinned` in the repository root first.
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
#'
#' @export

ve_run <- function(args, group = "dev-pinned") {
  uv <- Sys.which("uv")

  if (uv == "") {
    stop("uv not found on PATH")
  }

  system2(
    command = uv,
    args = c("run", "--group", group, "ve_run", args),
    stdout = "",
    stderr = ""
  )
}
