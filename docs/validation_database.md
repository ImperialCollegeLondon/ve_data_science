# Building a validation database for soil and litter

This workflow uses YAML metadata to read, harmonise, unit-convert, and combine
multiple source datasets into one validation database (Parquet).

## Repository paths used by default

Run commands from the repository root.

## Building a validation database for soil and litter

This workflow uses YAML metadata to read, harmonise, unit-convert, and combine
multiple source datasets into one validation database (Parquet).

## Repository paths used by default

Run commands from the repository root.

```text
data/primary/soil/<author>_<year>/
└── <data sheet>.csv            # source data, converted manually
data/derived/soil/validation/
├── config/
│   ├── sources/                # one screening/schema YAML file per DOI
│   ├── derived_variables.toml  # non-VE canonical variables (optional)
│   └── unit_conversions.csv    # unit_from/unit_to conversion rules
└── database/                   # output Parquet dataset
tools/R/R/valdb.R               # workflow functions
```

## How to load the functions

These functions are written to work with both `box::use()` and `source()`.

With `box::use()`:

```r
box::use(tools/R/R/valdb)
```

With `source()`:

```r
source("tools/R/R/valdb.R")
```

After `box::use()`, call exported functions as `valdb$function_name()`.
After `source()`, call them as `function_name()`.

## Workflow overview

1. Screen each candidate dataset and save one per-DOI YAML record.
2. Initialise schema fields for a dataset with a `proceed` decision.
3. Download the source dataset and convert it to CSV.
4. Complete the schema manually (file path, variable mapping, units, keys).
5. Build the harmonised validation database.
6. Combine the validation database with VE outputs.

## 1) Data screening

Use `screen_dataset()` to retrieve DOI metadata and record whether a dataset
should proceed, be excluded, or be deferred.

```r
box::use(tools/R/R/valdb)
valdb$screen_dataset()
```

The function prompts for a DOI, a decision, a decision-specific reason, and
notes. The available decisions are:

| Decision | Meaning |
| --- | --- |
| `proceed` | The source contains relevant validation data. |
| `exclude` | The source is unsuitable for the validation database. |
| `defer` | A decision requires more information or another opinion. |

Notes are required for `defer` decisions and when the selected reason is
`other`. DOI metadata must be resolvable through DOI content negotiation
(`rcrossref::cr_cn()`).

Each successful screening creates one file under
`data/derived/soil/validation/config/sources/`. The filename is a stable ID
derived from the normalised DOI, for example:

```text
doi-10-5281-zenodo-2024580.yaml
```

Existing DOI records are not overwritten. To amend a screening decision,
delete its per-DOI YAML file and screen the dataset again.

## 2) Add a schema template for one `proceed` dataset

`add_schema()` locates a screening record by DOI and adds the fields required by
the current build step.

```r
valdb$add_schema(doi = "10.5281/zenodo.2024580")
```

Set `sources_dir` only when the records are stored outside the default
directory:

```r
valdb$add_schema(
  doi = "10.5281/zenodo.2024580",
  sources_dir = "data/derived/soil/validation/config/sources"
)
```

The DOI may use upper-case characters, a `doi:` prefix, or a DOI resolver URL;
it is normalised before lookup. The record must already exist, have
`screening.decision: proceed`, and not contain a schema. If these checks pass,
the template is written safely and only the target per-DOI YAML file is opened
for manual editing. Existing schemas are not overwritten.

## 3) Download the dataset and convert it to CSV

Download the dataset to `data/primary/<module>/<author>_<year>`. Note that the
soil folder is used as an example throughout this page, and that
`author_year` is a folder naming convention. If there are conflicts, then the
next folder should be named `author_year_2`, and so on.

We work with CSV files. If the published dataset is in another format (for
example Excel or zip), then manually convert the desired data sheet into a CSV
file. We opted not to accommodate multiple data formats because the cost of
manual conversion is relatively minor even in the long run.

Keep any location or coordinate files supplied with the source dataset. The
current builder does not ingest them, but retaining the original files supports
a later coordinate-integration step.

## 4) Complete schema fields manually

The template is an editable scaffold, not a build-ready configuration. Replace
every placeholder with values from the source dataset, remove unused example
entries, and add one `variables` entry for each source column to include.

For each dataset with a `proceed` decision, complete:

- `source_id` (e.g. `dobert_2019`)
- `data_file` (path to the CSV file)
- `skip_rows`
- `variables` (original name, canonical name, original unit)
- `dedup_key`

These fields are added at the top level of the existing per-DOI record. They
sit alongside `schema_version`, `record_id`, `doi`, `screening`, and `metadata`;
they are not nested under a separate `schema` key.

Example:

```yaml
schema_version: 1
record_id: doi-10-5281-zenodo-2024580
doi: 10.5281/zenodo.2024580
screening:
  decision: proceed
  reason: relevant_validation_data
  notes: ""
  screened_at: "2026-08-13T12:05:00Z"
metadata:
  title: Example dataset
  authors:
    - Doe, Jane
  year: 2019
source_id: dobert_2019
data_file: data/primary/soil/dobert_2019/DoebertTF_SAFE_PlotData.csv
skip_rows: 9
variables:
  soilN:
    var_canonical: total_soil_n_per_volume
    unit: mg cm^-3
    description: Total soil nitrogen content
  soilP:
    var_canonical: dissolved_phosphorus
    unit: ug cm^-3
    description: Plant available soil phosphorus content
dedup_key:
  - plot.code
```

Assumptions and expectations:

- Input files are CSV (`readr::read_csv()` is used internally).
- `var_canonical` must exist in either VE `data_variables.toml` or
  `config/derived_variables.toml`.
- Any required `unit_from -> unit_to` pair must exist in
  `config/unit_conversions.csv`.

### Spatial coordinates

Spatial-coordinate configuration is not part of the current schema contract.
`add_schema()` does not add coordinate fields, and
`build_validation_database()` does not discover `locations.csv`, match
locations, validate coordinates, or add coordinate columns. Keep source
coordinate files unchanged for future integration rather than adding
unsupported configuration to a schema.

## 5) Build the validation database

Run:

```r
valdb$build_validation_database()
```

Default behavior:

- Reads conversion rules from
  `data/derived/soil/validation/config/unit_conversions.csv`
- Builds canonical variable metadata from VE + local derived variables
- Reads per-DOI records from
  `data/derived/soil/validation/config/sources/*.yaml`
- Keeps records that contain a top-level `source_id`
- Writes Parquet output to `data/derived/soil/validation/database`

Screening-only records do not contain `source_id`, so the build ignores them.
A `proceed` decision alone does not make a record build-ready; its schema
placeholders must first be completed.

## 6) Combine the validation database with VE outputs

Use
[analysis/soil/validation/combine_validation_database.R](analysis/soil/validation/combine_validation_database.R)
as a reference workflow.

```r
library(arrow)
box::use(tools/R/R/valdb)

validation_database <-
  open_dataset("data/derived/soil/validation/database") |>
  dplyr::collect()

combined_database <-
  valdb$join_ve_outputs(
    validation_database,
    zarr_path = "data/scenarios/maliau/maliau_2/out/model_data.zarr",
    config_path = "data/scenarios/maliau/maliau_2/out/compiled_configuration.toml"
  )

combined_database |>
  dplyr::group_by(dataset) |>
  write_dataset("data/derived/soil/validation/database_combined", format = "parquet")
```

`join_ve_outputs()` takes the validation database and VE scenario outputs (from
a Zarr store), then join the spatiotemporally aggregated VE outputs for each
row. It reads direct and derived VE variables, classifies each observation by
spatial/temporal overlap with the scenario bounds, and then returns three added
columns: the lower quantile `value_VE_q05`, median `value_VE_q50`, and the upper
quantile `value_VE_q95`.

Current implementation supports:

- full spatial and temporal matching (`spatial_within_temporal_within`)
- temporal-only matching for observations outside VE spatial bounds
  (`spatial_outside_temporal_within`)

Other spatiotemporal classes currently return `NA` quantiles with a warning.

## Legacy screening records

`data/derived/soil/validation/config/sources.yaml` is retained temporarily as
migration input. It is not read by the current screening, schema, or build
workflow. Some historical screening records and completed schemas in that file
have not yet been reconciled with `config/sources/`; do not delete it until the
migration has been checked DOI by DOI.

The report source at
`analysis/soil/validation/safe_database_screen/dataset_screening.qmd` has been
retired because it reads the legacy aggregate format. Its existing generated
HTML is a historical snapshot and must not be treated as current workflow
output.

## Ongoing metadata curation

When new unit conversions are needed, edit:
`data/derived/soil/validation/config/unit_conversions.csv`

When new derived variables are needed, edit:
`data/derived/soil/validation/config/derived_variables.toml`

## Notes for contributors

- Keep schema edits small and commit frequently.
- Prefer explicit relative paths from repo root.
