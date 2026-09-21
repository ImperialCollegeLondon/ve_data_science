#| ---
#| title: Build a compiled configuration TOML for the Virtual Ecosystem
#|
#| description: |
#|     Generate a single compiled TOML configuration file for the Virtual
#|     Ecosystem's ve_run command. This file now collects the small helper
#|     functions used to prepare and render configuration content, including
#|     input path collection, TOML rendering, and final file writing.
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
#' Write a compiled TOML configuration file for the Virtual Ecosystem from
#' pre-rendered lines.
#'
#' Use `render_comment()` for prose comments, `render_module()` for top-level
#' modules and their direct scalar settings, `render_table()` for child tables,
#' and `render_array_tables()` for repeated array-of-table entries.
#'
#' @param lines Character vector of TOML lines to write.
#' @param path Directory to save the compiled TOML configuration file.
#' @param file_name File name for the compiled TOML configuration file.
#'
#' @returns A compiled TOML configuration file saved in the specified path.
#'
#' @examples
#' lines <- c(
#'   render_comment("Core settings"),
#'   render_module("core"),
#'   render_table("core.grid", list(cell_nx = 10, cell_ny = 10)),
#'   render_table(
#'     "core.timing",
#'     list(start_date = "2010-01-01", run_length = "1 year")
#'   )
#' )

#' Build grouped `core$data$variable` entries for the compiled TOML config
#'
#' @param plants_path Full relative path and filename of the plants module
#'   input data.
#' @param climate_path Full relative path and filename of the climate input
#'   data.
#' @param elevation_path Full relative path and filename of the elevation input
#'   data.
#' @param soil_path Full relative path and filename of the soil module input
#'   data.
#' @param litter_path Full relative path and filename of the litter module
#'   input data.
#'
#' @returns A named list ready for `core$data$variable`, grouped according to
#'   the compiled TOML structure.

build_variable_groups <- function(
  plants_path,
  climate_path,
  elevation_path,
  soil_path,
  litter_path
) {
  make_entries <- function(file_path, var_names) {
    # Variable names are hard-coded currently and must be updated if upstream
    # Virtual Ecosystem variable names or module inputs change.
    lapply(var_names, function(var_name) {
      list(file_path = file_path, var_name = var_name)
    })
  }

  list(
    abiotic_simple = make_entries(
      climate_path,
      c(
        "air_temperature_ref",
        "relative_humidity_ref",
        "atmospheric_pressure_ref",
        "atmospheric_co2_ref",
        "mean_annual_temperature",
        "wind_speed_ref",
        "downward_longwave_radiation",
        "diurnal_temperature_range_ref"
      )
    ),
    hydrology = c(
      make_entries(climate_path, "precipitation"),
      make_entries(elevation_path, "elevation")
    ),
    plants = c(
      make_entries(
        plants_path,
        c(
          "plant_pft_propagules",
          "subcanopy_vegetation_biomass",
          "subcanopy_seedbank_biomass"
        )
      ),
      make_entries(climate_path, "downward_shortwave_radiation")
    ),
    soil = make_entries(
      soil_path,
      c(
        "pH",
        "clay_fraction",
        "soil_cnp_pool_lmwc",
        "soil_cnp_pool_maom",
        "soil_c_pool_bacteria",
        "soil_c_pool_saprotrophic_fungi",
        "soil_c_pool_arbuscular_mycorrhiza",
        "soil_c_pool_ectomycorrhiza",
        "soil_cnp_pool_pom",
        "soil_cnp_pool_necromass",
        "soil_enzyme_pom_bacteria",
        "soil_enzyme_maom_bacteria",
        "soil_enzyme_pom_fungi",
        "soil_enzyme_maom_fungi",
        "soil_n_pool_ammonium",
        "soil_n_pool_nitrate",
        "soil_p_pool_primary",
        "soil_p_pool_secondary",
        "soil_p_pool_labile",
        "fungal_fruiting_bodies_cnp"
      )
    ),
    litter = make_entries(
      litter_path,
      c(
        "litter_pool_above_metabolic_cnp",
        "litter_pool_above_structural_cnp",
        "litter_pool_woody_cnp",
        "litter_pool_below_metabolic_cnp",
        "litter_pool_below_structural_cnp",
        "lignin_above_structural",
        "lignin_woody",
        "lignin_below_structural"
      )
    )
  )
}

normalize_comment_lines <- function(lines, width = 80, prefix = "# ") {
  if (is.null(lines) || length(lines) == 0) {
    return(character())
  }

  raw_lines <- unlist(strsplit(as.character(lines), "\n", fixed = TRUE))

  unlist(
    lapply(raw_lines, function(line) {
      text <- sub("^\\s*#\\s?", "", line)

      if (!nzchar(text)) {
        return(sub("\\s+$", "", prefix))
      }

      wrapped <- strwrap(text, width = width - nchar(prefix))
      paste0(prefix, wrapped)
    }),
    use.names = FALSE
  )
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

filter_scalar_fields <- function(values) {
  if (is.null(values) || length(values) == 0) {
    return(list())
  }

  keep <- !vapply(values, is.list, logical(1)) &
    !vapply(values, is.null, logical(1))
  values[keep]
}

render_field_lines <- function(
  values,
  field_comments = NULL,
  comment_width = 80
) {
  values <- filter_scalar_fields(values)

  if (length(values) == 0) {
    return(character())
  }

  lines <- character()

  for (field_name in names(values)) {
    if (!is.null(field_comments) && field_name %in% names(field_comments)) {
      lines <- c(
        lines,
        render_comment(
          field_comments[[field_name]],
          comment_width = comment_width
        )
      )
    }

    lines <- c(
      lines,
      render_value_lines(stats::setNames(
        list(values[[field_name]]),
        field_name
      ))
    )
  }

  lines
}

#' Render TOML comment lines
#'
#' @param comment Plain text, pre-prefixed TOML comments, or multi-line text to
#'   place in the output.
#' @param comment_width Maximum width used when wrapping comment text.
#'
#' @returns A character vector of TOML comment lines.
#'
#' @examples
#' render_comment("Core settings")
render_comment <- function(comment, comment_width = 80) {
  normalize_comment_lines(comment, width = comment_width)
}

#' Render a top-level TOML module and its direct scalar settings
#'
#' @param module_name Name of the TOML module to render, such as `"core"` or
#'   `"animal"`.
#' @param values Named list of values to write directly in the module. Nested
#'   lists and `NULL` scalar fields are omitted.
#' @param field_comments Optional named list of comments keyed by field name.
#' @param comment_width Maximum width used when wrapping comment text.
#'
#' @returns A character vector of TOML lines ending with a blank line.
#'
#' @examples
#' render_module(
#'   "animal",
#'   values = list(functional_group_definitions_path = "animal.csv"),
#'   field_comments = list(
#'     functional_group_definitions_path =
#'       "Animal functional group definitions file path"
#'   )
#' )
render_module <- function(
  module_name,
  values = list(),
  field_comments = NULL,
  comment_width = 80
) {
  c(
    paste0("[", module_name, "]"),
    render_field_lines(
      values = values,
      field_comments = field_comments,
      comment_width = comment_width
    ),
    ""
  )
}

#' Render a TOML child table with scalar fields
#'
#' @param module_name Name of the TOML child table to render, such as
#'   `"core.grid"`, `"animal.cohort_data_export"`, or `"plants.constants"`.
#' @param values Named list of values to write as scalar or vector TOML fields.
#'   Nested lists and `NULL` scalar fields are omitted.
#' @param comment Optional comment placed immediately above the table header.
#' @param field_comments Optional named list of comments keyed by field name.
#' @param comment_width Maximum width used when wrapping comment text.
#'
#' @returns A character vector of TOML lines ending with a blank line.
#'
#' @examples
#' render_table(
#'   "plants.constants",
#'   list(subcanopy_specific_leaf_area = 10),
#'   comment = "Plant constants (non-defaults)"
#' )
render_table <- function(
  module_name,
  values = list(),
  comment = NULL,
  field_comments = NULL,
  comment_width = 80
) {
  c(
    normalize_comment_lines(comment, width = comment_width),
    paste0("[", module_name, "]"),
    render_field_lines(
      values = values,
      field_comments = field_comments,
      comment_width = comment_width
    ),
    ""
  )
}

#' Render repeated TOML array-of-table entries
#'
#' @param module_name Name of the repeated TOML table, such as
#'   `"core.data.variable"`.
#' @param entries List of named lists, one per repeated array-table entry.
#' @param comment Optional comment placed immediately above the first entry.
#' @param comment_width Maximum width used when wrapping comment text.
#'
#' @returns A character vector of TOML lines for repeated
#'   `[[module_name]]` entries.
#'
#' @examples
#' render_array_tables(
#'   "core.data.variable",
#'   list(
#'     list(file_path = "climate.nc", var_name = "precipitation"),
#'     list(file_path = "elevation.nc", var_name = "elevation")
#'   ),
#'   comment = "Hydrology array variables"
#' )
render_array_tables <- function(
  module_name,
  entries = list(),
  comment = NULL,
  comment_width = 80
) {
  if (is.null(entries) || length(entries) == 0) {
    return(character())
  }

  blocks <- lapply(entries, function(entry) {
    c(
      paste0("[[", module_name, "]]"),
      render_value_lines(entry),
      ""
    )
  })

  c(
    normalize_comment_lines(comment, width = comment_width),
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
