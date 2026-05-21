#' Log decision on whether a dataset should be included for validation purposes
#'
#' This function is intended to be used as \code{log_dataset()}, which will display
#' a UI in the R console and prompt you to enter the DOI and notes on
#' decisions. The log is then stored as a human-readable YAML file in the
#' specified output directory, which defaults to the soil module for now.
#'
#' @param outdir Path to the output directory, which currently defaults to the
#'   soil module
#'
#' @details
#' You will asked to enter:
#' \describe{
#'   \item{DOI}{DOI string of the dataset or publication}
#'   \item{Decision}{A menu to select decision}
#'   \item{Reason}{(Optional) A menu to select reason}
#'   \item{Notes}{(Optional) A string of long-form rationale}
#' }
#'
#' @returns A YAML file logging the decision and source metadata in
#'   \code{outdir}.
#'
#' @export
#'
#' @examples
#' box::use(tools/R/log_dataset[log_dataset])
#' box::help(log_dataset)
#' log_dataset()

log_dataset <- function(
  outdir = "data/derived/soil/validation/records"
) {
  # prompt to enter DOI
  doi <- readline("Enter DOI: ")

  # download dataset metadata
  meta <- rcrossref::cr_cn(doi, format = "bibentry")

  # set up output path
  slug <- gsub("[/.]", "-", meta$doi)
  path <- file.path(outdir, paste0(slug, ".yaml"))

  # early exit if already logged
  if (file.exists(path)) {
    cli::cli_abort("A log for {doi} already exists at {path}")
  }

  # prompt for decision, decision, decision...
  decision <- utils::select.list(
    c("included", "excluded"),
    title = "Decision (enter 0 to skip): ",
    graphics = FALSE
  )
  if (decision == "") {
    decision <- "skipped"
  }

  # prompt for short-form reason
  reason <- utils::select.list(
    c("used_elsewhere", "no_raw_data", "no_soil_data"),
    title = "Reason (enter 0 to skip): ",
    graphics = FALSE
  )

  # prompt for long-form notes
  notes <- readline("Notes (leave blank to skip): ")

  # Build record
  record <- list(
    doi = meta$doi,
    decision = decision,
    reason = reason,
    notes = notes,
    logged_at = format(Sys.time(), "%Y-%m-%d"),
    metadata = list(
      title = meta$title,
      author = meta$author,
      year = meta$year,
      journal = as.character(meta$journal %||% NA),
      publisher = meta$publisher,
      url = meta$url,
      keywords = meta$keywords
    )
  )

  # Write YAML
  yaml::write_yaml(record, path)

  # Completion message
  cli::cli_alert_info("Dataset from {doi} is {decision}")
  cli::cli_alert_success("Decision log saved to\n{path}")
}
