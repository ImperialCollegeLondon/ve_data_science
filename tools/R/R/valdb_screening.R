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
#| author:
#|   - Hao Ran Lai
#|   - Nicholas Wei Cheng Tan
#|
#| status: final
#|
#| input_files:
#|   - name: gazetteer.geojson
#|     path: data/primary/site/
#|     description: |
#|       SAFE gazetteer
#|
#| output_files:
#|
#| source_files:
#|   - name: get_ve_variables.R
#|     path: tools/R/R/get_ve_variables.R
#|     description: |
#|       Provides `get_data_variables()` and `get_derived_variables()` used by
#|       `join_ve_outputs()`.
#|
#| package_dependencies:
#|   - arrow
#|   - cli
#|   - dplyr
#|   - lubridate
#|   - pizzarr
#|   - purrr
#|   - rcrossref
#|   - readr
#|   - reshape2
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
#|
#| usage_notes: |
#|   `build_validation_database()` reads completed per-DOI schemas and writes
#|   grouped Parquet output. `join_ve_outputs()` requires VE output files and
#|   functions from `tools/R/R/get_ve_variables.R`.
#|   Use `screen_dataset()` and manual schema completion (see
#|   docs/validation_database.md) before calling
#|   `build_validation_database()`.
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
    authors <- purrr::pmap_chr(
      list(
        family = authors$family %||% rep(NA_character_, nrow(authors)),
        given = authors$given %||% rep(NA_character_, nrow(authors)),
        literal = authors$literal %||% rep(NA_character_, nrow(authors))
      ),
      \(family, given, literal) {
        name_parts <- c(family, given)[
          !is.na(c(family, given)) & nzchar(c(family, given))
        ]
        if (length(name_parts) > 0L) {
          stringr::str_c(name_parts, collapse = ", ")
        } else if (!is.na(literal) && nzchar(literal)) {
          literal
        } else {
          NA_character_
        }
      }
    )
    authors <- authors[!is.na(authors) & nzchar(authors)]
    if (length(authors) == 0L) authors <- NULL
  } else {
    authors <- NULL
  }

  year <- if (length(metadata$issued[["date-parts"]]) > 0L) {
    as.integer(unlist(metadata$issued[["date-parts"]])[[1L]])
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
  names(records) <- tools::file_path_sans_ext(basename(paths))

  records
}


#' List proceed screening records for schema setup
#'
#' Prints a compact console table of screening records whose decision is
#' `proceed`. This gives IDE users the DOI list that the retired dashboard used
#' to display before schema editing.
#'
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns Invisibly, a tibble of proceed records.
#'
#' @export

list_proceed_screening_records <- function(sources_dir) {
  records <- list_screening_records(sources_dir)
  proceed <- purrr::keep(records, function(record) {
    is.list(record) && identical(record$screening$decision, "proceed")
  })

  rows <- purrr::imap_dfr(proceed, function(record, record_name) {
    tibble::tibble(
      record_id = record_name,
      doi = record$doi %||% "",
      title = record$metadata$title %||% "",
      year = as.integer(record$metadata$year %||% NA_integer_),
      schema_status = if (schema_needs_completion(record)) {
        "Draft"
      } else {
        "Complete"
      }
    )
  })

  if (nrow(rows) == 0L) {
    cli::cli_inform(
      "No proceed screening records found in {.path {sources_dir}}."
    )
    return(invisible(rows))
  }

  print(rows, row.names = FALSE)
  invisible(rows)
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

  duplicates <- which(purrr::map_lgl(records, function(record) {
    is.list(record) && identical(record$doi, doi)
  }))

  if (length(duplicates) > 1L) {
    cli::cli_abort(
      "DOI {.val {doi}} occurs in multiple screening records: {names(records)[duplicates]}."
    )
  }
  if (length(duplicates) == 0L) {
    return(NULL)
  }

  records[[duplicates[1L]]]
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
#'   "data", "derived", module_name, "validation", "sources"
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

#' Construct one validation dataset schema template
#'
#' The template contains the dataset-level YAML fields currently consumed by
#' [build_validation_database()]. The returned list is an editable scaffold,
#' not a build-ready schema. Before running [build_validation_database()],
#' replace every example value with the actual CSV path, source column names,
#' canonical variable mappings, source units, and observation identifier for
#' the dataset. Remove unused template entries and add one variables entry for
#' each source column for [build_validation_database()] to use.
#'
#' This helper function is intended to be used with [initialise_source_schema()].
#'
#' @returns A named list containing placeholders for the mandatory dataset fields
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
    # Coordinates specification. Keep this field order stable for YAML templates:
    # file mapping first, then optional in-data columns, then blanket coordinates.
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
    ),
    row_filter = NULL
  )
}


#' Check whether one validation dataset schema entry needs completion
#'
#' A dataset schema needs completion when it is absent or still contains a
#' mandatory value copied from [new_schema_template()]. Optional spatial and
#' temporal fields do not affect completion status.
#'
#' @param dataset One dataset-schema entry.
#'
#' @returns `TRUE` when the mandatory schema is absent or still a draft.

dataset_needs_completion <- function(dataset) {
  template <- new_schema_template()

  is.null(dataset$source_id) ||
    identical(dataset$source_id, template$source_id) ||
    identical(dataset$data_file, template$data_file) ||
    identical(dataset$variables, template$variables) ||
    identical(dataset$dedup_key, template$dedup_key)
}


#' Check whether a screening record still lacks a completed dataset schema
#'
#' Returns `TRUE` when a record has no dataset entries yet, or when every entry
#' under `datasets` still contains placeholder values from
#' [new_schema_template()].
#'
#' @param record A screening record, optionally with a `datasets` field.
#'
#' @returns `TRUE` when the record has no completed dataset schemas.

schema_needs_completion <- function(record) {
  datasets <- record_dataset_entries(record)

  length(datasets) == 0L ||
    all(purrr::map_lgl(datasets, dataset_needs_completion))
}


#' Check whether a screening record uses the nested dataset layout
#'
#' This helper detects the supported record structure, where dataset schemas are
#' stored under the top-level `datasets` field.
#'
#' @param record A candidate screening record.
#'
#' @returns `TRUE` when `record` has a top-level `datasets` field.

record_has_nested_datasets <- function(record) {
  is.list(record) && "datasets" %in% names(record)
}


#' Check whether a screening record still contains top-level schema fields
#'
#' Flat top-level schema fields are no longer supported. This helper is used to
#' detect that invalid layout before dataset processing continues.
#'
#' @param record A candidate screening record.
#'
#' @returns `TRUE` when `record` contains any dataset-schema field at top level.

record_has_flat_schema_fields <- function(record) {
  schema_fields <- names(new_schema_template())

  is.list(record) && any(schema_fields %in% names(record))
}


#' Extract dataset-schema entries from a screening record
#'
#' Supported records store dataset schemas under the top-level `datasets`
#' field. Records with deprecated flat top-level schema fields abort with a
#' layout error instead of being coerced.
#'
#' @param record A screening record.
#'
#' @returns A list of dataset-schema entries, or an empty list for
#'   screening-only records.

record_dataset_entries <- function(record) {
  if (record_has_nested_datasets(record)) {
    return(record$datasets %||% list())
  }
  if (record_has_flat_schema_fields(record)) {
    cli::cli_abort(
      "Found legacy flat schema fields in a source record. Convert the record to nested {.field datasets} layout before continuing."
    )
  }

  list()
}


flatten_record_dataset <- function(record, dataset, path, dataset_index) {
  schema_fields <- names(new_schema_template())
  top_level <- record[setdiff(names(record), c(schema_fields, "datasets"))]

  c(
    top_level,
    dataset,
    list(
      schema_path = path,
      dataset_index = dataset_index
    )
  )
}


format_dataset_schema_label <- function(source) {
  path <- source$schema_path %||% "<unknown path>"

  if (
    is.character(source$source_id) &&
      length(source$source_id) == 1L &&
      !is.na(source$source_id) &&
      stringr::str_trim(source$source_id) != ""
  ) {
    paste0(path, " (source_id: ", source$source_id, ")")
  } else {
    paste0(path, " (dataset ", source$dataset_index, ")")
  }
}


#' List source records ready for the validation database build
#'
#' Screening-only records are ignored. Draft schemas are reported and skipped.
#' A record containing schema fields must retain a `proceed` screening decision.
#'
#' @param sources_dir Directory containing one YAML file per screened dataset.
#'
#' @returns A named list of build-ready source records, one per dataset.

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

  duplicated_dois <- unique(dois[!is.na(dois) & duplicated(dois)])
  if (length(duplicated_dois) > 0L) {
    cli::cli_abort(
      "DOI{?s} {duplicated_dois} occur{?s} in multiple source records."
    )
  }

  sources <- purrr::imap(records, function(record, record_name) {
    datasets <- record_dataset_entries(record)
    if (length(datasets) == 0L) {
      return(list())
    }

    path <- file.path(sources_dir, paste0(record_name, ".yaml"))
    if (!identical(record$screening$decision, "proceed")) {
      cli::cli_abort(
        "Source record {.path {path}} contain{?s} a schema without a
         {.val proceed} screening decision."
      )
    }

    purrr::imap(datasets, function(dataset, dataset_index) {
      flatten_record_dataset(record, dataset, path, dataset_index)
    })
  }) |>
    purrr::flatten()

  if (length(sources) == 0L) {
    cli::cli_abort(
      "No completed source schemas were found in {.path {sources_dir}}."
    )
  }

  draft_sources <- purrr::keep(sources, dataset_needs_completion)
  if (length(draft_sources) > 0L) {
    labels <- purrr::map_chr(draft_sources, format_dataset_schema_label)
    cli::cli_warn(
      "Skipping draft source schema{?s} {.path {labels}}. Complete the
       placeholder values before building the database."
    )
  }

  build_sources <- purrr::discard(sources, dataset_needs_completion)
  if (length(build_sources) == 0L) {
    cli::cli_abort(
      "No completed source schemas were found in {.path {sources_dir}}."
    )
  }

  names(build_sources) <- purrr::map_chr(build_sources, "source_id")
  build_sources
}


#' Check if a value is a single non-empty string
#'
#' @param value A value to check.
#'
#' @returns `TRUE` if `value` is a single non-empty string, `FALSE` otherwise.
#'
#' @keywords internal

scalar_string <- function(value) {
  is.character(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    stringr::str_length(stringr::str_trim(value)) > 0L
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
  # row_filter is optional and may be absent in existing schemas; exclude it
  # from required-field check. All other template fields are mandatory.
  # TODO: coordinates and temporal could also be made optional in future to
  # reduce boilerplate for schemas that don't use spatial/temporal metadata.
  template_fields <- names(new_schema_template())
  required_fields <- setdiff(template_fields, "row_filter")
  missing_fields <- setdiff(required_fields, names(source))
  if (length(missing_fields) > 0L) {
    cli::cli_abort(
      "Source schema {.path {path}} is missing required field{?s} \
       {.field {missing_fields}}."
    )
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
    !is.integer(source$skip_rows) ||
      length(source$skip_rows) != 1L ||
      is.na(source$skip_rows) ||
      source$skip_rows < 0
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

  # Validate row_filter: optional, must be character vector with no blanks
  # and each clause must parse as valid R expression. Applied during build
  # with AND semantics: all clauses must evaluate to TRUE for a row to be kept.
  if (!is.null(source$row_filter)) {
    if (!is.character(source$row_filter) || length(source$row_filter) == 0L) {
      cli::cli_abort(
        "Source schema {.path {path}} {.field row_filter} must be NULL or a \
         non-empty character vector."
      )
    }
    # Check for blank clauses
    blank_clauses <- which(
      is.na(source$row_filter) |
        stringr::str_length(
          stringr::str_trim(source$row_filter)
        ) ==
          0L
    )
    if (length(blank_clauses) > 0L) {
      cli::cli_abort(
        "Source schema {.path {path}} {.field row_filter} has blank clauses at \
         position{?s} {blank_clauses}."
      )
    }
    # Check that each clause parses as valid R expression. Column names are
    # validated at evaluation time during the build, not here.
    for (i in seq_along(source$row_filter)) {
      tryCatch(
        rlang::parse_expr(source$row_filter[[i]]),
        error = function(e) {
          cli::cli_abort(
            "Source schema {.path {path}} {.field row_filter} clause {i} is not \
             a valid R expression: {source$row_filter[[i]]}.",
            parent = e
          )
        }
      )
    }
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
  purrr::iwalk(sources, function(source, source_id) {
    validate_source_schema(
      source,
      source$schema_path %||% file.path(sources_dir, paste0(source_id, ".yaml"))
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

  # Extract coordinate column names if specified
  coord_cols <- c(
    source$coordinates$latitude_column,
    source$coordinates$longitude_column
  )
  coord_cols <- coord_cols[!is.na(coord_cols) & !is.null(coord_cols)]

  data <- dplyr::select(
    data,
    tidyr::all_of(c(source$dedup_key, available_measurements)),
    tidyr::any_of(coord_cols)
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
#' Adds one nested dataset template under `datasets` to an existing screening
#' record. The record must have a `proceed` decision and must not already
#' contain a schema. Existing screening and DOI metadata fields are preserved.
#'
#' The updated record is written to a temporary file, read back to verify the
#' YAML round trip, and then moved to the original record path. To amend an
#' existing schema, edit the YAML record directly.
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
  if (
    record_has_nested_datasets(record) || record_has_flat_schema_fields(record)
  ) {
    cli::cli_abort(c(
      "DOI {.val {doi}} already has a schema.",
      "i" = "Edit the existing YAML record directly instead of initialising a new schema."
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

  updated_record <- c(record, list(datasets = list(new_schema_template())))
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
#'   "data", "derived", module_name, "validation", "sources"
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
