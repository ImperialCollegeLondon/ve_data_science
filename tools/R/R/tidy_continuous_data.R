#| ---
#| title: Extract continuous state variables into long-format dataframe
#|
#| description: |
#|     Tidy up continuous state variables from a Virtual Ecosystem Zarr output
#|     dataset into a long-format tibble. Spatial (x, y) and temporal
#|     (timestamp) coordinates are joined onto each observation. Optionally,
#|     timeless initial-state values can be prepended with a time_index of -1.
#|     Time-varying initial arrays retain their time_index and use the matching
#|     initial time coordinate, converted to the output timestamp units.
#|     The function is designed for use in downstream visualisation and
#|     sensitivity analysis workflows.
#|
#| virtual_ecosystem_module: All
#|
#| author: Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|     - Virtual Ecosystem Zarr output dataset (.zarr), passed via `path`
#|
#| output_files:
#|     - None (returns an R tibble)
#|
#| source_files:
#|     - name: get_ve_variables.R
#|       path: tools/R/R/get_ve_variables.R
#|       description: |
#|           Provides get_data_variables() used to read variables from the
#|           Zarr dataset.
#|
#| package_dependencies:
#|     - cli
#|     - dplyr
#|     - pizzarr
#|     - reshape2
#|     - tibble
#|     - tidyr
#|
#| usage_notes: |
#|     See examples of use in:
#|       - analysis/soil/visualisation/visualise_continuous_data.R
#|       - >-
#|         analysis/troubleshoot/animal_continuous_states/
#|         small_temporal_variation.qmd
#| ---

#' Extract continuous state variables into long-format dataframe
#'
#' Reads selected state variables from a Virtual Ecosystem Zarr output
#' dataset and optionally its initial-state group, returning a long-format
#' tibble with spatial (x, y) and temporal
#' (timestamp) coordinates joined onto each observation. Designed for use in
#' downstream visualisation and sensitivity analysis workflows.
#'
#' @param path Path to a Virtual Ecosystem Zarr output dataset.
#' @param variables Optional character vector of state variable names to
#'   extract. If `NULL` (default), all available output variables are extracted;
#'   with `initial = TRUE`, all available initial variables are included too.
#'   Variables found only in `"init"` appear only in initial rows.
#' @param initial Logical. If `TRUE`, initial-state values from the `"init"`
#'   group are prepended to the output. Timeless arrays use `time_index = -1`
#'   and `timestamp = -1`; time-varying arrays retain their `time_index` and
#'   use the corresponding initial time coordinate, converted to the output
#'   timestamp units.
#'
#' @returns A long-format tibble with columns `variable`, `value`, `cell_id`,
#'   `x`, `y`, `time_index`, and `timestamp`. Additional array dimensions,
#'   such as `layers`, `element`, and `pft`, are retained when present.

tidy_continuous_data <- function(path, variables = NULL, initial = FALSE) {
  if (initial && !is.null(variables)) {
    # Validate both groups because requested variables may be initial-only.
    zarr <- pizzarr::zarr_open(path)
    output_names <- base::setdiff(
      zarr$get_item("outputs")$get_store()$listdir("outputs"),
      c(".zattrs", ".zgroup")
    )
    init_names <- base::setdiff(
      zarr$get_item("init")$get_store()$listdir("init"),
      c(".zattrs", ".zgroup")
    )
    missing_vars <- base::setdiff(variables, union(output_names, init_names))
    if (length(missing_vars) > 0) {
      cli::cli_abort(
        "The following variables are not found: {.val {missing_vars}}"
      )
    }
    output_variables <- intersect(variables, output_names)
    init_variables <- intersect(variables, init_names)
  } else {
    output_variables <- variables
    init_variables <- variables
  }

  # load continuous data file
  outputs <- get_data_variables(path, group = "outputs", output_variables)

  # spatial coordinates to join by cell_id
  xy <-
    get_data_variables(path, group = "outputs", variables = c("x", "y")) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1)
  # temporal coordinates to join by time_index
  timestamp <-
    get_data_variables(path, group = "outputs", variables = "timestamp") |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1)

  # tidy, long-format version of the continuous data
  tidy_cont <- if (length(outputs) > 0) {
    outputs |>
      reshape2::melt() |>
      dplyr::left_join(xy, by = dplyr::join_by(cell_id)) |>
      dplyr::left_join(timestamp, by = dplyr::join_by(time_index)) |>
      dplyr::mutate(time_index = as.numeric(time_index))
  } else {
    tibble::tibble(
      cell_id = integer(),
      time_index = double(),
      value = double(),
      L1 = character()
    ) |>
      dplyr::left_join(xy, by = dplyr::join_by(cell_id)) |>
      dplyr::left_join(timestamp, by = dplyr::join_by(time_index))
  }

  # If initial data is requested, preserve temporal coordinates on arrays
  # that vary over time; only timeless initial states use the -1 sentinel.
  init <- if (initial) {
    get_data_variables(path, group = "init", init_variables)
  } else {
    list()
  }
  if (length(init) > 0) {
    time_varying <- names(init)[vapply(
      init,
      \(x) "time_index" %in% names(dimnames(x)),
      logical(1)
    )]

    if (length(time_varying) > 0) {
      zarr <- pizzarr::zarr_open(path)
      init_group <- zarr$get_item("init")
      output_group <- zarr$get_item("outputs")
      init_arrays <- base::setdiff(
        init_group$get_store()$listdir("init"),
        c(".zattrs", ".zgroup")
      )
      init_attrs <- lapply(init_arrays, \(name) {
        init_group$get_item(name)$get_attrs()$to_list()
      })
      is_time_coordinate <- vapply(
        init_attrs,
        \(attrs) {
          dimensions <- unlist(attrs$`_ARRAY_DIMENSIONS`, use.names = FALSE)
          units <- attrs$units
          length(dimensions) == 1L &&
            identical(dimensions, "time_index") &&
            length(units) == 1L &&
            !is.na(units) &&
            grepl("\\bsince\\b", units, ignore.case = TRUE)
        },
        logical(1)
      )
      time_coordinates <- init_arrays[is_time_coordinate]

      if (length(time_coordinates) != 1L) {
        stop(
          "Could not identify one initial time coordinate for time-varying ",
          "initial arrays.",
          call. = FALSE
        )
      }

      init_time <- init_group$get_item(time_coordinates)
      init_time_attrs <- init_time$get_attrs()$to_list()
      output_time_attrs <- output_group$get_item(
        "timestamp"
      )$get_attrs()$to_list()

      parse_time_units <- function(units) {
        if (length(units) != 1L || is.na(units) || !nzchar(units)) {
          stop("Unsupported or missing CF time units.", call. = FALSE)
        }
        parts <- regmatches(
          units,
          regexec(
            "^\\s*(seconds?|minutes?|hours?|days?)\\s+since\\s+(.+?)\\s*$",
            units,
            ignore.case = TRUE
          )
        )[[1]]
        if (length(parts) != 3L) {
          stop("Unsupported or missing CF time units.", call. = FALSE)
        }

        unit_seconds <- switch(
          tolower(sub("s$", "", parts[[2]])),
          second = 1,
          minute = 60,
          hour = 3600,
          day = 86400
        )
        origin <- as.POSIXct(
          parts[[3]],
          tz = "UTC",
          tryFormats = c("%Y-%m-%d %H:%M:%OS", "%Y-%m-%d")
        )
        if (is.na(origin)) {
          stop("Unsupported CF time origin.", call. = FALSE)
        }
        c(origin = as.numeric(origin), unit_seconds = unit_seconds)
      }

      init_calendar <- init_time_attrs$calendar
      output_calendar <- output_time_attrs$calendar
      if (
        length(init_calendar) != 1L ||
          length(output_calendar) != 1L ||
          is.na(init_calendar) ||
          is.na(output_calendar) ||
          init_calendar != "proleptic_gregorian" ||
          output_calendar != init_calendar
      ) {
        stop(
          "Only matching proleptic_gregorian time calendars are supported.",
          call. = FALSE
        )
      }

      init_units <- parse_time_units(init_time_attrs$units)
      output_units <- parse_time_units(output_time_attrs$units)
      init_time_index <- as.numeric(
        init_group$get_item("time_index")$as.array()
      )
      init_time_values <- as.numeric(init_time$as.array())
      if (
        length(init_time_index) != length(init_time_values) ||
          any(!is.finite(init_time_index)) ||
          anyDuplicated(init_time_index) > 0 ||
          any(!is.finite(init_time_values))
      ) {
        stop("Invalid initial time coordinate mapping.", call. = FALSE)
      }

      # Match calendar times, since equal indices can represent different dates.
      init_timestamps <- tibble::tibble(
        time_index = init_time_index,
        timestamp = (init_time_values *
          init_units[["unit_seconds"]] +
          init_units[["origin"]] -
          output_units[["origin"]]) /
          output_units[["unit_seconds"]]
      )
    }

    tidy_init <- init |> reshape2::melt()
    if (!"time_index" %in% names(tidy_init)) {
      tidy_init$time_index <- NA_real_
    }
    tidy_init <- tidy_init |> dplyr::mutate(time_index = as.numeric(time_index))

    if (length(time_varying) > 0) {
      tidy_init <- tidy_init |>
        dplyr::left_join(init_timestamps, by = "time_index")
      if (anyNA(tidy_init$timestamp[tidy_init$L1 %in% time_varying])) {
        stop(
          "Could not map every time index in initial arrays to its time",
          "coordinate.",
          call. = FALSE
        )
      }
    } else {
      tidy_init <- tidy_init |> dplyr::mutate(timestamp = NA_real_)
    }

    tidy_init <- tidy_init |>
      dplyr::mutate(
        time_index = dplyr::if_else(L1 %in% time_varying, time_index, -1),
        timestamp = dplyr::if_else(L1 %in% time_varying, timestamp, -1)
      )
    if (!"cell_id" %in% names(tidy_init)) {
      tidy_init$cell_id <- NA_integer_
    }
    tidy_init <- tidy_init |>
      dplyr::left_join(xy, by = dplyr::join_by(cell_id))

    # merge initial and continuous data
    tidy_cont <- dplyr::bind_rows(tidy_init, tidy_cont)
  }

  # finalise output
  tidy_cont |> dplyr::rename(variable = L1) |> dplyr::as_tibble()
}
