#' Build user configuration files for the Virtual Ecosystem
#'
#' Generate a set of TOML configuration files for the Virtual Ecosystem's
#' ve_run command. Begin by selecting the modules to be loaded, and then
#' input any user-specified settings to each module. Module-named arguments
#' that are left blank will use default settings.
#'
#' @param requested_modules A character vector of requested modules. Can be
#'   any of "core", "abiotic", "hydrology", "plants", "animal", "soil" and
#'   "litter".
#' @param core A named list of core module settings.
#' @param abiotic A named list of abiotic module settings.
#' @param abiotic_simple A named list of abiotic_simple module settings.
#' @param hydrology A named list of hydrology module settings.
#' @param plants A named list of plants module settings.
#' @param animal A named list of animal module settings.
#' @param soil A named list of soil module settings.
#' @param litter A named list of litter module settings.
#' @param path Directory to save the output TOML configuration files.
#'
#' @notes The nested structure of each module's list need to reflect the
#'   TOML hierarchy, so that the lists can be parsed correctly to TOML using
#'   toml::write_toml.
#'
#' @returns TOML configuration files saved in the specified path.

build_config <- function(
  requested_modules = c(
    "core",
    "abiotic",
    "hydrology",
    "plants",
    "animal",
    "soil",
    "litter"
  ),
  core = NULL,
  abiotic = NULL,
  abiotic_simple = NULL,
  hydrology = NULL,
  plants = NULL,
  animal = NULL,
  soil = NULL,
  litter = NULL,
  path
) {
  # generate a master list of requested modules
  config_ve_run <- vector("list", length(requested_modules))
  names(config_ve_run) <- requested_modules
  write_toml(config_ve_run) |>
    writeLines(con = paste0(path, "/ve_run.toml"))
  message("Requested modules recorded in ve_run.toml")

  # generate user-specified configs and write them to modular TOML files

  # core config
  if (!is.null(core)) {
    export_config(core)
  }

  # abiotic config
  if (!is.null(abiotic)) {
    export_config(abiotic)
  }

  # abiotic_simple config
  if (!is.null(abiotic_simple)) {
    export_config(abiotic_simple)
  }

  # hydrology config
  if (!is.null(hydrology)) {
    export_config(hydrology)
  }

  # plants config
  if (!is.null(plants)) {
    export_config(plants)
  }

  # animal config
  if (!is.null(animal)) {
    export_config(animal)
  }

  # soil config
  if (!is.null(soil)) {
    export_config(soil)
  }

  # litter config
  if (!is.null(litter)) {
    export_config(litter)
  }

  message(paste0("These config files are saved in ", path))
}

# function to export configs
export_config <- function(config_list) {
  # retrieve the list name
  nm <- deparse(substitute(config_list))
  # assign name to set it a level deeper so we maintain the right TOML hierarchy
  setNames(list(config_list), nm) |>
    write_toml() |>
    writeLines(
      con = paste0(path, "/", nm, "_config.toml")
    )
  message(paste0(nm, " config recorded in ", nm, "_config.toml"))
}
