#| ---
#| title: Generate explicit R code-dependency graph
#|
#| description: |
#|   Scans analysis/soil, analysis/litter, and tools for static source(),
#|   box::use(), and intermediate-artifact dependencies. Source this file, then call
#|   build_file_dependency_graph() and render_file_dependency_graph().
#|
#| input_files:
#|   - name: R scripts
#|     path: analysis/soil, analysis/litter, tools
#|     description: Scripts scanned for explicit source() and box::use() calls.
#|
#| output_files:
#|   - name: file_dependencies.dot
#|     path: docs/modules/soil
#|     description: Graphviz DOT file for the dependency graph.
#|   - name: file_dependencies.svg
#|     path: docs/modules/soil
#|     description: SVG rendering of the dependency graph.
#|
#| package_dependencies:
#|   - DiagrammeR
#|   - DiagrammeRsvg
#| ---

normalise_dependency_path <- function(path) {
  path <- gsub("\\\\", "/", path)
  path[!grepl("\\.R$", path)] <- paste0(path[!grepl("\\.R$", path)], ".R")
  path
}

extract_dependencies <- function(path) {
  text <- readLines(path, warn = FALSE)
  text <- sub("\\s*#.*$", "", text)
  text <- paste(text, collapse = "\n")
  source_pattern <-
    "\\bsource\\s*\\(\\s*(?:here::here\\s*\\(\\s*)?['\"]([^'\"]+\\.R)['\"]"
  box_pattern <- "\\bbox::use\\s*\\(\\s*([^[:space:],)]+)"

  source_paths <- regmatches(
    text,
    gregexpr(source_pattern, text, perl = TRUE)
  )[[1]]
  source_paths <- sub(source_pattern, "\\1", source_paths, perl = TRUE)

  box_paths <- regmatches(text, gregexpr(box_pattern, text, perl = TRUE))[[1]]
  box_paths <- sub(box_pattern, "\\1", box_paths, perl = TRUE)
  box_paths <- sub("\\[.*$", "", box_paths)

  unique(normalise_dependency_path(c(source_paths, box_paths)))
}

extract_artifact_paths <- function(path) {
  text <- readLines(path, warn = FALSE)
  text <- sub("\\s*#.*$", "", text)
  text <- paste(text, collapse = "\n")
  read_patterns <- c(
    "\\b(?:readr::)?read_csv\\s*\\(\\s*['\"]([^'\"]+\\.csv)['\"]",
    "\\b(?:utils::)?read\\.csv\\s*\\(\\s*['\"]([^'\"]+\\.csv)['\"]",
    "\\b(?:yaml::)?read_yaml\\s*\\(\\s*['\"]([^'\"]+\\.ya?ml)['\"]",
    "\\b(?:RcppTOML::)?parseTOML\\s*\\(\\s*['\"]([^'\"]+\\.toml)['\"]",
    "\\b(?:arrow::)?read_parquet\\s*\\(\\s*['\"]([^'\"]+\\.parquet)['\"]",
    "\\b(?:ncdf4::)?nc_open\\s*\\(\\s*['\"]([^'\"]+\\.nc)['\"]",
    "\\b(?:RNetCDF::)?open\\.nc\\s*\\(\\s*['\"]([^'\"]+\\.nc)['\"]"
  )
  write_patterns <- c(
    "\\b(?:readr::)?write_csv\\s*\\(\\s*[^,\\n]+,\\s*['\"]([^'\"]+\\.csv)['\"]",
    "\\b(?:readr::)?write_csv\\s*\\(\\s*['\"]([^'\"]+\\.csv)['\"]",
    "\\b(?:utils::)?write\\.csv\\s*\\(\\s*[^,\\n]+,\\s*['\"]([^'\"]+\\.csv)['\"]",
    "\\b(?:yaml::)?write_yaml\\s*\\(\\s*[^,\\n]+,\\s*['\"]([^'\"]+\\.ya?ml)['\"]",
    "\\b(?:toml::)?write\\.toml\\s*\\(\\s*[^,\\n]+,\\s*['\"]([^'\"]+\\.toml)['\"]",
    "\\b(?:arrow::)?write_parquet\\s*\\(\\s*[^,\\n]+,\\s*['\"]([^'\"]+\\.parquet)['\"]",
    "\\b(?:ncdf4::)?nc_create\\s*\\(\\s*['\"]([^'\"]+\\.nc)['\"]",
    "\\b(?:RNetCDF::)?create\\.nc\\s*\\(\\s*['\"]([^'\"]+\\.nc)['\"]",
    "\\bconvert_df_to_nc\\s*\\([\\s\\S]{0,1000}?filename\\s*=\\s*['\"]([^'\"]+\\.nc)['\"]"
  )
  extract_paths <- function(patterns) {
    paths <- unlist(
      lapply(patterns, function(pattern) {
        matches <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
        sub(pattern, "\\1", matches, perl = TRUE)
      }),
      use.names = FALSE
    )
    unique(gsub("\\\\", "/", paths))
  }

  list(
    read = extract_paths(read_patterns),
    write = extract_paths(write_patterns)
  )
}

build_file_dependency_graph <- function(
  root = ".",
  output = file.path("docs", "modules", "soil", "file_dependencies.dot")
) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  scan_roots <- file.path(root, c("analysis/soil", "analysis/litter", "tools"))
  files <- unlist(
    lapply(
      scan_roots,
      list.files,
      pattern = "\\.(R|Rmd)$",
      recursive = TRUE,
      full.names = TRUE
    ),
    use.names = FALSE
  )
  files <- sort(normalizePath(files, winslash = "/", mustWork = TRUE))
  files <- files[!grepl("/tests/testthat/", files)]
  known_files <- sub(paste0("^", root, "/"), "", files)

  code_edges <- do.call(
    rbind,
    lapply(seq_along(files), function(i) {
      targets <- extract_dependencies(files[[i]])
      if (length(targets) == 0) {
        return(NULL)
      }
      cbind(source = known_files[[i]], target = targets)
    })
  )
  artifacts <- lapply(files, extract_artifact_paths)
  artifact_edges <- do.call(
    rbind,
    lapply(seq_along(files), function(i) {
      outputs <- artifacts[[i]]$write
      if (length(outputs) == 0) {
        return(NULL)
      }
      readers <- which(vapply(
        artifacts,
        function(artifact) any(artifact$read %in% outputs),
        logical(1)
      ))
      readers <- setdiff(readers, i)
      if (length(readers) == 0) {
        return(NULL)
      }
      cbind(source = known_files[[i]], target = known_files[readers])
    })
  )
  nodes <- sort(unique(c(known_files, code_edges)))

  node_lines <- vapply(
    nodes,
    function(node) {
      missing <- !node %in% known_files
      shape <- if (grepl("^tools/", node)) "ellipse" else "box"
      missing_style <- if (missing) ', color="#b91c1c", style="dashed"' else ""
      directory <- dirname(node)
      label <- paste0(
        '<FONT COLOR="#64748b">',
        directory,
        '/</FONT><FONT COLOR="#000000">',
        basename(node),
        "</FONT>"
      )
      paste0(
        '  "',
        node,
        '" [label=<',
        label,
        '>, target="_blank", URL="',
        "https://github.com/ImperialCollegeLondon/ve_data_science/blob/main/",
        node,
        '", shape="',
        shape,
        '"',
        missing_style,
        "];"
      )
    },
    character(1)
  )
  code_edge_lines <- if (is.null(code_edges)) {
    character()
  } else {
    apply(
      code_edges,
      1,
      function(edge) {
        paste0(
          '  "',
          edge[["target"]],
          '" -> "',
          edge[["source"]],
          '";'
        )
      }
    )
  }
  artifact_edge_lines <- if (is.null(artifact_edges)) {
    character()
  } else {
    apply(
      artifact_edges,
      1,
      function(edge) {
        paste0(
          '  "',
          edge[["source"]],
          '" -> "',
          edge[["target"]],
          '" [style="dashed", color="#0f766e"];'
        )
      }
    )
  }
  dot <- c(
    "digraph file_dependencies {",
    "  graph [rankdir=LR, overlap=false, splines=ortho];",
    "  node [shape=box, fontname=Helvetica, fontsize=10];",
    '  edge [color="#64748b", arrowsize=0.7];',
    node_lines,
    code_edge_lines,
    artifact_edge_lines,
    "}"
  )

  if (!grepl("^(?:[A-Za-z]:[/\\\\]|/|\\\\\\\\)", output)) {
    output <- file.path(root, output)
  }
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  writeLines(dot, output)
  invisible(output)
}

render_file_dependency_graph <- function(
  dot_file = file.path("docs", "modules", "soil", "file_dependencies.dot"),
  svg_file = file.path("docs", "modules", "soil", "file_dependencies.svg")
) {
  if (
    !requireNamespace("DiagrammeR", quietly = TRUE) ||
      !requireNamespace("DiagrammeRsvg", quietly = TRUE)
  ) {
    stop("Install DiagrammeR and DiagrammeRsvg to render the SVG.")
  }

  dot <- paste(readLines(dot_file, warn = FALSE), collapse = "\n")
  svg <- DiagrammeRsvg::export_svg(DiagrammeR::grViz(dot))
  writeLines(svg, svg_file)
  invisible(svg_file)
}
