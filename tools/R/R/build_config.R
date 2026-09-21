#| ---
#| title: Build a compiled configuration TOML for the Virtual Ecosystem
#|
#| description: |
#|     Generate a single compiled TOML configuration file for the Virtual
#|     Ecosystem's ve_run command. Values are serialized with the toml package,
#|     while comments, section order, empty tables, and repeated
#|     [[core.data.variable]] blocks are assembled explicitly.
#|
#| VE_module: All
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
#|   - purrr
#|   - toml
#|
#| usage_notes: See details below
#| ---

#' Build a compiled configuration TOML for the Virtual Ecosystem
#'
#' Write a single compiled TOML configuration file for the Virtual Ecosystem's
#' `ve_run` command from pre-rendered lines. Scalar, vector, and table values
#' can be serialized with the helper renderers in this file, while the caller
#' retains control of section order, chosen module names, comments, and repeated
#' `[[core.data.variable]]` blocks.
#'
#' @param lines Character vector of TOML lines to write.
#' @param path Directory to save the compiled TOML configuration file.
#' @param file_name File name for the compiled TOML configuration file.
#'
#' @returns A compiled TOML configuration file saved in the specified path.

normalize_comment_lines <- function(lines) {
  if (is.null(lines) || length(lines) == 0) {
    return(character())
  }

  unname(as.character(lines))
}

trim_blank_tail <- function(lines) {
  while (length(lines) > 0 && identical(tail(lines, 1), "")) {
    lines <- lines[-length(lines)]
  }

  lines
}

render_value_lines <- function(values) {
  if (is.null(values) || length(values) == 0) {
    return(character())
  }

  lines <- strsplit(toml::write_toml(values), "\n", fixed = TRUE)[[1]]
  trim_blank_tail(lines)
}

render_table <- function(header, values = list(), comment = NULL) {
  c(
    normalize_comment_lines(comment),
    paste0("[", header, "]"),
    render_value_lines(values),
    ""
  )
}

remove_nested_list_fields <- function(values) {
  if (is.null(values) || length(values) == 0) {
    return(list())
  }

  keep <- !vapply(values, is.list, logical(1)) &
    !vapply(values, is.null, logical(1))
  values[keep]
}

render_table_with_body_comments <- function(
  header,
  values = list(),
  comment = NULL,
  body_comments = NULL
) {
  c(
    normalize_comment_lines(comment),
    paste0("[", header, "]"),
    if (length(body_comments) > 0 || length(values) > 0) "" else character(),
    normalize_comment_lines(body_comments),
    render_value_lines(values),
    ""
  )
}

render_array_tables <- function(header, entries = list(), comment = NULL) {
  if (is.null(entries) || length(entries) == 0) {
    return(character())
  }

  blocks <- lapply(entries, function(entry) {
    c(
      paste0("[[", header, "]]"),
      render_value_lines(entry),
      ""
    )
  })

  c(
    normalize_comment_lines(comment),
    unlist(blocks, use.names = FALSE)
  )
}

build_config <- function(lines, path, file_name = "config.toml") {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  lines <- unlist(lines, use.names = FALSE)
  lines <- trim_blank_tail(lines)

  output_path <- file.path(path, file_name)
  writeLines(lines, con = output_path)

  message(paste0("Compiled config recorded in ", output_path))
}
