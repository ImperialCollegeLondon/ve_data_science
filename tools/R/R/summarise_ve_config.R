#| ---
#| title: Summarise Virtual Ecosystem run configuration
#|
#| description: |
#|   Reads the compiled configuration and log file saved with every Virtual
#|   Ecosystem (VE) simulation and returns a Markdown summary: VE version,
#|   registered models, grid size, resolution, bounding box, simulation period
#|   and input file names. The text can be pasted into GitHub issues or
#|   included in markdown-based reports.
#|
#|   Input files are taken to be any config string ending in .nc or .csv. The
#|   bounding box assumes xoff and yoff are the lower-left corner of a square
#|   grid.
#|
#| virtual_ecosystem_module: All
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|   - name: Markdown text on the console
#|     path: Not applicable
#|     description: |
#|       Character string returned invisibly and printed with cat().
#|
#| package_dependencies:
#|   - toml
#|
#| usage_notes: See the @examples section.
#| ---

#' Summarise key settings of a Virtual Ecosystem run as Markdown
#'
#' @param config_path Path to compiled_configuration.toml.
#' @param log_path Path to logfile.log (only first 100 lines are read).
#' @param dev TRUE if VE was ran on the develop version.
#' @return Markdown-friendly text printed via cat.
#' @examples
#' out_dir <- here::here("data/scenarios/maliau/maliau_2/out")
#' summarise_ve_config(
#'   file.path(out_dir, "compiled_configuration.toml"),
#'   file.path(out_dir, "logfile.log")
#' )
#'
#' # Flag a run on the develop version
#' summarise_ve_config(
#'   file.path(out_dir, "compiled_configuration.toml"),
#'   file.path(out_dir, "logfile.log"),
#'   dev = TRUE
#' )

summarise_ve_config <- function(config_path, log_path, dev = FALSE) {
  cfg <- toml::read_toml(config_path)
  grid <- cfg$core$grid
  side <- sqrt(grid$cell_area)
  # Square grid: xoff/yoff are the lower-left origin
  x_max <- grid$xoff + grid$cell_nx * side
  y_max <- grid$yoff + grid$cell_ny * side

  timing <- cfg$core$timing

  # Any string ending in .nc or .csv, anywhere in the config
  files <- unique(basename(grep(
    "\\.(nc|csv)$",
    unlist(cfg),
    value = TRUE,
    ignore.case = TRUE
  )))

  log <- readLines(log_path, n = 100)
  version <- sub(
    ".*Using Virtual Ecosystem (v[0-9][^ ]*?)\\.?$",
    "\\1",
    grep("Using Virtual Ecosystem", log, value = TRUE)[1]
  )
  models <- grep("Registering model class for", log, value = TRUE) |>
    sub(pattern = ".*: (\\w+?)Model$", replacement = "\\1")

  out <- c(
    paste0(
      "- **VE version**: ",
      version,
      if (dev) " (develop version)"
    ),
    paste0("- **Models**: ", paste(models, collapse = ", ")),
    paste0("- **Grid**: ", grid$cell_nx, " x ", grid$cell_ny, " cells"),
    paste0("- **Resolution**: ", side, " m"),
    paste0(
      "- **Extent (bbox)**: xmin: ",
      grid$xoff,
      " ymin: ",
      grid$yoff,
      " xmax: ",
      x_max,
      " ymax: ",
      y_max
    ),
    paste0(
      "- **Time period**: start ",
      timing$start_date,
      ", length ",
      timing$run_length,
      ", update interval ",
      timing$update_interval
    ),
    "- **Input files**:",
    paste0("  - `", files, "`")
  )
  out <- paste(out, collapse = "\n")
  cat(out, "\n")
  invisible(out)
}
