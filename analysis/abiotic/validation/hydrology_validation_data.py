"""
---
title: Hydrology validation data

description: |
  Builds the observed side of the hydrology validation for the Virtual
  Ecosystem (VE) Maliau scenario. It does not read VE model output: it prepares
  observations in VE units and on the VE monthly time step, ready to be joined
  with VE output for the same grid cells and months in a later step.

  What the script does, in order:
    1. Lists the VE hydrology output variables, their units and validation
       priority from maliau_variables_summary.xlsx (the summary leaves out
       snow variables, as Maliau has no snow), plus the inputs and derived quantities
       (specific discharge, quickflow, baseflow index, runoff ratio,
       evapotranspiration) that the data can check.
    2. Reads the VE scenario grid (maliau_2, 10 x 10 cells of 100 m) and run
       period from maliau_grid_definition.toml.
    3. Reads the VJR (SAFE) and PF (Danum Valley) stream gauges: removes
       missing codes and negative values, averages the five-minute records to
       hourly values, fills gaps of up to 6 hours, splits baseflow and
       quickflow with the Lyne-Hollick filter, and sums to daily and monthly
       values (a month needs at least 80 % of its hours). Specific discharge
       (m3 s-1 km-2) x 3.6 gives runoff in mm per hour. PF rainfall comes from
       the Danum Valley weather station.
    4. Reads the storm events of both catchments.
    5. Reads the soil moisture surveys (hand-held probes, 0-12 cm) in
       old-growth plots, averages them per plot and month and converts them
       to the VE unit (theta x 250 mm, the VE top soil layer).
    6. Reads the literature values (rows with status "extracted" only).
    7. Puts every observation in one long table with the columns of the
       validation database (docs/validation_database.md), the value in the VE
       unit, where to read the VE value (sink cell or grid mean) and the
       spatial and temporal match classes (distance to the grid, overlap with
       the run period).
    8. Writes the Excel workbook and rewrites the validation tracker
       (Section 6 only) of docs/hydrology_validation_plan.md.

virtual_ecosystem_module: Hydrology

author:
  - Lelavathy

status: wip

input_files:
  - name: vjr_streamflow.csv, pf_streamflow.csv, vjr_event_basis_new.csv,
      pf_event_basis_new.csv
    path: data/primary/validation/dataset/safe_hydro/streamflow/{VJR,PF}/
    description: |
      Nainar et al. (2018, 2022). SAFE stream gauges 2011-2013: five-minute
      specific discharge, rainfall and water temperature, and storm event
      details.
      To change by hand: if a file is renamed or moved, edit streamflow_file
      and event_file under [sources.catchments.VJR] or [sources.catchments.PF]
      in hydrology_sources.toml (paths are relative to safe_hydro/). Catchment
      areas (VJR 3.08 km2, PF 1.7 km2) and gauging station coordinates are set
      there too. To use other catchments, edit comparison_catchments in the
      settings section.
  - name: SEARPP_compiled_climate_data_2025.xlsx
    path: data/primary/validation/dataset/safe_hydro/
    description: |
      O'Brien et al. (2026). SEARRP Danum Valley and Malua weather stations,
      daily climate 1985-2025. The Danum daily rainfall is used as PF
      rainfall.
      To change by hand: for a newer version of the file, edit the file name
      (data under [sources.files]), sheet and header_row of the source
      searrp_danum_climate_1985_2025 in hydrology_sources.toml.
  - name: SAFE_SoilRespiration_Data_SAFEdatabase_update_2021-01-11.xlsx,
      Termite_monitoring_maliau.xlsx, Carbon_corrected_slopes.xlsx
    path: data/primary/validation/dataset/safe_soil/
    description: |
      Riutta et al. (2021), Ashton et al. (2019), Orme et al. (2019). Soil
      moisture spot surveys (hand-held probes, 0-12 cm) in old-growth plots
      at Maliau and Danum Valley, 2011-2019.
      To change by hand: file, sheet, columns and the plot filters are in each
      source's file, sheet and [sources.keep] entries in
      hydrology_sources.toml. To add a soil moisture dataset, add a
      [[sources]] table there, set up like the existing soil moisture
      sources (file, sheet, value_column, keep filters, decision "proceed").
  - name: maliau_variables_summary.xlsx
    path: data/primary/validation/
    description: |
      VE output variables (output_variables sheet) with unit,
      classification, validation_priority and spin_up_sensitive, and the
      model constants (model_constats sheet).
      To change by hand: add or rename variables and set their priority in
      the output_variables sheet; the script reads it on every run. Close the
      file in Excel before running.
  - name: hydrology_sources.toml
    path: data/primary/validation/hydrology/
    description: |
      Where each dataset is, its columns, units, filters, coordinates,
      citation and screening record.
      To change by hand: whenever a data file is renamed, moved or added.
  - name: hydrology_literature_values.csv
    path: data/primary/validation/hydrology/
    description: |
      Published values and ranges, one row per value, with citation and DOI.
      To change by hand: add rows, and set status to "extracted" once a value
      is checked against the paper; other rows are not used.
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau/
    description: |
      The VE scenario grids and run period, used for the match classes.
      To change by hand: nothing here; to compare with another scenario, set
      scenario_name in the settings section.
  - name: gazetteer.geojson
    path: data/primary/site/
    description: |
      SAFE gazetteer, used for plot and catchment coordinates.

output_files:
  - name: hydrology_validation_data.xlsx
    path: data/derived/validation/hydrology/ (output_file in the settings
      section)
    description: |
      Hydrology validation workbook:  variable registry, catchments,
      sources, quality-control log, hourly, daily and monthly stream values,
      Danum daily rainfall, storm events, soil moisture, literature values and
      one long table (validation_long) in the validation database layout.
      The whole workbook is rewritten on every run.
  - name: hydrology_validation_plan.md
    path: docs/ (plan_file in the settings section)
    description: |
      Only the validation tracker (Section 6) is written: the script replaces
      the text between the <!-- tracker:start --> and <!-- tracker:end -->
      lines and leaves the rest of the plan unchanged. Edits made inside the
      tracker block are lost on the next run; edit the other sections freely.
      Both marker lines must stay in the plan, or the script stops with an
      error. Close the plan in your editor before running, so an unsaved copy
      does not overwrite the new tracker.

package_dependencies:
  - pandas
  - numpy
  - openpyxl
  - pyproj

usage_notes: |
  Run from anywhere inside the repository:

   `python analysis/abiotic/validation/hydrology_validation_data.py`

  Edit only the settings section (paths, catchments, gap and completeness
  limits, Lyne-Hollick filter, scenario). The dataset folder can also be set
  with the VE_SAFE_DIR environment variable.
---
"""  # noqa: D400, D212, D205, D415

import json
import os
import tomllib
from pathlib import Path

import numpy as np
import pandas as pd
from openpyxl.styles import Font
from openpyxl.utils import get_column_letter
from pyproj import Transformer

# ============================================================
# OVERVIEW
# ============================================================
# This script builds the observed side of the hydrology validation. It does not
# read VE outputs: joining VE outputs to these observations is a later step (see
# `docs/hydrology_validation_plan.md`). The abiotic validation is in
# `abiotic_validation_data.py` in this folder.
#
# Steps:
#
# 1. List the VE hydrology output variables from `maliau_variables_summary.xlsx`,
#    plus the inputs and derived quantities the data can check.
# 2. Look up approximate catchment coordinates in the SAFE gazetteer.
# 3. Read and clean the VJR and PF stream gauges; put them on an hourly step,
#    fill short gaps, derive specific discharge, runoff, baseflow, quickflow and
#    ratios, and aggregate to monthly values and record means.
#    Read the soil moisture surveys and average them per plot and month.
# 4. Read the literature values.
# 5. Combine monthly observations, record means and literature values in one long
#    table that uses the validation database columns
#    (`docs/validation_database.md`).
# 6. Summarise data availability per VE variable, write the Excel workbook and
#    the tracker table (Section 6) in the hydrology_validation_plan.md.
#
# The VE `maliau_2` scenario runs on a monthly time step, so the monthly tables are
# the ones to compare against. Hourly tables are kept for checks of storm response.

# ============================================================
# SETTINGS
# ============================================================
# Edit only this section. Relative paths are relative to the repository root.
# The input_files notes in the header say what else may need changing by hand
# (mostly in hydrology_sources.toml) when data files are renamed or added.


# Dataset folder holding safe_hydro/ and safe_soil/. Set the VE_SAFE_DIR
# environment variable or change the default; an absolute path works.
safe_dir = os.environ.get("VE_SAFE_DIR", "data/primary/validation/dataset")

variables_summary_file = "data/primary/validation/maliau_variables_summary.xlsx"
sources_file = "data/primary/validation/hydrology/hydrology_sources.toml"
literature_file = "data/primary/validation/hydrology/hydrology_literature_values.csv"
gazetteer_file = "data/primary/site/gazetteer.geojson"

output_file = "data/derived/validation/hydrology/hydrology_validation_data.xlsx"
plan_file = "docs/hydrology_validation_plan.md"


# Catchments compared with Maliau, gap filling and completeness.
comparison_catchments = ["VJR", "PF"]  # areas are in hydrology_sources.toml
min_records_per_hour = 6  # of the 12 five-minute records
max_fill_gap_hours_streams = 6  # interpolate discharge gaps up to this many hours
min_month_coverage = 0.8  # share of hours with data for a complete month
lh_alpha = 0.98  # Lyne-Hollick filter parameter for hourly data
lh_passes = 3
max_dry_run_days = (
    20  # longer runs of exactly zero rainfall are treated as gauge failure
)
min_hours_per_day = 20  # hours with runoff for a complete day

# VE scenario from the site definition. Observations are matched against its grid.
grid_definition_file = "data/derived/site/maliau/maliau_grid_definition.toml"
scenario_name = "maliau_2"  # 10 x 10 cells of 100 m
near_grid_km = 2  # sites this close to the grid edge are "near grid"
regional_max_km = 100  # beyond this distance from the grid there is no spatial match

# VE soil layers (core config soil_layers, default [-0.25, -1.0] m). The probes
# measure the top 12 cm, so they are compared with the top soil layer.
topsoil_depth_m = 0.25

# ============================================================
# PROJECT ROOT AND HELPER FUNCTIONS
# ============================================================
# Determine the root directory of the ve_data_science repository (the
# first parent folder holding pyproject.toml and mkdocs.yml), resolve the
# paths in the settings, read hydrology_sources.toml and define the helper
# functions used below (quality-control log, gap filling).


def find_repo_root(start: Path) -> Path:
    """Return the first parent folder holding pyproject.toml and mkdocs.yml."""
    for folder in [start, *start.parents]:
        if (folder / "pyproject.toml").exists() and (folder / "mkdocs.yml").exists():
            return folder
    raise FileNotFoundError("Run the script from inside the ve_data_science repo.")


repo_root = find_repo_root(Path(__file__).resolve().parent)


def repo_path(path: str) -> Path:
    """Resolve a path relative to the repository root (absolute paths unchanged)."""
    path = Path(path)
    return path if path.is_absolute() else repo_root / path


safe_path = repo_path(safe_dir)
if not safe_path.exists():
    raise FileNotFoundError(
        f"Dataset folder not found: {safe_dir}. Set safe_dir or VE_SAFE_DIR."
    )

with open(repo_path(sources_file), "rb") as f:
    sources = {s["source_id"]: s for s in tomllib.load(f)["sources"]}
st_source = sources["safe_streams_2011_2013"]
local_tz = st_source["local_timezone"]

qc_log = []  # one row per quality-control step


def log_qc(dataset: str, location: str, step: str, n_rows: int, note: str = "") -> None:
    """Record one quality-control step."""
    qc_log.append(
        {
            "dataset": dataset,
            "location": location,
            "step": step,
            "rows": int(n_rows),
            "note": note,
        }
    )


def fill_short_gaps(series: pd.Series, max_gap: int) -> tuple[pd.Series, pd.Series]:
    """Linearly interpolate runs of missing values no longer than max_gap steps.

    Args:
      series: Values on a regular time index.
      max_gap: Longest run of missing steps to fill.

    Returns:
      The filled series and a boolean series marking filled steps.

    """
    missing = series.isna()
    run_id = (missing != missing.shift()).cumsum()
    run_length = missing.groupby(run_id).transform("sum")
    fillable = missing & (run_length <= max_gap)
    interpolated = series.interpolate(method="time", limit_area="inside")
    filled = series.where(~fillable, interpolated)
    return filled, fillable & filled.notna()


pd.set_option("display.width", 160)
print("Repository root found; SAFE folder:", safe_dir)

# ============================================================
# 1. VE OUTPUT VARIABLES TO VALIDATE
# ============================================================
# `maliau_variables_summary.xlsx` lists the output variables per module
# (`output_variables` sheet), with their classification, validation priority
# and spin-up sensitivity.
# The sheets repeat their header row between modules, so the module name is filled
# down and repeated header rows are dropped. `abiotc_simple` is read as
# `abiotic_simple`. Only the hydrology variables are kept, plus the inputs and
# derived quantities that the stream data and literature can check.

summary_xlsx = repo_path(variables_summary_file)

outputs = pd.read_excel(summary_xlsx, sheet_name="output_variables")
outputs = outputs[outputs["var_name_provided"].notna()]
outputs = outputs[outputs["var_name_provided"] != "var_name_provided"]
outputs["module"] = (
    outputs["module"].ffill().replace({"abiotc_simple": "abiotic_simple"}).str.strip()
)
outputs = outputs.rename(
    columns={
        "var_name_provided": "variable",
        "unit_provided": "unit_ve",
        "description_origin": "description",
    }
)[
    [
        "module",
        "variable",
        "unit_ve",
        "description",
        "classification",
        "validation_priority",
        "spin_up_sensitive",
    ]
]
outputs["variable"] = outputs["variable"].str.strip()

registry = outputs[outputs["module"] == "hydrology"]

# Inputs and derived quantities that the observations or literature also cover.
extra_rows = pd.DataFrame(
    [
        (
            "hydrology",
            "precipitation",
            "mm",
            "Rainfall input (ERA5 forcing)",
            "Input check",
        ),
        (
            "hydrology",
            "quickflow",
            "mm",
            "Derived: surface_runoff_routed_plus_local + subsurface_stormflow",
            "Derived flux",
        ),
        (
            "hydrology",
            "baseflow_index",
            "fraction",
            "Derived: baseflow / total_runoff",
            "Derived ratio",
        ),
        (
            "hydrology",
            "specific_discharge",
            "m³ s⁻¹ km⁻²",
            "Derived: river_discharge_rate / upstream area",
            "Derived flux",
        ),
        (
            "hydrology",
            "runoff_ratio",
            "fraction",
            "Derived: total_runoff / precipitation",
            "Derived ratio",
        ),
        (
            "hydrology",
            "transpiration",
            "mm",
            "Transpiration passed from the plants module",
            "Derived flux",
        ),
        (
            "hydrology",
            "evapotranspiration",
            "mm",
            "Derived: canopy_evaporation + soil_evaporation + transpiration",
            "Derived flux",
        ),
        (
            "hydrology",
            "saturated_hydraulic_conductivity",
            "m s⁻¹",
            "Model constant",
            "Constant check",
        ),
    ],
    columns=["module", "variable", "unit_ve", "description", "classification"],
)
registry = pd.concat([registry, extra_rows], ignore_index=True)
print(registry.groupby("module").size().to_string())
print(registry.head(10))

# ============================================================
# 2. SITES AND COORDINATES
# ============================================================
# Catchment coordinates come from the SAFE gazetteer (`centroid_x`,
# `centroid_y`, WGS84), the same fallback the validation database uses. Only the
# VJR sampling-block centroid is available, as an approximate location; PF has
# no coordinates yet. Each site is checked against the `maliau_2` grid.

gazetteer = pd.DataFrame(
    [f["properties"] for f in json.load(open(repo_path(gazetteer_file)))["features"]]
)[["location", "type", "centroid_x", "centroid_y"]].rename(
    columns={
        "centroid_x": "longitude",
        "centroid_y": "latitude",
        "type": "gazetteer_type",
    }
)
gazetteer = gazetteer.drop_duplicates("location")


def load_scenario(name: str) -> dict:
    """Return the grid bounds and run period of one scenario in the site definition."""
    with open(repo_path(grid_definition_file), "rb") as f:
        site = tomllib.load(f)["Scenario"][name]
    timing = site["core"]["timing"]
    assert timing["update_interval"] == "1 month", timing["update_interval"]
    years, unit = timing["run_length"].split()
    assert unit == "years", timing["run_length"]
    start = pd.Timestamp(timing["start_date"])
    end = start + pd.DateOffset(years=int(years))  # first day after the run
    last = end - pd.DateOffset(months=1)
    return {
        "name": name,
        "epsg_code": site["epsg_code"],
        "ll_x": site["ll_x"],
        "ll_y": site["ll_y"],
        "ur_x": site["ur_x"],
        "ur_y": site["ur_y"],
        "start": start,
        "end": end,
        "period": f"{start:%Y-%m} to {last:%Y-%m}",
        "time_step": "monthly",
    }


scenario = load_scenario(scenario_name)
print(
    scenario["name"], scenario["period"], "bounds", scenario["ll_x"], scenario["ll_y"]
)

to_utm = Transformer.from_crs(
    "EPSG:4326", f"EPSG:{scenario['epsg_code']}", always_xy=True
)


def distance_to_grid_km(lat, lon, grid: dict) -> np.ndarray:
    """Return the distance (km) from points to the edge of a grid; 0 inside it."""
    x, y = to_utm.transform(np.asarray(lon, float), np.asarray(lat, float))
    dx = np.maximum.reduce([grid["ll_x"] - x, np.zeros_like(x), x - grid["ur_x"]])
    dy = np.maximum.reduce([grid["ll_y"] - y, np.zeros_like(y), y - grid["ur_y"]])
    return np.hypot(dx, dy) / 1000


def add_scenario_overlap(sites: pd.DataFrame) -> pd.DataFrame:
    """Flag sites inside the scenario grid and give their distance to its edge."""
    distance = distance_to_grid_km(sites["latitude"], sites["longitude"], scenario)
    sites["in_scenario_grid"] = distance == 0
    sites["distance_to_grid_km"] = np.where(
        np.isfinite(distance), distance.round(2), np.nan
    )
    return sites


# ============================================================
# 3. STREAM GAUGES (VJR AND PF)
# ============================================================
# Only the two forest catchments closest to Maliau old-growth forest are used:
# VJR (Virgin Jungle Reserve, 3.08 km²) and PF (primary forest, 1.7 km²). Each
# has a five-minute record of specific discharge (m³ s⁻¹ km⁻², discharge already
# divided by the catchment area), rainfall (mm) and water temperature in
# `streamflow/VJR/vjr_streamflow.csv` and `streamflow/PF/pf_streamflow.csv`,
# and a table of storm events in `*_event_basis_new.csv`. The VJR file
# gives only the date of each record; times are rebuilt from the record's
# position within the day.
# Storm-event details come from `*_event_basis_new.csv` only.
#
# Cleaning and gap filling:
#
# 1. Set -999, -6999 and `NAN` to missing; set negative discharge and water
#    temperature outside 0-40 °C to missing. The PF stream gauge has no rainfall
#    and no valid water temperature; PF rainfall comes from the daily Danum Valley
#    weather station record instead (section 3.1).
# 2. Aggregate to a regular hourly series: an hour needs at least
#    `min_records_per_hour` of its 12 five-minute records. Hourly rainfall is the
#    sum scaled to 12 records.
# 3. Fill discharge gaps of up to `max_fill_gap_hours_streams` hours by linear
#    interpolation in time and flag them (`discharge_filled`). Longer gaps stay
#    missing; they are not invented. Rainfall gaps are not filled; monthly rainfall
#    is scaled from the days with data. At a catchment's own rain gauge, runs of
#    exactly zero rainfall longer than `max_dry_run_days`, and months with less
#    rainfall than runoff, are treated as gauge failures and set missing. Months
#    where the off-site Danum station rainfall is below PF runoff are kept and
#    flagged (`rainfall_below_runoff`).
#
# Derived hydrology quantities, all from streamflow:
#
# * specific discharge $q$ (m³ s⁻¹ km⁻²) is the recorded value, so catchments of
#   different size compare directly with each other and with a VE grid of known
#   contributing area; discharge $Q = q \times A$ (m³ s⁻¹) is derived for
#   comparison with `river_discharge_rate`;
# * total runoff depth (mm) $= q \times 3.6$ per hour, since
#   1 m³ s⁻¹ km⁻² for one hour is 3.6 mm;
# * baseflow and quickflow from a Lyne-Hollick digital filter on hourly runoff
#   (`lh_alpha`, `lh_passes`); the share of storm runoff that the source's event
#   separation calls subsurface flow (Qsub / QY) is kept as a check;
# * baseflow index (baseflow / total runoff), runoff ratio (runoff / rainfall)
#   and the water-balance residual $P - Q$, which approximates
#   evapotranspiration over long periods.
#
# Monthly values are means (or totals scaled to the full month) over the hours
# with data; a month is complete with at least `min_month_coverage` of its hours.

st_cols = st_source["columns"]
missing_values = st_source["missing_values"]
origin = pd.Timestamp(st_source["excel_origin"])
hydro_dir = safe_path / "safe_hydro"


def lyne_hollick(flow: np.ndarray, alpha: float, passes: int) -> np.ndarray:
    """Return baseflow from the Lyne-Hollick digital filter.

    Passes alternate forward and backward; each pass filters the baseflow of
    the previous one. Baseflow is kept between zero and the flow.

    Args:
      flow: Flow series without missing values.
      alpha: Filter parameter.
      passes: Number of passes.

    """
    base = flow.astype(float).copy()
    for p in range(passes):
        x = base if p % 2 == 0 else base[::-1]
        quick = np.zeros_like(x)
        for k in range(1, len(x)):
            quick[k] = max(
                alpha * quick[k - 1] + (1 + alpha) / 2 * (x[k] - x[k - 1]), 0
            )
        y = np.clip(x - quick, 0, x)
        base = y if p % 2 == 0 else y[::-1]
    return base


def baseflow_by_segment(runoff: pd.Series) -> pd.Series:
    """Apply the Lyne-Hollick filter to each unbroken run of hourly runoff."""
    base = pd.Series(np.nan, index=runoff.index)
    present = runoff.notna()
    segment = (present != present.shift()).cumsum()
    for _, part in runoff[present].groupby(segment[present]):
        base.loc[part.index] = lyne_hollick(part.to_numpy(), lh_alpha, lh_passes)
    return base


def read_streamflow(path: Path) -> pd.DataFrame:
    """Read a streamflow file and return time, discharge, rainfall and temperature.

    Rows are consecutive five-minute records; event rows refer to them by their
    1-based position. The VJR csv gives only the date, so the time of each record
    is rebuilt from its position within the day (exact for complete days of 288
    records; flagged `time_approximate` on shorter days). The PF workbook gives
    Excel serial date-times in local logger time; it is an Excel workbook
    saved with a .csv name, so the format is read from the file content.
    """
    with open(path, "rb") as f:
        is_excel = f.read(4) == b"PK\x03\x04"  # xlsx content, whatever the extension
    raw = pd.read_excel(path, engine="openpyxl") if is_excel else pd.read_csv(path)
    raw.columns = [c["name"] for c in st_cols["streamflow"]]
    out = raw[["discharge", "rainfall", "water_temperature"]].apply(
        pd.to_numeric, errors="coerce"
    )
    if pd.api.types.is_numeric_dtype(raw["date"]):
        out.insert(
            0, "time", (origin + pd.to_timedelta(raw["date"], unit="D")).dt.round("min")
        )
        out["time_approximate"] = False
    else:
        day = pd.to_datetime(raw["date"], format="%d/%m/%Y")
        position = day.groupby(day).cumcount()
        out.insert(0, "time", day + pd.to_timedelta(position * 5, unit="min"))
        out["time_approximate"] = day.map(day.value_counts()) < 288
    return out


hourly_frames, event_frames, stream_sites = [], [], []
for name in comparison_catchments:
    catch = st_source["catchments"][name]
    area = catch["catchment_area_km2"]

    # 1. Clean the five-minute records.
    df = read_streamflow(hydro_dir / catch["streamflow_file"])
    log_qc(
        "streams",
        name,
        "records with time rebuilt on incomplete days",
        df["time_approximate"].sum(),
        "date-only file; position within the day",
    )
    for col in ["discharge", "rainfall", "water_temperature"]:
        coded = df[col].isin(missing_values)
        if coded.any():
            log_qc(
                "streams", name, f"{col} missing-value codes set missing", coded.sum()
            )
        df.loc[coded, col] = np.nan
    checks = {
        "negative discharge": df["discharge"] < 0,
        "negative rainfall": df["rainfall"] < 0,
        "water temperature outside 0-40": ~df["water_temperature"].between(0, 40)
        & df["water_temperature"].notna(),
    }
    for step, mask in checks.items():
        log_qc("streams", name, f"{step} set missing", mask.sum())
    df.loc[checks["negative discharge"], "discharge"] = np.nan
    df.loc[checks["negative rainfall"], "rainfall"] = np.nan
    df.loc[checks["water temperature outside 0-40"], "water_temperature"] = np.nan
    rows = df["time"].copy()  # event rows refer to this order
    dup = df["time"].duplicated()
    log_qc("streams", name, "duplicate times dropped", dup.sum())
    df = df.loc[~dup]
    if df["rainfall"].isna().all():
        log_qc("streams", name, "no rainfall record", len(df))

    # 2. Hourly series on a regular index.
    grouped = df.set_index("time").resample("h")
    h = pd.DataFrame(
        {
            "n_records": grouped["discharge"].count(),
            "discharge_raw": grouped["discharge"].mean(),
            "n_rain": grouped["rainfall"].count(),
            "rainfall": grouped["rainfall"].sum(min_count=1),
            "water_temperature": grouped["water_temperature"].mean(),
        }
    )
    short_hour = h["n_records"] < min_records_per_hour
    h.loc[short_hour, "discharge_raw"] = np.nan
    h["rainfall"] = np.where(
        h["n_rain"] >= min_records_per_hour, h["rainfall"] * 12 / h["n_rain"], np.nan
    )
    log_qc(
        "streams",
        name,
        "hours with too few records set missing",
        short_hour.sum(),
        f"fewer than {min_records_per_hour} of 12",
    )
    dry = h["rainfall"] == 0
    dry_run = (dry != dry.shift()).cumsum()
    long_dry = dry & (dry.groupby(dry_run).transform("sum") > max_dry_run_days * 24)
    h.loc[long_dry, "rainfall"] = np.nan
    log_qc(
        "streams",
        name,
        "zero-rainfall runs set missing (gauge failure)",
        long_dry.sum(),
        f"runs longer than {max_dry_run_days} days",
    )

    # 3. Fill short discharge gaps.
    h["discharge"], h["discharge_filled"] = fill_short_gaps(
        h["discharge_raw"], max_fill_gap_hours_streams
    )
    log_qc(
        "streams",
        name,
        "hourly discharge gaps filled",
        h["discharge_filled"].sum(),
        f"gaps up to {max_fill_gap_hours_streams} h, linear in time",
    )
    log_qc(
        "streams",
        name,
        "hourly discharge still missing",
        h["discharge"].isna().sum(),
        "longer gaps left missing",
    )

    # Derived quantities.
    # The source records specific discharge (m3 s-1 km-2); Q = q x A in m3 s-1.
    h["specific_discharge"] = h["discharge"]
    h["discharge"] = h["specific_discharge"] * area
    h["runoff_mm"] = h["specific_discharge"] * 3.6  # mm per hour
    h["baseflow_mm"] = baseflow_by_segment(h["runoff_mm"])
    h["quickflow_mm"] = h["runoff_mm"] - h["baseflow_mm"]
    h = h.reset_index(names="time")
    h.insert(0, "location", name)
    hourly_frames.append(h)

    # Storm events as given in *_event_basis_new.csv. Checked against the
    # streamflow file: Qinitial, Qend and Qpeak equal the specific discharge
    # (m3 s-1 km-2) at the start, end and peak rows, and Ttpeak is the time in
    # minutes from start to peak, whatever the headers say. QY, Qsub and Qstorm
    # are depths in mm.
    events = pd.read_csv(hydro_dir / catch["event_file"])
    events.columns = [c["name"] for c in st_cols["events"]]
    events.loc[events["rainfall"] < 0, "rainfall"] = np.nan
    events.insert(0, "location", name)
    events.insert(4, "start_time", rows.iloc[events["start_row"] - 1].to_numpy())
    events.insert(5, "end_time", rows.iloc[events["end_row"] - 1].to_numpy())
    events.insert(
        6,
        "duration_h",
        (events["end_time"] - events["start_time"]).dt.total_seconds() / 3600,
    )
    events = events.rename(
        columns={
            "rainfall": "rainfall_mm",
            "q_total": "q_total_mm",
            "q_sub": "q_sub_mm",
            "q_storm": "q_storm_mm",
            "q_initial": "q_initial_m3_s_km2",
            "q_end": "q_end_m3_s_km2",
            "q_peak": "q_peak_m3_s_km2",
            "t_peak": "t_peak_min",
            "t_storm": "t_storm_min",
        }
    )
    events["runoff_coefficient"] = events["q_total_mm"] / events["rainfall_mm"].where(
        events["rainfall_mm"] > 0
    )
    log_qc("streams", name, "storm events read", len(events), catch["event_file"])
    event_frames.append(events)

    stream_sites.append(
        {
            "location": name,
            "dataset": st_source["source_id"],
            "habitat": catch["habitat"],
            "site_group": "SAFE (Maliau analogue)",
            "catchment_area_km2": area,
            "gazetteer_location": catch.get("gazetteer_location"),
            "outlet_latitude": catch.get("outlet_latitude"),
            "outlet_longitude": catch.get("outlet_longitude"),
            "first_record": df["time"].min(),
            "last_record": df["time"].max(),
            "notes": catch.get("notes", ""),
        }
    )

st_hourly = pd.concat(hourly_frames, ignore_index=True)
storm_events = pd.concat(event_frames, ignore_index=True)
print(
    st_hourly.groupby("location").agg(
        first=("time", "min"),
        last=("time", "max"),
        hours=("time", "size"),
        hours_with_discharge=("discharge", "count"),
        filled_hours=("discharge_filled", "sum"),
    )
)

# ============================================================
# 3.1 DAILY RAINFALL
# ============================================================
# The PF stream gauge recorded no rainfall, so PF uses the daily rainfall of the
# Danum Valley Field Centre weather station (SEARRP compiled climate data,
# 1985-2025, `rainfall_source` in `hydrology_sources.toml`). The file holds one
# row per station and day, with metadata rows above the `field_name` header.
# Days are taken as calendar days in local time; the file does not state the
# reading time of the gauge. Missing days stay missing.
#
# Every catchment also gets a daily table: runoff, baseflow and quickflow are
# summed from hourly values on days with at least `min_hours_per_day` hours of
# runoff (scaled to 24 h), and rainfall is the stream gauge's own (VJR, days
# with at least `min_hours_per_day` hours of rain) or the daily station record
# (PF). Monthly rainfall, the runoff ratio and the record water balance for
# both catchments come from this daily table.

rain_sources = {
    name: sources[st_source["catchments"][name]["rainfall_source"]]
    for name in comparison_catchments
    if st_source["catchments"][name].get("rainfall_source")
}
station_daily = {}
for name, src in rain_sources.items():
    raw = pd.read_excel(
        safe_path / src["files"]["data"],
        sheet_name=src["sheet"],
        header=src["header_row"] - 1,
        na_values=src["missing_values"],
    )
    raw["date"] = pd.to_datetime(
        raw["year"].astype(str)
        + "-"
        + raw["month"].astype(str)
        + "-"
        + raw["day"].astype(str),
        format="%Y-%b-%d",
        errors="coerce",
    )
    raw = raw[raw["location"] == src["station"]]
    bad_date = raw["date"].isna()
    log_qc(
        src["source_id"],
        src["station"],
        "rows with invalid dates dropped",
        bad_date.sum(),
    )
    raw = raw[~bad_date].drop_duplicates("date").set_index("date").sort_index()
    rain = pd.to_numeric(raw[src["rain_column"]], errors="coerce")
    negative = rain < 0
    log_qc(
        src["source_id"],
        src["station"],
        "negative rainfall set missing",
        negative.sum(),
    )
    rain[negative] = np.nan
    rain = rain.reindex(pd.date_range(rain.index.min(), rain.index.max(), freq="D"))
    log_qc(
        src["source_id"],
        src["station"],
        "days without rainfall",
        rain.isna().sum(),
        "left missing",
    )
    station_daily[name] = rain.rename("rainfall_mm")

danum_daily = (
    next(iter(station_daily.values())).rename_axis("date").reset_index()
    if station_daily
    else pd.DataFrame(columns=["date", "rainfall_mm"])
)

st_hourly["date"] = st_hourly["time"].dt.floor("D")
st_daily = st_hourly.groupby(["location", "date"], as_index=False).agg(
    n_hours=("runoff_mm", "count"),
    n_hours_rain=("rainfall", "count"),
    runoff_mm=("runoff_mm", "mean"),
    baseflow_mm=("baseflow_mm", "mean"),
    quickflow_mm=("quickflow_mm", "mean"),
    rainfall_mm=("rainfall", "mean"),
)
day_ok = st_daily["n_hours"] >= min_hours_per_day
for col in ["runoff_mm", "baseflow_mm", "quickflow_mm"]:
    st_daily[col] = np.where(day_ok, st_daily[col] * 24, np.nan)
st_daily["rainfall_mm"] = np.where(
    st_daily["n_hours_rain"] >= min_hours_per_day, st_daily["rainfall_mm"] * 24, np.nan
)
st_daily["rainfall_source"] = "stream gauge"
for name, rain in station_daily.items():
    here = st_daily["location"] == name
    st_daily.loc[here, "rainfall_mm"] = st_daily.loc[here, "date"].map(rain).to_numpy()
    st_daily.loc[here, "rainfall_source"] = rain_sources[name]["source_id"]
st_daily = st_daily.drop(columns="n_hours_rain")
st_hourly = st_hourly.drop(columns="date")
print(
    st_daily.groupby("location").agg(
        days=("date", "size"),
        complete_days=("runoff_mm", "count"),
        days_with_rain=("rainfall_mm", "count"),
        rainfall_source=("rainfall_source", "first"),
    )
)

# ============================================================
# MONTHLY STREAM AND RAINFALL VALUES
# ============================================================
# Monthly values. Means and totals use the hours with data; totals are scaled to
# the full month ($X_m = \bar{x}_h \times$ hours in month). The record summary
# uses every complete month and annualises hourly means (x 8 766 hours).

st_hourly["month"] = st_hourly["time"].dt.to_period("M")
st_monthly = st_hourly.groupby(["location", "month"], as_index=False).agg(
    n_hours=("discharge", "count"),
    n_hours_filled=("discharge_filled", "sum"),
    n_hours_rain=("rainfall", "count"),
    discharge_mean=("discharge", "mean"),
    specific_discharge_mean=("specific_discharge", "mean"),
    runoff_mm_hour=("runoff_mm", "mean"),
    baseflow_mm_hour=("baseflow_mm", "mean"),
    quickflow_mm_hour=("quickflow_mm", "mean"),
    rainfall_mm_hour=("rainfall", "mean"),
    water_temperature_mean=("water_temperature", "mean"),
)
hours_in_month = st_monthly["month"].dt.days_in_month * 24
st_monthly["coverage"] = st_monthly["n_hours"] / hours_in_month
st_monthly["complete_month"] = st_monthly["coverage"] >= min_month_coverage
for col in ["runoff", "baseflow", "quickflow"]:
    st_monthly[f"{col}_month_mm"] = st_monthly[f"{col}_mm_hour"] * hours_in_month
st_daily["month"] = st_daily["date"].dt.to_period("M")
rain_monthly = st_daily.groupby(["location", "month"], as_index=False).agg(
    n_days_rain=("rainfall_mm", "count"),
    rainfall_mm_day=("rainfall_mm", "mean"),
    rainfall_source=("rainfall_source", "first"),
)
st_daily = st_daily.drop(columns="month")
days_in_month = rain_monthly["month"].dt.days_in_month
rain_monthly["rainfall_month_mm"] = np.where(
    rain_monthly["n_days_rain"] / days_in_month >= min_month_coverage,
    rain_monthly["rainfall_mm_day"] * days_in_month,
    np.nan,
)
st_monthly = st_monthly.drop(columns="n_hours_rain").merge(
    rain_monthly.drop(columns="rainfall_mm_day"), on=["location", "month"], how="left"
)
st_monthly["baseflow_index"] = (
    st_monthly["baseflow_month_mm"] / st_monthly["runoff_month_mm"]
)
# At the catchment's own gauge, a month with less rain than runoff points to a
# failed gauge, so the rainfall is set missing. Station rainfall measured
# outside the catchment (PF) is kept and only flagged, since a wet month can give
# more runoff than the distant gauge recorded.
st_monthly["rainfall_below_runoff"] = (
    st_monthly["rainfall_month_mm"] < st_monthly["runoff_month_mm"]
)
low_rain = st_monthly["rainfall_below_runoff"] & (
    st_monthly["rainfall_source"] == "stream gauge"
)
for name, n in st_monthly[low_rain].groupby("location").size().items():
    log_qc(
        "streams",
        name,
        "months with rainfall below runoff set missing",
        n,
        "gauge failure",
    )
for name, n in (
    st_monthly[st_monthly["rainfall_below_runoff"] & ~low_rain]
    .groupby("location")
    .size()
    .items()
):
    log_qc(
        "streams", name, "months with station rainfall below runoff flagged", n, "kept"
    )
st_monthly.loc[low_rain, "rainfall_month_mm"] = np.nan
st_monthly["runoff_ratio"] = (
    st_monthly["runoff_month_mm"] / st_monthly["rainfall_month_mm"]
)
st_monthly = st_monthly.drop(columns=[c for c in st_monthly if c.endswith("_mm_hour")])

# Record summary over complete months, annualised.
hours_per_year = 8766
complete_hours = st_hourly.merge(
    st_monthly.loc[
        st_monthly["complete_month"], ["location", "month", "rainfall_month_mm"]
    ],
    on=["location", "month"],
)
# Water balance from days with both runoff and rainfall in complete months whose
# rainfall passed the gauge checks.
days_per_year = 365.25
balance_days = st_daily.assign(month=st_daily["date"].dt.to_period("M")).merge(
    st_monthly.loc[
        st_monthly["complete_month"] & st_monthly["rainfall_month_mm"].notna(),
        ["location", "month"],
    ],
    on=["location", "month"],
)
balance_days = balance_days[
    balance_days["runoff_mm"].notna() & balance_days["rainfall_mm"].notna()
]
summary_rows = []
for name, part in complete_hours.groupby("location"):
    runoff = part["runoff_mm"].mean() * hours_per_year
    baseflow = part["baseflow_mm"].mean() * hours_per_year
    days = balance_days[balance_days["location"] == name]
    rain = days["rainfall_mm"].mean() * days_per_year if len(days) else np.nan
    runoff_rain_days = days["runoff_mm"].mean() * days_per_year if len(days) else np.nan
    summary_rows.append(
        {
            "location": name,
            "period_start": str(part["month"].min()),
            "period_end": str(part["month"].max()),
            "complete_months": part["month"].nunique(),
            "specific_discharge_mean": part["specific_discharge"].mean(),
            "discharge_mean": part["discharge"].mean(),
            "runoff_mm_year": runoff,
            "baseflow_mm_year": baseflow,
            "quickflow_mm_year": runoff - baseflow,
            "baseflow_index": baseflow / runoff,
            # Share of storm runoff that the source separation calls subsurface
            # flow (Qsub / QY over all events); a check on the filter, not a BFI.
            "event_qsub_share": storm_events.loc[
                storm_events["location"] == name, "q_sub_mm"
            ].sum()
            / storm_events.loc[storm_events["location"] == name, "q_total_mm"].sum(),
            "n_events": int((storm_events["location"] == name).sum()),
            "rainfall_mm_year": rain,
            "rainfall_days": len(days),
            "rainfall_period_start": str(days["month"].min()) if len(days) else None,
            "rainfall_period_end": str(days["month"].max()) if len(days) else None,
            "rainfall_source": st_daily.loc[
                st_daily["location"] == name, "rainfall_source"
            ].iloc[0],
            "runoff_ratio": runoff_rain_days / rain if len(days) else np.nan,
            "p_minus_q_mm_year": rain - runoff_rain_days if len(days) else np.nan,
        }
    )
st_summary = pd.DataFrame(summary_rows)

st_sites = pd.DataFrame(stream_sites).merge(
    gazetteer.rename(columns={"location": "gazetteer_location"}),
    on="gazetteer_location",
    how="left",
)
st_sites["location_type"] = "catchment"
# Gauging-station (outlet) coordinates from hydrology_sources.toml take priority
# over the gazetteer sampling-block centroid.
has_outlet = st_sites["outlet_latitude"].notna() & st_sites["outlet_longitude"].notna()
st_sites["coordinate_source"] = np.select(
    [has_outlet, st_sites["latitude"].notna()],
    ["gauging_station_outlet", "gazetteer_block_centroid_unverified"],
    "missing",
)
st_sites.loc[has_outlet, "latitude"] = st_sites.loc[has_outlet, "outlet_latitude"]
st_sites.loc[has_outlet, "longitude"] = st_sites.loc[has_outlet, "outlet_longitude"]
st_sites = st_sites.drop(columns=["outlet_latitude", "outlet_longitude"])
st_sites = st_sites.merge(
    st_monthly[st_monthly["complete_month"]]
    .groupby("location")
    .size()
    .rename("complete_months"),
    on="location",
    how="left",
).fillna({"complete_months": 0})
st_sites = add_scenario_overlap(st_sites)
st_sites.loc[st_sites["latitude"].isna(), "in_scenario_grid"] = False
print(st_summary.round(3))

# ============================================================
# 3.2 SOIL MOISTURE
# ============================================================
# Soil moisture comes from spot surveys with hand-held probes (0-12 cm) in
# old-growth forest plots, listed in `hydrology_sources.toml` (sources with a
# `value_column`):
#
# * `safe_soil_respiration_2011_2018`: SAFE carbon plots, about monthly visits,
#   2011-2018; Car_Bel and Car_Ser at Maliau, Car_D1 and Car_D2 at Danum Valley;
# * `safe_termite_maliau_2015_2016`: four control plots at Maliau, March 2016
#   (El Niño drought) and October 2016;
# * `safe_belian_soil_flux_2019`: Belian plot at Maliau, four days in February 2019
#   (file `Carbon_corrected_slopes.xlsx`).
#
# Cleaning: values outside 0-100 % are set missing; rows are kept only where the
# `[sources.keep]` columns match (old-growth plots, undisturbed collars, control
# plots). Each plot gets one value per month: the mean of all readings in that
# month, with the number of readings and visit days. These are spot surveys, not
# continuous records, so a monthly value is the mean of the visit days only.
#
# Units: volume % is divided by 100 to give volumetric water content θ
# (m³ m⁻³). VE `soil_moisture` is water depth per layer (mm), so the VE value of
# an observation is $\theta \times$ the top soil layer thickness
# (`topsoil_depth_m`, 250 mm). The probe samples 0-12 cm of the 0-25 cm layer.

sm_sources = [s for s in sources.values() if "value_column" in s]


def read_soil_moisture(src: dict) -> pd.DataFrame:
    """Read one soil moisture source into rows of location, date and value."""
    path = safe_path / src["file"]
    raw = pd.read_excel(path, sheet_name=src["sheet"], header=src["header_row"])
    raw = raw.drop(columns=raw.columns[0])  # the field_name label column
    for col, allowed in src.get("keep", {}).items():
        before = len(raw)
        raw = raw[raw[col].isin(allowed)]
        log_qc(
            src["source_id"],
            "all",
            f"kept {col} in {allowed}",
            before - len(raw),
            "rows removed",
        )
    data = pd.DataFrame(
        {
            "location": raw[src["location_column"]].astype(str).str.strip(),
            "subplot": raw[src["location_column"]].astype(str).str.strip(),
            "date": pd.to_datetime(raw[src["date_column"]], errors="coerce"),
            "value": pd.to_numeric(raw[src["value_column"]], errors="coerce"),
            "habitat": raw[src["habitat_column"]]
            if "habitat_column" in src
            else src["habitat"],
        }
    )
    bad = data["value"].notna() & ~data["value"].between(0, 100)
    data.loc[bad, "value"] = np.nan
    log_qc(src["source_id"], "all", "values outside 0-100 % set missing", bad.sum())
    missing = data["value"].isna() | data["date"].isna()
    log_qc(src["source_id"], "all", "rows without value or date dropped", missing.sum())
    data = data[~missing].copy()
    data["dataset"] = src["source_id"]
    if src.get("aggregate_to_plot"):  # subplots such as Car_Bel-01 to plot Car_Bel
        data["location"] = data["location"].str.split("-").str[0]
    # Plot coordinates, from the Locations sheet of the file or the gazetteer.
    if src["coordinates"] == "locations_sheet":
        locs = pd.read_excel(path, sheet_name="Locations").rename(
            columns={
                "Location name": "location",
                "Latitude": "latitude",
                "Longitude": "longitude",
            }
        )
        locs["location"] = locs["location"].astype(str).str.strip()
        coordinate_source = "source_locations_sheet"
    else:
        locs = gazetteer
        coordinate_source = "gazetteer_centroid"
    data = data.merge(
        locs[["location", "latitude", "longitude"]], on="location", how="left"
    )
    data["coordinate_source"] = np.where(
        data["latitude"].notna(), coordinate_source, "missing"
    )
    return data


sm_points = pd.concat([read_soil_moisture(s) for s in sm_sources], ignore_index=True)
sm_points["month"] = sm_points["date"].dt.to_period("M")
sm_monthly = sm_points.groupby(["dataset", "location", "month"], as_index=False).agg(
    habitat=("habitat", "first"),
    latitude=("latitude", "first"),
    longitude=("longitude", "first"),
    coordinate_source=("coordinate_source", "first"),
    n_readings=("value", "count"),
    n_visit_days=("date", "nunique"),
    soil_moisture_pct_mean=("value", "mean"),
    soil_moisture_pct_sd=("value", "std"),
)
sm_monthly["theta_m3_m3"] = sm_monthly["soil_moisture_pct_mean"] / 100

sm_sites = sm_monthly.groupby(["dataset", "location"], as_index=False).agg(
    habitat=("habitat", "first"),
    latitude=("latitude", "first"),
    longitude=("longitude", "first"),
    coordinate_source=("coordinate_source", "first"),
    first_record=("month", "min"),
    last_record=("month", "max"),
    n_months=("month", "nunique"),
    n_readings=("n_readings", "sum"),
)
sm_sites["location_type"] = "plot"
sm_sites = add_scenario_overlap(sm_sites)
for col in ["first_record", "last_record"]:
    sm_sites[col] = sm_sites[col].astype(str)
print(sm_sites.sort_values("distance_to_grid_km"))

# ============================================================
# 4. LITERATURE VALUES
# ============================================================
# `hydrology_literature_values.csv` holds one row per published value or range,
# with the VE variable it validates (`var_canonical`), units, site, period and
# citation.
# `status` is `extracted` when the number is in the table, `to_extract` when a
# candidate source is known but the number is not yet copied, and `to_find` when
# no source is known yet. Only extracted rows go into the long table; ranges
# become two rows (`range_min`, `range_max`).

literature = pd.read_csv(repo_path(literature_file))
print(literature["status"].value_counts().to_string())
print(
    literature[
        [
            "lit_id",
            "var_canonical",
            "quantity",
            "value",
            "value_min",
            "value_max",
            "unit",
            "citation",
            "status",
        ]
    ]
)

# ============================================================
# 5. LONG VALIDATION TABLE
# ============================================================
# One observation per row with the columns of the validation database
# (`docs/validation_database.md`), plus `location`, `habitat`, `site_group`,
# `statistic`, `n_days`, `source_type` and `in_scenario_grid`. Times are UTC,
# as half-open intervals `[time_start, time_end)`; a local calendar month starts
# at 16:00 UTC on the last day of the previous month. Only complete months are
# used.

LONG_COLUMNS = [
    "ID",
    "latitude",
    "longitude",
    "location_type",
    "coordinate_source",
    "time_start",
    "time_end",
    "time_type",
    "time_precision",
    "time_source",
    "time_note",
    "var_original",
    "value_original",
    "unit_original",
    "var_canonical",
    "unit_canonical",
    "value_canonical",
    "dataset",
    "location",
    "habitat",
    "site_group",
    "statistic",
    "n_days",
    "source_type",
    "in_scenario_grid",
]


def month_bounds_utc(months: pd.Series) -> tuple[pd.Series, pd.Series]:
    """Return UTC start and end of local calendar months."""
    start = (
        months.dt.start_time.dt.tz_localize(local_tz)
        .dt.tz_convert("UTC")
        .dt.tz_localize(None)
    )
    end = (
        (months + 1)
        .dt.start_time.dt.tz_localize(local_tz)
        .dt.tz_convert("UTC")
        .dt.tz_localize(None)
    )
    return start, end


def monthly_long(monthly, sites, mapping, dataset):
    """Reshape a monthly table to the long layout for the mapped columns."""
    monthly = monthly[monthly["complete_month"]]
    if "n_days" in monthly:
        note_unit = " complete days"
    else:  # streams: hours with data
        monthly = monthly.rename(columns={"n_hours": "n_days"})
        note_unit = " hours with data"
    frames = []
    for col, (
        var_original,
        unit_original,
        var_canonical,
        unit_canonical,
        statistic,
        factor,
    ) in mapping.items():
        part = monthly[["location", "month", "n_days", col]].rename(
            columns={col: "value_original"}
        )
        part = part[part["value_original"].notna() | (factor is None)]
        if part.empty:
            continue
        part = part.assign(
            var_original=var_original,
            unit_original=unit_original,
            var_canonical=var_canonical,
            unit_canonical=unit_canonical,
            statistic=statistic,
        )
        part["value_canonical"] = (
            part["value_original"] * factor if factor is not None else np.nan
        )
        frames.append(part)
    long = pd.concat(frames, ignore_index=True)
    long["time_start"], long["time_end"] = month_bounds_utc(long["month"])
    long = long.merge(
        sites[
            [
                "location",
                "latitude",
                "longitude",
                "location_type",
                "coordinate_source",
                "habitat",
                "site_group",
                "in_scenario_grid",
            ]
        ],
        on="location",
        how="left",
    )
    long["time_type"] = "interval"
    long["time_precision"] = "month"
    long["time_source"] = "source_columns"
    long["time_note"] = (
        "Local month (" + local_tz + "), " + long["n_days"].astype(str) + note_unit
    )
    long["dataset"] = dataset
    long["source_type"] = "observed_time_series"
    long["ID"] = (
        dataset
        + "__"
        + long["location"]
        + "__"
        + long["var_canonical"]
        + "__"
        + long["statistic"]
        + "__"
        + long["month"].astype(str)
    )
    return long[LONG_COLUMNS]


st_mapping = {
    "discharge_mean": (
        "discharge x area",
        "m^3 s^-1",
        "river_discharge_rate",
        "m^3 s^-1",
        "monthly_mean",
        1,
    ),
    "specific_discharge_mean": (
        "discharge",
        "m^3 s^-1 km^-2",
        "specific_discharge",
        "m^3 s^-1 km^-2",
        "monthly_mean",
        1,
    ),
    "runoff_month_mm": (
        "discharge x 3.6",
        "mm month^-1",
        "total_runoff",
        "mm month^-1",
        "monthly_total",
        1,
    ),
    "baseflow_month_mm": (
        "Lyne-Hollick baseflow",
        "mm month^-1",
        "baseflow",
        "mm month^-1",
        "monthly_total",
        1,
    ),
    "quickflow_month_mm": (
        "Lyne-Hollick quickflow",
        "mm month^-1",
        "quickflow",
        "mm month^-1",
        "monthly_total",
        1,
    ),
    "baseflow_index": (
        "baseflow / runoff",
        "fraction",
        "baseflow_index",
        "fraction",
        "monthly_ratio",
        1,
    ),
    "rainfall_month_mm": (
        "rainfall",
        "mm month^-1",
        "precipitation",
        "mm month^-1",
        "monthly_total",
        1,
    ),
    "runoff_ratio": (
        "runoff / rainfall",
        "fraction",
        "runoff_ratio",
        "fraction",
        "monthly_ratio",
        1,
    ),
}
st_long = monthly_long(st_monthly, st_sites, st_mapping, st_source["source_id"])
for name, src in rain_sources.items():
    rows = (st_long["location"] == name) & (st_long["var_canonical"] == "precipitation")
    st_long.loc[rows, "ID"] = st_long.loc[rows, "ID"].str.replace(
        st_source["source_id"], src["source_id"], n=1
    )
    st_long.loc[rows, "dataset"] = src["source_id"]
    st_long.loc[rows, "var_original"] = (
        f"{src['rain_column']} ({src['station']}, daily)"
    )

# Record means (annualised) for comparison with annual literature values.
record_mapping = {
    "runoff_mm_year": ("total_runoff", "mm year^-1"),
    "baseflow_mm_year": ("baseflow", "mm year^-1"),
    "quickflow_mm_year": ("quickflow", "mm year^-1"),
    "baseflow_index": ("baseflow_index", "fraction"),
    "rainfall_mm_year": ("precipitation", "mm year^-1"),
    "runoff_ratio": ("runoff_ratio", "fraction"),
    "p_minus_q_mm_year": ("evapotranspiration", "mm year^-1"),
}
record_rows = []
for r in st_summary.itertuples(index=False):
    site = st_sites.set_index("location").loc[r.location]
    start, end = month_bounds_utc(
        pd.Series([pd.Period(r.period_start), pd.Period(r.period_end)])
    )
    rain_based = ("rainfall_mm_year", "runoff_ratio", "p_minus_q_mm_year")
    if r.rainfall_days:
        # Rainfall-based means only use complete months with checked rainfall.
        rain_start, rain_end = month_bounds_utc(
            pd.Series(
                [pd.Period(r.rainfall_period_start), pd.Period(r.rainfall_period_end)]
            )
        )
    for col, (var, unit) in record_mapping.items():
        value = getattr(r, col)
        if pd.isna(value):
            continue
        window = (rain_start, rain_end) if col in rain_based else (start, end)
        record_rows.append(
            {
                "ID": f"{st_source['source_id']}__{r.location}__{var}__record_mean",
                "latitude": site["latitude"],
                "longitude": site["longitude"],
                "location_type": "catchment",
                "coordinate_source": site["coordinate_source"],
                "time_start": window[0].iloc[0],
                "time_end": window[1].iloc[1],
                "time_type": "whole_dataset",
                "time_precision": "month",
                "time_source": "source_columns",
                "time_note": (
                    f"Annualised mean over {r.rainfall_days} days with runoff and rain"
                    if col in rain_based
                    else f"Annualised mean over {r.complete_months} complete months"
                )
                + (
                    " (P - Q: approximates ET, ignores storage change)"
                    if col == "p_minus_q_mm_year"
                    else ""
                ),
                "var_original": col,
                "value_original": value,
                "unit_original": unit,
                "var_canonical": var,
                "unit_canonical": unit,
                "value_canonical": value,
                "dataset": (
                    rain_sources[r.location]["source_id"]
                    if var == "precipitation" and r.location in rain_sources
                    else st_source["source_id"]
                ),
                "location": r.location,
                "habitat": site["habitat"],
                "site_group": site["site_group"],
                "statistic": "record_mean_annual",
                "n_days": np.nan,
                "source_type": "observed_time_series",
                "in_scenario_grid": False,
            }
        )
st_record_long = pd.DataFrame(record_rows, columns=LONG_COLUMNS)


def literature_long(lit: pd.DataFrame) -> pd.DataFrame:
    """Reshape extracted literature rows to the long layout."""
    lit = lit[lit["status"] == "extracted"]
    rows = []
    for r in lit.itertuples(index=False):
        values = (
            [("range_min", r.value_min), ("range_max", r.value_max)]
            if pd.isna(r.value)
            else [(r.statistic, r.value)]
        )
        for statistic, value in values:
            start = (
                pd.Timestamp(f"{int(r.period_start)}-01-01")
                if pd.notna(r.period_start)
                else pd.NaT
            )
            end = (
                pd.Timestamp(f"{int(r.period_end) + 1}-01-01")
                if pd.notna(r.period_end)
                else pd.NaT
            )
            rows.append(
                {
                    "ID": f"{r.lit_id}__{statistic}",
                    "latitude": r.latitude,
                    "longitude": r.longitude,
                    "location_type": "site",
                    "coordinate_source": "data_columns"
                    if pd.notna(r.latitude)
                    else "missing",
                    "time_start": start,
                    "time_end": end,
                    "time_type": "whole_dataset" if pd.notna(start) else "missing",
                    "time_precision": "year" if pd.notna(start) else None,
                    "time_source": "fixed_metadata" if pd.notna(start) else "missing",
                    "time_note": r.time_basis,
                    "var_original": r.quantity,
                    "value_original": value,
                    "unit_original": r.unit,
                    "var_canonical": r.var_canonical,
                    "unit_canonical": r.unit,
                    "value_canonical": value,
                    "dataset": r.citation,
                    "location": r.site,
                    "habitat": r.habitat,
                    "site_group": "literature",
                    "statistic": statistic,
                    "n_days": np.nan,
                    "source_type": "literature",
                    "in_scenario_grid": False,
                }
            )
    return pd.DataFrame(rows, columns=LONG_COLUMNS)


def soil_moisture_long(monthly: pd.DataFrame) -> pd.DataFrame:
    """Reshape plot-month soil moisture means to the long layout."""
    long = monthly.copy()
    long["time_start"], long["time_end"] = month_bounds_utc(long["month"])
    long = long.assign(
        ID=long["dataset"]
        + "__"
        + long["location"]
        + "__soil_moisture__visit_mean__"
        + long["month"].astype(str),
        location_type="plot",
        time_type="interval",
        time_precision="month",
        time_source="source_columns",
        time_note=(
            "Local month ("
            + local_tz
            + "), "
            + long["n_readings"].astype(str)
            + " readings on "
            + long["n_visit_days"].astype(str)
            + " visit days"
        ),
        var_original="soil moisture (probe, 0-12 cm)",
        value_original=long["soil_moisture_pct_mean"],
        unit_original="%",
        var_canonical="soil_moisture",
        unit_canonical="m^3 m^-3",
        value_canonical=long["theta_m3_m3"],
        site_group="soil_moisture_plots",
        statistic="visit_mean",
        n_days=long["n_visit_days"],
        source_type="observed_time_series",
    )
    long["in_scenario_grid"] = (
        distance_to_grid_km(long["latitude"], long["longitude"], scenario) == 0
    )
    return long[LONG_COLUMNS]


sm_long = soil_moisture_long(sm_monthly)
lit_long = literature_long(literature)
validation_long = pd.concat(
    [st_long, st_record_long, sm_long, lit_long], ignore_index=True
)
for col in ["time_start", "time_end"]:
    validation_long[col] = pd.to_datetime(validation_long[col])
assert validation_long["ID"].is_unique
print(
    validation_long.groupby(["source_type", "var_canonical"])
    .size()
    .rename("rows")
    .to_frame()
)

# ============================================================
# 5.1 VE NAMES, UNITS AND VALUES
# ============================================================
# Validation plots use the VE variable names and units, so every row also gets
# `ve_variable`, `ve_unit` and `obs_in_ve_unit`. `obs_in_ve_unit` is the
# observed (or literature) value converted to the VE unit, not a model value:
# `value_canonical` times the factor in `VE_CONVERSIONS` (for soil moisture,
# theta x 250 mm). The model values are added later, when VE outputs are joined.
# `ve_formula` gives the VE outputs combined for a derived target and is blank
# when the VE writes the variable directly. `ve_note` says how to aggregate the
# monthly VE time steps to match the row, or why no value is given.
#
# `ve_compare_at` says which grid values to compare with: `sink cell` for
# catchment-scale stream quantities (the routed flow at the grid's outlet cell
# divided by its upstream area, since a gauge integrates its whole catchment),
# or `grid mean` for local fluxes and stores (the mean over the 100 cells, since
# every cell has the same forcing). `ve_compare_note` gives the detail.

# unit_canonical: (factor to the VE unit, note on how to aggregate the VE output)
VE_CONVERSIONS = {
    "mm month^-1": (1.0, "Sum of the VE values over the month"),
    "mm year^-1": (1.0, "Mean annual sum of the VE values over the record"),
    "mm year-1": (1.0, "Mean annual sum of the VE values"),
    "mm": (1.0, "Sum of the VE values over the same period"),
    "fraction": (1.0, ""),
    "percent": (0.01, "Converted from percent to fraction"),
    "m^3 s^-1": (1.0, "Mean of the VE values over the month"),
    "m^3 s^-1 km^-2": (1.0, "Mean of the VE values over the month"),
    "cm h-1": (0.01 / 3600, "Converted from cm h-1 to m s-1"),
    "m^3 m^-3": (
        topsoil_depth_m * 1000,
        f"VE top soil layer (0-{topsoil_depth_m} m) soil_moisture for the visit month; "
        f"obs_in_ve_unit = theta x {topsoil_depth_m * 1000:.0f} mm",
    ),
}
# Rows reported as a percent of rainfall have no VE value until they are
# multiplied by the rainfall of the same study.
PERCENT_OF_RAINFALL = {"interception", "surface_runoff"}


# Catchment-scale quantities measured at a stream gauge: compare with the routed
# flow at the grid's outlet (sink) cell. Everything else: grid mean.
SINK_CELL_VARIABLES = {
    "river_discharge_rate",
    "specific_discharge",
    "total_runoff",
    "baseflow",
    "quickflow",
    "baseflow_index",
    "runoff_ratio",
}
COMPARE_NOTES = {
    "river_discharge_rate": "Sink cell discharge; compare as discharge / upstream area",
    "specific_discharge": "Sink cell river_discharge_rate / upstream area",
    "total_runoff": "Sink cell discharge / upstream area, as mm per month",
    "baseflow": "Routed subsurface flow at the sink cell / upstream area",
    "quickflow": "Routed surface flow + stormflow at the sink cell / upstream area",
    "baseflow_index": "Ratio of sink cell baseflow to total flow",
    "runoff_ratio": "Sink cell runoff / grid mean precipitation",
    "soil_moisture": "Grid mean top layer; also the edge cells nearest each plot",
    "evapotranspiration": "Grid mean (P - Q is a catchment water balance)",
    "saturated_hydraulic_conductivity": "Model constant; compare the configured value",
}


def add_ve_columns(long: pd.DataFrame) -> pd.DataFrame:
    """Add the VE variable name, unit, value, formula and note to the long table."""
    ve = registry.drop_duplicates("variable").set_index("variable")
    long = long.copy()
    long["ve_variable"] = long["var_canonical"]
    long["ve_unit"] = long["ve_variable"].map(ve["unit_ve"])
    factor = long["unit_canonical"].map(lambda u: VE_CONVERSIONS[u][0])
    long["obs_in_ve_unit"] = (
        pd.to_numeric(long["value_canonical"], errors="coerce") * factor
    )
    long["ve_note"] = long["unit_canonical"].map(lambda u: VE_CONVERSIONS[u][1])
    ratio = long["statistic"].isin(["monthly_ratio"])
    long.loc[ratio, "ve_note"] = "Ratio of the monthly VE sums"
    annual_ratio = (long["statistic"] == "record_mean_annual") & (
        long["unit_canonical"] == "fraction"
    )
    long.loc[annual_ratio, "ve_note"] = "Ratio of the annual VE sums over the record"
    rain_share = long["ve_variable"].isin(PERCENT_OF_RAINFALL) & (
        long["unit_canonical"] == "percent"
    )
    long.loc[rain_share, "obs_in_ve_unit"] = np.nan
    long.loc[rain_share, "ve_note"] = (
        "Percent of rainfall; multiply by the study rainfall to compare in mm"
    )
    derived = ve["description"].where(ve["description"].str.startswith("Derived:"))
    long["ve_formula"] = (
        long["ve_variable"].map(derived).str.replace("Derived: ", "").fillna("")
    )
    sink = long["ve_variable"].isin(SINK_CELL_VARIABLES)
    long["ve_compare_at"] = np.where(sink, "sink cell", "grid mean")
    default_note = pd.Series(
        np.where(
            sink,
            "Outlet (sink) cell value divided by its upstream area",
            "Mean of the monthly values over all grid cells",
        ),
        index=long.index,
    )
    long["ve_compare_note"] = (
        long["ve_variable"].map(COMPARE_NOTES).fillna(default_note)
    )
    return long


validation_long = add_ve_columns(validation_long)
assert validation_long["ve_unit"].notna().all()
print(
    validation_long[
        ["var_canonical", "unit_canonical", "ve_variable", "ve_unit"]
    ].drop_duplicates()
)

# ============================================================
# 5.2 SPATIAL AND TEMPORAL MATCH WITH THE VE SCENARIO
# ============================================================
# Each row is classed against the scenario grid and run period read from the
# site definition (`maliau_grid_definition.toml`).
#
# Spatial match (`spatial_match`, detail in `spatial_match_detail`):
#
# * `match`: the site is inside the scenario grid (`inside_grid`);
# * `partial`: the site is outside the grid but within `near_grid_km` of its
#   edge (`near_grid`), or within `regional_max_km` of it (`regional`);
# * `no_match`: further than `regional_max_km` from the grid (`outside_region`);
# * `unknown`: no location (`no_location`).
#
# Literature values without coordinates use the approximate centre of the named
# location below, only for this class; their latitude and longitude stay blank.
#
# Temporal match (`temporal_match`, detail in `temporal_match_detail`;
# `temporal_overlap_fraction` is the share of the row's period inside the run):
#
# * `match`: the period lies inside the run and the statistic can be computed
#   from monthly VE output (`inside_run_monthly`);
# * `partial`: the period lies partly inside the run (`partial_overlap`), or
#   inside it but the statistic needs sub-monthly output such as daily maxima
#   (`inside_run_needs_daily`);
# * `no_match`: the period lies outside the run (`outside_run`);
# * `unknown`: no dates (`no_dates`).
#
# `match_category` combines both: `full` when both match, `no_match` when either
# has no match, `unknown` when either is unknown, and `partial` otherwise.

# Approximate centres (latitude, longitude) of named literature locations.
literature_locations = {
    "Danum Valley": (4.965, 117.795),
    "Danum Valley and SAFE": (4.965, 117.795),
    "PF (Danum) and VJR (SAFE)": (4.965, 117.795),  # farther gauge, PF
    "SAFE": (4.70, 117.58),
    "Lambir": (4.20, 114.04),
    "Miri (near Lambir)": (4.40, 113.99),
    "Central Kalimantan": (-1.6, 113.9),
}
# Statistics that need sub-monthly VE output.
DAILY_STATISTICS = {"mean_daily_max", "mean_daily_min"}


def add_match_columns(long: pd.DataFrame) -> pd.DataFrame:
    """Add spatial and temporal match classes against the VE scenario."""
    long = long.copy()
    named = long["location"].map(literature_locations)
    lat = long["latitude"].fillna(named.str[0])
    lon = long["longitude"].fillna(named.str[1])
    distance = distance_to_grid_km(lat, lon, scenario)
    long["distance_to_grid_km"] = np.round(distance, 2)
    spatial = np.select(
        [
            ~np.isfinite(distance),
            distance == 0,
            distance <= near_grid_km,
            distance <= regional_max_km,
        ],
        ["no_location", "inside_grid", "near_grid", "regional"],
        "outside_region",
    )
    long["spatial_match_detail"] = spatial
    long["spatial_match"] = pd.Series(spatial, index=long.index).map(
        {
            "no_location": "unknown",
            "inside_grid": "match",
            "near_grid": "partial",
            "regional": "partial",
            "outside_region": "no_match",
        }
    )

    # Observed times are UTC; the run period is in local dates, which is close
    # enough for monthly classes.
    start = pd.to_datetime(long["time_start"])
    end = pd.to_datetime(long["time_end"])
    end = end.where(end > start, start + pd.Timedelta(days=1))
    overlap = end.clip(upper=scenario["end"]) - start.clip(lower=scenario["start"])
    overlap = overlap.clip(lower=pd.Timedelta(0))
    fraction = overlap / (end - start)
    long["temporal_overlap_fraction"] = fraction.round(3)
    daily = long["statistic"].isin(DAILY_STATISTICS)
    temporal = np.select(
        [
            start.isna(),
            fraction <= 0,
            fraction < 0.999,
            daily,
        ],
        ["no_dates", "outside_run", "partial_overlap", "inside_run_needs_daily"],
        "inside_run_monthly",
    )
    long["temporal_match_detail"] = temporal
    long["temporal_match"] = pd.Series(temporal, index=long.index).map(
        {
            "no_dates": "unknown",
            "outside_run": "no_match",
            "partial_overlap": "partial",
            "inside_run_needs_daily": "partial",
            "inside_run_monthly": "match",
        }
    )
    both = long[["spatial_match", "temporal_match"]]
    long["match_category"] = np.select(
        [
            (both == "no_match").any(axis=1),
            (both == "unknown").any(axis=1),
            (both == "match").all(axis=1),
        ],
        ["no_match", "unknown", "full"],
        "partial",
    )
    return long


validation_long = add_match_columns(validation_long)
print(
    validation_long.groupby(
        ["spatial_match_detail", "temporal_match_detail", "match_category"]
    )
    .size()
    .rename("rows")
    .to_frame()
)

# ============================================================
# 6. DATA AVAILABILITY PER VE VARIABLE AND TRACKER TABLE
# ============================================================
# For each VE variable the registry records the observed series that map to it,
# the literature values, the observed period and number of sites, and a status:
#
# * `observed + literature`, `observed` or `literature`: data ready to compare;
# * `literature to extract`: candidate sources known, numbers not yet copied;
# * `no data yet`.

obs = validation_long[validation_long["source_type"] == "observed_time_series"].copy()
# Back to local months for reporting periods.
obs["month_local"] = (
    obs["time_start"]
    .dt.tz_localize("UTC")
    .dt.tz_convert(local_tz)
    .dt.tz_localize(None)
    .dt.to_period("M")
)
# Last month covered: the month holding the end of each window (end exclusive).
obs["month_local_end"] = (
    (obs["time_end"] - pd.Timedelta(seconds=1))
    .dt.tz_localize("UTC")
    .dt.tz_convert(local_tz)
    .dt.tz_localize(None)
    .dt.to_period("M")
)
obs_summary = obs.groupby("var_canonical").agg(
    observed_dataset=("dataset", lambda s: ", ".join(sorted(s.unique()))),
    observed_variable=("var_original", lambda s: ", ".join(sorted(s.unique()))),
    observed_period_start=("month_local", "min"),
    observed_period_end=("month_local_end", "max"),
    n_sites=("location", "nunique"),
    site_kind=(
        "location_type",
        lambda s: "catchments" if (s == "catchment").all() else "plots",
    ),
    observed_unit=("unit_original", lambda s: ", ".join(sorted(s.unique()))),
    n_monthly_values=("value_original", "count"),
    n_canonical_values=("value_canonical", "count"),
    n_sites_in_scenario_grid=(
        "in_scenario_grid",
        lambda s: int(obs.loc[s.index].loc[s, "location"].nunique()),
    ),
)
lit_summary = literature.groupby("var_canonical").agg(
    literature_extracted=("status", lambda s: int((s == "extracted").sum())),
    literature_pending=("status", lambda s: int((s == "to_extract").sum())),
    literature_sources=(
        "citation",
        lambda s: "; ".join(
            sorted(c for c in s.dropna().unique() if not c.startswith("TODO"))
        ),
    ),
)
registry_out = registry.merge(
    obs_summary, left_on="variable", right_index=True, how="left"
).merge(lit_summary, left_on="variable", right_index=True, how="left")
registry_out[["literature_extracted", "literature_pending"]] = (
    registry_out[["literature_extracted", "literature_pending"]].fillna(0).astype(int)
)


def status(row) -> str:
    """Return the validation data status of one registry row."""
    has_obs = pd.notna(row["n_monthly_values"]) and row["n_monthly_values"] > 0
    obs_ready = has_obs and row["n_canonical_values"] > 0
    has_lit = row["literature_extracted"] > 0
    if has_obs and not obs_ready:
        return "observed (needs catchment area)" + (" + literature" if has_lit else "")
    if obs_ready and has_lit:
        return "observed + literature"
    if obs_ready:
        return "observed"
    if has_lit:
        return "literature"
    if row["literature_pending"] > 0:
        return "literature to extract"
    return "no data yet"


registry_out["status"] = registry_out.apply(status, axis=1)
for col in ["observed_period_start", "observed_period_end"]:
    registry_out[col] = (
        registry_out[col].astype(str).replace({"NaT": np.nan, "nan": np.nan})
    )
print(registry_out.groupby(["module", "status"]).size().rename("variables").to_frame())


# ============================================================
# 6. TRACKER TABLE FOR THE PLAN
# ============================================================
# Format the periods, sites and data columns of the tracker table that is
# written into Section 6 of hydrology_validation_plan.md.
def fmt_period(row) -> str:
    """Return the observed period of one registry row as text."""
    if pd.isna(row["observed_period_start"]):
        return ""
    return f"{row['observed_period_start']} to {row['observed_period_end']}"


# Spatial and temporal information per VE variable, from the match columns of
# validation_long: which sites, how far from the grid, the time step of the
# values, and how many rows match the scenario in space and time.
SPATIAL_LABELS = {
    "inside_grid": "inside grid",
    "near_grid": f"near grid (<= {near_grid_km} km)",
    "regional": f"regional (<= {regional_max_km} km)",
    "outside_region": "outside region",
    "no_location": "no location",
}
TEMPORAL_LABELS = {
    "inside_run_monthly": "in run",
    "inside_run_needs_daily": "in run, needs daily",
    "partial_overlap": "partly in run",
    "outside_run": "outside run",
    "no_dates": "no dates",
}
STEP_LABELS = {
    "monthly_mean": "monthly mean",
    "monthly_total": "monthly total",
    "monthly_ratio": "monthly ratio",
    "record_mean_annual": "record mean (annual)",
    "visit_mean": "survey visits (monthly mean)",
}


def site_list(rows: pd.DataFrame) -> str:
    """Return the sites of some rows with their distance to the grid (km)."""
    sites = rows.groupby("location")["distance_to_grid_km"].first().sort_values()
    return ", ".join(
        f"{loc} ({d:.1f} km)" if pd.notna(d) else f"{loc} (no location)"
        for loc, d in sites.items()
    )


def class_counts(rows: pd.DataFrame, column: str, labels: dict, by_site: bool) -> str:
    """Count sites (or rows) per match class, in the order of labels."""
    counts = (
        rows.groupby(column)["location"].nunique()
        if by_site
        else rows[column].value_counts()
    )
    unit = " sites" if by_site else ""
    return "; ".join(f"{labels[k]} {counts[k]}{unit}" for k in labels if k in counts)


extent_rows = []
for var, rows in validation_long.groupby("var_canonical"):
    observed = rows[rows["source_type"] == "observed_time_series"]
    lit = rows[rows["source_type"] == "literature"]
    extent_rows.append(
        {
            "variable": var,
            "observed_sites_km": site_list(observed),
            "observed_spatial_match": class_counts(
                observed, "spatial_match_detail", SPATIAL_LABELS, by_site=True
            ),
            "observed_time_step": ", ".join(
                STEP_LABELS.get(v, v) for v in observed["statistic"].unique()
            ),
            "observed_temporal_match": class_counts(
                observed, "temporal_match_detail", TEMPORAL_LABELS, by_site=False
            ),
            "literature_sites_km": site_list(lit),
            "rows_full_match": int((rows["match_category"] == "full").sum()),
        }
    )
extents = pd.DataFrame(extent_rows)


def source_label(citation: str, doi, candidate=None) -> str:
    """Return a citation with its DOI (Zenodo or other), or a missing-DOI note.

    A candidate DOI (found by search, not yet checked) is added as unconfirmed.
    """
    doi = "" if pd.isna(doi) else str(doi).strip()
    if doi.startswith("10."):
        label = f"{citation} [doi:{doi}](https://doi.org/{doi})"
    else:
        label = f"{citation} ({doi or 'DOI to confirm'})"
    if candidate:
        label += (
            f", candidate [doi:{candidate}](https://doi.org/{candidate}) (unconfirmed)"
        )
    return label


# Citation and DOI of every observed dataset and extracted literature value.
observed_labels = {
    s["source_id"]: source_label(
        s.get("short_citation", s["source_id"]), s.get("doi"), s.get("doi_candidate")
    )
    for s in sources.values()
}
cited = []
for var, rows in validation_long.groupby("var_canonical"):
    observed = rows.loc[
        rows["source_type"] == "observed_time_series", "dataset"
    ].unique()
    labels = [observed_labels[d] for d in sorted(observed)]
    lit = literature[
        (literature["var_canonical"] == var) & (literature["status"] == "extracted")
    ].drop_duplicates("citation")
    labels += [source_label(r.citation, r.doi) for r in lit.itertuples(index=False)]
    cited.append({"variable": var, "data_sources": "; ".join(labels)})
pending = literature[literature["status"] == "to_extract"]
cited += [
    {
        "variable": r.var_canonical,
        "data_sources": source_label(r.citation, r.doi) + " (to extract)",
    }
    for r in pending.itertuples(index=False)
    if r.var_canonical not in {c["variable"] for c in cited}
]
extents = extents.merge(pd.DataFrame(cited), on="variable", how="outer")


def data_location(src: dict) -> str:
    """Return the folder or file of one observed source, under the SAFE folder."""
    if "catchments" in src:
        folders = [
            Path(c["streamflow_file"]).parent
            for c in src["catchments"].values()
            if "streamflow_file" in c
        ]
        return ", ".join(f"`safe_hydro/{f.as_posix()}/`" for f in folders)
    return f"`{src.get('file') or src['files']['data']}`"


# Where the data of each variable sit: the observed files or folders, and the
# literature sheet. Values and citations are in the workbook, not the plan.
located = []
for var in registry_out["variable"]:
    rows = validation_long[validation_long["var_canonical"] == var]
    observed = rows.loc[
        rows["source_type"] == "observed_time_series", "dataset"
    ].unique()
    places = [data_location(sources[d]) for d in sorted(observed)]
    lit = literature[literature["var_canonical"] == var]
    if (lit["status"] == "extracted").any():
        places.append("`hydrology_literature_values.csv`")
    elif len(lit):
        places.append("`hydrology_literature_values.csv` (to extract)")
    observed_rows = rows[rows["source_type"] == "observed_time_series"]
    dist = observed_rows.groupby("location")["distance_to_grid_km"].first()
    located.append(
        {
            "variable": var,
            "data_location": "; ".join(places),
            "sites_simple": (
                f"{len(dist)} sites, {dist.min():.1f}-{dist.max():.1f} km"
                if len(dist) > 1
                else (f"1 site, {dist.iloc[0]:.1f} km" if len(dist) else "")
            ),
            "spatial_simple": ", ".join(
                SPATIAL_LABELS[k].split(" (")[0]
                for k in SPATIAL_LABELS
                if k in set(observed_rows["spatial_match_detail"])
            ),
            "temporal_simple": ", ".join(
                TEMPORAL_LABELS[k]
                for k in TEMPORAL_LABELS
                if k in set(observed_rows["temporal_match_detail"])
            ),
        }
    )
extents = extents.merge(pd.DataFrame(located), on="variable", how="outer")
registry_out = registry_out.merge(extents, on="variable", how="left")

tracker = registry_out.assign(
    observed_period=registry_out.apply(fmt_period, axis=1),
    predicted_period=scenario["period"],
    predicted_spatial_extent=f"{scenario['name']} grid cells (to be pooled or matched)",
    predicted_temporal_extent=f"{scenario['time_step'].capitalize()} time steps",
)
tracker_cols = {
    "module": "module",
    "variable": "predicted_variable",
    "data_sources": "data_sources (citation, DOI)",
    "unit_ve": "predicted_units",
    "validation_priority": "priority",
    "observed_variable": "observed_variable",
    "observed_unit": "observed_unit",
    "observed_sites_km": "observed_sites (distance to grid)",
    "observed_spatial_match": "spatial_match",
    "observed_period": "observed_period",
    "predicted_period": "predicted_period",
    "observed_time_step": "observed_time_step",
    "observed_temporal_match": "temporal_match (rows)",
    "predicted_spatial_extent": "predicted_spatial_extent",
    "predicted_temporal_extent": "predicted_temporal_extent",
    "literature_sources": "literature_sources",
    "literature_sites_km": "literature_sites (distance to grid)",
    "data_location": "data",
    "sites_simple": "sites (distance to grid)",
    "spatial_simple": "spatial match",
    "temporal_simple": "temporal match",
    "status": "status",
}
tracker_table = tracker[list(tracker_cols)].rename(columns=tracker_cols).fillna("")


def to_markdown(df: pd.DataFrame) -> str:
    """Write a pipe table without needing the tabulate package."""
    cells = df.astype(str).map(lambda v: v.replace("|", "/"))

    def row(values) -> str:
        # Compact style (markdownlint MD060): one space around each cell,
        # a single space in an empty cell.
        return "|" + "|".join(f" {v} " if v else " " for v in values) + "|"

    lines = [row(df.columns), row("---" for _ in df.columns)]
    lines += [row(r) for r in cells.to_numpy()]
    return "\n".join(lines)


status_counts = ", ".join(
    f"{k} {v}" for k, v in tracker_table["status"].value_counts().items()
)
# A short tracker table lives in the validation plan (section 6), between two
# markers. It points to where the data sit; the full detail (citations, every
# site, time steps, row counts) is in the workbook's variable_registry sheet.
plan_cols = [
    "predicted_variable",
    "predicted_units",
    "priority",
    "data",
    "sites (distance to grid)",
    "spatial match",
    "observed_period",
    "temporal match",
    "status",
]
plan_tracker = f"""<!-- tracker:start -->
<!-- Generated by hydrology_validation_data.py; do not edit this block. -->

Every VE value is predicted for {scenario["period"]} on the {scenario["name"]} grid
({scenario["name"]}: 10 x 10 cells of 100 m) at {scenario["time_step"]} time steps.
Data folders and files are under the dataset folder; the literature values
are in `hydrology_literature_values.csv`. Distances are from the sites to the
edge of the grid; the match classes are explained in
[Section 5](#5-processing-to-ve-units-and-monthly-values). Citations, every
site and the row counts are in the `variable_registry` sheet of the workbook.

<!-- markdownlint-disable MD013 -->

Status counts: {status_counts}.

{
    to_markdown(
        tracker_table[plan_cols].rename(
            columns={
                "predicted_variable": "VE variable",
                "predicted_units": "VE unit",
                "observed_period": "period",
            }
        )
    )
}

<!-- markdownlint-enable MD013 -->

<!-- tracker:end -->"""
print(tracker_table[["module", "predicted_variable", "observed_period", "status"]])

# ============================================================
# 7. WRITE THE WORKBOOK AND THE PLAN'S TRACKER TABLE
# ============================================================
# Write every table to one Excel workbook (output_file), with bold headers and
# a note on each sheet, then replace only the validation tracker (Section 6,
# between the tracker markers) in the plan (plan_file).


sheet_notes = {
    "README": "This sheet",
    "variable_registry": "Full tracker: priority, data, citations, sites, status",
    "stream_sites": "VJR and PF: area, habitat, coordinates and record means",
    "sources": "Source datasets with screening decision (hydrology_sources.toml)",
    "qc_log": "Rows changed or removed by each quality-control step",
    "streams_monthly": "VJR and PF monthly values from cleaned, gap-filled hourly data",
    "streams_daily": "VJR and PF daily runoff, baseflow, quickflow and rainfall",
    "streams_hourly": "VJR and PF hourly series; discharge_filled marks filled hours",
    "danum_rainfall_daily": "Danum Valley weather station daily rainfall, full record",
    "storm_events": "VJR and PF storm events from *_event_basis_new.csv",
    "soil_moisture_sites": "Soil moisture plots, coordinates, distance to grid, record",
    "soil_moisture_monthly": "Soil moisture plot means per month of survey visits",
    "soil_moisture_points": "Soil moisture readings after cleaning",
    "literature_values": "Literature values from hydrology_literature_values.csv",
    "validation_long": (
        "Monthly observations and extracted literature values in the validation "
        "database layout (times in UTC), with VE names and units, the value in "
        "the VE unit, where to compare on the grid, and match classes"
    ),
}
readme = pd.DataFrame(
    {"sheet": list(sheet_notes), "contents": list(sheet_notes.values())}
)
readme_meta = pd.DataFrame(
    {
        "sheet": [
            "",
            "scenario",
            "comparison_catchments",
            "max_fill_gap_hours",
            "min_records_per_hour, min_hours_per_day, min_month_coverage",
            "max_dry_run_days",
            "lyne_hollick alpha, passes",
            "created",
        ],
        "contents": [
            "",
            f"{scenario['name']} ({scenario['period']}, {scenario['time_step']})",
            ", ".join(comparison_catchments),
            max_fill_gap_hours_streams,
            f"{min_records_per_hour}, {min_hours_per_day}, {min_month_coverage}",
            max_dry_run_days,
            f"{lh_alpha}, {lh_passes}",
            pd.Timestamp.now().strftime("%Y-%m-%d %H:%M"),
        ],
    }
)
sources_table = pd.DataFrame(
    [
        {
            "source_id": s["source_id"],
            "module": s["module"],
            "description": " ".join(s["description"].split()),
            "citation": " ".join(str(s["citation"]).split()),
            "record_id": s.get("record_id"),
            "doi": s.get("doi"),
            "related_dois": "; ".join(s.get("related_dois", [])),
            "screening_decision": s.get("screening", {}).get("decision"),
            "screening_reason": s.get("screening", {}).get("reason"),
            "screening_notes": s.get("screening", {}).get("notes"),
            "title": s.get("metadata", {}).get("title"),
            "year": s.get("metadata", {}).get("year"),
            "metadata_provider": s.get("metadata", {}).get("provider"),
            "file": s.get("file") or s.get("files", {}).get("data"),
        }
        for s in sources.values()
    ]
)
site_cols = [
    "location",
    "dataset",
    "site_group",
    "habitat",
    "location_type",
    "latitude",
    "longitude",
    "coordinate_source",
    "in_scenario_grid",
    "distance_to_grid_km",
    "first_record",
    "last_record",
    "complete_months",
    "logger_type",
    "catchment_area_km2",
    "notes",
]
sites = st_sites.reindex(columns=[c for c in site_cols if c != "logger_type"])
# One sheet per catchment: site details and the record means side by side.
stream_sites = sites.merge(
    st_summary.drop(columns=["complete_months"], errors="ignore"),
    on="location",
    how="left",
)

# The registry sheet holds the full tracker: the plan's short columns plus
# citations, every site and the row counts. Working columns are left out.
registry_sheet_cols = {
    "module": "module",
    "variable": "variable",
    "unit_ve": "ve_unit",
    "description": "description",
    "classification": "classification",
    "validation_priority": "validation_priority",
    "spin_up_sensitive": "spin_up_sensitive",
    "data_location": "data",
    "data_sources": "data_sources (citation, DOI)",
    "observed_variable": "observed_variable",
    "observed_unit": "observed_unit",
    "observed_sites_km": "observed_sites (distance to grid)",
    "observed_spatial_match": "spatial_match (sites)",
    "observed_period": "observed_period",
    "observed_time_step": "observed_time_step",
    "observed_temporal_match": "temporal_match (rows)",
    "rows_full_match": "rows_full_match",
    "literature_sites_km": "literature_sites (distance to grid)",
    "status": "status",
}
registry_sheet = tracker[list(registry_sheet_cols)].rename(columns=registry_sheet_cols)
registry_sheet["data"] = registry_sheet["data"].str.replace("`", "", regex=False)

sheets = {
    "README": pd.concat([readme, readme_meta], ignore_index=True),
    "variable_registry": registry_sheet,
    "stream_sites": stream_sites,
    "sources": sources_table,
    "qc_log": pd.DataFrame(qc_log),
    "streams_monthly": st_monthly.assign(month=st_monthly["month"].astype(str)),
    "streams_daily": st_daily.assign(date=st_daily["date"].dt.date),
    "streams_hourly": st_hourly.drop(columns="month"),
    "danum_rainfall_daily": danum_daily.assign(date=danum_daily["date"].dt.date),
    "storm_events": storm_events,
    "soil_moisture_sites": sm_sites,
    "soil_moisture_monthly": sm_monthly.assign(month=sm_monthly["month"].astype(str)),
    "soil_moisture_points": sm_points.assign(
        date=sm_points["date"].dt.date, month=sm_points["month"].astype(str)
    ),
    "literature_values": literature,
    "validation_long": validation_long,
}

out_path = repo_path(output_file)
out_path.parent.mkdir(parents=True, exist_ok=True)
with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    for name, table in sheets.items():
        # obs_in_ve_unit keeps full precision: some VE units give very small numbers.
        table = table.apply(
            lambda s: (
                s.round(4) if s.dtype.kind == "f" and s.name != "obs_in_ve_unit" else s
            )
        )
        table.to_excel(writer, sheet_name=name, index=False)
        ws = writer.sheets[name]
        ws.freeze_panes = "A2"
        for i, col in enumerate(table.columns, start=1):
            ws.cell(row=1, column=i).font = Font(bold=True)
            width = (
                max(len(str(col)), *(len(str(v)) for v in table[col].head(200)))
                if len(table)
                else len(str(col))
            )
            ws.column_dimensions[get_column_letter(i)].width = min(
                max(10, width + 2), 60
            )

plan_text = repo_path(plan_file).read_text(encoding="utf-8")
start, end = (
    plan_text.index("<!-- tracker:start -->"),
    plan_text.index("<!-- tracker:end -->"),
)
plan_text = (
    plan_text[:start] + plan_tracker + plan_text[end + len("<!-- tracker:end -->") :]
)
repo_path(plan_file).write_text(plan_text, encoding="utf-8")
print(f"Updated the tracker section of {plan_file}")
print(f"Wrote {output_file}")
print(pd.Series({k: len(v) for k, v in sheets.items()}, name="rows").to_frame())

# ============================================================
# NEXT STEPS
# ============================================================
# * Confirm the dataset citation and DOI in `hydrology_sources.toml`.
# * Check the Lyne-Hollick baseflow against the source separation
#   (`event_qsub_share` in `stream_sites`) and adjust `lh_alpha` if needed.
# * Extract the numbers for the `to_extract` rows in
#   `hydrology_literature_values.csv`.
# * Join VE outputs to `validation_long` (see `docs/hydrology_validation_plan.md`).
