# app.R is the entry point that Shiny looks for when runApp() receives this
# directory. It loads dependencies, sources the application functions, and then
# combines the UI and server into one runnable application.
library(bslib)
library(shiny)

# here::here() builds paths from the repository root. This lets the app start
# correctly even when the current working directory is not this folder.
source(here::here("tools/R/R/valdb.R"))
source(here::here(
  "analysis/soil/validation/schema_dashboard/dashboard.R"
))

# The YAML files are the source of truth. No separate application database or
# in-memory copy is maintained between Shiny sessions.
sources_dir <- here::here(
  "data/derived/soil/validation/config/sources"
)

# shinyApp() pairs the browser interface with its server logic. The configured
# server receives sources_dir through schema_dashboard_server().
# Launch it with `runApp("analysis/soil/validation/schema_dashboard/app.R")`
shinyApp(
  ui = schema_dashboard_ui(),
  server = schema_dashboard_server(sources_dir)
)
