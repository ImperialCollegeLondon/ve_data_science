#| ---
#| title: Build a compiled configuration TOML for the Virtual Ecosystem
#|
#| description: |
#|     Generate a single compiled TOML configuration file for the Virtual
#|     Ecosystem's ve_run command. The caller supplies module lists in the
#|     order they should appear in the output, and empty lists are written as
#|     empty TOML tables.
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
#|
#| usage_notes: See details below
#| ---

#' Build a compiled configuration TOML for the Virtual Ecosystem
#'
#' Generate a single compiled TOML configuration file for the Virtual
#' Ecosystem's `ve_run` command. The caller supplies module lists in the order
#' they should appear in the output, and empty lists are written as empty TOML
#' tables.
#'
#' The schema used by the caller is a nested list with module names at the top
#' level. `core$data$variable` is itself a named list of variable groups, and
#' each group is a list of `file_path` / `var_name` records that are written as
#' `[[core.data.variable]]` blocks.
#'
#' @param core A named list with `grid`, `timing`, and `data$variable` groups.
#' @param abiotic_simple A named list of abiotic_simple module settings.
#' @param hydrology A named list of hydrology module settings.
#' @param plants A named list of plants module settings.
#' @param animal A named list of animal module settings.
#' @param soil A named list of soil module settings.
#' @param litter A named list of litter module settings.
#' @param path Directory to save the compiled TOML configuration file.
#' @param file_name File name for the compiled TOML configuration file.
#'
#' @returns A compiled TOML configuration file saved in the specified path.

format_number <- function(x, digits = 15) {
  formatC(x, format = "fg", digits = digits, drop0trailing = TRUE)
}

format_value <- function(x, digits = 15) {
  if (is.null(x) || (is.list(x) && length(x) == 0)) {
    return("[]")
  }

  if (is.list(x)) {
    stop("Nested lists must be rendered by a table helper.", call. = FALSE)
  }

  if (is.logical(x)) {
    return(ifelse(isTRUE(x), "true", "false"))
  }

  if (is.numeric(x)) {
    return(format_number(x, digits = digits))
  }

  if (is.character(x)) {
    if (length(x) == 1) {
      return(paste0('"', gsub('"', '\\"', x, fixed = TRUE), '"'))
    }

    return(paste0(
      "[",
      paste(
        vapply(x, format_value, character(1), digits = digits),
        collapse = ","
      ),
      "]"
    ))
  }

  stop("Unsupported TOML value type.", call. = FALSE)
}

emit_simple_table <- function(header, values = list()) {
  c(
    paste0("[", header, "]"),
    if (is.null(values) || length(values) == 0) {
      character()
    } else {
      vapply(
        names(values),
        function(nm) {
          if (is.list(values[[nm]])) {
            stop(
              "Nested lists must be rendered by a table helper.",
              call. = FALSE
            )
          }
          paste0(nm, " = ", format_value(values[[nm]]))
        },
        character(1)
      )
    },
    ""
  )
}

emit_variable_blocks <- function(comment, entries) {
  if (is.null(entries) || length(entries) == 0) {
    return(character())
  }

  blocks <- lapply(entries, function(entry) {
    c(
      "[[core.data.variable]]",
      paste0("file_path = ", format_value(entry$file_path)),
      paste0("var_name = ", format_value(entry$var_name)),
      ""
    )
  })

  c(comment, unlist(blocks, use.names = FALSE))
}

emit_empty_section <- function(comment, header) {
  c(comment, paste0("[", header, "]"), "")
}

emit_module_with_subtables <- function(
  comment,
  header,
  values,
  subtables = list()
) {
  lines <- c(comment, paste0("[", header, "]"))

  if (!is.null(values) && length(values) > 0) {
    lines <- c(
      lines,
      vapply(
        names(values),
        function(nm) {
          if (is.list(values[[nm]])) {
            stop(
              "Nested lists must be rendered by a table helper.",
              call. = FALSE
            )
          }
          paste0(nm, " = ", format_value(values[[nm]]))
        },
        character(1)
      )
    )
  }

  lines <- c(lines, "")

  for (subtable_name in names(subtables)) {
    subtable_values <- subtables[[subtable_name]]
    lines <- c(lines, paste0("[", header, ".", subtable_name, "]"))
    if (!is.null(subtable_values) && length(subtable_values) > 0) {
      lines <- c(
        lines,
        vapply(
          names(subtable_values),
          function(nm) {
            if (
              is.list(subtable_values[[nm]]) &&
                length(subtable_values[[nm]]) > 0
            ) {
              stop(
                "Nested lists must be rendered by a table helper.",
                call. = FALSE
              )
            }
            paste0(nm, " = ", format_value(subtable_values[[nm]]))
          },
          character(1)
        )
      )
    }
    lines <- c(lines, "")
  }

  lines
}

trim_blank_tail <- function(lines) {
  while (length(lines) > 0 && identical(tail(lines, 1), "")) {
    lines <- lines[-length(lines)]
  }

  lines
}

build_config <- function(
  core,
  abiotic_simple,
  hydrology,
  plants,
  animal,
  soil,
  litter,
  path,
  file_name = "config.toml"
) {
  if (is.null(core)) {
    stop("`core` must be supplied.", call. = FALSE)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  variable_groups <- core$data$variable

  lines <- c(
    "# Core settings",
    emit_simple_table("core.grid", core$grid),
    emit_simple_table("core.timing", core$timing),
    "# Abiotic config settings",
    emit_empty_section("", "abiotic_simple"),
    emit_variable_blocks(
      "# Abiotic array variables",
      variable_groups$abiotic_simple
    ),
    "# Hydrology config settings",
    emit_empty_section("", "hydrology"),
    emit_variable_blocks(
      "# Hydrology array variables",
      variable_groups$hydrology
    ),
    "# Animal config settings",
    emit_module_with_subtables(
      "",
      "animal",
      list(
        functional_group_definitions_path = animal$functional_group_definitions_path
      ),
      subtables = list(
        cohort_data_export = animal$cohort_data_export,
        resource_pool_export = animal$resource_pool_export
      )
    ),
    "# Plant config settings",
    emit_module_with_subtables(
      "",
      "plants",
      list(
        cohort_data_path = plants$cohort_data_path,
        pft_definitions_path = plants$pft_definitions_path
      ),
      subtables = list(
        community_data_export = plants$community_data_export
      )
    ),
    "# Plant constants (non-defaults)",
    "[plants.constants]",
    vapply(
      names(plants$constants),
      function(nm) {
        paste0(nm, " = ", format_value(plants$constants[[nm]]))
      },
      character(1)
    ),
    "",
    "# Plant array variables",
    emit_variable_blocks("", variable_groups$plants),
    "# Soil config settings",
    emit_empty_section("", "soil"),
    emit_variable_blocks("# Soil array variables", variable_groups$soil),
    "# Litter config settings",
    emit_empty_section("", "litter"),
    emit_variable_blocks("# Litter array variables", variable_groups$litter)
  )

  lines <- unlist(lines, use.names = FALSE)
  lines <- trim_blank_tail(lines)

  output_path <- file.path(path, file_name)
  writeLines(lines, con = output_path)

  message(paste0("Compiled config recorded in ", output_path))
}
