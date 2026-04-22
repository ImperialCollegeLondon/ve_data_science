library(reticulate)


use_virtualenv("./ve_release")

config_builder <- import("virtual_ecosystem.core.config_builder")

config <- config_builder$build_configuration_model(
  requested_modules = c("core", "abiotic_simple"),
  requested_disturbances = list()
)

config$export_toml(
  self = config(),
  path = "data/scenarios/runtime_per_cell/config/config_template.toml"
)
