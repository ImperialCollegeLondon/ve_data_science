#| ---
#| title: Database assembly, harmonization, coordinates, and temporal handling
#|
#| description: |
#|     Functions for building and harmonizing the validation database,
#|     including database assembly, harmonization of source data,
#|     coordinate handling, and temporal metadata attachment.
#|     This file contains helper functions for [build_validation_database()].
#|
#| virtual_ecosystem_module: [Soil, Litter]
#|
#| author:
#|   - Hao Ran Lai
#|   - Nicholas Wei Cheng Tan
#|
#| status: final
#|
#| package_dependencies:
#|   - arrow
#|   - cli
#|   - dplyr
#|   - lubridate
#|   - purrr
#|   - readr
#|   - rlang
#|   - sf
#|   - stats
#|   - stringr
#|   - tibble
#|   - tidyr
#|   - toml
#|   - units
#|   - utils
#|   - yaml
#| ---

#' (Re)Build the validation database
#'
#' Build or rebuild the validation database based on the YAML configs of source
#' datasets.
#'
#' @param variables_derived Path to local derived-variable metadata.
#' @param sources_dir Directory containing one YAML record per screened dataset.
#' @param db_path Output path for the harmonised database.
#'
#' @returns A harmonised database stored in db_path. Currently it is written out
#'   in the parquet format for efficient compression (and possibly appending).
#'   We may consider a plain csv in the future.
#'
#' @export
#' @examples
#' box::use(tools/R/R/valdb)
#' module_name <- "soil"
#' validation_root <- here::here(
#'   "data", "derived", module_name, "validation"
#' )
#' variables_derived <- here::here(
#'   "data", "derived", "validation", "derived_variables.toml"
#' )
#' valdb$build_validation_database(
#'   variables_derived = variables_derived,
#'   sources_dir = file.path(validation_root, "sources"),
#'   db_path = file.path(validation_root, "database")
#' )

build_validation_database <- function(
  variables_derived = file.path(
    "data",
    "derived",
    "validation",
    "derived_variables.toml"
  ),
  sources_dir,
  db_path
) {
  # Ingest datasets --------------------------------------------------------

  sources <- list_build_sources(sources_dir)
  validate_build_sources(sources, sources_dir)

  # Configs ----------------------------------------------------------------

  # Load canonical units only after local source preflight succeeds.
  canonical_units <- build_canonical_units_table(
    variables_derived = variables_derived
  )

  # Harmonise each dataset ------------------------------------------------
  data_harmonised <-
    sources |>
    purrr::map(\(src) harmonise_source_data(src, canonical_units)) |>
    purrr::compact()

  if (length(data_harmonised) == 0L) {
    cli::cli_abort(
      "No source datasets contain configured measurement columns."
    )
  }

  # combine datasets into a database
  database <-
    data_harmonised |>
    purrr::list_rbind() |>
    # cleanup
    dplyr::select(
      dataset,
      ID,
      latitude,
      longitude,
      location_type,
      coordinate_source,
      time_start,
      time_end,
      time_type,
      time_precision,
      time_source,
      time_note,
      var_original,
      value_original = value,
      unit_original,
      var_canonical,
      unit_canonical,
      value_canonical
    )

  # Write database ---------------------------------------------------------
  database |>
    dplyr::group_by(dataset) |>
    arrow::write_dataset(db_path, format = "parquet")

  # print message on write
  cli::cli_alert_success("Database saved to {db_path}.")
}


#' Harmonise one validation source dataset
#'
#' Internal helper for [build_validation_database()]. It reads and prepares one
#' configured source, applies optional row-level filtering, attaches spatial and
#' temporal metadata, reshapes measurements, and converts known variables to
#' canonical units. Unknown canonical mappings retain their original values and
#' units and receive missing canonical values and units.
#'
#' @param src A validated source schema returned by [list_build_sources()].
#' @param canonical_units A data frame with `var_canonical` and
#'   `unit_canonical` columns.
#'
#' @returns A long-format data frame of harmonised observations, or `NULL` when
#'   the source has no available configured measurement columns. Row filtering,
#'   if configured, is applied before coordinate and temporal attachment.

harmonise_source_data <- function(src, canonical_units) {
  data <- readr::read_csv(
    src$data_file,
    show_col_types = FALSE,
    skip = src$skip_rows
  ) |>
    # Apply dataset-level row filters before column selection so all columns
    # are available for filter clauses
    apply_row_filter(src) |>
    prepare_source_data(src)
  if (is.null(data)) {
    return(NULL)
  }
  measurement_columns <- attr(data, "measurement_columns")

  data <-
    data |>
    # Attach metadata before `unite()` consumes the deduplication columns.
    add_coordinates(src) |>
    add_temporal(src) |>
    add_observation_id(src) |>
    # Pivot long for unit conversion and missing-value removal.
    tidyr::pivot_longer(
      cols = tidyr::all_of(measurement_columns),
      names_to = "var_original"
    ) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::left_join(
      src$variables[measurement_columns] |>
        tibble::enframe(name = "var_original") |>
        tidyr::unnest_wider(value) |>
        dplyr::rename(unit_original = unit),
      by = dplyr::join_by(var_original)
    ) |>
    dplyr::left_join(canonical_units, by = dplyr::join_by(var_canonical))

  unknown <-
    data |>
    dplyr::filter(is.na(unit_canonical)) |>
    dplyr::distinct(var_original, var_canonical)
  if (nrow(unknown) > 0L) {
    mappings <- paste0(
      unknown$var_original,
      " -> ",
      unknown$var_canonical,
      collapse = ", "
    )
    cli::cli_warn(c(
      "Unknown canonical variable mapping{?s} in source {.val {src$source_id}}.",
      "i" = "Retaining original values and units for: {mappings}."
    ))
  }

  data |>
    dplyr::mutate(
      value_original = as.numeric(value),
      value_canonical = purrr::pmap_dbl(
        list(value, unit_original, unit_canonical, var_original, var_canonical),
        \(value, unit_original, unit_canonical, var_original, var_canonical) {
          convert_canonical_value(
            value,
            unit_original,
            unit_canonical,
            src$source_id,
            var_original,
            var_canonical
          )
        }
      ),
      unit_canonical = unit_canonical,
      dataset = src$source_id
    ) |>
    dplyr::select(-value) |>
    dplyr::rename(value = value_original)
}


#' Convert one observation to its canonical unit
#'
#' Internal helper for [harmonise_source_data()]. Unit parsing and conversion
#' errors include source and variable context. An unknown canonical mapping,
#' represented by a missing canonical unit, returns a typed missing value
#' without parsing the original unit.
#'
#' @param value A numeric observation value.
#' @param unit_original The unit declared for the source variable.
#' @param unit_canonical The target canonical unit, or `NA_character_` for an
#'   unknown canonical mapping.
#' @param source_id The source dataset identifier used in error messages.
#' @param var_original The source variable name used in error messages.
#' @param var_canonical The configured canonical variable name used in error
#'   messages.
#'
#' @returns A numeric scalar in the canonical unit, or `NA_real_` for an unknown
#'   canonical mapping.

convert_canonical_value <- function(
  value,
  unit_original,
  unit_canonical,
  source_id,
  var_original,
  var_canonical
) {
  if (is.na(unit_canonical)) {
    return(NA_real_)
  }

  tryCatch(
    {
      original <- value * units::as_units(unit_original)
      converted <- units::set_units(
        original,
        units::as_units(unit_canonical),
        mode = "standard"
      )
      as.numeric(converted)
    },
    error = function(error) {
      cli::cli_abort(
        c(
          "Cannot convert units for source {.val {source_id}}.",
          "x" = paste0(
            "Variable ",
            var_original,
            " mapped to ",
            var_canonical,
            " cannot be converted from ",
            unit_original,
            " to ",
            unit_canonical,
            "."
          ),
          "i" = conditionMessage(error)
        ),
        parent = error
      )
    }
  )
}


#' Attach spatial coordinates to a source dataset
#'
#' This is an unexported helper for [build_validation_database()]. It adds four
#' columns to a dataset: \code{latitude}, \code{longitude},
#' \code{location_type} and \code{coordinate_source}.
#'
#' Coordinates can be obtained in three ways, checked in this order:
#' \enumerate{
#'   \item A single coordinate for the entire dataset, specified via
#'     \code{coordinates: same_for_all_rows} in the source YAML.
#'   \item Coordinates as columns in the data file itself, specified via
#'     \code{coordinates: latitude_column} and
#'     \code{coordinates: longitude_column} in the source YAML.
#'   \item Coordinates from an external locations file (SAFE convention or
#'     custom path), specified via \code{coordinates: from_file} in the
#'     source YAML.
#' }
#'
#' Most SAFE Zenodo datasets use approach (3) by default: a \code{Locations}
#' sheet holding \code{Location name}, \code{Latitude} and \code{Longitude}
#' in decimal degrees (WGS84). Following the manual-conversion convention for
#' the data sheet, export that sheet to \code{locations.csv} in the same
#' folder as \code{data_file} and this function will find it automatically.
#'
#' Datasets that deviate are handled by the optional \code{coordinates} block
#' in the source YAML; see [add_schema()] for the annotated template.
#'
#' @param dat A dataset that is one row per observation, still carrying its raw
#'   \code{dedup_key} columns.
#' @param src One source entry from the source YAML metadata.
#'
#' @returns \code{dat} with the four coordinate columns added. The row count is
#'   guaranteed to be unchanged.

add_coordinates <- function(dat, src) {
  spec <- drop_blanks(src$coordinates)
  n_before <- nrow(dat)

  # Case 1: one blanket coordinate for the whole dataset
  blanket <- drop_blanks(spec$same_for_all_rows)
  if (
    length(blanket) > 0 &&
      !is.null(blanket$latitude) &&
      !is.null(blanket$longitude)
  ) {
    return(dplyr::mutate(
      dat,
      latitude = as.numeric(blanket$latitude),
      longitude = as.numeric(blanket$longitude),
      location_type = "whole dataset",
      coordinate_source = "same_for_all_rows"
    ))
  }
  if (length(blanket) > 0) {
    cli::cli_abort(
      "{.field same_for_all_rows} in {.val {src$source_id}} needs both
       a {.field latitude} and a {.field longitude}."
    )
  }

  # Case 1b: coordinates are columns in the data itself
  # Only apply this when from_file is NOT specified (coordinates are in data, not external).
  # This ensures that external locations files take precedence over similarly named
  # data columns, maintaining the documented coordinate precedence order.
  data_lat_col <- spec$latitude_column
  data_lon_col <- spec$longitude_column

  if (
    !is.null(data_lat_col) && !is.null(data_lon_col) && is.null(spec$from_file)
  ) {
    dat <-
      dat |>
      dplyr::mutate(
        latitude = as.numeric(.data[[data_lat_col]]),
        longitude = as.numeric(.data[[data_lon_col]]),
        location_type = NA_character_,
        coordinate_source = dplyr::if_else(
          is.na(latitude) | is.na(longitude),
          "missing",
          "data_columns"
        )
      )

    validate_coordinates(dat, src$source_id)

    # Check row count hasn't changed
    if (nrow(dat) != n_before) {
      cli::cli_abort(
        "Extracting coordinates changed the number of rows of
         {.val {src$source_id}} from {n_before} to {nrow(dat)}."
      )
    }

    return(dat)
  }

  # Case 2: look the coordinates up from a locations file
  locations_file <- spec$from_file %||%
    file.path(dirname(src$data_file), "locations.csv")

  # the column in `dat` naming the location: default to the dedup key, but
  # only when that key is unambiguous
  key_data <- spec$match_data_column
  if (is.null(key_data)) {
    if (length(src$dedup_key) > 1) {
      if (file.exists(locations_file)) {
        cli::cli_abort(
          "{.val {src$source_id}} has a multi-column {.field dedup_key},
           so the location column is ambiguous. Name it explicitly with
           {.field coordinates: match_data_column} in the source YAML."
        )
      }
      key_data <- NULL
    } else {
      key_data <- src$dedup_key
    }
  }

  if (!file.exists(locations_file)) {
    cli::cli_warn(
      "No coordinates for {.val {src$source_id}}: cannot find
       {.file {locations_file}}. Export the {.field Locations} sheet of the
       source file to that path, or add a {.field coordinates} block to the
       source YAML. Currently NA coordinates are assigned for
       {.val {src$source_id}}"
    )
    dat <- dplyr::mutate(
      dat,
      latitude = NA_real_,
      longitude = NA_real_,
      location_type = NA_character_,
      coordinate_source = "missing"
    )
  } else {
    # gather the location coordinates
    locations <-
      readr::read_csv(locations_file, show_col_types = FALSE) |>
      dplyr::select(
        location_key = tidyr::all_of(
          spec$match_location_column %||% "Location name"
        ),
        latitude = tidyr::all_of(spec$latitude_column %||% "Latitude"),
        longitude = tidyr::all_of(spec$longitude_column %||% "Longitude"),
        # `Type` records how the location was defined, e.g. "POINT" or
        # "Carbon Plot". It is absent in non-SAFE locations files.
        location_type = tidyr::any_of("Type")
      ) |>
      dplyr::mutate(dplyr::across(c(latitude, longitude), as.numeric))

    if (!"location_type" %in% names(locations)) {
      locations$location_type <- NA_character_
    }

    # join locations to the data
    # For multi-column keys (e.g., [site, chamber_id]), create a temporary unified key
    # for the join to avoid the error "names attribute must be the same length as vector".
    # This handles datasets like drewer_2019_1b where locations are matched on multiple columns.
    if (length(key_data) > 1) {
      dat <- dat |>
        tidyr::unite(
          "_temp_location_key",
          tidyr::all_of(key_data),
          remove = FALSE,
          sep = "_"
        )
      locations <- locations |>
        dplyr::rename("_temp_location_key" = "location_key")
      join_by_spec <- dplyr::join_by("_temp_location_key")
    } else {
      join_by_spec <- stats::setNames("location_key", key_data)
    }

    dat <-
      dat |>
      dplyr::left_join(
        locations,
        by = join_by_spec,
        # errors if the locations file has duplicated keys, which would
        # silently inflate the number of observations
        # NB: many-to-one should also cover one-to-one
        relationship = "many-to-one"
      )

    # Remove temporary key column if it was created
    if (length(key_data) > 1) {
      dat <- dplyr::select(dat, -"_temp_location_key")
    }

    # cover the case of partial missingness in a location file
    dat <- dat |>
      dplyr::mutate(
        coordinate_source = dplyr::if_else(
          is.na(latitude) | is.na(longitude),
          "missing",
          "locations_file"
        )
      )
  }

  # Second pass: fill remaining missing coordinates from gazetteer centroids.
  # Apply the same multi-column key handling to the gazetteer lookup as was applied
  # to the locations file join. This ensures consistent coordinate resolution across
  # both sources for datasets with composite location identifiers.
  if (!is.null(key_data)) {
    gazetteer_data <- sf::st_read(
      here::here("data/primary/site/gazetteer.geojson"),
      quiet = TRUE
    ) |>
      sf::st_drop_geometry() |>
      dplyr::select(location, centroid_x, centroid_y)

    if (length(key_data) > 1) {
      dat <- dat |>
        tidyr::unite(
          "_temp_gaz_key",
          tidyr::all_of(key_data),
          remove = FALSE,
          sep = "_"
        )
      gazetteer_data <- gazetteer_data |>
        dplyr::rename("_temp_gaz_key" = "location")
      gaz_join_spec <- dplyr::join_by("_temp_gaz_key")
    } else {
      gaz_join_spec <- stats::setNames("location", key_data)
    }

    dat <-
      dat |>
      dplyr::left_join(
        gazetteer_data,
        by = gaz_join_spec,
        relationship = "many-to-one"
      )

    # Remove temporary key column if it was created
    if (length(key_data) > 1) {
      dat <- dplyr::select(dat, -"_temp_gaz_key")
    }

    dat <- dat |>
      dplyr::mutate(
        longitude_missing_before = is.na(longitude),
        latitude_missing_before = is.na(latitude),
        longitude = dplyr::if_else(is.na(longitude), centroid_x, longitude),
        latitude = dplyr::if_else(is.na(latitude), centroid_y, latitude),
        gazetteer_filled = (longitude_missing_before & !is.na(centroid_x)) |
          (latitude_missing_before & !is.na(centroid_y)),
        coordinate_source = dplyr::if_else(
          gazetteer_filled,
          "gazetteer_second_pass",
          coordinate_source
        )
      ) |>
      dplyr::select(
        -centroid_x,
        -centroid_y,
        -longitude_missing_before,
        -latitude_missing_before,
        -gazetteer_filled
      )
  }

  # check the join in case the dplyr::left_join `relationship` argument is
  # ever relaxed
  if (nrow(dat) != n_before) {
    cli::cli_abort(
      "Joining coordinates changed the number of rows of
       {.val {src$source_id}} from {n_before} to {nrow(dat)}."
    )
  }

  validate_coordinates(dat, src$source_id)

  dat
}


#' Sanity-check the coordinates of one source dataset
#'
#' An unexported helper for [add_coordinates()]. Out-of-range coordinates are
#' an error, because they usually mean the columns were swapped or are in a
#' projected coordinate system rather than decimal degrees. Missing
#' coordinates are only a warning, because some curated locations genuinely
#' have none.
#'
#' @param dat A dataset with \code{latitude} and \code{longitude} columns.
#' @param source_id The source ID, used in messages.
#'
#' @returns \code{dat}, invisibly.

validate_coordinates <- function(dat, source_id) {
  out_of_range <- dat |>
    dplyr::filter(
      !dplyr::between(latitude, -90, 90) |
        !dplyr::between(longitude, -180, 180)
    )

  if (nrow(out_of_range) > 0) {
    cli::cli_abort(
      c(
        "{nrow(out_of_range)} row{?s} of {.val {source_id}} have coordinates
         outside the valid range.",
        "i" = "Coordinates must be decimal degrees (WGS84). Are the latitude
               and longitude columns swapped, or projected?"
      )
    )
  }

  n_gazetteer_second_pass <- sum(
    dat$coordinate_source == "gazetteer_second_pass"
  )
  if (n_gazetteer_second_pass > 0) {
    cli::cli_inform(
      "{n_gazetteer_second_pass} coordinate row{?s} were filled by gazetteer
       second pass for {.val {source_id}}."
    )
  }

  n_missing <- sum(dat$coordinate_source == "missing")
  if (n_missing > 0) {
    cli::cli_warn(
      "{n_missing} of {nrow(dat)} row{?s} of {.val {source_id}} have no
       coordinates."
    )
  }

  invisible(dat)
}


#' Attach temporal coordinates to a source dataset
#'
#' This is an unexported helper for [build_validation_database()]. It adds six
#' columns to a dataset: \code{time_start}, \code{time_end}, \code{time_type},
#' \code{time_precision}, \code{time_source} and \code{time_note}.
#'
#' Times are stored as a HALF-OPEN interval \code{[time_start, time_end)} in
#' UTC, so that consecutive periods tile without overlapping; defaults to
#' Asia/Kuching since we start building with SAFE datasets. A point-in-time
#' observation is widened to its precision granule: a date-only sample becomes
#' a one-day interval rather than a zero-width one, because a zero-width
#' half-open interval would match nothing under any filter.
#'
#' Note that \code{lubridate::\%within\%} is closed at BOTH ends, so it
#' disagrees with the stored convention by one granule at \code{time_end}.
#' Filter with \code{time_start <= t & t < time_end} instead.
#'
#' Unlike the spatial case there is no curation standard to fall back on: SAFE
#' datasets are usually plot-level summaries carrying no per-row date, so the
#' sampling period normally has to be read off the summary metadata and entered
#' as \code{same_for_all_rows}. A source with no \code{temporal} block at all
#' gets \code{NA} times and a \code{time_source} of \code{"missing"}.
#'
#' @param dat A dataset that is one row per observation, still carrying its raw
#'   \code{dedup_key} columns.
#' @param src One source entry from the source YAML metadata.
#'
#' @returns \code{dat} with the six temporal columns added. The row count is
#'   ensured to be the same.

add_temporal <- function(dat, src) {
  spec <- drop_blanks(src$temporal)
  n_before <- nrow(dat)

  # UTC throughout, so that the build is reproducible regardless of the
  # machine's locale. The source zone is only used to interpret the input.
  tz_in <- spec$timezone %||% "Asia/Kuching"
  precision <- spec$precision %||% "day"

  # Case 0: nothing configured at all. Note that `drop_blanks()` only strips
  # blank scalars, so an unedited template still leaves an all-NA
  # `same_for_all_rows` list behind; emptiness has to be judged after that
  # nested block has itself been cleaned.
  blanket <- drop_blanks(spec$same_for_all_rows)
  temporal_top_settings <- purrr::discard_at(spec, "same_for_all_rows")
  if (length(temporal_top_settings) == 0 && length(blanket) == 0) {
    cli::cli_warn(
      "No sampling time for {.val {src$source_id}}: add a {.field temporal}
       block to the source YAML. If the dataset carry no per-row date, then
       {.field same_for_all_rows} with the sampling period is usually what you
       want. Currently {.val NA} times are assigned for {.val {src$source_id}}."
    )
    return(empty_temporal(dat))
  }

  # Case 1: one blanket sampling window for the whole dataset
  if (length(blanket) > 0) {
    if (is.null(blanket$start)) {
      cli::cli_abort(
        "{.field same_for_all_rows} in {.val {src$source_id}} needs at least a
         {.field start} value. You are getting this because you specified
         something in {.field same_for_all_rows} but left {.field start} blank."
      )
    }
    precision <- blanket$precision %||% precision
    start <- parse_time(blanket$start, spec$format, tz_in, src$source_id)
    # an "open" end marks an ongoing or unbounded campaign
    if (is.null(blanket$end) || identical(blanket$end, "open")) {
      end <- lubridate::NA_POSIXct_
    } else {
      # the YAML end is written as the last INCLUSIVE granule, so widen it to
      # get the exclusive bound we store
      end <- widen_time(
        parse_time(blanket$end, spec$format, tz_in, src$source_id),
        precision,
        tz_in
      )
    }
    dat <- dplyr::mutate(
      dat,
      time_start = start,
      time_end = end,
      time_type = "whole dataset",
      time_precision = precision,
      time_source = "same_for_all_rows",
      time_note = blanket$note %||% NA_character_
    )
    validate_temporal(dat, src$source_id)
    return(dat)
  }

  # Case 2: per-row times read from the data itself
  if (!is.null(spec$date_column)) {
    if (!is.null(spec$start_column) || !is.null(spec$end_column)) {
      cli::cli_abort(
        "{.val {src$source_id}} sets both {.field date_column} and
         {.field start_column}/{.field end_column} in its {.field temporal}
         block. Use one or the other: {.field date_column} for point-in-time
         observations, the pair for windows."
      )
    }
    check_time_columns(dat, spec$date_column, src$source_id)
    dat <- dplyr::mutate(
      dat,
      time_start = parse_time(
        .data[[spec$date_column]],
        spec$format,
        tz_in,
        src$source_id
      ),
      # widen the instant to its precision granule
      time_end = widen_time(time_start, precision, tz_in),
      time_type = "instant"
    )
  } else if (!is.null(spec$start_column) && !is.null(spec$end_column)) {
    check_time_columns(
      dat,
      c(spec$start_column, spec$end_column),
      src$source_id
    )
    dat <- dplyr::mutate(
      dat,
      time_start = parse_time(
        .data[[spec$start_column]],
        spec$format,
        tz_in,
        src$source_id
      ),
      # the source end is the last inclusive granule; store the exclusive bound
      time_end = widen_time(
        parse_time(
          .data[[spec$end_column]],
          spec$format,
          tz_in,
          src$source_id
        ),
        precision,
        tz_in
      ),
      time_type = "interval"
    )
  } else {
    cli::cli_abort(
      "The {.field temporal} block of {.val {src$source_id}} supplies neither
       {.field date_column}, nor both of {.field start_column} and
       {.field end_column}, nor {.field same_for_all_rows}. Give one of these,
       or delete the block entirely."
    )
  }

  dat <-
    dat |>
    dplyr::mutate(
      time_precision = precision,
      # cover partial missingness within an otherwise valid date column
      time_source = dplyr::if_else(
        is.na(time_start),
        "missing",
        "data_column"
      ),
      time_note = NA_character_
    )

  if (nrow(dat) != n_before) {
    cli::cli_abort(
      "Attaching times changed the number of rows of {.val {src$source_id}}
       from {n_before} to {nrow(dat)}."
    )
  }

  validate_temporal(dat, src$source_id)

  dat
}


#' Sanity-check the temporal coordinates of one source dataset
#'
#' An unexported helper for [add_temporal()]. Following the spatial
#' convention, structurally impossible times are an error, because they
#' usually mean the columns were swapped or the date format was misread.
#' Missing times are only a warning, because many sources genuinely never
#' record when they sampled.
#'
#' @param dat A dataset with the six temporal columns.
#' @param source_id The source ID, used in messages.
#'
#' @returns \code{dat}, invisibly.

validate_temporal <- function(dat, source_id) {
  # an end before its start is the temporal analogue of swapped lat/lon
  reversed <- dat |>
    dplyr::filter(!is.na(time_start), !is.na(time_end), time_end < time_start)

  if (nrow(reversed) > 0) {
    cli::cli_abort(
      c(
        "{nrow(reversed)} row{?s} of {.val {source_id}} end before they
         start.",
        "i" = "Are the start and end columns swapped, or is the date
               {.field format} being misread?"
      )
    )
  }

  # an implausible year almost always means a misparsed format, or an Excel
  # serial number that survived the manual CSV conversion
  out_of_range <- dat |>
    dplyr::filter(dplyr::if_any(
      c(time_start, time_end),
      \(x) !is.na(x) & !dplyr::between(lubridate::year(x), 1900, 2100)
    ))

  if (nrow(out_of_range) > 0) {
    cli::cli_abort(
      c(
        "{nrow(out_of_range)} row{?s} of {.val {source_id}} fall outside
         1900-2100.",
        "i" = "Is the {.field format} entry wrong, or did an Excel serial
               date number survive the manual CSV conversion?"
      )
    )
  }

  n_missing <- sum(dat$time_source == "missing")
  if (n_missing > 0) {
    cli::cli_warn(
      "{n_missing} of {nrow(dat)} row{?s} of {.val {source_id}} have no
       sampling time."
    )
  }

  invisible(dat)
}


#' Assign wholly missing temporal columns
#'
#' An unexported helper for [add_temporal()], used when a source configures no
#' times at all. Kept separate so that the six columns always appear with the
#' same names and types, which matters because the sources are row-bound into
#' one database.
#'
#' @param dat A dataset.
#'
#' @returns \code{dat} with the six temporal columns added, all missing.

empty_temporal <- function(dat) {
  dplyr::mutate(
    dat,
    time_start = lubridate::NA_POSIXct_,
    time_end = lubridate::NA_POSIXct_,
    time_type = NA_character_,
    time_precision = NA_character_,
    time_source = "missing",
    time_note = NA_character_
  )
}


#' Parse a source date or datetime into UTC
#'
#' An unexported helper for [add_temporal()]. Everything is stored in UTC so
#' that the build does not depend on the machine's locale; \code{tz_in} says
#' how to interpret the source strings, which for SAFE field data is usually
#' \code{"Asia/Kuching"} rather than UTC.
#'
#' @param x A character, Date or POSIXct vector from the source.
#' @param format A strptime-style format, or \code{NULL} to guess.
#' @param tz_in IANA time zone the source values are expressed in.
#' @param source_id The source ID, used in messages.
#'
#' @returns A POSIXct vector in UTC.

parse_time <- function(x, format = NULL, tz_in = "UTC", source_id = NULL) {
  # a bare number is almost certainly an Excel serial date, which would parse
  # into a nonsense year and be caught much later
  if (is.numeric(x)) {
    cli::cli_abort(
      c(
        "The date column of {.val {source_id}} is numeric.",
        "i" = "This usually indicates Excel serial numbers were exported instead
               of dates. Reformat the column as a date before converting the
               sheet to CSV."
      )
    )
  }

  if (inherits(x, "POSIXct")) {
    return(lubridate::with_tz(x, "UTC"))
  }

  # a bare Date carries no zone, so anchor it at midnight in the source zone
  if (inherits(x, "Date")) {
    return(lubridate::with_tz(
      lubridate::force_tz(
        as.POSIXct(format(x), tz = "UTC"),
        tz_in
      ),
      "UTC"
    ))
  }

  x <- as.character(x)
  parsed <- if (is.null(format)) {
    # Only unambiguous ISO-like strings are safe to guess at. Without this
    # guard `ymd_hms(truncated = 3)` happily reads "14/03/2015" as the year
    # 2014, which is silent corruption rather than an error.
    non_iso <- x[!is.na(x) & x != "" & !grepl("^\\d{4}[-/]\\d{2}", x)]
    if (length(non_iso) > 0) {
      n_non_iso <- length(non_iso)
      example <- non_iso[[1]]
      cli::cli_abort(
        c(
          "{.val {source_id}} has {n_non_iso} date{?s} that {?is/are} not in
           ISO order, e.g. {.val {example}}.",
          "i" = "Set an explicit {.field format} in the {.field temporal}
                 block, e.g. {.val %d/%m/%Y}. Guessing is refused here because
                 {.val 03/04/2015} is ambiguous between March and April."
        )
      )
    }
    lubridate::ymd_hms(x, tz = tz_in, quiet = TRUE, truncated = 3)
  } else {
    as.POSIXct(x, format = format, tz = tz_in)
  }

  n_failed <- sum(is.na(parsed) & !is.na(x) & x != "")
  if (n_failed > 0) {
    cli::cli_abort(
      c(
        "{n_failed} date{?s} of {.val {source_id}} could not be parsed.",
        "i" = "Set an explicit {.field format} in the {.field temporal} block,
               e.g. {.val %d/%m/%Y}. Note that {.val 03/04/2015} is ambiguous
               and cannot be guessed reliably."
      )
    )
  }

  lubridate::with_tz(parsed, "UTC")
}


#' Widen a time instant to the exclusive end of its precision granule
#'
#' An unexported helper for [add_temporal()]. Because intervals are stored
#' half-open, an instant stored as a zero-width interval would match nothing.
#' Widening a date-only value to the following midnight keeps
#' \code{time_start <= t & t < time_end} meaningful while
#' \code{time_precision} records that the underlying observation was a point.
#'
#' @param x A POSIXct vector.
#' @param precision One of \code{"second"}, \code{"day"}, \code{"month"} or
#'   \code{"year"}.
#' @param tz_in IANA time zone whose calendar defines the granule. This must
#'   be the zone the source dates were expressed in, not UTC: a Malaysian
#'   midnight is 16:00 UTC the previous day, so flooring in UTC would widen
#'   the value onto the wrong calendar day.
#'
#' @returns A POSIXct vector in UTC.

widen_time <- function(x, precision, tz_in = "UTC") {
  # `period` rather than `duration`, so that months and years stay calendrical
  if (!precision %in% c("second", "day", "month", "year")) {
    cli::cli_abort(
      "Unknown {.field precision} {.val {precision}}. Use one of
       {.val second}, {.val day}, {.val month} or {.val year}."
    )
  }
  step <- lubridate::period(1, units = precision)
  # do the calendar arithmetic in the source zone, then return to UTC storage
  local <- lubridate::with_tz(x, tz_in)
  # floor first, so that a mid-day timestamp with day precision still yields a
  # clean granule boundary
  lubridate::with_tz(
    lubridate::floor_date(local, unit = precision) + step,
    "UTC"
  )
}


#' Check that configured time columns exist in the data
#'
#' An unexported helper for [add_temporal()]. Named columns that are absent
#' are an error rather than a warning, because a typo in the YAML would
#' otherwise silently produce a dataset with no times at all.
#'
#' @param dat A dataset.
#' @param cols Column names named in the \code{temporal} block.
#' @param source_id The source ID, used in messages.
#'
#' @returns \code{dat}, invisibly.

check_time_columns <- function(dat, cols, source_id) {
  missing_cols <- setdiff(cols, names(dat))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      c(
        "The {.field temporal} block of {.val {source_id}} names
         {.field {missing_cols}}, which {?is/are} not in the dataset.",
        "i" = "Note that only the {.field dedup_key} and {.field variables}
               columns are read from {.field data_file}, so a date column must
               also be listed in {.field dedup_key} to pass."
      )
    )
  }
  invisible(dat)
}


#' Drop empty entries from a YAML config block
#'
#' An unexported helper. Template entries left as \code{NA} in the source YAML
#' are treated as "not supplied", so that curators can delete or ignore the
#' fields they do not need.
#'
#' @param x A list read from the source YAML, possibly \code{NULL}.
#'
#' @returns A list with \code{NULL}, \code{NA} and empty-string entries removed.

drop_blanks <- function(x) {
  if (is.null(x)) {
    return(list())
  }
  purrr::discard(x, \(entry) {
    is.null(entry) ||
      (length(entry) == 0) ||
      (length(entry) == 1 && is.atomic(entry) && (is.na(entry) || entry == ""))
  })
}


#' Build a table of canonical VE and derived variables
#'
#' Compile the metadata of canonical VE data variables, which are maintained on
#' the virtual_ecosystem repository, and optionally append a custom table of
#' derived or emergent variables not defined in VE. This function is expected
#' to be ran whenever there is an update to the VE data variables or the custom
#' derived variables. This helper function is unexported.
#'
#' @param variables_ve Path or URL to the virtual_ecosystem's data variable TOML
#'   table.
#' @param variables_derived Path to the custom derived variable TOML table, or
#'   `NULL` to omit derived variables.
#' @param downloader A function compatible with [utils::download.file()]. It is
#'   injectable so tests can supply canonical metadata without network access.
#'
#' @returns A named list of metadata for canonical VE and derived variables.

build_data_variables_table <- function(
  variables_ve = "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/main/virtual_ecosystem/data_variables.toml",
  variables_derived,
  downloader = utils::download.file
) {
  ve_path <- retrieve_variables_table(variables_ve, downloader)
  var_list <- import_variables_table(ve_path)
  if (!is.null(variables_derived)) {
    var_list <- c(var_list, import_variables_table(variables_derived))
  }
  return(var_list)
}


#' Retrieve a canonical-variable TOML table
#'
#' Internal helper for [build_data_variables_table()]. Remote HTTP or HTTPS
#' sources are downloaded to a temporary file so the exact retrieved payload is
#' parsed. Local paths are returned unchanged.
#'
#' @param source A local path or HTTP or HTTPS URL to a TOML table.
#' @param downloader A function compatible with [utils::download.file()].
#'
#' @returns A local path to the source TOML table.

retrieve_variables_table <- function(
  source,
  downloader = utils::download.file
) {
  if (!grepl("^https?://", source)) {
    return(source)
  }

  destination <- tempfile(fileext = ".toml")
  downloader(source, destination, mode = "wb", quiet = TRUE)
  destination
}


#' Build the canonical unit lookup table
#'
#' Internal helper for [build_validation_database()]. It combines VE and local
#' derived-variable metadata and removes element annotations such as `{C}` from
#' unit strings before conversion with the `units` package.
#'
#' @param variables_ve Path or URL to the virtual_ecosystem data-variable TOML
#'   table.
#' @param variables_derived Path to a local derived-variable TOML table, or
#'   `NULL` to omit derived variables.
#' @param downloader A function compatible with [utils::download.file()].
#'
#' @returns A data frame with `var_canonical` and `unit_canonical` columns.

build_canonical_units_table <- function(
  variables_ve = "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/main/virtual_ecosystem/data_variables.toml",
  variables_derived,
  downloader = utils::download.file
) {
  build_data_variables_table(
    variables_ve = variables_ve,
    variables_derived = variables_derived,
    downloader = downloader
  ) |>
    tibble::enframe(name = "var_canonical") |>
    tidyr::unnest_wider(value) |>
    dplyr::select(var_canonical, unit_canonical = unit) |>
    dplyr::mutate(
      unit_canonical = gsub("\\{[^}]+\\}", "", unit_canonical)
    )
}


#' Import data variable TOML table into a tidy list
#'
#' This is an unexported helper function for [build_data_variables_table()].
#'
#' @param toml Path or URL to the virtual_ecosystem's data variable TOML
#'   table.
#'
#' @returns A list of data variables.

import_variables_table <- function(toml) {
  vars <- toml::read_toml(toml) |>
    purrr::pluck("variable")
  vars <- purrr::set_names(vars, purrr::map_chr(vars, "name"))
  purrr::map(vars, ~ purrr::discard(.x, names(.x) == "name"))
}


#' Apply dataset-level row filters from schema
#'
#' Internal helper for [harmonise_source_data()]. Runs before column selection
#' so all source columns are available for filter clauses. Applies all
#' `row_filter` clauses in order with AND semantics. Each clause is parsed as
#' an R expression and evaluated with `rlang::eval_tidy()` against the data
#' frame. The result must be a logical vector the same length as the input data;
#' all TRUE values across all clauses are required to retain a row.
#'
#' If `row_filter` is NULL or absent, data is returned unchanged. Independently,
#' missing measurement values (NA) are always removed post-pivot in
#' [harmonise_source_data()].
#'
#' @param data A source data frame (full CSV, before column selection).
#' @param source The source schema containing optional `row_filter` field.
#'
#' @returns `data` with rows filtered by all clauses, or unchanged if
#'   `row_filter` is NULL. Row count may decrease.

apply_row_filter <- function(data, source) {
  if (is.null(source$row_filter)) {
    return(data)
  }

  for (clause in source$row_filter) {
    expr <- rlang::parse_expr(clause)
    # Evaluate the expression in the context of the data frame
    result <- tryCatch(
      rlang::eval_tidy(expr, data = data),
      error = function(e) {
        cli::cli_abort(
          c(
            "Row filter clause evaluation failed for source \
             {.val {source$source_id}}.",
            "x" = "Clause: {.val {clause}}",
            "i" = conditionMessage(e)
          ),
          parent = e
        )
      }
    )

    # Validate that result is logical and matches row count
    if (!is.logical(result)) {
      cli::cli_abort(
        "Row filter clause for source {.val {source$source_id}} must return \
         logical values. Got {.cls {class(result)}} instead.",
        i = "Clause: {.val {clause}}"
      )
    }
    if (length(result) != nrow(data)) {
      cli::cli_abort(
        "Row filter clause for source {.val {source$source_id}} returned \
         {length(result)} values, but data has {nrow(data)} rows.",
        i = "Clause: {.val {clause}}"
      )
    }

    # Apply the filter; FALSE rows are removed
    data <- dplyr::filter(data, result)
  }

  data
}
