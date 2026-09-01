#| ---
#| title: Functions to build a validation database
#|
#| description: |
#|     Here we use a config-driven pipeline to read, wrangle, unit-convert,
#|     and combine multiple datasets into a single master file, hereafter
#|     referred to as the "validation database". We are not aiming for a full
#|     database backend; instead, the main goal is to avoid writing many custom
#|     codes that each only work for one dataset. The idea is to run a single
#|     script to build the database while YAML config metadata handles all
#|     dataset-specific idiosyncracies.
#|     This script now also includes `join_ve_outputs()` and helper functions
#|     to append VE outputs to the validation database based on spatial and
#|     temporal matching.
#|     Please refer to `docs/validation_database.md` for full documentation.
#|
#| virtual_ecosystem_module: [Soil, Litter]
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
#|     - arrow
#|     - cli
#|     - dplyr
#|     - lubridate
#|     - purrr
#|     - rcrossref
#|     - readr
#|     - reshape2
#|     - rlang
#|     - sf
#|     - stats
#|     - stringr
#|     - tibble
#|     - tidyr
#|     - toml
#|     - utils
#|     - yaml
#|
#| usage_notes: |
#|   Please refer to `docs/validation_database.md` for a step-by-step tutorial.
#| ---

# Screening record contract -----------------------------------------------

screening_decisions <- c("proceed", "exclude", "defer")

screening_reasons <- list(
  proceed = "relevant_validation_data",
  exclude = c(
    "no_raw_data",
    "no_relevant_variables",
    "duplicate_source",
    "insufficient_metadata",
    "other"
  ),
  defer = c(
    "needs_second_opinion",
    "access_pending",
    "outside_module_scope",
    "other"
  )
)


#' Normalise a DOI to lower case
#'
#' @param doi A DOI, optionally prefixed by `doi:` or a DOI resolver URL.
#'
#' @returns A lower-case DOI without a prefix or resolver URL.
#'
#' @export

normalise_doi <- function(doi) {
  if (!is.character(doi) || length(doi) != 1L || is.na(doi)) {
    cli::cli_abort("{.arg doi} must be one non-missing string.")
  }

  normalised <- doi |>
    stringr::str_trim() |>
    stringr::str_remove(stringr::regex("^doi\\s*:\\s*", ignore_case = TRUE)) |>
    stringr::str_remove(
      stringr::regex(
        "^https?://(dx\\.)?doi\\.org/",
        ignore_case = TRUE
      )
    ) |>
    stringr::str_to_lower()

  if (!stringr::str_detect(normalised, "^10\\.[0-9]{4,9}/\\S+$")) {
    cli::cli_abort("{.arg doi} is not a valid DOI.")
  }

  normalised
}


#' Create a stable record identifier from a DOI
#'
#' @param doi A DOI accepted by [normalise_doi()].
#'
#' @returns A file-safe record identifier.
#'
#' @export

doi_to_record_id <- function(doi) {
  record_id <- doi |>
    normalise_doi() |>
    stringr::str_replace_all("[^a-z0-9]+", "-")

  stringr::str_c("doi-", record_id)
}


#' Normalise metadata returned by DOI content search
#'
#' The metadata should be a list rather than a `bibentry`, so that it can be
#' normalised into a stable structure for YAML and use from R or Python. This is
#' why DOI metadata are requested in the `citeproc-json-ish` format.
#'
#' @param metadata Metadata returned by `rcrossref::cr_cn()` using the
#'   `citeproc-json-ish` format.
#' @param retrieved_at Date and time when the metadata was retrieved. The
#'   current time is used by default; this argument mainly supports
#'   reproducible tests and imports.
#'
#' @returns A named list following the screening metadata contract.
#'
#' @export

normalise_doi_metadata <- function(metadata, retrieved_at = Sys.time()) {
  if (!is.list(metadata)) {
    cli::cli_abort("{.arg metadata} must be a list.")
  }
  if (!inherits(retrieved_at, "POSIXt") || length(retrieved_at) != 1L) {
    cli::cli_abort("{.arg retrieved_at} must be one date-time value.")
  }

  authors <- metadata$author
  if (is.data.frame(authors) && nrow(authors) > 0L) {
    authors <- authors |>
      dplyr::transmute(
        author = stringr::str_c(.data$family, .data$given, sep = ", ")
      ) |>
      dplyr::pull(.data$author)
  } else {
    authors <- NULL
  }

  date_parts <- metadata$issued[["date-parts"]]
  year <- if (length(date_parts) > 0L) {
    as.integer(unlist(date_parts)[[1L]])
  } else {
    NULL
  }

  list(
    title = metadata$title,
    authors = authors,
    year = year,
    journal = metadata[["container-title"]],
    publisher = metadata$publisher,
    url = metadata$URL,
    keywords = metadata$categories,
    provider = "doi_content_search",
    retrieved_at = format(retrieved_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}


#' Retrieve metadata for a DOI
#'
#' @param doi A DOI accepted by [normalise_doi()].
#' @param retrieved_at Date and time when the metadata was retrieved. The
#'   current time is used by default; this argument mainly supports
#'   reproducible tests and imports.
#' @param .fetcher Function used to retrieve DOI metadata. This supports
#'   network-independent tests and normally should not be changed.
#'
#' @returns A named list following the screening metadata contract.
#'
#' @export

fetch_doi_metadata <- function(
  doi,
  retrieved_at = Sys.time(),
  .fetcher = rcrossref::cr_cn
) {
  doi <- normalise_doi(doi)

  metadata <- tryCatch(
    .fetcher(doi, format = "citeproc-json-ish"),
    error = function(error) {
      cli::cli_abort(
        c(
          "Could not retrieve metadata for DOI {.val {doi}}.",
          "i" = "Check the DOI and the network connection, then try again."
        ),
        parent = error
      )
    }
  )

  if (!is.list(metadata) || length(metadata) == 0L) {
    cli::cli_abort("No metadata were returned for DOI {.val {doi}}.")
  }

  normalise_doi_metadata(metadata, retrieved_at = retrieved_at)
}


#' Construct a dataset screening record
#'
#' @param doi A DOI accepted by [normalise_doi()].
#' @param decision Screening decision. Use `proceed` when the dataset is
#'   relevant for validation, `exclude` when it is not suitable, or `defer`
#'   when the decision needs more information.
#' @param reason Reason for the decision. For `proceed`, use
#'   `relevant_validation_data`. For `exclude`, use `no_raw_data`,
#'   `no_relevant_variables`, `duplicate_source`, `insufficient_metadata`, or
#'   `other`. For `defer`, use `needs_second_opinion`, `access_pending`,
#'   `outside_module_scope`, or `other`.
#' @param notes Free-text screening notes. Notes are required for `defer` and
#'   when the reason is `other`.
#' @param metadata Normalised DOI metadata.
#' @param screened_at Date and time of the decision. The current time is used
#'   by default; this argument mainly supports reproducible tests and imports.
#'
#' @returns A screening record as a named list.
#'
#' @export

new_screening_record <- function(
  doi,
  decision,
  reason,
  notes = "",
  metadata,
  screened_at = Sys.time()
) {
  decision <- match.arg(decision, screening_decisions)
  reason <- match.arg(reason, screening_reasons[[decision]])

  if (!is.character(notes) || length(notes) != 1L || is.na(notes)) {
    cli::cli_abort("{.arg notes} must be one non-missing string.")
  }
  if (
    (identical(decision, "defer") || identical(reason, "other")) &&
      !stringr::str_detect(notes, "\\S")
  ) {
    cli::cli_abort("{.arg notes} is required for {.val {decision}} decisions.")
  }
  if (!is.list(metadata)) {
    cli::cli_abort("{.arg metadata} must be a list.")
  }
  if (!inherits(screened_at, "POSIXt") || length(screened_at) != 1L) {
    cli::cli_abort("{.arg screened_at} must be one date-time value.")
  }

  doi <- normalise_doi(doi)

  list(
    schema_version = 1L,
    record_id = doi_to_record_id(doi),
    doi = doi,
    screening = list(
      decision = decision,
      reason = reason,
      notes = notes,
      screened_at = format(screened_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    ),
    metadata = metadata
  )
}


#' Read all dataset screening records
#'
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns A named list of screening records. Names are the source filenames
#'   without their `.yaml` extension.
#'
#' @export

list_screening_records <- function(sources_dir) {
  if (!dir.exists(sources_dir)) {
    return(list())
  }

  paths <-
    list.files(
      sources_dir,
      pattern = "\\.yaml$",
      full.names = TRUE,
      ignore.case = TRUE
    ) |>
    sort()

  records <- purrr::map(paths, function(path) {
    tryCatch(
      yaml::read_yaml(path),
      error = function(error) {
        cli::cli_abort(
          "Could not read screening record {.path {path}}.",
          parent = error
        )
      }
    )
  })
  names(records) <-
    basename(paths) |>
    stringr::str_remove(stringr::regex("\\.yaml$", ignore_case = TRUE))

  records
}


#' Find a dataset screening record by DOI
#'
#' This function supports record lookup and checks that a DOI occurs at most
#' once in `sources_dir`. Duplicate prevention cannot take place in
#' [new_screening_record()], because that function constructs an in-memory
#' record without reading the repository. [write_screening_record()] uses this
#' function to reject a DOI that has already been saved.
#'
#' @param doi A DOI accepted by [normalise_doi()].
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns The matching screening record, or `NULL` if the DOI has not been
#'   screened.
#'
#' @export

find_screening_record <- function(
  doi,
  sources_dir
) {
  doi <- normalise_doi(doi)
  records <- list_screening_records(sources_dir)

  matches <- purrr::keep(records, function(record) {
    is.list(record) && identical(record$doi, doi)
  })

  if (length(matches) > 1L) {
    cli::cli_abort(
      "DOI {.val {doi}} occurs in multiple screening records: {names(matches)}."
    )
  }
  if (length(matches) == 0L) {
    return(NULL)
  }

  matches[[1L]]
}


#' Write a dataset screening record
#'
#' The record is written to a temporary file in `sources_dir`, read back to
#' verify the YAML round trip, and then renamed to its final path. Existing
#' records are never overwritten. To amend a saved decision, delete its YAML
#' file and screen the dataset again.
#'
#' The DOI and record ID are checked again at this file-writing step. This
#' protects against records that were loaded from YAML or modified after they
#' were created.
#'
#' @param record A screening record created by [new_screening_record()].
#' @param sources_dir Directory in which to create the YAML file.
#'
#' @returns The path of the new YAML file.
#'
#' @export

write_screening_record <- function(
  record,
  sources_dir
) {
  if (!is.list(record) || is.null(record$doi) || is.null(record$record_id)) {
    cli::cli_abort(
      "{.arg record} should be a screening record created by {.fn new_screening_record}."
    )
  }

  doi <- normalise_doi(record$doi)
  expected_record_id <- doi_to_record_id(doi)
  if (
    !identical(record$doi, doi) ||
      !identical(record$record_id, expected_record_id)
  ) {
    cli::cli_abort("The screening record DOI and record ID are inconsistent.")
  }

  existing <- find_screening_record(doi, sources_dir)
  if (!is.null(existing)) {
    cli::cli_abort(c(
      "DOI {.val {doi}} has already been screened.",
      "i" = "To amend it, delete the existing YAML file and screen it again."
    ))
  }

  dir.create(sources_dir, recursive = TRUE, showWarnings = FALSE)
  destination <- file.path(
    sources_dir,
    stringr::str_c(record$record_id, ".yaml")
  )
  if (file.exists(destination)) {
    cli::cli_abort(c(
      "Screening record {.path {destination}} already exists.",
      "i" = "Delete the existing file before screening the dataset again."
    ))
  }

  temporary <- tempfile(
    pattern = stringr::str_c(".", record$record_id, "-"),
    tmpdir = sources_dir,
    fileext = ".yaml"
  )
  on.exit(unlink(temporary), add = TRUE)

  yaml::write_yaml(record, temporary)
  round_trip <- yaml::read_yaml(temporary)
  if (!identical(record, round_trip)) {
    cli::cli_abort("The screening record changed during YAML serialisation.")
  }
  if (!file.rename(temporary, destination)) {
    cli::cli_abort("Could not save screening record to {.path {destination}}.")
  }

  destination
}


#' Screen a dataset for validation use
#'
#' This function provides an interactive R-console workflow for Step 1 of the
#' validation database process. It retrieves DOI metadata, collects a screening
#' decision and rationale, and writes one YAML record per dataset.
#'
#' @param sources_dir Directory containing one YAML file per screened dataset.
#' @param .metadata_fetcher Function used to retrieve normalised DOI metadata.
#'   This supports network-independent tests and normally should not be changed.
#' @param .readline Function used to collect free-text console input. This
#'   supports tests and normally should not be changed.
#' @param .select Function used to collect choices from a console menu. This
#'   supports tests and normally should not be changed.
#'
#' @returns Invisibly, the path of the new YAML screening record.
#'
#' @export
#'
#' @examples
#' box::use(tools/R/R/valdb)
#' box::help(valdb$screen_dataset)  # if you need a conventional R help page
#' module_name <- "soil"
#' sources_dir <- here::here(
#'   "data", "derived", module_name, "validation", "config", "sources"
#' )
#' valdb$screen_dataset(sources_dir = sources_dir)

screen_dataset <- function(
  sources_dir,
  .metadata_fetcher = fetch_doi_metadata,
  .readline = readline,
  .select = utils::select.list
) {
  doi <- normalise_doi(.readline("Enter DOI: "))

  if (!is.null(find_screening_record(doi, sources_dir))) {
    cli::cli_abort(c(
      "DOI {.val {doi}} has already been screened.",
      "i" = "To amend it, delete the existing YAML file and screen it again."
    ))
  }

  metadata <- .metadata_fetcher(doi)
  authors <- paste(metadata$authors, collapse = "; ")
  metadata_summary <- c(
    Title = metadata$title,
    Authors = authors,
    Year = as.character(metadata$year),
    Publisher = metadata$publisher,
    URL = metadata$url
  )
  metadata_summary <- metadata_summary[
    !is.na(metadata_summary) & stringr::str_detect(metadata_summary, "\\S")
  ]
  cli::cli_inform(c(
    "Metadata retrieved for DOI {.val {doi}}:",
    "*" = "{.field {names(metadata_summary)}}: {metadata_summary}"
  ))

  decision <- .select(
    screening_decisions,
    title = "Screening decision: ",
    graphics = FALSE
  )
  if (!stringr::str_detect(decision, "\\S")) {
    cli::cli_abort("A screening decision is required.")
  }

  reason <- .select(
    screening_reasons[[decision]],
    title = "Reason for decision: ",
    graphics = FALSE
  )
  if (!stringr::str_detect(reason, "\\S")) {
    cli::cli_abort("A reason for the screening decision is required.")
  }

  notes <- .readline("Notes (leave blank if not required): ")
  record <- new_screening_record(
    doi = doi,
    decision = decision,
    reason = reason,
    notes = notes,
    metadata = metadata
  )
  path <- write_screening_record(record, sources_dir)

  cli::cli_alert_info("Dataset from {.val {doi}} will {.val {decision}}.")
  cli::cli_alert_success("Screening record saved to {.path {path}}.")

  invisible(path)
}


# Schema template contract -----------------------------------------------

#' Construct a validation dataset schema template
#'
#' The template contains the YAML fields currently consumed by
#' [build_validation_database()]. The returned list is an editable scaffold,
#' not a build-ready schema. Before running [build_validation_database()],
#' replace every example value with the actual CSV path, source column names,
#' canonical variable mappings, source units, and observation identifier for
#' the dataset. Remove unused template entries and add one variables entry for
#' each source column for [build_validation_database()] to use.
#'
#' This helper function is intended to be used with [initialise_source_schema()].
#'
#' @returns A named list containing placeholders for the mandatory source fields
#'   and optional `coordinates` and `temporal` blocks.
#'
#' @export

new_schema_template <- function() {
  list(
    source_id = "author_year",
    data_file = "data/primary/<module>/author_year/*.csv",
    skip_rows = 0L,
    variables = list(
      var_original_1 = list(
        var_canonical = "var_ve_1",
        unit = "unit",
        description = NULL
      )
    ),
    dedup_key = c("sample_id", "date", "site_id"),
    coordinates = list(
      from_file = NULL,
      match_data_column = NULL,
      match_location_column = NULL,
      latitude_column = NULL,
      longitude_column = NULL,
      same_for_all_rows = list(
        latitude = NULL,
        longitude = NULL
      )
    ),
    temporal = list(
      date_column = NULL,
      start_column = NULL,
      end_column = NULL,
      format = NULL,
      timezone = NULL,
      precision = NULL,
      same_for_all_rows = list(
        start = NULL,
        end = NULL,
        precision = NULL,
        note = NULL
      )
    )
  )
}


#' Check whether a validation dataset schema needs completion
#'
#' A schema needs completion when it has not been initialised or still contains
#' a mandatory value copied from [new_schema_template()]. Optional spatial and
#' temporal fields do not affect completion status.
#'
#' @param record A screening record, optionally with schema fields.
#'
#' @returns `TRUE` when the mandatory schema is absent or still a draft.

schema_needs_completion <- function(record) {
  template <- new_schema_template()

  is.null(record$source_id) ||
    identical(record$source_id, template$source_id) ||
    identical(record$data_file, template$data_file) ||
    identical(record$variables, template$variables) ||
    identical(record$dedup_key, template$dedup_key)
}


#' List source records ready for the validation database build
#'
#' Screening-only records are ignored. Draft schemas are reported and skipped.
#' A record containing schema fields must retain a `proceed` screening decision.
#'
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns A named list of build-ready source records.

list_build_sources <- function(sources_dir) {
  records <- list_screening_records(sources_dir)

  dois <- purrr::map_chr(records, function(record) {
    if (
      is.list(record) && is.character(record$doi) && length(record$doi) == 1L
    ) {
      record$doi
    } else {
      NA_character_
    }
  })

  # check for duplicated DOIs
  duplicated_dois <- unique(dois[!is.na(dois) & duplicated(dois)])
  if (length(duplicated_dois) > 0L) {
    cli::cli_abort(
      "DOI{?s} {duplicated_dois} occur{?s} in multiple source records."
    )
  }

  # check for draft (incomplete) schema
  schema_fields <- names(new_schema_template())
  with_schema <- purrr::keep(records, function(record) {
    is.list(record) && any(schema_fields %in% names(record))
  })
  invalid_decisions <- purrr::keep(with_schema, function(record) {
    !identical(record$screening$decision, "proceed")
  })
  if (length(invalid_decisions) > 0L) {
    paths <- file.path(sources_dir, paste0(names(invalid_decisions), ".yaml"))
    cli::cli_abort(
      "Source record{?s} {.path {paths}} contain{?s} a schema without a
       {.val proceed} screening decision."
    )
  }

  drafts <- purrr::keep(with_schema, schema_needs_completion)
  if (length(drafts) > 0L) {
    paths <- file.path(sources_dir, paste0(names(drafts), ".yaml"))
    cli::cli_warn(
      "Skipping draft source schema{?s} {.path {paths}}. Complete the
       placeholder values before building the database."
    )
  }

  build_sources <- purrr::discard(with_schema, schema_needs_completion)
  if (length(build_sources) == 0L) {
    cli::cli_abort(
      "No completed source schemas were found in {.path {sources_dir}}."
    )
  }

  build_sources
}


#' Validate one source schema
#'
#' Checks that a source schema contains the required fields and that their
#' values can be used by [build_validation_database()]. This includes validating
#' source identifiers, input paths, skipped rows, variable mappings, and
#' deduplication keys. The configured data file must already exist.
#'
#' @param source A source record containing the fields from
#'   [new_schema_template()].
#' @param path Path to the source YAML file, used in validation messages.
#'
#' @returns `source`, invisibly. Aborts when the schema is invalid.
#'
#' @keywords internal

validate_source_schema <- function(source, path) {
  required_fields <- names(new_schema_template())
  missing_fields <- setdiff(required_fields, names(source))
  if (length(missing_fields) > 0L) {
    cli::cli_abort(
      "Source schema {.path {path}} is missing required field{?s} \
       {.field {missing_fields}}."
    )
  }

  scalar_string <- function(value) {
    is.character(value) &&
      length(value) == 1L &&
      !is.na(value) &&
      stringr::str_length(stringr::str_trim(value)) > 0L
  }

  if (!scalar_string(source$source_id)) {
    cli::cli_abort(
      "Source schema {.path {path}} must have one non-empty {.field source_id}."
    )
  }
  if (!scalar_string(source$data_file)) {
    cli::cli_abort(
      "Source schema {.path {path}} must have one non-empty {.field data_file}."
    )
  }
  if (
    !is.numeric(source$skip_rows) ||
      length(source$skip_rows) != 1L ||
      is.na(source$skip_rows) ||
      !is.finite(source$skip_rows) ||
      source$skip_rows < 0 ||
      source$skip_rows != floor(source$skip_rows)
  ) {
    cli::cli_abort(
      "Source schema {.path {path}} must have a non-negative integer \
       {.field skip_rows}."
    )
  }
  if (
    !is.list(source$variables) ||
      length(source$variables) == 0L ||
      is.null(names(source$variables)) ||
      any(names(source$variables) == "") ||
      anyDuplicated(names(source$variables))
  ) {
    cli::cli_abort(
      "Source schema {.path {path}} must have a non-empty, uniquely named \
       {.field variables} list."
    )
  }
  invalid_variables <- names(source$variables)[purrr::map_lgl(
    source$variables,
    function(variable) {
      !is.list(variable) ||
        !all(c("var_canonical", "unit") %in% names(variable)) ||
        !scalar_string(variable$var_canonical) ||
        !scalar_string(variable$unit)
    }
  )]
  if (length(invalid_variables) > 0L) {
    cli::cli_abort(
      "Invalid entries in {.field variables}: {.field {invalid_variables}} in \
       source schema {.path {path}}. Each mapping must have one non-empty \
       {.field var_canonical} and {.field unit}."
    )
  }
  if (
    !is.character(source$dedup_key) ||
      length(source$dedup_key) == 0L ||
      any(is.na(source$dedup_key)) ||
      any(stringr::str_length(stringr::str_trim(source$dedup_key)) == 0L) ||
      anyDuplicated(source$dedup_key)
  ) {
    cli::cli_abort(
      "Source schema {.path {path}} must have one or more unique, non-empty \
       {.field dedup_key} values."
    )
  }
  if (!file.exists(source$data_file)) {
    cli::cli_abort(
      "Data file {.path {source$data_file}} configured by source schema \
       {.path {path}} does not exist."
    )
  }

  invisible(source)
}


#' Validate all sources selected for a database build
#'
#' Applies [validate_source_schema()] to every build source and verifies that
#' `source_id` values are unique across source schemas.
#'
#' @param sources A named list of source records returned by
#'   [list_build_sources()].
#' @param sources_dir Directory containing the corresponding source YAML files.
#'
#' @returns `sources`, invisibly. Aborts when any source is invalid or source
#'   identifiers are duplicated.
#'
#' @keywords internal

validate_build_sources <- function(sources, sources_dir) {
  purrr::iwalk(sources, function(source, record_id) {
    validate_source_schema(
      source,
      file.path(sources_dir, paste0(record_id, ".yaml"))
    )
  })

  source_ids <- purrr::map_chr(sources, "source_id")
  duplicated_ids <- unique(source_ids[duplicated(source_ids)])
  if (length(duplicated_ids) > 0L) {
    cli::cli_abort(
      "Duplicate source ID{?s} {.val {duplicated_ids}} occur{?s} across schemas."
    )
  }

  invisible(sources)
}


#' Validate and select columns from one source dataset
#'
#' Requires all configured deduplication columns. Missing measurement columns
#' are reported and omitted. The remaining observation keys must be complete
#' and unique before spatial and temporal metadata are added.
#'
#' @param data A data frame read from the source CSV file.
#' @param source The source schema associated with `data`.
#'
#' @returns A data frame containing the deduplication columns and available
#'   measurement columns. The selected measurement names are stored in the
#'   `measurement_columns` attribute. Returns `NULL` with a warning when no
#'   configured measurement columns are available.
#'
#' @keywords internal

prepare_source_data <- function(data, source) {
  missing_keys <- setdiff(source$dedup_key, names(data))
  if (length(missing_keys) > 0L) {
    cli::cli_abort(
      "Source {.val {source$source_id}} is missing deduplication column{?s} \
       {.field {missing_keys}}."
    )
  }

  measurement_columns <- names(source$variables)
  missing_measurements <- setdiff(measurement_columns, names(data))
  available_measurements <- setdiff(measurement_columns, missing_measurements)
  if (length(available_measurements) == 0L) {
    cli::cli_warn(
      "Skipping source {.val {source$source_id}} because none of its \
       configured measurement columns are present."
    )
    return(NULL)
  }
  if (length(missing_measurements) > 0L) {
    cli::cli_warn(
      "Source {.val {source$source_id}} is missing measurement column{?s} \
       {.field {missing_measurements}}; skipping {?this measurement/these \
       measurements}."
    )
  }

  data <- dplyr::select(
    data,
    tidyr::all_of(c(source$dedup_key, available_measurements))
  )
  key_data <- dplyr::select(data, tidyr::all_of(source$dedup_key))
  missing_values <- key_data |>
    purrr::map(function(column) {
      is.na(column) |
        (is.character(column) & stringr::str_trim(column) == "")
    }) |>
    purrr::reduce(`|`)
  if (any(missing_values)) {
    cli::cli_abort(
      "Source {.val {source$source_id}} has missing values in its \
       deduplication key at row{?s} {which(missing_values)}."
    )
  }

  duplicate_keys <- duplicated(key_data) | duplicated(key_data, fromLast = TRUE)
  if (any(duplicate_keys)) {
    cli::cli_abort(
      "Source {.val {source$source_id}} has duplicate observation key{?s} at \
       row{?s} {which(duplicate_keys)}."
    )
  }

  attr(data, "measurement_columns") <- available_measurements
  data
}


#' Create and validate observation identifiers
#'
#' Combines the configured deduplication columns into `ID` after spatial and
#' temporal metadata have been attached. Aborts if distinct key combinations
#' collapse to the same identifier under [tidyr::unite()].
#'
#' @param data A source data frame containing the configured deduplication
#'   columns.
#' @param source The source schema associated with `data`.
#'
#' @returns `data` with the deduplication columns replaced by `ID`.
#'
#' @keywords internal

add_observation_id <- function(data, source) {
  data <- tidyr::unite(data, "ID", tidyr::all_of(source$dedup_key))
  duplicate_ids <- duplicated(data$ID) | duplicated(data$ID, fromLast = TRUE)
  if (any(duplicate_ids)) {
    cli::cli_abort(
      "Source {.val {source$source_id}} has observation keys that collide \
       when combined into {.field ID}: {.val {unique(data$ID[duplicate_ids])}}."
    )
  }

  data
}


#' Initialise a validation dataset schema
#'
#' Adds [new_schema_template()] to an existing screening record. The record must
#' have a `proceed` decision and must not already contain a schema. Existing
#' screening and DOI metadata fields are preserved.
#'
#' The updated record is written to a temporary file, read back to verify the
#' YAML round trip, and then moved to the original record path. To amend an
#' existing schema, delete its YAML file and screen the dataset again.
#'
#' @param doi A DOI accepted by [normalise_doi()].
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns The path of the updated YAML file.
#'
#' @export

initialise_source_schema <- function(
  doi,
  sources_dir
) {
  doi <- normalise_doi(doi)
  record <- find_screening_record(doi, sources_dir)

  if (is.null(record)) {
    cli::cli_abort("DOI {.val {doi}} has not been screened.")
  }
  if (!identical(record$screening$decision, "proceed")) {
    cli::cli_abort(
      "DOI {.val {doi}} must have a {.val proceed} screening decision before a schema can be added."
    )
  }
  if (!is.null(record$source_id)) {
    cli::cli_abort(c(
      "DOI {.val {doi}} already has a schema.",
      "i" = "To amend it, delete the existing YAML file and screen it again."
    ))
  }

  destination <- file.path(
    sources_dir,
    stringr::str_c(doi_to_record_id(doi), ".yaml")
  )
  if (!file.exists(destination)) {
    cli::cli_abort(
      "The screening record for DOI {.val {doi}} is not at the expected path {.path {destination}}."
    )
  }

  updated_record <- c(record, new_schema_template())
  temporary <- tempfile(
    pattern = stringr::str_c(".", doi_to_record_id(doi), "-"),
    tmpdir = sources_dir,
    fileext = ".yaml"
  )
  backup <- tempfile(
    pattern = stringr::str_c(".", doi_to_record_id(doi), "-backup-"),
    tmpdir = sources_dir,
    fileext = ".yaml"
  )
  on.exit(unlink(c(temporary, backup)), add = TRUE)

  yaml::write_yaml(updated_record, temporary)
  round_trip <- yaml::read_yaml(temporary)
  if (!identical(updated_record, round_trip)) {
    cli::cli_abort("The schema record changed during YAML serialisation.")
  }

  if (!file.rename(destination, backup)) {
    cli::cli_abort(
      "Could not prepare screening record {.path {destination}} for update."
    )
  }
  if (!file.rename(temporary, destination)) {
    restored <- file.rename(backup, destination)
    if (!restored) {
      cli::cli_abort(
        "Could not save or restore screening record {.path {destination}}."
      )
    }
    cli::cli_abort("Could not save schema record to {.path {destination}}.")
  }
  unlink(backup)

  destination
}


#' Add a validation dataset schema for editing
#'
#' Initialises a schema for a screened dataset and opens its per-DOI YAML file
#' in an editor. The screening decision must be `proceed`, and the record must
#' not already contain a schema.
#'
#' @param doi A DOI accepted by [normalise_doi()].
#' @param sources_dir Directory containing one YAML file per screened dataset.
#' @param .editor Function used to open the YAML file. This supports tests and
#'   normally should not be changed.
#'
#' @returns Invisibly, the path of the updated YAML file.
#'
#' @export
#' @examples
#' box::use(tools/R/R/valdb)
#' module_name <- "soil"
#' sources_dir <- here::here(
#'   "data", "derived", module_name, "validation", "config", "sources"
#' )
#' valdb$add_schema("10.5281/zenodo.8158810", sources_dir = sources_dir)

add_schema <- function(
  doi,
  sources_dir,
  .editor = utils::file.edit
) {
  doi <- normalise_doi(doi)
  path <- initialise_source_schema(doi, sources_dir)
  .editor(path)

  invisible(path)
}


#' (Re)Build the validation database
#'
#' Build or rebuild the validation database based on the YAML configs of source
#' datasets.
#'
#' @param config_dir Path containing validation database configuration.
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
#' config_dir <- file.path(validation_root, "config")
#' valdb$build_validation_database(
#'   config_dir = config_dir,
#'   sources_dir = file.path(config_dir, "sources"),
#'   db_path = file.path(validation_root, "database")
#' )

build_validation_database <- function(
  config_dir,
  sources_dir = file.path(config_dir, "sources"),
  db_path
) {
  # Ingest datasets --------------------------------------------------------

  sources <- list_build_sources(sources_dir)
  validate_build_sources(sources, sources_dir)

  # Configs ----------------------------------------------------------------

  # Load canonical units only after local source preflight succeeds.
  canonical_units <- build_canonical_units_table(
    variables_derived = file.path(config_dir, "derived_variables.toml")
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
#' configured source, attaches spatial and temporal metadata, reshapes
#' measurements, and converts known variables to canonical units. Unknown
#' canonical mappings retain their original values and units and receive
#' missing canonical values and units.
#'
#' @param src A validated source schema returned by [list_build_sources()].
#' @param canonical_units A data frame with `var_canonical` and
#'   `unit_canonical` columns.
#'
#' @returns A long-format data frame of harmonised observations, or `NULL` when
#'   the source has no available configured measurement columns.

harmonise_source_data <- function(src, canonical_units) {
  data <- readr::read_csv(
    src$data_file,
    show_col_types = FALSE,
    skip = src$skip_rows
  ) |>
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
      unit_canonical = dplyr::if_else(
        is.na(unit_canonical),
        NA_character_,
        unit_canonical
      ),
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
#' Most SAFE Zenodo datasets need no configuration at all, because they are
#' curated to a common standard: a \code{Locations} sheet holding
#' \code{Location name}, \code{Latitude} and \code{Longitude} in decimal
#' degrees (WGS84). Following the manual-conversion convention for the data
#' sheet, export that sheet to \code{locations.csv} in the same folder as
#' \code{data_file} and this function will find it automatically.
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
  if (length(blanket) > 0) {
    if (is.null(blanket$latitude) || is.null(blanket$longitude)) {
      cli::cli_abort(
        "{.field same_for_all_rows} in {.val {src$source_id}} needs both
         a {.field latitude} and a {.field longitude}. You are getting this
         because you specified something in {.field same_for_all_rows} but left
         {.field latitude} and a {.field longitude} as blank."
      )
    }
    return(dplyr::mutate(
      dat,
      latitude = as.numeric(blanket$latitude),
      longitude = as.numeric(blanket$longitude),
      location_type = "whole dataset",
      coordinate_source = "same_for_all_rows"
    ))
  }

  # Case 2: look the coordinates up from a locations file
  locations_file <- spec$from_file %||%
    file.path(dirname(src$data_file), "locations.csv")

  if (!file.exists(locations_file)) {
    cli::cli_warn(
      "No coordinates for {.val {src$source_id}}: cannot find
       {.file {locations_file}}. Export the {.field Locations} sheet of the
       source file to that path, or add a {.field coordinates} block to the
       source YAML. Currently NA coordinates are assigned for
       {.val {src$source_id}}"
    )
    return(dplyr::mutate(
      dat,
      latitude = NA_real_,
      longitude = NA_real_,
      location_type = NA_character_,
      coordinate_source = "missing"
    ))
  }

  # the column in `dat` naming the location: default to the dedup key, but
  # only when that key is unambiguous
  key_data <- spec$match_data_column
  if (is.null(key_data)) {
    if (length(src$dedup_key) > 1) {
      cli::cli_abort(
        "{.val {src$source_id}} has a multi-column {.field dedup_key},
         so the location column is ambiguous. Name it explicitly with
         {.field coordinates: match_data_column} in the source YAML."
      )
    }
    key_data <- src$dedup_key
  }

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
  dat <-
    dat |>
    dplyr::left_join(
      locations,
      # setNames() because the column name comes from a variable
      by = stats::setNames("location_key", key_data),
      # errors if the locations file has duplicated keys, which would
      # silently inflate the number of observations
      # NB: many-to-one should also cover one-to-one
      relationship = "many-to-one"
    ) |>
    # cover the case of partial missingness in a location file
    dplyr::mutate(
      coordinate_source = dplyr::if_else(
        is.na(latitude) | is.na(longitude),
        "missing",
        "locations_file"
      )
    )

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
#' UTC, so that consecutive periods tile without overlapping. A point-in-time
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
  tz_in <- spec$timezone %||% "UTC"
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
  variables_ve = "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/develop/virtual_ecosystem/data_variables.toml",
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
  variables_ve = "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/develop/virtual_ecosystem/data_variables.toml",
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
      unit_canonical = stringr::str_remove_all(unit_canonical, "\\{[^}]+\\}")
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
  toml::read_toml(toml) |>
    purrr::pluck("variable") |>
    {
      \(x) purrr::set_names(x, purrr::map_chr(x, "name"))
    }() |>
    purrr::map(~ purrr::discard(.x, names(.x) == "name"))
}


#' Read VE scenario metadata from compiled configuration
#'
#' Internal helper for [join_ve_outputs()]. It reads VE grid and timing metadata
#' from a compiled configuration TOML and reconstructs WGS84 spatial bounds from
#' the UTM 50N grid definition.
#'
#' @param config_path Path to a compiled VE configuration TOML file.
#'
#' @returns A list with `grid_res`, `start_date`, `spatial_bounds`, and
#'   `temporal_bounds`.

read_scenario_definition <- function(config_path) {
  scenario <- toml::read_toml(config_path)
  scenario$res <- sqrt(scenario$core$grid$cell_area)
  run_length_parts <- stringr::str_split_1(scenario$core$timing$run_length, " ")
  start_date <- lubridate::ymd(scenario$core$timing$start_date)

  utm_bounds <- c(
    xmin = scenario$core$grid$xoff,
    ymin = scenario$core$grid$yoff,
    xmax = scenario$core$grid$xoff +
      scenario$core$grid$cell_nx * scenario$res,
    ymax = scenario$core$grid$yoff +
      scenario$core$grid$cell_ny * scenario$res
  )

  wgs84_bbox <-
    sf::st_bbox(utm_bounds, crs = sf::st_crs(32650)) |>
    sf::st_as_sfc() |>
    sf::st_transform(crs = 4326) |>
    sf::st_bbox()

  list(
    grid_res = scenario$res,
    start_date = start_date,
    spatial_bounds = stats::setNames(as.numeric(wgs84_bbox), names(wgs84_bbox)),
    temporal_bounds = c(
      start_date,
      start_date +
        lubridate::duration(
          as.numeric(run_length_parts[1]),
          run_length_parts[2]
        )
    )
  )
}


#' Classify whether coordinates are inside scenario bounds
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param lat Numeric latitude in WGS84.
#' @param lon Numeric longitude in WGS84.
#' @param bounds_spatial Numeric vector `c(xmin, ymin, xmax, ymax)`.
#'
#' @returns Character vector with values `"within"` or `"outside"`.

classify_spatial_bounds <- function(lat, lon, bounds_spatial) {
  within <-
    (lon >= bounds_spatial[1] & lon <= bounds_spatial[3]) &
    (lat >= bounds_spatial[2] & lat <= bounds_spatial[4])
  dplyr::case_when(within ~ "within", !within ~ "outside")
}


#' Classify temporal overlap with scenario bounds
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param time_start Observation start time.
#' @param time_end Observation end time; if missing, `time_start` is used.
#' @param bounds_temporal Length-2 vector with scenario start and end time.
#' @param tz Time zone used for coercing `bounds_temporal`.
#'
#' @returns Character vector with values `"within"`, `"partial"`,
#'   `"outside"`, or `NA`.

classify_temporal_bounds <- function(
  time_start,
  time_end,
  bounds_temporal,
  tz = "UTC"
) {
  obs_end <- dplyr::coalesce(time_end, time_start)
  bounds_temporal <- as.POSIXct(bounds_temporal, tz = tz)
  bounds_start <- bounds_temporal[1]
  bounds_end <- bounds_temporal[2]

  no_overlap <- obs_end <= bounds_start | time_start >= bounds_end
  fully_within <- time_start >= bounds_start & obs_end <= bounds_end

  dplyr::case_when(
    is.na(time_start) ~ NA_character_,
    no_overlap ~ "outside",
    fully_within ~ "within",
    .default = "partial"
  )
}


#' Summarise VE outputs for one validation row
#'
#' Internal helper for [join_ve_outputs()].
#'
#' @param ve_data VE output table prepared by [join_ve_outputs()].
#' @param var_canonical Canonical variable name to match.
#' @param time_start Observation start time.
#' @param time_end Observation end time.
#' @param latitude Observation latitude.
#' @param longitude Observation longitude.
#' @param spatiotemporal_join_class Join class label used to choose matching
#'   logic.
#'
#' @returns Named numeric vector with `value_VE_q05`, `value_VE_q50`, and
#'   `value_VE_q95`.

join_ve_outputs_per_row <- function(
  ve_data,
  var_canonical,
  time_start,
  time_end,
  latitude,
  longitude,
  spatiotemporal_join_class
) {
  # placeholder to fill NA for empty variables
  empty_quantiles <- c(
    value_VE_q05 = NA_real_,
    value_VE_q50 = NA_real_,
    value_VE_q95 = NA_real_
  )

  # function to summarise/aggregate VE outputs
  # currently it is median and the lower/upper quantiles; this can be changed
  # later
  summarise_ve_outputs <- function(data) {
    values <- dplyr::pull(data, value)
    if (length(values) == 0) {
      return(empty_quantiles)
    }
    stats::quantile(values, probs = c(0.05, 0.5, 0.95)) |>
      stats::setNames(c("value_VE_q05", "value_VE_q50", "value_VE_q95"))
  }

  switch(
    spatiotemporal_join_class,
    "spatial_within_temporal_within" = {
      ve_data |>
        dplyr::filter(
          var_canonical == !!var_canonical,
          lubridate::`%within%`(
            date,
            lubridate::interval(time_start, time_end)
          ),
          lat_min <= latitude & latitude <= lat_max,
          lon_min <= longitude & longitude <= lon_max
        ) |>
        summarise_ve_outputs()
    },
    "spatial_within_temporal_outside" = empty_quantiles,
    "spatial_within_temporal_partial" = empty_quantiles,
    "spatial_outside_temporal_within" = {
      ve_data |>
        dplyr::filter(
          var_canonical == !!var_canonical,
          lubridate::`%within%`(
            date,
            lubridate::interval(time_start, time_end)
          )
        ) |>
        summarise_ve_outputs()
    },
    "spatial_outside_temporal_outside" = empty_quantiles,
    "spatial_outside_temporal_partial" = empty_quantiles,
    stop("Unknown case: ", spatiotemporal_join_class)
  )
}


#' Join VE outputs to a validation database
#'
#' Reads direct and derived Virtual Ecosystem (VE) outputs, reshapes VE spatial
#' and temporal coordinates, classifies validation observations against scenario
#' bounds, and appends VE quantile predictions to each validation row.
#'
#' The output preserves all rows and columns of `validation_database` and adds
#' `value_VE_q05`, `value_VE_q50`, and `value_VE_q95`.
#'
#' @param validation_database A data frame containing at least
#'   `var_canonical`, `time_start`, `time_end`, `latitude`, and `longitude`.
#' @param zarr_path Path to VE model outputs in a Zarr store.
#' @param config_path Path to a compiled VE configuration TOML.
#'
#' @details
#' Spatiotemporal join classes are handled intentionally as follows:
#' \itemize{
#'   \item `spatial_within_temporal_within`: spatial and temporal matching.
#'   \item `spatial_outside_temporal_within`: temporal matching only.
#'   \item Other classes are not yet implemented and currently return `NA` quantiles by design. There will be a warning to the user.
#' }
#'
#' @returns A data frame with three appended columns: `value_VE_q05`,
#'   `value_VE_q50`, and `value_VE_q95`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' module_name <- "soil"
#' scenario_group <- "maliau"
#' scenario_name <- "maliau_2"
#' validation_root <- here::here(
#'   "data", "derived", module_name, "validation"
#' )
#' scenario_root <- here::here(
#'   "data", "scenarios", scenario_group, scenario_name, "out"
#' )
#' db <- arrow::open_dataset(file.path(validation_root, "database")) |>
#'   dplyr::collect()
#' join_ve_outputs(
#'   validation_database = db,
#'   zarr_path = file.path(scenario_root, "model_data.zarr"),
#'   config_path = file.path(scenario_root, "compiled_configuration.toml")
#' )
#' }

join_ve_outputs <- function(validation_database, zarr_path, config_path) {
  scenario_def <- read_scenario_definition(config_path)

  # Half-cell offset used to convert grid centroids to grid bounds.
  grid_offset <- scenario_def$grid_res / 2

  # xy coordinates: convert UTM centroids to WGS84 cell bounds.
  xy_ve <-
    get_data_variables(zarr_path, group = "outputs", variables = c("x", "y")) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1, values_from = value) |>
    dplyr::mutate(
      x_min = x - grid_offset,
      x_max = x + grid_offset,
      y_min = y - grid_offset,
      y_max = y + grid_offset,
      geometry = purrr::pmap(
        list(x_min, x_max, y_min, y_max),
        \(xmin, xmax, ymin, ymax) {
          sf::st_polygon(list(matrix(
            c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
            ncol = 2,
            byrow = TRUE
          )))
        }
      )
    ) |>
    sf::st_as_sf(sf_column_name = "geometry", crs = 32650) |>
    sf::st_transform(crs = 4326) |>
    dplyr::mutate(
      bbox = purrr::map(geometry, sf::st_bbox),
      lon_min = purrr::map_dbl(bbox, \(b) b[["xmin"]]),
      lon_max = purrr::map_dbl(bbox, \(b) b[["xmax"]]),
      lat_min = purrr::map_dbl(bbox, \(b) b[["ymin"]]),
      lat_max = purrr::map_dbl(bbox, \(b) b[["ymax"]])
    ) |>
    dplyr::select(-bbox) |>
    sf::st_drop_geometry()

  # Timestamps from VE simulation.
  timestamp_ve <-
    get_data_variables(
      zarr_path,
      group = "outputs",
      variables = c("timestamp")
    ) |>
    reshape2::melt() |>
    tidyr::pivot_wider(names_from = L1, values_from = value)

  # Direct data variables from the Zarr store.
  vars_target <- base::unique(validation_database$var_canonical)
  vars_ve_output <-
    pizzarr::zarr_open(zarr_path)$get_item("outputs")$get_store()$listdir(
      "outputs"
    )
  data_variables <-
    get_data_variables(
      zarr_path,
      group = "outputs",
      variables = base::intersect(vars_target, vars_ve_output)
    ) |>
    reshape2::melt() |>
    dplyr::rename(var_canonical = L1)

  # Derived variables, calculated from direct data variables.
  derived_variables <-
    get_derived_variables(
      zarr_path,
      config_path,
      group = "outputs"
    ) |>
    reshape2::melt() |>
    dplyr::rename(var_canonical = L1)

  ve_variables <-
    dplyr::bind_rows(data_variables, derived_variables) |>
    dplyr::left_join(
      dplyr::select(
        xy_ve,
        cell_id,
        dplyr::starts_with("lon"),
        dplyr::starts_with("lat")
      ),
      by = dplyr::join_by(cell_id)
    ) |>
    dplyr::left_join(timestamp_ve, by = dplyr::join_by(time_index)) |>
    dplyr::mutate(date = scenario_def$start_date + timestamp)

  scenario_bounds <- list(
    spatial = scenario_def$spatial_bounds,
    temporal = scenario_def$temporal_bounds
  )

  validation_database_classified <-
    validation_database |>
    dplyr::mutate(
      spatial_join_class = classify_spatial_bounds(
        latitude,
        longitude,
        scenario_bounds$spatial
      ),
      temporal_join_class = classify_temporal_bounds(
        time_start,
        time_end,
        scenario_bounds$temporal
      )
    ) |>
    dplyr::mutate(
      spatiotemporal_join_class = paste(
        "spatial",
        spatial_join_class,
        "temporal",
        temporal_join_class,
        sep = "_"
      )
    )

  # A summary warning if any of the unimplemented spatiotemporal classes is
  # found in the database
  unimplemented_summary_classes <- c(
    "spatial_within_temporal_outside",
    "spatial_within_temporal_partial",
    "spatial_outside_temporal_outside",
    "spatial_outside_temporal_partial"
  )
  unimplemented_counts <-
    validation_database_classified |>
    dplyr::count(spatiotemporal_join_class, name = "n") |>
    dplyr::filter(spatiotemporal_join_class %in% unimplemented_summary_classes)
  if (nrow(unimplemented_counts) > 0) {
    counts_text <- paste0(
      unimplemented_counts$spatiotemporal_join_class,
      "=",
      unimplemented_counts$n,
      collapse = ", "
    )
    cli::cli_warn(c(
      "Summary method not implemented yet for selected classes.",
      "i" = "Rows will return NA quantiles for: {.val {counts_text}}"
    ))
  }

  validation_database_classified |>
    dplyr::mutate(
      value_VE = purrr::pmap(
        list(
          var_canonical,
          time_start,
          time_end,
          latitude,
          longitude,
          spatiotemporal_join_class
        ),
        \(...) join_ve_outputs_per_row(ve_data = ve_variables, ...)
      )
    ) |>
    tidyr::unnest_wider(value_VE)
}
