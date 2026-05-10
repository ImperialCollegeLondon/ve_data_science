# Source - https://stackoverflow.com/a/25291271
# Posted by charliebone, modified by community. See post 'Timeline' for change history
# Retrieved 2026-05-08, License - CC BY-SA 3.0

library(roxygen2)
library(roxygen2md)

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
foo <- blocks[[1]] |> roxygen2:::block_to_rd(env = env)
foo$format() |> markdownify()
