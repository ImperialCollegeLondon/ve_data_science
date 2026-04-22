library(reticulate)
library(toml)

use_virtualenv("./ve_release")

model_config <- list(
  core = import("virtual_ecosystem.core.model_config"),
  abiotic = import("virtual_ecosystem.models.abiotic.model_config"),
  abiotic_simple = import(
    "virtual_ecosystem.models.abiotic_simple.model_config"
  ),
  soil = import("virtual_ecosystem.models.soil.model_config")
)

parse_config_JSON <- function(Configuration) {
  jsonlite::fromJSON(Configuration$json())
}

model_config_list <- list(
  core = list(
    grid = model_config$core$GridConfiguration(),
    timing = model_config$core$TimingConfiguration(),
    layers = model_config$core$LayersConfiguration(),
    data_output_options = model_config$core$DataOutputConfiguration(),
    constants = model_config$core$CoreConstants()
    # core.data.variable not added because it's just a placeholder
  ),
  abiotic = list(
    constants = model_config$abiotic$AbioticConstants()
  ),
  abiotic_simple = list(
    constants = model_config$abiotic_simple$AbioticSimpleConstants(),
    bounds = model_config$abiotic_simple$AbioticSimpleBounds()
  ),
  hydrology = list(),
  soil = model_config$soil$SoilConfiguration(),
  litter = list(),
  plants = list(),
  animals = list()
) |>
  rapply(parse_config_JSON, how = "replace")

# add static mode settings
model_config_list$abiotic$static <- FALSE
model_config_list$abiotic_simple$static <- FALSE

write_toml(model_config_list)
