library(reticulate)
library(toml)

use_virtualenv("./ve_release")

virtual_ecosystem <- import("virtual_ecosystem.core.registry")
