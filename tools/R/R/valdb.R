#| ---
#| title: Functions to build a validation database
#|
#| description: |
#|     Here we use a config-driven pipeline to read, wrangle, unit-convert, and
#|     combine multiple datasets into a single master file, hereafter referred to as
#|     the "validation database". We are not aiming for a full database backend, instead
#|     the main goal is to avoid having to write many custom codes that each only work
#|     for one dataset. The idea to run a single script to build the database, while YAML
#|     config metadata handles all dataset-specific idiosyncracies.
#|     Please refer to `docs/validation_database.md` for a full documentation.
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
#|     - purrr
#|     - rcrossref
#|     - readr
#|     - rlang
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
#'   Currently hardcoded to the soil module; to relax this later.
#'
#' @returns A named list of screening records. Names are the source filenames
#'   without their `.yaml` extension.
#'
#' @export

list_screening_records <- function(
  sources_dir = "data/derived/soil/validation/config/sources"
) {
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
  sources_dir = "data/derived/soil/validation/config/sources"
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
#'   Currently hardcoded to the soil module; to relax this later.
#'
#' @returns The path of the new YAML file.
#'
#' @export

write_screening_record <- function(
  record,
  sources_dir = "data/derived/soil/validation/config/sources"
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
#'   Currently defaults to the soil module; to be relaxed later.
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
#' valdb$screen_dataset()

screen_dataset <- function(
  sources_dir = "data/derived/soil/validation/config/sources",
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
#' @returns A named list containing placeholders for `source_id`, `data_file`,
#'   `skip_rows`, `variables`, and `dedup_key`.
#'
#' @export

new_schema_template <- function() {
  list(
    source_id = "author_year",
    data_file = "data/primary/soil/author_year/*.csv",
    skip_rows = 0L,
    variables = list(
      var_original_1 = list(
        var_canonical = "var_ve_1",
        unit = "unit",
        description = NULL
      )
    ),
    dedup_key = c("sample_id", "date", "site_id")
  )
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
#'   Currently defaults to the soil module; to be relaxed later.
#'
#' @returns The path of the updated YAML file.
#'
#' @export

initialise_source_schema <- function(
  doi,
  sources_dir = "data/derived/soil/validation/config/sources"
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
#'   Currently defaults to the soil module; to be relaxed later.
#' @param .editor Function used to open the YAML file. This supports tests and
#'   normally should not be changed.
#'
#' @returns Invisibly, the path of the updated YAML file.
#'
#' @export
#' @examples
#' box::use(tools/R/R/valdb)
#' valdb$add_schema("10.5281/zenodo.8158810")

add_schema <- function(
  doi,
  sources_dir = "data/derived/soil/validation/config/sources",
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
#' @param config_dir Path to where the dataset YAML config files are stored.
#' @param db_path Output path for the harmonised database.
#'
#' @returns A harmonised database stored in db_path. Currently it is written out
#'   in the parquet format for efficient compression (and possibly appending).
#'   We may consider a plain csv in the future.
#'
#' @export
#' @examples
#' box::use(tools/R/valdb)
#' valdb$build_validation_database()

build_validation_database <- function(
  config_dir = "data/derived/soil/validation/config",
  db_path = "data/derived/soil/validation/database"
) {
  # Configs ----------------------------------------------------------------

  # load unit conversions
  # the CSV file needs to be manually updated when there is a new unit_from and
  # unit_to pairs
  unit_conversions <-
    readr::read_csv(
      file.path(config_dir, "unit_conversions.csv"),
      show_col_types = FALSE
    ) |>
    # convert literal function to function objects
    dplyr::mutate(
      convert_unit = purrr::map(
        `function`,
        ~ rlang::as_function(stats::as.formula(paste("~", gsub("x", ".x", .x))))
      )
    )

  # load canonical unit of VE data variables
  # this YAML file is generated by tools/R/build_data_variables_table.R, which
  # should be re-run once when there is any update to VE's data variable TOML
  units <-
    build_data_variables_table() |>
    tibble::enframe(name = "var_canonical") |>
    tidyr::unnest_wider(value) |>
    dplyr::select(var_canonical, unit_to = unit)

  # Ingest datasets --------------------------------------------------------

  # path to source datasets
  sources_dir <- file.path(config_dir, "sources")
  sources_files <- list.files(
    sources_dir,
    pattern = "\\.yaml$",
    full.names = TRUE
  )

  # read the metadata of data sources
  sources <-
    sources_files |>
    purrr::map(yaml::read_yaml) |>
    # filter and keep only sources that has the source_id entry
    purrr::keep(~ purrr::pluck_exists(.x, "source_id"))

  # Harmonise each dataset
  data_harmonised <-
    sources |>
    purrr::map(\(source_dat) {
      # read dataset csv file
      readr::read_csv(
        source_dat$data_file,
        show_col_types = FALSE,
        skip = source_dat$skip_rows
      ) |>
        # select the relevant columns: unique IDs and validation variables
        dplyr::select(tidyr::all_of(c(
          source_dat$dedup_key,
          names(source_dat$variables)
        ))) |>
        # combine dedup keys into a single ID column
        tidyr::unite("ID", tidyr::all_of(source_dat$dedup_key)) |>
        # pivot to long format because this is the easiest way to convert units and
        # remove NAs
        tidyr::pivot_longer(
          cols = names(source_dat$variables),
          names_to = "var_original"
        ) |>
        dplyr::filter(!is.na(value)) |>
        # join variable information,
        # including unit and target validation variable
        dplyr::left_join(
          source_dat$variables |>
            tibble::enframe(name = "var_original") |>
            tidyr::unnest_wider(value),
          by = dplyr::join_by(var_original)
        ) |>
        # Unit conversion
        dplyr::rename(unit_from = unit) |>
        # join canonical or target units
        dplyr::left_join(units, by = dplyr::join_by(var_canonical)) |>
        # join conversion function
        dplyr::left_join(
          unit_conversions,
          by = dplyr::join_by(unit_from, unit_to)
        ) |>
        # convert the unit finally
        dplyr::mutate(
          value_canonical = purrr::map2_dbl(value, convert_unit, ~ .y(.x))
        ) |>
        # add the source ID
        dplyr::mutate(dataset = source_dat$source_id)
    })

  # combine datasets into a database
  database <-
    data_harmonised |>
    purrr::list_rbind() |>
    dplyr::select(
      dataset,
      ID,
      var_original,
      value_original = value,
      var_canonical,
      unit_from,
      unit_to,
      value_canonical
    )

  # Write database ---------------------------------------------------------
  database |>
    dplyr::group_by(dataset) |>
    arrow::write_dataset(db_path, format = "parquet")

  # print message on write
  cli::cli_alert_success("Database saved to {db_path}.")
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
#' @param variables_derived Path to the custom derived variable TOML table.
#'   Currently it defaults to the soil module.
#'
#' @returns A list of metadata of canonical VE and/or derived data variables.

build_data_variables_table <- function(
  variables_ve = "https://github.com/ImperialCollegeLondon/virtual_ecosystem/raw/refs/heads/develop/virtual_ecosystem/data_variables.toml",
  variables_derived = "data/derived/soil/validation/config/derived_variables.toml"
) {
  var_list <- import_variables_table(variables_ve)
  if (!is.null(variables_derived)) {
    var_list <- c(var_list, import_variables_table(variables_derived))
  }
  return(var_list)
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
