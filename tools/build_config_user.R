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
  config_list,
  path
) {
  # generate a master list of requested modules
  config_ve_run <- vector("list", length(requested_modules))
  names(config_ve_run) <- requested_modules
  write_toml(config_ve_run) |>
    writeLines(con = paste0(path, "/ve_run.toml"))

  # generate a list of user-specified configs
  config_list |>
    write_toml() |>
    writeLines(con = paste0(path, "/config_user.toml"))
}
