# Building a validation database for soil and litter

This workflow uses YAML metadata to read, harmonise, unit-convert, and combine
multiple source datasets into one validation database (Parquet).

## Repository paths used by default

Run commands from the repository root.

```text
data/derived/soil/validation/
├── config/
│   ├── sources.yaml            # screening log and dataset schema entries
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

1. Screen candidate datasets and record inclusion decisions.
2. Add schema fields to included datasets in `sources.yaml`.
3. Fill schema manually (file path, variable mapping, units, keys).
4. Build the harmonised validation database.

## 1) Data screening

Use this stage to log whether a dataset is included or excluded.

```r
box::use(tools/R/R/valdb)
valdb$log_dataset()
```

By default, `log_dataset()` appends one record to
`data/derived/soil/validation/config/sources.yaml`.
Each record includes DOI metadata plus fields such as `decision`, `reason`, and
`notes`.

Assumption: DOI metadata can be resolved via Crossref (`rcrossref::cr_cn()`).

## 2) Add schema template for one included dataset

`add_schema()` modifies a record inside `sources.yaml` by DOI and appends schema
fields required by the build step.

```r
valdb$add_schema(
  source_yaml = "data/derived/soil/validation/config/sources.yaml",
  doi = "10.5281/ZENODO.2024580"
)
```

This opens the YAML file for manual editing.

## 3) Complete schema fields manually

For each included dataset, fill at least:

- `source_id` (e.g. `dobert_2019`)
- `data_file` (path to the CSV file)
- `skip_rows`
- `variables` (original name, canonical name, original unit)
- `dedup_key`

Example:

```yaml
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

## 4) Build the validation database

Run:

```r
valdb$build_validation_database()
```

Default behavior:

- Reads conversion rules from
  `data/derived/soil/validation/config/unit_conversions.csv`
- Builds canonical variable metadata from VE + local derived variables
- Reads dataset schemas from `data/derived/soil/validation/config/sources.yaml`
- Writes Parquet output to `data/derived/soil/validation/database`

## Ongoing metadata curation

When new unit conversions are needed, edit:
`data/derived/soil/validation/config/unit_conversions.csv`

When new derived variables are needed, edit:
`data/derived/soil/validation/config/derived_variables.toml`

## Notes for contributors

- Keep schema edits small and commit frequently.
- Prefer explicit relative paths from repo root.
