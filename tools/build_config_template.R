#| ---
#| title: Create a template config for the virtual ecosystem
#|
#| description: |
#|     Create a template config TOML. This function is basically an import of
#|     the virtual_ecosystem.core.config_builder module from the virtual
#|     ecosystem python script, therefore the virtual_ecosystem needs to be
#|     installed to use this function. Be mindful of version changes in the
#|     list of config variables.
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
#|     - reticulate (R)
#|     - virtual_ecosystem (Python)
#|
#| usage_notes: See details below
#| ---

#' Create a template config for the virtual ecosystem
#'
#' Create a template config TOML. This function is basically an import of the
#' virtual_ecosystem.core.config_builder module from the virtual ecosystem
#' python script, therefore the virtual_ecosystem needs to be installed to use
#' this function. Be mindful of version changes in the list of config variables.
#'
#' @param requested_modules A list of modules to be configured.
#' @param requested_disturbances A list of modules to be disturbed.
#' @param filename Name of the output TOML file.
#'
#' @returns A TOML file.
#'
#' @export
#' @examples
#'   build_config_template(list("core", "abiotic_simple"), filename = "tmp.toml")

build_config_template <- function(
  requested_modules = list("core"),
  requested_disturbances = list(),
  filename
) {
  # import the config_builder function from virtual ecosystem
  config_builder <- import("virtual_ecosystem.core.config_builder")

  # build the config
  config <- config_builder$build_configuration_model(
    requested_modules = requested_modules,
    requested_disturbances = requested_disturbances
  )

  # export the config to a TOML file
  config()$export_toml(path = filename)
}
