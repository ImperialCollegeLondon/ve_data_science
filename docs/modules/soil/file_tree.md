# Soil, litter, and shared-tools file tree

This page maps tracked code and documentation that support soil and litter
workflows. It includes files under `analysis/soil/`, `analysis/litter/`, and
`tools/` only. Scenario and source data are not shown because synchronisation to
this repository is inconsistent.

The file tree is not shown here because it is long and subjected to changes.

## Explicit code dependencies

The [interactive Graphviz diagram](file_dependencies.svg) maps explicit
`source()` and `box::use()` relationships under the listed analysis and tools
directories, excluding unit tests. It also joins scripts that write and read an
identical static CSV, YAML, TOML, NetCDF, or Parquet path. Artefact files are
not nodes. Each node labels one exact R script. Click a node to open its GitHub
source. Use browser zoom and find to inspect a script and its nearby
dependencies.

The diagram is generated and rendered by
`tools/R/R/generate_file_dependencies.R`. Source it from R at the repository
root:

```r
source("tools/R/R/generate_file_dependencies.R")
build_file_dependency_graph()
render_file_dependency_graph()
```

`render_file_dependency_graph()` uses `DiagrammeR` and `DiagrammeRsvg` to
create `file_dependencies.svg` from the DOT file.

Solid arrows point from a required script to the script that uses it. Dashed
green arrows point from a script that writes a static artefact path to one that
reads it. Rectangles are analysis scripts; ellipses are scripts under `tools/`.
Calls in comments, Zarr, and dynamically constructed paths are excluded.

Dashed red nodes are paths referenced by code but absent from the scanned tree.
They expose known path inconsistencies rather than silently resolving them.

## Shared tools and tests

The R helpers provide configuration generation, NetCDF conversion and
subsetting, model-output extraction, output tidying, validation-database
construction, and Virtual Ecosystem execution. `valdb.R` loads the validation
helper modules. Tests under `tools/R/tests/testthat/` cover selected helpers,
including NetCDF conversion, VE-output joins, and validation workflows.

The Python package supports wider repository workflows. Only
`constant_usage_tool.py` is directly used by the soil LLM metadata workflow.
Python tests cover animal-population, functional-group-density, and trophic-flow
tools; they do not test soil or litter scripts.

## Data dependencies

Data files are intentionally omitted from the tree. Input data are distributed
outside Git when they are too large or unavailable for repository storage.

Litter workflows depend on primary measurements and derived decay, stock, and
nutrient-pool products. Soil workflows depend on SAFE campaign observations,
spatial covariates, microbial and nutrient measurements, and published
stoichiometry or necromass values. Scenario compilers write soil and litter
NetCDF inputs. Validation combines source observations, validation schemas, and
Virtual Ecosystem outputs into Parquet data. See [the module overview](index.md)
for Maliau metadata and input-distribution details.

## Known path inconsistencies

Some script path references do not match the current tree. `model_leaf.R`
references `tools/R/lognormal_natural.R`, but the tracked helper is under
`tools/R/R/`. `input_data_safe_1.R` similarly references
`tools/R/convert_df_to_nc.R`. `marginalise_other_modules.R` references missing
helpers under `tools/R/R/`; `get_mean_array.R` and `cell_id_to_xy.R` are instead
in `analysis/soil/sensitivity/`.
