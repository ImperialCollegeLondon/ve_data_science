# This file contains both parts of the Shiny application:
#
# 1. UI functions describe what appears in the browser.
# 2. Server functions define how the app reacts to user actions.
#
# The remaining functions are ordinary R helpers. Keeping file and data logic
# outside the server makes that logic easier to understand and test.

# Convert YAML records into a rectangular data frame suitable for a Shiny
# table. The dashboard shows one row per dataset for `proceed` records, with a
# placeholder row for screening-only records that have not yet been initialised.
dataset_schema_status <- function(record, dataset = NULL) {
  if (is.null(dataset)) {
    return("Not started")
  }
  if (record_has_nested_datasets(record)) {
    if (dataset_needs_completion(dataset)) "Draft" else "Complete"
  } else {
    if (dataset_needs_completion(dataset)) "Legacy draft" else "Legacy complete"
  }
}


record_rows_for_dashboard <- function(record) {
  if (!is.list(record) || !identical(record$screening$decision, "proceed")) {
    return(list())
  }

  title <- record$metadata$title %||% ""
  year <- as.integer(record$metadata$year %||% NA_integer_)
  notes <- record$screening$notes %||% ""
  screened_at <- record$screening$screened_at %||% ""

  if (record_has_nested_datasets(record)) {
    return(purrr::imap(record$datasets, function(dataset, dataset_index) {
      data.frame(
        doi = record$doi,
        title = title,
        year = year,
        notes = notes,
        source_id = dataset$source_id %||% "",
        schema_status = dataset_schema_status(record, dataset),
        screened_at = screened_at,
        dataset_index = as.integer(dataset_index),
        layout = "nested"
      )
    }))
  }

  if (record_has_legacy_flat_schema(record)) {
    dataset <- record_dataset_entries(record)[[1]]
    return(list(data.frame(
      doi = record$doi,
      title = title,
      year = year,
      notes = notes,
      source_id = dataset$source_id %||% "",
      schema_status = dataset_schema_status(record, dataset),
      screened_at = screened_at,
      dataset_index = 1L,
      layout = "legacy_flat"
    )))
  }

  list(data.frame(
    doi = record$doi,
    title = title,
    year = year,
    notes = notes,
    source_id = "",
    schema_status = dataset_schema_status(record, NULL),
    screened_at = screened_at,
    dataset_index = NA_integer_,
    layout = "screening_only"
  ))
}


pending_schema_records <- function(records) {
  rows <- records |>
    lapply(record_rows_for_dashboard) |>
    unlist(recursive = FALSE)

  if (length(rows) == 0L) {
    return(data.frame(
      doi = character(),
      title = character(),
      year = integer(),
      notes = character(),
      source_id = character(),
      schema_status = character(),
      screened_at = character(),
      dataset_index = integer(),
      layout = character()
    ))
  }

  do.call(rbind, rows)
}


# bslib's code editor accepts one character string, whereas readLines() returns
# one string per line. Join the lines before sending the YAML to the browser.
read_yaml_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}


# Validate and safely save text received from the browser editor. Browser input
# must be treated as untrusted: it may contain invalid YAML or may accidentally
# change the identity fields that connect a DOI to its canonical filename.
save_yaml_record <- function(yaml_text, path) {
  record <- tryCatch(
    yaml::yaml.load(yaml_text),
    error = function(error) {
      cli::cli_abort("The edited text is not valid YAML.", parent = error)
    }
  )

  if (!is.list(record) || is.null(record$doi) || is.null(record$record_id)) {
    cli::cli_abort("The YAML must contain {.field doi} and {.field record_id}.")
  }

  doi <- normalise_doi(record$doi)
  expected_record_id <- doi_to_record_id(doi)
  if (
    !identical(record$doi, doi) ||
      !identical(record$record_id, expected_record_id) ||
      !identical(basename(path), paste0(expected_record_id, ".yaml"))
  ) {
    cli::cli_abort("The YAML DOI, record ID, and filename are inconsistent.")
  }
  if (!file.exists(path)) {
    cli::cli_abort("YAML record {.path {path}} does not exist.")
  }

  has_nested <- record_has_nested_datasets(record)
  has_legacy <- record_has_legacy_flat_schema(record)
  if (has_nested && has_legacy) {
    cli::cli_abort(
      "The YAML mixes legacy top-level schema fields with a {.field datasets} list. Use one layout only."
    )
  }
  if (has_nested) {
    if (!is.list(record$datasets) || length(record$datasets) == 0L) {
      cli::cli_abort(
        "The {.field datasets} field must contain at least one dataset entry."
      )
    }
  }

  temporary <- tempfile(
    pattern = paste0(".", expected_record_id, "-"),
    tmpdir = dirname(path),
    fileext = ".yaml"
  )
  backup <- tempfile(
    pattern = paste0(".", expected_record_id, "-backup-"),
    tmpdir = dirname(path),
    fileext = ".yaml"
  )
  on.exit(unlink(c(temporary, backup)), add = TRUE)

  writeLines(yaml_text, temporary, useBytes = TRUE)
  round_trip <- yaml::read_yaml(temporary)
  if (!identical(record, round_trip)) {
    cli::cli_abort("The edited record changed during YAML serialisation.")
  }

  if (!file.rename(path, backup)) {
    cli::cli_abort("Could not prepare YAML record {.path {path}} for update.")
  }
  if (!file.rename(temporary, path)) {
    restored <- file.rename(backup, path)
    if (!restored) {
      cli::cli_abort("Could not save or restore YAML record {.path {path}}.")
    }
    cli::cli_abort("Could not save YAML record {.path {path}}.")
  }
  unlink(backup)

  invisible(path)
}


# Render dataset rows as a Bootstrap table with an action beside each source.
pending_records_table <- function(records) {
  headings <- c(
    "DOI",
    "Title",
    "Year",
    "Notes",
    "Source ID",
    "Schema status",
    "Screened at",
    ""
  )

  shiny::tags$table(
    class = paste(
      "table table-striped table-hover align-middle",
      "pending-records-table"
    ),
    shiny::tags$thead(
      shiny::tags$tr(lapply(headings, shiny::tags$th, scope = "col"))
    ),
    shiny::tags$tbody(
      lapply(seq_len(nrow(records)), function(index) {
        record <- records[index, , drop = FALSE]
        dataset_index_js <- if (is.na(record$dataset_index)) {
          "null"
        } else {
          as.character(record$dataset_index)
        }
        onclick <- paste0(
          "Shiny.setInputValue('open_schema', ",
          "{doi: '",
          record$doi,
          "', dataset_index: ",
          dataset_index_js,
          ", source_id: '",
          record$source_id,
          "'}, ",
          "{priority: 'event'});"
        )

        shiny::tags$tr(
          shiny::tags$td(record$doi),
          shiny::tags$td(record$title),
          shiny::tags$td(record$year),
          shiny::tags$td(record$notes),
          shiny::tags$td(record$source_id),
          shiny::tags$td(record$schema_status),
          shiny::tags$td(record$screened_at),
          shiny::tags$td(
            shiny::tags$button(
              type = "button",
              class = "btn btn-primary btn-sm open-schema",
              `data-doi` = record$doi,
              `data-source-id` = record$source_id,
              `data-dataset-index` = dataset_index_js,
              onclick = onclick,
              "Open record"
            )
          )
        )
      })
    )
  )
}


# Build the static browser interface. Input and output IDs connect controls to
# objects of the same name in the server function below.
schema_dashboard_ui <- function() {
  # page_sidebar() provides a Bootstrap 5 page with controls on the left and
  # the main dashboard content on the right.
  bslib::page_sidebar(
    title = "Validation schema dashboard",
    theme = bslib::bs_theme(version = 5),
    # tags$head() registers this stylesheet in the document head. Passing a
    # `header` argument would not work because page_sidebar() has no such
    # argument and would treat it as an HTML attribute on the page body.
    shiny::tags$head(
      shiny::tags$style(shiny::HTML(paste(
        ".pending-records-table th,",
        ".pending-records-table td,",
        ".pending-records-table .btn {",
        "  font-size: 12px !important;",
        "}",
        "",
        "#yaml_editor .prism-code-editor,",
        "#yaml_editor .pce-wrapper,",
        "#yaml_editor .pce-textarea,",
        "#yaml_editor .pce-line,",
        "#yaml_editor .pce-line * {",
        "  font-family: Consolas, 'Courier New', monospace !important;",
        "  font-size: 14px !important;",
        "  line-height: 1.4 !important;",
        "  letter-spacing: 0 !important;",
        "  font-kerning: none !important;",
        "  font-variant-ligatures: none !important;",
        "  font-feature-settings: 'liga' 0, 'calt' 0 !important;",
        "}",
        sep = "\n"
      )))
    ),
    sidebar = bslib::sidebar(
      shiny::actionButton("refresh", "Refresh records"),
      bslib::input_dark_mode(id = "dark_mode"),
      shiny::helpText(
        "The table shows one row per dataset for proceed records. Opening a row ",
        "loads the full per-DOI YAML file into the browser editor. Add more ",
        "datasets by editing the nested `datasets:` list manually."
      )
    ),
    # Bootstrap divides each row into 12 columns. Giving each card all 12
    # columns stacks the table and editor vertically at the full page width.
    bslib::layout_columns(
      col_widths = c(12, 12),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Proceed records by dataset"),
        shiny::uiOutput("pending_records")
      ),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header(
          "YAML editor",
          shiny::span(
            shiny::textOutput("editor_path", inline = TRUE),
            class = "text-body-secondary small ms-2"
          )
        ),
        # This input runs a code editor in the browser. Its current text is
        # available to the server as input$yaml_editor.
        bslib::input_code_editor(
          "yaml_editor",
          language = "yaml",
          height = "500px",
          line_numbers = TRUE,
          word_wrap = FALSE
        ),
        bslib::card_footer(
          shiny::actionButton("save_yaml", "Save YAML", class = "btn-primary"),
          shiny::actionButton("open_editor", "Open in desktop editor")
        )
      )
    )
  )
}


# Create the server function that runs once for each browser session. Returning
# a function here lets callers configure the source directory and desktop
# editor while retaining Shiny's required function(input, output, session)
# signature.
schema_dashboard_server <- function(
  sources_dir,
  .editor = utils::file.edit
) {
  # Evaluate the configuration arguments before returning the server function.
  # R arguments are lazy, so this ensures the closure captures their current
  # values rather than evaluating them later when a session starts.
  force(sources_dir)
  force(.editor)

  function(input, output, session) {
    # reactiveVal() stores one value and tells dependent reactive code when that
    # value changes. Incrementing refresh_token triggers a fresh filesystem read.
    refresh_token <- shiny::reactiveVal(0L)

    # Keep the loaded record's path on the server. The browser edits text but
    # does not choose arbitrary filesystem paths.
    editor_path <- shiny::reactiveVal(NULL)
    editor_context <- shiny::reactiveVal("No record loaded")

    # A reactive expression caches its result and recomputes when a reactive
    # dependency changes. Calling refresh_token() establishes that dependency.
    pending <- shiny::reactive({
      refresh_token()
      list_screening_records(sources_dir) |>
        pending_schema_records()
    })

    # renderUI() rebuilds the table when pending records change. Each row has
    # its own Open schema button carrying that record's DOI.
    output$pending_records <- shiny::renderUI({
      pending_records_table(pending())
    })

    # Display only the filename to avoid exposing a long machine-specific path.
    output$editor_path <- shiny::renderText({
      path <- editor_path()
      if (is.null(path)) {
        editor_context()
      } else {
        paste0(basename(path), " — ", editor_context())
      }
    })

    # observeEvent() runs its body in response to an event. Action buttons hold
    # an integer click count, so each click triggers this observer.
    shiny::observeEvent(input$refresh, {
      refresh_token(refresh_token() + 1L)
    })

    # Open the record requested by a row button. req() stops this observer
    # quietly if no DOI was supplied, avoiding operations with an empty value.
    shiny::observeEvent(input$open_schema, {
      shiny::req(input$open_schema)

      tryCatch(
        {
          request <- input$open_schema
          doi <- request$doi
          dataset_index <- request$dataset_index
          source_id <- request$source_id %||% ""
          record <- find_screening_record(doi, sources_dir)

          path <- if (
            !record_has_nested_datasets(record) &&
              !record_has_legacy_flat_schema(record)
          ) {
            initialise_source_schema(doi, sources_dir)
          } else {
            file.path(sources_dir, paste0(record$record_id, ".yaml"))
          }
          editor_path(path)

          if (!is.null(dataset_index) && !is.na(dataset_index)) {
            editor_context(paste0("dataset ", dataset_index, ": ", source_id))
          } else {
            editor_context("new dataset schema")
          }

          bslib::update_code_editor(
            "yaml_editor",
            value = read_yaml_text(path),
            language = "yaml",
            session = session
          )
          refresh_token(refresh_token() + 1L)
          shiny::showNotification(
            "Record loaded into the YAML editor.",
            type = "message"
          )
        },
        error = function(error) {
          shiny::showNotification(conditionMessage(error), type = "error")
        }
      )
    })

    # Saving is deliberately separate from editing. Nothing is written until
    # the user presses Save YAML.
    shiny::observeEvent(input$save_yaml, {
      shiny::req(editor_path(), input$yaml_editor)

      tryCatch(
        {
          save_yaml_record(input$yaml_editor, editor_path())
          refresh_token(refresh_token() + 1L)
          shiny::showNotification("YAML record saved.", type = "message")
        },
        error = function(error) {
          shiny::showNotification(conditionMessage(error), type = "error")
        }
      )
    })

    # The desktop editor is an optional escape hatch for users who prefer their
    # normal IDE. The injected .editor argument also keeps this action testable.
    shiny::observeEvent(input$open_editor, {
      shiny::req(editor_path())
      .editor(editor_path())
    })
  }
}
