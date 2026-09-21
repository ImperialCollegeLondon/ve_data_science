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
