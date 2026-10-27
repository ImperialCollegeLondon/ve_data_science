#| ---
#| title: Generate the soil constant metadata review workbook
#|
#| description: |
#|   Converts the generated Virtual Ecosystem constant-usage TOML database into
#|   an Excel/LibreOffice workbook for rapid review of soil constants. Generated
#|   metadata is protected; reviewers record only an overall status, an optional
#|   pipeline issue category, a comment, and decisions requested by the pipeline.
#|
#| VE_module: Soil
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: ve_constant_usage.toml
#|     path: data/derived/soil/llm/
#|     description: |
#|       Generated constant metadata, classified reference sites, function
#|       descriptions, and source-code provenance.
#|
#| output_files:
#|   - name: soil_constant_review.xlsx
#|     path: data/derived/soil/llm/
#|     description: |
#|       Soil-only review workbook with protected generated fields and editable
#|       review columns.
#|
#| package_dependencies:
#|   - RcppTOML
#|   - dplyr
#|   - purrr
#|   - tibble
#|   - stringr
#|   - openxlsx2
#|   - here
#|
#| usage_notes: |
#|   Re-run whenever ve_constant_usage.toml changes. Declaration and reference
#|   links are pinned to the Virtual Ecosystem commit recorded in the TOML.
#|   The human_decision field is enabled only for constants with at least one
#|   derived_forward reference, which the extraction pipeline marks for manual
#|   interpretation.
#| ---

library(dplyr)
library(here)
library(openxlsx2)
library(purrr)
library(stringr)
library(tibble)

input_file <- here("data/derived/soil/llm/ve_constant_usage.toml")
output_file <- here("data/derived/soil/llm/soil_constant_review.xlsx")
soil_module_prefix <- "virtual_ecosystem.models.soil"
ve_repository_url <-
  "https://github.com/ImperialCollegeLondon/virtual_ecosystem"

collapse_values <- function(values) {
  values <- unique(values[nzchar(values)])
  paste(values, collapse = "; ")
}

source_url <- function(repository_url, commit, file, line) {
  paste0(repository_url, "/blob/", commit, "/", file, "#L", line)
}

summarise_references <- function(references, function_docs) {
  if (length(references) == 0) {
    return("No reference sites found")
  }

  map2_chr(references, seq_along(references), function(reference, index) {
    context_name <- reference$consumer
    if (!nzchar(context_name)) {
      context_name <- reference$caller
    }
    context_doc <- function_docs[[context_name]]
    if (is.null(context_doc)) {
      context_doc <- ""
    }

    parts <- c(
      paste0("Reference ", index),
      paste0(reference$file, ":", reference$line),
      reference$usage_kind,
      reference$expression,
      context_name,
      context_doc
    )
    paste(parts[nzchar(parts)], collapse = " | ")
  }) |>
    paste(collapse = "\n")
}

attention_flags <- function(record) {
  references <- record$referenced_in
  usage_kinds <- map_chr(references, "usage_kind")
  missing_consumer <- any(map_lgl(references, function(reference) {
    reference$usage_kind %in%
      c(
        "kwarg_forward",
        "positional_forward",
        "derived_forward",
        "instantiation"
      ) &&
      !nzchar(reference$consumer)
  }))

  flags <- c(
    if (!nzchar(str_trim(record$docstring))) "missing_docstring",
    if (length(references) == 0) "no_references",
    if ("derived_forward" %in% usage_kinds) "derived_forward",
    if ("unresolved" %in% usage_kinds) "unresolved",
    if (missing_consumer) "missing_consumer"
  )
  paste(flags, collapse = "; ")
}

build_review_tables <- function(database) {
  required_sections <- c("metadata", "functions", "constants")
  missing_sections <- setdiff(required_sections, names(database))
  if (length(missing_sections) > 0) {
    stop(
      "Missing required TOML sections: ",
      paste(missing_sections, collapse = ", "),
      call. = FALSE
    )
  }

  commit <- database$metadata$project_commit
  if (is.null(commit) || !nzchar(commit)) {
    stop("The TOML metadata does not contain project_commit.", call. = FALSE)
  }

  soil_records <- database$constants |>
    keep(~ str_starts(.x$module, soil_module_prefix))

  review <- imap_dfr(soil_records, function(record, qualified_name) {
    references <- record$referenced_in
    usage_kinds <- map_chr(references, "usage_kind")
    requires_decision <- "derived_forward" %in% usage_kinds

    tibble(
      name = record$name,
      declaration_source = paste0(record$file, ":", record$line),
      docstring = record$docstring,
      default_expression = record$default_expression,
      type_annotation = record$type_annotation,
      reference_count = length(references),
      usage_kinds = collapse_values(usage_kinds),
      reference_summary = summarise_references(
        references,
        database$functions
      ),
      qualified_name = qualified_name,
      class_name = record$class_name,
      declaration = record$declaration,
      human_decision_required = requires_decision,
      attention_flags = attention_flags(record),
      review_status = "",
      issue_category = "",
      review_comment = "",
      human_decision = "",
      declaration_url = source_url(
        ve_repository_url,
        commit,
        record$file,
        record$line
      )
    )
  }) |>
    arrange(
      desc(human_decision_required),
      desc(nzchar(attention_flags)),
      class_name,
      name
    )

  references <- imap_dfr(soil_records, function(record, qualified_name) {
    if (length(record$referenced_in) == 0) {
      return(tibble())
    }

    map2_dfr(
      record$referenced_in,
      seq_along(record$referenced_in),
      function(reference, reference_index) {
        context_name <- reference$consumer
        if (!nzchar(context_name)) {
          context_name <- reference$caller
        }
        context_doc <- database$functions[[context_name]]
        if (is.null(context_doc)) {
          context_doc <- ""
        }

        tibble(
          qualified_name = qualified_name,
          name = record$name,
          reference_label = paste0("Reference ", reference_index),
          reference_index = reference_index,
          usage_kind = reference$usage_kind,
          expression = reference$expression,
          caller = reference$caller,
          consumer = reference$consumer,
          forwarded_as = reference$forwarded_as,
          context_docstring = context_doc,
          reference_source = paste0(reference$file, ":", reference$line),
          reference_url = source_url(
            ve_repository_url,
            commit,
            reference$file,
            reference$line
          )
        )
      }
    )
  })

  list(review = review, references = references)
}

add_external_links <- function(workbook, sheet, column, urls, labels) {
  column_letter <- int2col(column)
  walk2(seq_along(urls) + 1L, seq_along(urls), function(row, index) {
    workbook$add_formula(
      sheet = sheet,
      dims = paste0(column_letter, row),
      x = create_hyperlink(text = labels[[index]], file = urls[[index]])
    )
  })
}

style_table_sheet <- function(workbook, sheet, data, widths) {
  last_column <- int2col(ncol(data))
  last_row <- nrow(data) + 1L

  workbook$freeze_pane(sheet = sheet, first_active_row = 2)
  workbook$set_col_widths(
    sheet = sheet,
    cols = seq_along(widths),
    widths = widths
  )
  workbook$add_cell_style(
    sheet = sheet,
    dims = paste0("A1:", last_column, last_row),
    vertical = "top",
    wrap_text = TRUE
  )
  workbook$set_row_heights(sheet = sheet, rows = 2:last_row, heights = 45)
}

create_review_workbook <- function(database, review, references, path) {
  review_export <- review |>
    select(-declaration_url)
  references_export <- references |>
    select(-reference_url)

  instructions <- tibble(
    topic = c(
      "Purpose",
      "Fast review",
      "Review status",
      "Issue category",
      "Review comment",
      "Human decision",
      "Generated fields",
      "Source links"
    ),
    guidance = c(
      "Review soil constant metadata and report exceptions in the extraction pipeline.",
      "Read one row at a time. Mark ok when no discrepancy is found; investigate only flagged or suspicious records.",
      "Use ok, issue, uncertain, or not_applicable. A blank status means not yet reviewed.",
      "Classify an issue when useful. Do not use review fields to overwrite generated metadata.",
      "Describe the discrepancy and expected pipeline behaviour. Leave blank for records marked ok.",
      "Editable only when human_decision_required is TRUE. Record the interpretation requested by a derived_forward usage.",
      "Protected cells come from ve_constant_usage.toml. Fix errors in the Jedi-AST pipeline and regenerate the workbook.",
      "Declaration and reference cells link to GitHub at the exact reviewed commit."
    )
  )

  metadata_names <- c(
    "generated_at",
    "project_version",
    "project_commit",
    "project_branch",
    "project_describe",
    "project_source_modified",
    "project_upstream",
    "project_upstream_synced",
    "jedi_version",
    "python_version",
    "include_tests",
    "constant_count",
    "function_count"
  )
  metadata <- tibble(
    field = c(
      "workbook_scope",
      "soil_constant_count",
      metadata_names
    ),
    value = c(
      soil_module_prefix,
      as.character(nrow(review)),
      map_chr(metadata_names, function(name) {
        paste(database$metadata[[name]], collapse = "; ")
      })
    )
  )

  workbook <- wb_workbook(
    title = "Virtual Ecosystem soil constant metadata review",
    subject = "Review of Jedi-AST constant metadata",
    theme = "LibreOffice"
  )

  workbook$add_worksheet("Review")
  workbook$add_data_table(
    sheet = "Review",
    x = review_export,
    table_name = "soil_constant_review",
    table_style = "TableStyleMedium2",
    na = ""
  )
  style_table_sheet(
    workbook,
    "Review",
    review_export,
    widths = c(
      28,
      42,
      58,
      35,
      25,
      16,
      28,
      90,
      38,
      58,
      24,
      55,
      24,
      28,
      18,
      26
    )
  )

  workbook$add_worksheet("References")
  workbook$add_data_table(
    sheet = "References",
    x = references_export,
    table_name = "soil_constant_references",
    table_style = "TableStyleMedium2",
    na = ""
  )
  style_table_sheet(
    workbook,
    "References",
    references_export,
    widths = c(58, 28, 12, 22, 50, 50, 50, 18, 60, 42)
  )

  workbook$add_worksheet("Instructions")
  workbook$add_data_table(
    sheet = "Instructions",
    x = instructions,
    table_name = "review_instructions",
    table_style = "TableStyleMedium2"
  )
  style_table_sheet(workbook, "Instructions", instructions, c(24, 100))

  workbook$add_worksheet("Metadata")
  workbook$add_data_table(
    sheet = "Metadata",
    x = metadata,
    table_name = "review_metadata",
    table_style = "TableStyleMedium2"
  )
  style_table_sheet(workbook, "Metadata", metadata, c(35, 95))

  declaration_link_column <- match("declaration_source", names(review_export))
  reference_link_column <- match("reference_source", names(references_export))
  add_external_links(
    workbook,
    "Review",
    declaration_link_column,
    review$declaration_url,
    review$declaration_source
  )
  add_external_links(
    workbook,
    "References",
    reference_link_column,
    references$reference_url,
    references$reference_source
  )

  review_last_row <- nrow(review_export) + 1L
  editable_columns <- match(
    c(
      "review_status",
      "issue_category",
      "review_comment",
      "human_decision"
    ),
    names(review_export)
  )
  editable_dims <- paste0(
    int2col(min(editable_columns)),
    "2:",
    int2col(max(editable_columns)),
    review_last_row
  )
  workbook$add_cell_style(
    sheet = "Review",
    dims = editable_dims,
    locked = FALSE,
    apply_protection = TRUE
  )
  workbook$add_fill(
    sheet = "Review",
    dims = editable_dims,
    color = wb_color(hex = "FFFFF2CC")
  )

  human_decision_column <- int2col(match(
    "human_decision",
    names(review_export)
  ))
  ineligible_rows <- which(!review$human_decision_required) + 1L
  walk(ineligible_rows, function(row) {
    dims <- paste0(human_decision_column, row)
    workbook$add_cell_style(
      sheet = "Review",
      dims = dims,
      locked = TRUE,
      apply_protection = TRUE
    )
    workbook$add_fill(
      sheet = "Review",
      dims = dims,
      color = wb_color(hex = "FFE7E6E6")
    )
  })

  status_column <- int2col(match("review_status", names(review_export)))
  category_column <- int2col(match("issue_category", names(review_export)))
  workbook$add_data_validation(
    sheet = "Review",
    dims = paste0(status_column, "2:", status_column, review_last_row),
    type = "list",
    value = '"ok,issue,uncertain,not_applicable"',
    allow_blank = TRUE,
    error_title = "Invalid review status",
    error = "Choose a value from the list or leave the cell blank."
  )
  workbook$add_data_validation(
    sheet = "Review",
    dims = paste0(category_column, "2:", category_column, review_last_row),
    type = "list",
    value = paste0(
      '"wrong_reference,missing_reference,wrong_usage_kind,',
      'wrong_consumer,incomplete_context,other_pipeline_issue"'
    ),
    allow_blank = TRUE,
    error_title = "Invalid issue category",
    error = "Choose a value from the list or leave the cell blank."
  )

  flagged_rows <- which(nzchar(review$attention_flags)) + 1L
  if (length(flagged_rows) > 0) {
    attention_column <- int2col(match("attention_flags", names(review_export)))
    workbook$add_fill(
      sheet = "Review",
      dims = paste0(attention_column, flagged_rows),
      color = wb_color(hex = "FFFFC7CE")
    )
  }

  workbook$protect_worksheet(
    sheet = "Review",
    protect = TRUE,
    properties = c(
      "formatCells",
      "formatColumns",
      "formatRows",
      "insertColumns",
      "insertRows",
      "deleteColumns",
      "deleteRows"
    )
  )
  walk(c("References", "Instructions", "Metadata"), function(sheet) {
    workbook$protect_worksheet(
      sheet = sheet,
      protect = TRUE,
      properties = c(
        "formatCells",
        "formatColumns",
        "formatRows",
        "insertColumns",
        "insertRows",
        "deleteColumns",
        "deleteRows"
      )
    )
  })

  workbook$save(path, overwrite = TRUE)
  invisible(path)
}

if (!file.exists(input_file)) {
  stop("Input TOML does not exist: ", input_file, call. = FALSE)
}

database <- RcppTOML::parseTOML(input_file, escape = FALSE)
tables <- build_review_tables(database)

if (nrow(tables$review) == 0) {
  stop("No soil constants were found in the TOML database.", call. = FALSE)
}
if (anyDuplicated(tables$review$qualified_name)) {
  stop("Soil constants contain duplicate qualified names.", call. = FALSE)
}

create_review_workbook(
  database,
  tables$review,
  tables$references,
  output_file
)
