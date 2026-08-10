# Building a validation database for soil and litter

This workflow uses YAML metadata to read, harmonise, unit-convert, and combine
multiple source datasets into one validation database (Parquet).

## Repository paths used by default

Run commands from the repository root.

```text
data/primary/soil/<author>_<year>/
├── <data sheet>.csv            # source data, converted manually
└── locations.csv               # SAFE Locations sheet, converted manually
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

1. Download the source dataset and convert it to CSV.
2. Screen candidate datasets and record inclusion decisions.
3. Add schema fields to included datasets in `sources.yaml`.
4. Fill schema manually (file path, variable mapping, units, keys).
5. Build the harmonised validation database.
6. Combine the validation database with VE outputs.

## 1) Download the dataset and convert it to CSV

Download the dataset to `data/primary/<module>/<author>_<year>`. Note that the
soil folder is used as an example throughout this page, and that
`author_year` is a folder naming convention. If there are conflicts, then the
next folder should be named `author_year_2`, and so on.

We work with CSV files. If the published dataset is in another format (for
example Excel or zip), then manually convert the desired data sheet into a CSV
file. We opted not to accommodate multiple data formats because the cost of
manual conversion is relatively minor even in the long run.

### Also export the `Locations` sheet

Datasets curated to the SAFE standard carry a second sheet named `Locations`,
holding the spatial coordinates of each sampling location. Export that sheet
too, as `locations.csv`, into the same folder as the data CSV.

A folder therefore usually ends up looking like this:

```text
data/primary/soil/dobert_2019/
├── template_Doebert.xlsx           # the file as downloaded
├── DoebertTF_SAFE_PlotData.csv     # the data sheet, converted manually
└── locations.csv                   # the Locations sheet, converted manually
```

`build_validation_database()` picks up `locations.csv` automatically, so no
configuration is needed for datasets that follow this convention. See
[Spatial coordinates](#spatial-coordinates) for datasets that do not.

## 2) Data screening

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

## 3) Add schema template for one included dataset

`add_schema()` modifies a record inside `sources.yaml` by DOI and appends schema
fields required by the build step.

```r
valdb$add_schema(
  source_yaml = "data/derived/soil/validation/config/sources.yaml",
  doi = "10.5281/ZENODO.2024580"
)
```

This opens the YAML file for manual editing.

## 4) Complete schema fields manually

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

### Spatial coordinates

The build adds four columns to every observation: `latitude`, `longitude`,
`location_type` and `coordinate_source`. Coordinates are always decimal
degrees (WGS84).

Datasets that follow the SAFE convention above need **no configuration at
all**: the build reads `locations.csv` from the same folder as `data_file`,
and matches its `Location name` column against the dataset's `dedup_key`.

`add_schema()` writes an optional `coordinates` block for the datasets that
differ. Every entry is optional, and entries left as `.na` are ignored, so
delete the ones you do not need, or delete the whole block:

```yaml
coordinates:
  # where the coordinates live
  # default: locations.csv next to data_file
  from_file: data/primary/soil/smith_2022/plots.csv
  # column in data_file holding the location name
  # default: the dedup_key, which must then be a single column
  match_data_column: site
  # column in the locations file holding the location name
  # default: Location name
  match_location_column: plot_code
  # coordinate columns in the locations file
  # defaults: Latitude and Longitude
  latitude_column: lat_dd
  longitude_column: lon_dd
```

When a source gives only one blanket location for every row, for example a
study site named in the paper but never pinned down per sample, use
`same_for_all_rows` **instead of** the entries above:

```yaml
coordinates:
  same_for_all_rows:
    latitude: 4.7422
    longitude: 116.9678
    note: "Paper states 'Maliau Basin Conservation Area' only"
```

`coordinate_source` records which of these routes supplied each row, and takes
one of three values:

| Value | Meaning |
| --- | --- |
| `locations_file` | Looked up from a locations file |
| `same_for_all_rows` | One blanket coordinate for the whole dataset |
| `missing` | No coordinates available; latitude and longitude are `NA` |

`location_type` carries the SAFE `Type` column verbatim, for example `POINT`
or `Carbon Plot`. It is useful for telling a precise GPS fix apart from a
plot-level location. It is `NA` when the locations file has no `Type` column,
and `"whole dataset"` under `same_for_all_rows`.

The build stops with an error if:

- a locations file has duplicated location names, because that would silently
  multiply the number of observations;
- any coordinate falls outside the valid range, which usually means the
  latitude and longitude columns are swapped or are in a projected coordinate
  system;
- `dedup_key` has more than one column and `match_data_column` was not given,
  because the location column is then ambiguous;
- `same_for_all_rows` is used without both `latitude` and `longitude`.

It warns, but continues, when the locations file is absent altogether, or when
some rows match no coordinates. Those rows get `NA` coordinates and a
`coordinate_source` of `missing`.

Sources giving northing/easting rather than decimal degrees are not yet
supported; they would need an EPSG code in the schema and a reprojection step.

## 5) Build the validation database

Run:

```r
valdb$build_validation_database()
```

Default behavior:

- Reads conversion rules from
  `data/derived/soil/validation/config/unit_conversions.csv`
- Builds canonical variable metadata from VE + local derived variables
- Reads dataset schemas from `data/derived/soil/validation/config/sources.yaml`
- Attaches spatial coordinates, by default from the `locations.csv` sitting
  next to each `data_file`
- Writes Parquet output to `data/derived/soil/validation/database`

Only sources that have a `source_id` are built, so screening records that were
never given a schema are ignored.

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

## Ongoing metadata curation

When new unit conversions are needed, edit:
`data/derived/soil/validation/config/unit_conversions.csv`

When new derived variables are needed, edit:
`data/derived/soil/validation/config/derived_variables.toml`

## Notes for contributors

- Keep schema edits small and commit frequently.
- Prefer explicit relative paths from repo root.
