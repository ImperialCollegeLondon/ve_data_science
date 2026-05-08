# Source - https://stackoverflow.com/a/25291271
# Posted by charliebone, modified by community. See post 'Timeline' for change history
# Retrieved 2026-05-08, License - CC BY-SA 3.0

library(roxygen2)
tools_dir <- "tools/R"
rfiles <- list.files(tools_dir, full.names = TRUE)

# get parsed source into roxygen-friendly format
env <- new.env(parent = globalenv())
blocks <- unlist(
  lapply(rfiles, parse_file, env = env),
  recursive = FALSE
)
parsed <- list(env = env, blocks = blocks)


############################
roclet_preprocess(blocks[[1]])

# parse roxygen comments into rd files and output then into the "./man" directory
roc <- rd_roclet()
results <- roc_process(roc, parsed, tools_dir)
roc_output(
  roc,
  results,
  mydir,
  options = list(wrap = FALSE),
  check = FALSE
)
