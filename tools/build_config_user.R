build_config_user <- function(
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
