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
#|   - toml
#|
#| usage_notes: See details below
#| ---

#' Build a compiled configuration TOML for the Virtual Ecosystem
#'
#' Generate a single compiled TOML configuration file for the Virtual
#' Ecosystem's `ve_run` command. Scalar, vector, and table values are
#' serialized with `toml::write_toml()`, while comments, section order, empty
#' tables, and repeated `[[core.data.variable]]` blocks are assembled
#' explicitly.
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
#' @param comments A named list of comment lines to insert before sections or
#'   field groups. Each element should be a character vector of complete comment
#'   lines, for example `c("# Plant config settings")`.
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

build_config <- function(
  core,
  abiotic_simple,
  hydrology,
  plants,
  animal,
  soil,
  litter,
  path,
  file_name = "config.toml",
  comments = list()
) {
  default_comments <- list(
    core = "# Core settings",
    abiotic_simple = "# Abiotic config settings",
    abiotic_variables = "# Abiotic array variables",
    hydrology = "# Hydrology config settings",
    hydrology_variables = "# Hydrology array variables",
    animal = "# Animal config settings",
    animal_functional_group_definitions_path = character(),
    plants = "# Plant config settings",
    plants_pft_definitions_path = character(),
    plants_cohort_data_path = character(),
    plants_community_data_export = character(),
    plants_variables = "# Plant array variables",
    plants_constants = "# Plant constants (non-defaults)",
    soil = "# Soil config settings",
    soil_variables = "# Soil array variables",
    litter = "# Litter config settings",
    litter_variables = "# Litter array variables"
  )

  comments <- utils::modifyList(default_comments, comments)

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  variable_groups <- core$data$variable

  animal_values <- list(
    functional_group_definitions_path = animal$functional_group_definitions_path
  )

  plants_values <- list(
    pft_definitions_path = plants$pft_definitions_path,
    cohort_data_path = plants$cohort_data_path
  )

  lines <- c(
    render_table("core.grid", core$grid, comments$core),
    render_table("core.timing", core$timing),
    render_table("abiotic_simple", abiotic_simple, comments$abiotic_simple),
    render_array_tables(
      "core.data.variable",
      variable_groups$abiotic_simple,
      comments$abiotic_variables
    ),
    render_table("hydrology", hydrology, comments$hydrology),
    render_array_tables(
      "core.data.variable",
      variable_groups$hydrology,
      comments$hydrology_variables
    ),
    render_table_with_body_comments(
      "animal",
      animal_values,
      comments$animal,
      comments$animal_functional_group_definitions_path
    ),
    render_table("animal.cohort_data_export", animal$cohort_data_export),
    render_table("animal.resource_pool_export", animal$resource_pool_export),
    render_table_with_body_comments(
      "plants",
      plants_values,
      comments$plants,
      c(
        normalize_comment_lines(comments$plants_pft_definitions_path),
        normalize_comment_lines(comments$plants_cohort_data_path)
      )
    ),
    render_table(
      "plants.community_data_export",
      plants$community_data_export,
      comments$plants_community_data_export
    ),
    render_array_tables(
      "core.data.variable",
      variable_groups$plants,
      comments$plants_variables
    ),
    render_table("plants.constants", plants$constants, comments$plants_constants),
    render_table("soil", soil, comments$soil),
    render_array_tables(
      "core.data.variable",
      variable_groups$soil,
      comments$soil_variables
    ),
    render_table("litter", litter, comments$litter),
    render_array_tables(
      "core.data.variable",
      variable_groups$litter,
      comments$litter_variables
    )
  )

  lines <- unlist(lines, use.names = FALSE)
  lines <- trim_blank_tail(lines)

  output_path <- file.path(path, file_name)
  writeLines(lines, con = output_path)

  message(paste0("Compiled config recorded in ", output_path))
}
