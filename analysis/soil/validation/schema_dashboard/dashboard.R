# This file contains both parts of the Shiny application:
#
# 1. UI functions describe what appears in the browser.
# 2. Server functions define how the app reacts to user actions.
#
# The remaining functions are ordinary R helpers. Keeping file and data logic
# outside the server makes that logic easier to understand and test.

# Decide whether a record should remain in the dashboard's to-do list. A schema
# is incomplete if it has not been created or still contains any value copied
# from the starter template.
schema_needs_completion <- function(record) {
  template <- new_schema_template()

  is.null(record$source_id) ||
    identical(record$source_id, template$source_id) ||
    identical(record$data_file, template$data_file) ||
    identical(record$variables, template$variables) ||
    identical(record$dedup_key, template$dedup_key)
}


# Convert the nested YAML records into a rectangular data frame suitable for a
# Shiny table. Only datasets approved with a `proceed` decision and requiring
# further schema work are shown.
pending_schema_records <- function(records) {
  pending <- Filter(
    function(record) {
      is.list(record) &&
        identical(record$screening$decision, "proceed") &&
        schema_needs_completion(record)
    },
    records
  )

  # Return an empty data frame with the normal columns. This allows the table
  # renderer to keep working when there are no outstanding records.
  if (length(pending) == 0L) {
    return(data.frame(
      doi = character(),
      title = character(),
      year = integer(),
      notes = character(),
      schema_status = character(),
      screened_at = character()
    ))
  }

  # Each YAML record is a nested list. Extract only the fields needed by the
  # dashboard, producing one data-frame row per record.
  rows <- lapply(pending, function(record) {
    data.frame(
      doi = record$doi,
      title = record$metadata$title %||% "",
      year = as.integer(record$metadata$year %||% NA_integer_),
      notes = record$screening$notes %||% "",
      schema_status = if (is.null(record$source_id)) {
        "Not started"
      } else {
        "Draft"
      },
      screened_at = record$screening$screened_at %||% ""
    )
  })

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
  # Parse the text before touching the existing file. tryCatch() converts the
  # parser's technical error into a concise message suitable for the UI.
  record <- tryCatch(
    yaml::yaml.load(yaml_text),
    error = function(error) {
      cli::cli_abort("The edited text is not valid YAML.", parent = error)
    }
  )

  if (!is.list(record) || is.null(record$doi) || is.null(record$record_id)) {
    cli::cli_abort("The YAML must contain {.field doi} and {.field record_id}.")
  }

  # These three identity values must agree. The dashboard supports editing a
  # schema, not moving one DOI's contents into another DOI's record.
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

  # Write and verify a temporary file first. The original record is preserved
  # until the edited YAML has passed a complete read-back check.
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

  # Replace the original through a backup. If installing the edited file fails,
  # the function attempts to restore the original record.
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


# Render pending records as a Bootstrap table with an action beside each source.
# The data DOI identifies the record without exposing a filesystem path.
pending_records_table <- function(records) {
  headings <- c(
    "DOI",
    "Title",
    "Year",
    "Notes",
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
        shiny::tags$tr(
          shiny::tags$td(record$doi),
          shiny::tags$td(record$title),
          shiny::tags$td(record$year),
          shiny::tags$td(record$notes),
          shiny::tags$td(record$schema_status),
          shiny::tags$td(record$screened_at),
          shiny::tags$td(
            shiny::tags$button(
              type = "button",
              class = "btn btn-primary btn-sm open-schema",
              `data-doi` = record$doi,
              onclick = paste(
                "Shiny.setInputValue(",
                "'open_schema', this.dataset.doi, {priority: 'event'});"
              ),
              "Open schema"
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
        "Opening adds a schema template when needed, then loads the YAML ",
        "record into the browser editor. Drafts remain in the to-do list."
      )
    ),
    # Bootstrap divides each row into 12 columns. Giving each card all 12
    # columns stacks the table and editor vertically at the full page width.
    bslib::layout_columns(
      col_widths = c(12, 12),
      bslib::card(
        full_screen = TRUE,
        bslib::card_header("Proceed records awaiting schemas"),
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
      if (is.null(path)) "No record loaded" else basename(path)
    })

    # observeEvent() runs its body in response to an event. Action buttons hold
    # an integer click count, so each click triggers this observer.
    shiny::observeEvent(input$refresh, {
      refresh_token(refresh_token() + 1L)
    })

    # Open the schema requested by a row button. req() stops this observer
    # quietly if no DOI was supplied, avoiding operations with an empty value.
    shiny::observeEvent(input$open_schema, {
      shiny::req(input$open_schema)

      tryCatch(
        {
          doi <- input$open_schema
          record <- find_screening_record(doi, sources_dir)

          # Initialise only a new schema. Existing drafts must be reopened
          # without overwriting work already saved in their YAML records.
          path <- if (is.null(record$source_id)) {
            initialise_source_schema(doi, sources_dir)
          } else {
            file.path(sources_dir, paste0(record$record_id, ".yaml"))
          }
          editor_path(path)

          # update_code_editor() sends the file contents from R to the existing
          # browser editor widget; it does not save changes back to disk.
          bslib::update_code_editor(
            "yaml_editor",
            value = read_yaml_text(path),
            language = "yaml",
            session = session
          )
          refresh_token(refresh_token() + 1L)
          shiny::showNotification(
            "Schema loaded into the YAML editor.",
            type = "message"
          )
        },
        # File and validation errors appear as notifications rather than ending
        # the Shiny session and disconnecting the browser.
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
