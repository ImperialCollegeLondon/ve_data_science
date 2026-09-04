# app.R is the entry point that Shiny looks for when runApp() receives this
# directory. It loads dependencies, sources the application functions, and then
# combines the UI and server into one runnable application.
library(bslib)
library(shiny)

module_name <- Sys.getenv("VE_MODULE", unset = "")
if (!nzchar(module_name)) {
  stop(
    "Set VE_MODULE before launching the schema dashboard.",
    call. = FALSE
  )
}

# here::here() builds paths from the repository root. This lets the app start
# correctly even when the current working directory is not this folder.
source(here::here("tools/R/R/valdb.R"))
source(here::here(
  "analysis",
  "soil",
  "validation",
  "schema_dashboard",
  "dashboard.R"
))

# The YAML files are the source of truth. No separate application database or
# in-memory copy is maintained between Shiny sessions.
sources_dir <- here::here(
  "data",
  "derived",
  module_name,
  "validation",
  "config",
  "sources"
)
sources_dir_override <- Sys.getenv("VE_SOURCES_DIR", unset = "")
if (nzchar(sources_dir_override)) {
  sources_dir <- sources_dir_override
}

# shinyApp() pairs the browser interface with its server logic. The configured
# server receives sources_dir through schema_dashboard_server().
# Launch from the repository root after setting VE_MODULE, for example:
# Sys.setenv(VE_MODULE = "soil")
# shiny::runApp("analysis/soil/validation/schema_dashboard")
shinyApp(
  ui = schema_dashboard_ui(),
  server = schema_dashboard_server(sources_dir)
)
