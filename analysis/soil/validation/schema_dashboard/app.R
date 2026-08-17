# app.R is the entry point that Shiny looks for when runApp() receives this
# directory. It sources valdb helpers and delegates dashboard construction to
# add_schema_dashboard() so there is only one launch path.
source(here::here("tools/R/R/valdb.R"))

# The YAML files are the source of truth. No separate application database or
# in-memory copy is maintained between Shiny sessions.
add_schema_dashboard(
  sources_dir = here::here("data/derived/soil/validation/config/sources"),
  launch = FALSE
)
