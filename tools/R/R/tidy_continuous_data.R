#| ---
#| title: Extract continuous state variables into long-format dataframe
#|
#| description: |
#|     Tidy up continuous state variables from a Virtual Ecosystem Zarr output
#|     dataset into a long-format tibble. Spatial (x, y) and temporal
#|     (timestamp) coordinates are joined onto each observation. Optionally,
#|     variables saved in the inputs and init groups are included. Time-varying
#|     initial arrays retain their source time_index and stored time coordinate.
#|     Timeless initial values use time_index -1 and a missing timestamp.
#|     Indices are local to each group, not a shared simulation timeline.
#|     Stored timestamps are not corrected for rounding; reconstruct precise
#|     output times separately from output indices and the configured timing.
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
#' dataset and optionally its input and initial-state groups, returning a
#' long-format tibble with spatial (x, y) and temporal (timestamp) coordinates.
#'
#' @param path Path to a Virtual Ecosystem Zarr output dataset.
#' @param variables Optional character vector of state variable names to
#'   extract. If `NULL` (default), all available data variables are extracted.
#' @param initial Logical. If `TRUE`, values from the `"inputs"` and `"init"`
#'   groups are included. Timeless arrays use `time_index = -1` and a missing
#'   `timestamp`; time-varying arrays retain their source time coordinate,
#'   converted to the output timestamp units. Equal indices in different groups
#'   need not denote the same date.
#'
#' @returns A long-format tibble with columns `variable`, `value`, `cell_id`,
#'   `x`, `y`, `time_index`, and `timestamp`. Additional array dimensions,
#'   such as `layers`, `element`, and `pft`, are retained when present.
#'
#' @details
#'   This function preserves stored time coordinates; it does not reconstruct
#'   simulation time or correct rounding in stored timestamps. For precise
#'   output times, use the output `time_index`, configured update interval,
#'   and appropriate start-time offset for the output recording convention.
#'   Do not apply that output-time mapping to time-varying input arrays.

tidy_continuous_data <- function(path, variables = NULL, initial = FALSE) {
  zarr <- pizzarr::zarr_open(path)

  group_variable_names <- function(group_name) {
    group <- zarr$get_item(group_name)
    arrays <- base::setdiff(
      group$get_store()$listdir(group_name),
      c(".zattrs", ".zgroup", "number", "spatial_ref")
    )
    attrs <- lapply(arrays, \(name) group$get_item(name)$get_attrs()$to_list())
    dimensions <- unique(unlist(
      lapply(attrs, \(x) {
        unlist(x$`_ARRAY_DIMENSIONS`, use.names = FALSE)
      }),
      use.names = FALSE
    ))
    referenced_coordinates <- unique(unlist(
      lapply(attrs, \(x) {
        coordinates <- if (is.null(x$coordinates)) "" else x$coordinates
        strsplit(coordinates, " ")[[1]]
      }),
      use.names = FALSE
    ))
    time_coordinates <- vapply(
      attrs,
      \(x) {
        units <- x$units
        length(units) == 1L &&
          !is.na(units) &&
          grepl("\\bsince\\b", units, ignore.case = TRUE)
      },
      logical(1)
    )

    coordinates <- union(
      dimensions,
      union(
        referenced_coordinates,
        union(arrays[time_coordinates], c("x", "y", "expver"))
      )
    )
    base::setdiff(arrays, coordinates)
  }

  output_names <- group_variable_names("outputs")
  initial_groups <- if (initial) c("inputs", "init") else character()
  initial_names <- setNames(
    lapply(initial_groups, group_variable_names),
    initial_groups
  )

  if (is.null(variables)) {
    output_variables <- output_names
    initial_variables <- initial_names
  } else {
    available <- union(output_names, unlist(initial_names, use.names = FALSE))
    missing_vars <- base::setdiff(variables, available)
    if (length(missing_vars) > 0) {
      cli::cli_abort(
        "The following variables are not found: {.val {missing_vars}}"
      )
    }
    output_variables <- intersect(variables, output_names)
    initial_variables <- lapply(initial_names, \(names) {
      intersect(variables, names)
    })
  }

  outputs <- get_data_variables(path, group = "outputs", output_variables)
  xy <- get_data_variables(path, group = "outputs", c("x", "y")) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1)
  timestamp <- get_data_variables(path, group = "outputs", "timestamp") |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1)

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

  tidy_initial_group <- function(group_name, variables_to_read) {
    if (length(variables_to_read) == 0L) {
      return(NULL)
    }

    initial <- get_data_variables(path, group = group_name, variables_to_read)
    time_varying <- names(initial)[vapply(
      initial,
      \(x) "time_index" %in% names(dimnames(x)),
      logical(1)
    )]

    if (length(time_varying) > 0L) {
      group <- zarr$get_item(group_name)
      arrays <- base::setdiff(
        group$get_store()$listdir(group_name),
        c(".zattrs", ".zgroup")
      )
      is_time_coordinate <- vapply(
        arrays,
        \(name) {
          attrs <- group$get_item(name)$get_attrs()$to_list()
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
      time_coordinates <- arrays[is_time_coordinate]

      if (length(time_coordinates) != 1L) {
        stop(
          "Could not identify one time coordinate for time-varying ",
          group_name,
          " arrays.",
          call. = FALSE
        )
      }

      source_time <- group$get_item(time_coordinates)
      source_attrs <- source_time$get_attrs()$to_list()
      output_attrs <- zarr$get_item("outputs")$get_item(
        "timestamp"
      )$get_attrs()$to_list()
      source_calendar <- source_attrs$calendar
      output_calendar <- output_attrs$calendar
      if (
        length(source_calendar) != 1L ||
          length(output_calendar) != 1L ||
          is.na(source_calendar) ||
          is.na(output_calendar) ||
          source_calendar != "proleptic_gregorian" ||
          output_calendar != source_calendar
      ) {
        stop(
          "Only matching proleptic_gregorian time calendars are supported.",
          call. = FALSE
        )
      }

      source_units <- parse_time_units(source_attrs$units)
      output_units <- parse_time_units(output_attrs$units)
      source_index <- as.numeric(group$get_item("time_index")$as.array())
      source_values <- as.numeric(source_time$as.array())
      if (
        length(source_index) != length(source_values) ||
          any(!is.finite(source_index)) ||
          anyDuplicated(source_index) > 0 ||
          any(!is.finite(source_values))
      ) {
        stop("Invalid time coordinate mapping.", call. = FALSE)
      }

      source_timestamps <- tibble::tibble(
        time_index = source_index,
        timestamp = (source_values *
          source_units[["unit_seconds"]] +
          source_units[["origin"]] -
          output_units[["origin"]]) /
          output_units[["unit_seconds"]]
      )
    }

    tidy_initial <- initial |>
      reshape2::melt()
    if (!"time_index" %in% names(tidy_initial)) {
      tidy_initial$time_index <- NA_real_
    }
    tidy_initial <- tidy_initial |>
      dplyr::mutate(time_index = as.numeric(time_index))

    if (length(time_varying) > 0L) {
      tidy_initial <- tidy_initial |>
        dplyr::left_join(source_timestamps, by = "time_index")
      if (anyNA(tidy_initial$timestamp[tidy_initial$L1 %in% time_varying])) {
        stop(
          "Could not map every time index in ",
          group_name,
          " arrays to its time coordinate.",
          call. = FALSE
        )
      }
    } else {
      tidy_initial$timestamp <- NA_real_
    }

    tidy_initial <- tidy_initial |>
      dplyr::mutate(
        time_index = dplyr::if_else(L1 %in% time_varying, time_index, -1),
        timestamp = dplyr::if_else(L1 %in% time_varying, timestamp, NA_real_)
      )
    if (!"cell_id" %in% names(tidy_initial)) {
      tidy_initial$cell_id <- NA_integer_
    }
    tidy_initial |>
      dplyr::left_join(xy, by = dplyr::join_by(cell_id))
  }

  tidy_initial <- Map(tidy_initial_group, initial_groups, initial_variables) |>
    Filter(f = Negate(is.null))
  if (length(tidy_initial) > 0L) {
    tidy_cont <- dplyr::bind_rows(c(tidy_initial, list(tidy_cont)))
  }

  tidy_cont |> dplyr::rename(variable = L1) |> dplyr::as_tibble()
}
