ve_docs_provenance <- function(ve_root) {
  ve_root <- normalizePath(ve_root, winslash = "/", mustWork = TRUE)
  docs_root <- file.path(ve_root, "docs/source/virtual_ecosystem")
  if (!dir.exists(docs_root)) {
    stop("VE documentation directory not found: ", docs_root, call. = FALSE)
  }

  paths <- sort(list.files(
    docs_root,
    pattern = "\\.md$",
    recursive = TRUE,
    full.names = TRUE
  ))
  if (length(paths) == 0L) {
    stop("No VE Markdown documentation found: ", docs_root, call. = FALSE)
  }

  relative <- substring(paths, nchar(ve_root) + 2L)
  relative <- gsub("\\\\", "/", relative)
  commit <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(ve_root), "rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = FALSE
  ))
  if (
    length(commit) != 1L ||
      !is.null(attr(commit, "status")) ||
      !grepl("^[0-9a-f]{40}$", commit)
  ) {
    stop("Cannot determine VE commit: ", ve_root, call. = FALSE)
  }

  data.frame(
    path = relative,
    md5 = unname(tools::md5sum(paths)),
    commit = rep(commit, length(paths)),
    stringsAsFactors = FALSE
  )
}
