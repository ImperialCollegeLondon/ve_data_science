# Building a validation database for soil and litter

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
│   └── derived_variables.toml  # non-VE canonical variables (optional)
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
After `source()`, call them as `function_name()`. If you call
`join_ve_outputs()` after `source()`, also source
`tools/R/R/get_ve_variables.R` so VE variable readers are available.

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

A minimal local dashboard provides the same workflow for all pending `proceed`
records. Launch it from the repository root:

```r
shiny::runApp("analysis/soil/validation/schema_dashboard")
```

The dashboard reads the YAML records directly, shows screening notes, and loads
the selected record into a browser YAML editor. It calls
`initialise_source_schema()` only when a schema does not exist. Untouched or
partially completed template schemas remain in the to-do list as drafts. Saving
validates the YAML and record identity before replacing the filesystem record.
The record can also be opened in the desktop editor. The dashboard does not
maintain a separate database.

## 3) Download the dataset and convert it to CSV

Download the dataset to `data/primary/<module>/<author>_<year>`. Note that the
soil folder is used as an example throughout this page, and that
`author_year` is a folder naming convention. If there are conflicts, then the
next folder should be named `author_year_2`, and so on.

We work with CSV files. If the published dataset is in another format (for
example Excel or zip), then manually convert the desired data sheet into a CSV
file. We opted not to accommodate multiple data formats because the cost of
manual conversion is relatively minor even in the long run.

Keep any location or coordinate files supplied with the source dataset. For the
default spatial workflow, export the source location table as `locations.csv`
beside the measurement CSV.

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
- Known `var_canonical` names are resolved against the latest VE
  `data_variables.toml` from the `develop` branch and
  `config/derived_variables.toml`.
- Source and canonical units are interpreted and converted directly with the
  `units` package. Malformed or dimensionally incompatible units are errors.
- Unknown canonical names produce a warning. Their observations and original
  units are retained, while canonical values and units are recorded as missing.

### Spatial and temporal metadata

The `coordinates` and `temporal` blocks are optional. Leave their template
values blank when the source does not provide the corresponding metadata.
Missing spatial or temporal metadata produces a warning and typed missing
values in the database; it does not make an otherwise complete schema a draft.

By default, the builder looks for `locations.csv` beside `data_file`. It matches
the single `dedup_key` column against `Location name` and reads `Latitude` and
`Longitude`. Use `match_data_column`, `match_location_column`,
`latitude_column`, and `longitude_column` to override those names, or
`from_file` to use another location file. A multi-column `dedup_key` requires an
explicit `match_data_column`. Coordinates must be WGS84 decimal degrees. Use
`same_for_all_rows.latitude` and `same_for_all_rows.longitude` when one location
applies to the complete dataset.

After that first join, the workflow runs a second-pass gazetteer fill using
`data/primary/site/gazetteer.geojson`. For rows still missing latitude or
longitude, it matches the configured location key to `location` in the
gazetteer and fills coordinates from centroid values (`centroid_x`,
`centroid_y`). Rows filled this way are flagged as
`coordinate_source: gazetteer_second_pass`.

Temporal metadata can come from one `date_column`, from paired `start_column`
and `end_column` values, or from `same_for_all_rows.start` and
`same_for_all_rows.end`. Columns used for time metadata must also be retained by
`dedup_key` or `variables`. Optional `format`, `timezone`, and `precision`
settings control parsing; supported precision values are `second`, `day`,
`month`, and `year`. Times are stored in UTC as half-open intervals
`[time_start, time_end)`. Source end values are interpreted as the last
inclusive precision unit, and `same_for_all_rows.end: open` represents an
unbounded end. The optional blanket `note` is stored in `time_note`.

For example:

```yaml
coordinates:
  from_file:
  match_data_column: plot.code
  match_location_column: Location name
  latitude_column: Latitude
  longitude_column: Longitude
  same_for_all_rows:
    latitude:
    longitude:
temporal:
  date_column:
  start_column:
  end_column:
  format:
  timezone: UTC
  precision: day
  same_for_all_rows:
    start: 2011-01-01
    end: 2014-12-31
    precision: day
    note: Sampling period reported by the source
```

Use either per-row settings or `same_for_all_rows` within each block, and remove
unused entries when the schema is complete.

## 5) Build the validation database

Run:

```r
valdb$build_validation_database()
```

Default behavior:

- Downloads current canonical variable metadata from the VE `develop` branch
  and combines it with local derived-variable metadata
- Converts known variables directly between compatible units with `units`
- Reads per-DOI records in filename order from
  `data/derived/soil/validation/config/sources/*.yaml`
- Ignores screening-only records
- Warns about initialised schemas that still contain mandatory placeholders and
  skips them
- Requires every schema record to retain a `proceed` screening decision
- Writes Parquet output to `data/derived/soil/validation/database`

A `proceed` decision alone does not make a record build-ready. The builder only
uses records with a completed top-level schema. It stops if no completed schemas
remain after screening-only and draft records are excluded.

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

When new derived variables are needed, edit
`data/derived/soil/validation/config/derived_variables.toml`. Source schemas
should use unit strings understood by the `units` package.

## Notes for contributors

- Keep schema edits small and commit frequently.
- Prefer explicit relative paths from repo root.
