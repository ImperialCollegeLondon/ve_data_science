"""
---
title: Abiotic validation data

description: |
  Builds the observed side of the abiotic validation for the Virtual Ecosystem
  (VE) Maliau scenario, for both the abiotic and the abiotic simple model. It
  does not read VE model output: it prepares observations in VE units and on
  the VE monthly time step, ready to be joined with VE output for the same
  grid cells and months in a later step.

  What the script does, in order:
    1. Lists the VE abiotic and abiotic simple output variables, their units
       and validation priority from maliau_variables_summary.xlsx.
    2. Reads the VE scenario grid (maliau_2, 10 x 10 cells of 100 m) and run
       period from maliau_grid_definition.toml, and the plot coordinates from
       the SAFE gazetteer.
    3. Reads the SAFE and Maliau microclimate loggers (hourly air temperature
       and relative humidity): removes values outside 10-45 degC, caps
       relative humidity between 100 and 130 % at 100 %, fills gaps of up to
       3 hours, calculates vapour pressure and vapour pressure deficit, and
       makes daily values (at least 20 hours) and monthly values (at least 20
       complete days) in local time.
    4. Reads the SAFE flux tower meteorology (above-canopy air temperature,
       relative humidity, net radiation and pressure; soil temperature at 5,
       10 and 20 cm) with the same daily and monthly rules, and the eddy
       covariance data (latent and sensible heat flux with quality flag at
       most 3, wind speed), whose monthly value is the mean of the month's
       mean diurnal course, as the VE abiotic model reports the mean of one
       modelled day.
    5. Reads soil temperature and soil moisture from spot surveys in primary
       (old-growth) forest only (safe_soil/: Riutta et al. 2021, Orme et al.
       2019, Ashton et al. 2019): monthly means of the visit readings per
       plot. Then reads the literature values (status "extracted" only).
    6. Puts every observation in one long table with the columns of the
       validation database (docs/validation_database.md), the value in the VE
       unit, where to read the VE value (grid mean) and the spatial and
       temporal match classes (distance to the grid, overlap with the run
       period).
    7. Records per VE variable the data in hand, the status and the data
       still needed or lacking to complete its validation (DATA_NEEDED,
       based on the VE abiotic model code).
    8. Writes the Excel workbook and rewrites the validation tracker
       (Section 6 only) of docs/abiotic_validation_plan.md.

virtual_ecosystem_module: Abiotic

author:
  - Lelavathy

status: wip

input_files:
  - name: Microclimate1319.csv
    path: data/primary/validation/dataset/safe_abiotic/
    description: |
      Hardwick, Nilus & Ewers (2024), Forest microclimate data from 2nd
      order sites (Version v2), Zenodo, doi:10.5281/zenodo.12751374. SAFE and
      Maliau microclimate loggers 2013-2019 at 1 m above ground: hourly air
      temperature and relative humidity per plot.
      To change by hand: if the file is renamed or moved, edit data under
      [sources.files] of the source safe_microclimate_2013_2019 in
      abiotic_sources.toml (paths are relative to the dataset folder).
      Column names, units and the plot coordinates rule are set there too.
  - name: SAFE_FluxTower_MetData_2012-2017 .xlsx
    path: data/primary/validation/dataset/safe_abiotic/
    description: |
      Riutta et al. (2020). SAFE flux tower meteorology, half-hourly, above
      the canopy (50 m) and below it (soil temperature and moisture),
      2012-2017.
      To change by hand: file name, sheets and header_row of the source
      safe_flux_tower_met_2012_2017 in abiotic_sources.toml. Columns read are
      listed in MET_COLUMNS (section 4 of this script).
  - name: SAFE_EC_byYear.xlsx
    path: data/primary/validation/dataset/safe_abiotic/
    description: |
      Mills et al. (2022). SAFE flux tower eddy covariance (EddyPro output at
      52 m), half-hourly, 2012-2018, one sheet per year.
      To change by hand: file name, sheets (add a sheet name when a new year
      is added) and header_row of the source safe_flux_tower_ec_2012_2018 in
      abiotic_sources.toml. The quality-flag threshold (flux_qc_max) and the
      excluded periods (ec_exclude_periods) are in the settings section;
      columns read are listed in EC_COLUMNS (section 4 of this script).
  - name: safe_soil/*.xlsx
    path: data/primary/validation/dataset/safe_soil/
    description: |
      Riutta et al. (2021) soil respiration plots, Orme et al. (2019) Belian
      plot and Ashton et al. (2019) termite plots: soil temperature (10-12 cm)
      and soil moisture (0-12 cm) at spot visits. Only primary forest rows are
      kept (old-growth plots, total-respiration collars, termite control
      plots); the other safe_soil files are screened out (no primary forest).
      To change by hand: file, sheet, header_row, columns and [sources.keep]
      of the sources safe_soil_respiration_2011_2018,
      safe_belian_soil_flux_2019 and safe_termite_maliau_2015_2016 in
      abiotic_sources.toml.
  - name: maliau_variables_summary.xlsx
    path: data/primary/validation/
    description: |
      VE output variables (output_variables sheet) with unit,
      classification, validation_priority and spin_up_sensitive, and the
      model constants (model_constats sheet).
      To change by hand: add or rename variables and set their priority in
      the output_variables sheet; the script reads it on every run. Close the
      file in Excel before running.
  - name: abiotic_sources.toml
    path: data/primary/validation/abiotic/
    description: |
      Where each dataset is, its columns, units, quality limits, coordinates,
      citation and screening record.
      To change by hand: whenever a data file is renamed, moved or added.
  - name: abiotic_literature_values.csv
    path: data/primary/validation/abiotic/
    description: |
      Published values and ranges, one row per value, with citation and DOI.
      To change by hand: add rows, and set status to "extracted" once a value
      is checked against the paper; other rows are not used.
  - name: maliau_grid_definition.toml
    path: data/derived/site/maliau/
    description: |
      The VE scenario grid (maliau_2) and run period, used for the match
      classes. To change by hand: nothing here; to compare with another
      scenario, set scenario_name in the settings section.
  - name: gazetteer.geojson
    path: data/primary/site/
    description: |
      SAFE gazetteer, used for plot coordinates.

output_files:
  - name: abiotic_validation_data.xlsx
    path: data/derived/validation/abiotic/ (output_file in the settings
      section)
    description: |
      Abiotic validation workbook: README, variable registry (with the data
      needed or lacking per variable), sites, sources, quality-control log,
      daily and monthly logger and flux tower values, literature values and
      one long table (validation_long) in the validation database layout.
      The whole workbook is rewritten on every run.
  - name: abiotic_validation_plan.md
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

   `python analysis/abiotic/validation/abiotic_validation_data.py`

  Edit only the settings section (paths, gap and completeness limits, eddy
  covariance quality flag, scenarios). The dataset folder can also be set
  with the VE_SAFE_DIR environment variable. To update the data needed or
  lacking for a variable, edit DATA_NEEDED in section 7.
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
# This script builds the observed side of the abiotic validation. It does not
# read VE outputs: joining VE outputs to these observations is a later step (see
# `docs/abiotic_validation_plan.md`). The hydrology validation is in
# `hydrology_validation_data.py` in this folder.
#
# Steps:
#
# 1. List the VE abiotic output variables from `maliau_variables_summary.xlsx`.
# 2. Look up plot coordinates in the SAFE gazetteer.
# 3. Read and clean the microclimate loggers; put them on an hourly step, fill
#    short gaps, and aggregate to daily and monthly values in local time.
# 4. Read the SAFE flux tower meteorology and eddy covariance data and make
#    monthly values.
# 5. Read soil temperature and soil moisture from primary forest plots
#    (safe_soil/), then the literature values.
# 6. Combine monthly observations and literature values in one long table that
#    uses the validation database columns (`docs/validation_database.md`).
# 7. Summarise data availability per VE variable, with the data still needed or
#    lacking to complete its validation, write the Excel workbook and the
#    tracker table (Section 6) in abiotic_validation_plan.md.
#
# The VE `maliau_2` scenario runs on a monthly time step, so the monthly tables are
# the ones to compare against. Daily tables are kept for checks of day-to-day
# behaviour and daily extremes.

# ============================================================
# SETTINGS
# ============================================================
# Edit only this section. Relative paths are relative to the repository root.
# The input_files notes in the header say what else may need changing by hand
# (mostly in abiotic_sources.toml) when data files are renamed or added.


# Dataset folder holding safe_abiotic/. Set the VE_SAFE_DIR environment
# variable or change the default; an absolute path works.
safe_dir = os.environ.get("VE_SAFE_DIR", "data/primary/validation/dataset")

variables_summary_file = "data/primary/validation/maliau_variables_summary.xlsx"
sources_file = "data/primary/validation/abiotic/abiotic_sources.toml"
literature_file = "data/primary/validation/abiotic/abiotic_literature_values.csv"
gazetteer_file = "data/primary/site/gazetteer.geojson"

output_file = "data/derived/validation/abiotic/abiotic_validation_data.xlsx"
plan_file = "docs/abiotic_validation_plan.md"

# Microclimate: hourly gap filling and completeness.
max_fill_gap_hours_microclimate = 3  # interpolate gaps up to this many hours
min_hours_per_day = 20  # hours with data for a complete day
min_days_per_month = 20  # complete days for a monthly value

# SAFE flux tower meteorology: same daily and monthly rules as the loggers.
max_fill_gap_hours_flux_tower = 3

# SAFE flux tower eddy covariance. Quality flags run from 0 (best) to 5 (worst);
# the threshold is still to be agreed. A monthly value is the mean of the
# month's mean diurnal course, so every hour of the day needs valid half-hours.
flux_qc_max = 3  # keep LE and H half-hours with a flag up to this value
min_values_per_hour_slot = 2  # valid half-hours per hour of the day and month
# Periods to drop per eddy covariance column, [start, end) in local time.
# 2012-12 to 2013-02: midday LE near 0 W m-2 while H is normal and the flags
# are good, so the water vapour signal failed.
ec_exclude_periods = {"LE": [("2012-12-01", "2013-03-01")]}

# VE scenario from the site definition. Observations are matched against the
# maliau_2 scenario grid only.
grid_definition_file = "data/derived/site/maliau/maliau_grid_definition.toml"
scenario_name = "maliau_2"  # 10 x 10 cells of 100 m
regional_max_km = 100  # beyond this distance from the grid there is no spatial match

# Soil plots (primary forest only): range limits for spot readings and the VE
# top soil layer thickness used to turn volumetric soil moisture into mm.
soil_temperature_limits = (10, 45)  # degC, as for the loggers
soil_moisture_limits = (0, 100)  # volume %
topsoil_depth_m = 0.25  # VE soil_layers default: top soil layer 0-0.25 m

# ============================================================
# PROJECT ROOT AND HELPER FUNCTIONS
# ============================================================
# Determine the root directory of the ve_data_science repository (the
# first parent folder holding pyproject.toml and mkdocs.yml), resolve the
# paths in the settings, read abiotic_sources.toml and define the helper
# functions used below.


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
        f"SAFE data folder not found: {safe_dir}. Set safe_dir or VE_SAFE_DIR."
    )

with open(repo_path(sources_file), "rb") as f:
    sources = {s["source_id"]: s for s in tomllib.load(f)["sources"]}
mc_source = sources["safe_microclimate_2013_2019"]
local_tz = mc_source["local_timezone"]

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
# (`output_variables` sheet), with their validation priority in the
# `classification`, `validation_priority` and `spin_up_sensitive` columns.
# The sheets repeat their header row between modules, so the module name is filled
# down and repeated header rows are dropped. `abiotc_simple` is read as
# `abiotic_simple`. Only the abiotic and abiotic simple variables are kept.

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

registry = outputs[outputs["module"].isin(["abiotic", "abiotic_simple"])]
# soil_moisture is a hydrology output that the abiotic model reads (soil heat
# capacity and conductivity), so it is checked here too.
soil_moisture_row = outputs[
    (outputs["module"] == "hydrology") & (outputs["variable"] == "soil_moisture")
].assign(module="hydrology (abiotic input)")
registry = pd.concat([registry, soil_moisture_row], ignore_index=True)
print(registry.groupby("module").size().to_string())
print(registry.head(10))

# ============================================================
# 2. SITES AND COORDINATES
# ============================================================
# Plot and block coordinates come from the SAFE gazetteer (`centroid_x`,
# `centroid_y`, WGS84), the same fallback the validation database uses. Habitat
# is set from the plot code (plot types from Lela, 2026-10-22):
#
# * OG1-OG3: old-growth (primary) forest at Maliau, the forest that the
#   `maliau_2` grid represents;
# * VJR: Virgin Jungle Reserve at SAFE, resembles primary forest but is not
#   fully primary (near-primary; comparable, regional);
# * A-F: salvage-logged forest;
# * LFE: twice-logged forest;
# * LF1-LF3: logged forest;
# * RP: riparian plots; OP: oil palm.
#
# `comparable_to_maliau_2` is True for primary forest only; the other plots
# stay in the workbook as context. Each site is also checked against the
# `maliau_2` grid.

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


def habitat_from_plot(plot: str) -> tuple[str, str]:
    """Return (site_group, habitat) from a SAFE plot code."""
    block = plot.split("_")[0].upper()
    if plot.upper().startswith("RP_"):
        return "SAFE", f"riparian ({plot.split('_')[1]})"
    if block.startswith("OG"):
        return "Maliau", "old-growth forest"
    if block == "VJR":
        return "SAFE", "near-primary forest (Virgin Jungle Reserve)"
    if block.startswith("OP"):
        return "SAFE", "oil palm"
    if block in list("ABCDEF"):
        return "SAFE", "salvage-logged forest"
    if block == "LFE":
        return "SAFE", "twice-logged forest"
    return "SAFE", "logged forest"


def comparable_to_maliau_2(habitat: pd.Series) -> pd.Series:
    """Return True where the habitat is primary or near-primary (VJR) forest."""
    return habitat.fillna("").str.startswith(("old-growth forest", "near-primary"))


# ============================================================
# 3. MICROCLIMATE LOGGERS
# ============================================================
# Quality control, in order:
#
# * drop rows without a plot or a parsable time (the file holds embedded header
#   rows from logger exports);
# * set air temperature outside 10-45 °C to missing;
# * cap relative humidity between 100 % and 130 % at 100 % (unlabelled loggers
#   read up to 122 % in saturated air) and set values outside 0-130 % to missing;
# * convert UTC to local time (Asia/Kuching, UTC+8) so days and months are local;
# * average all readings within the same plot and local hour, which removes
#   duplicate timestamps and puts all loggers on one hourly step;
# * put each plot on a regular hourly index and fill gaps of up to
#   `max_fill_gap_hours_microclimate` hours by linear interpolation in time
#   (`filled` marks them); longer gaps stay missing.
#
# Vapour pressure and vapour pressure deficit are calculated hourly with the
# same Magnus equation as the VE (pyrealm `calc_vp_sat`, default coefficients
# of Sonntag 1990),
# $e_s(T) = 0.6112 \exp\left(\frac{17.62 T}{T + 243.12}\right)$ kPa,
# $e_a = e_s \cdot RH / 100$ and $VPD = e_s - e_a$.
#
# A day is complete with at least `min_hours_per_day` hours of temperature; a
# month with at least `min_days_per_month` complete days.


def saturation_vapour_pressure(temperature):
    """Return saturation vapour pressure (kPa) as in the VE (pyrealm default)."""
    return 0.6112 * np.exp(17.62 * temperature / (temperature + 243.12))


mc_vars = mc_source["variables"]
mc = pd.read_csv(
    safe_path / mc_source["files"]["data"],
    dtype=str,
    encoding=mc_source["encoding"],
)
mc = mc.rename(
    columns={mc_source["location_column"]: "location", mc_source["time_column"]: "time"}
)
n_raw = len(mc)
mc["time"] = pd.to_datetime(
    mc["time"], utc=True, format=mc_source["time_format"], errors="coerce"
)
bad = mc["time"].isna() | mc["location"].isna()
log_qc(
    "microclimate",
    "all",
    "drop rows without plot or time",
    bad.sum(),
    "embedded header rows and NA times",
)
mc = mc.loc[~bad]

for col, spec in mc_vars.items():
    mc[col] = pd.to_numeric(mc[col], errors="coerce")
    if "cap_at" in spec:
        capped = (mc[col] > spec["cap_at"]) & (mc[col] <= spec["valid_max"])
        log_qc("microclimate", "all", f"cap {col} at {spec['cap_at']}", capped.sum())
        mc.loc[capped, col] = spec["cap_at"]
    out = (mc[col] < spec["valid_min"]) | (mc[col] > spec["valid_max"])
    log_qc(
        "microclimate",
        "all",
        f"{col} outside {spec['valid_min']}-{spec['valid_max']} set missing",
        out.sum(),
    )
    mc.loc[out, col] = np.nan

mc["time_local"] = mc["time"].dt.tz_convert(local_tz).dt.tz_localize(None)
mc["hour"] = mc["time_local"].dt.floor("h")
logger_type = (
    mc.assign(LoggerType=mc["LoggerType"].fillna("unlabelled"))
    .groupby("location")["LoggerType"]
    .agg(lambda s: s.value_counts().index[0])
)

hourly = mc.groupby(["location", "hour"], as_index=False).agg(
    air_temperature=("Temp", "mean"), relative_humidity=("RH", "mean")
)
log_qc(
    "microclimate",
    "all",
    "average readings within plot-hour",
    len(mc) - len(hourly),
    "rows merged",
)


def fill_plot(group: pd.DataFrame) -> pd.DataFrame:
    """Put one plot on a regular hourly index and fill short gaps."""
    group = group.set_index("hour").asfreq("h")
    filled_any = pd.Series(False, index=group.index)
    for col in ["air_temperature", "relative_humidity"]:
        group[col], flag = fill_short_gaps(group[col], max_fill_gap_hours_microclimate)
        filled_any |= flag
    group["filled"] = filled_any
    return group.drop(columns="location")


hourly = (
    hourly.groupby("location", group_keys=True)[
        ["location", "hour", "air_temperature", "relative_humidity"]
    ]
    .apply(fill_plot)
    .reset_index()
)
hourly = hourly[hourly[["air_temperature", "relative_humidity"]].notna().any(axis=1)]
log_qc(
    "microclimate",
    "all",
    "plot-hours filled by interpolation",
    hourly["filled"].sum(),
    f"gaps up to {max_fill_gap_hours_microclimate} h",
)

es = saturation_vapour_pressure(hourly["air_temperature"])
hourly["vapour_pressure"] = es * hourly["relative_humidity"] / 100
hourly["vapour_pressure_deficit"] = es - hourly["vapour_pressure"]
hourly["date"] = hourly["hour"].dt.normalize()

mc_daily = hourly.groupby(["location", "date"], as_index=False).agg(
    n_hours=("air_temperature", "count"),
    n_hours_rh=("relative_humidity", "count"),
    air_temperature_mean=("air_temperature", "mean"),
    air_temperature_min=("air_temperature", "min"),
    air_temperature_max=("air_temperature", "max"),
    relative_humidity_mean=("relative_humidity", "mean"),
    relative_humidity_min=("relative_humidity", "min"),
    vapour_pressure_mean=("vapour_pressure", "mean"),
    vapour_pressure_deficit_mean=("vapour_pressure_deficit", "mean"),
    vapour_pressure_deficit_max=("vapour_pressure_deficit", "max"),
)
mc_daily["complete_day"] = mc_daily["n_hours"] >= min_hours_per_day
humid_cols = [c for c in mc_daily if c.startswith(("relative_humidity", "vapour"))]
mc_daily.loc[mc_daily["n_hours_rh"] < min_hours_per_day, humid_cols] = np.nan
log_qc(
    "microclimate",
    "all",
    "incomplete days (excluded from monthly)",
    (~mc_daily["complete_day"]).sum(),
    f"fewer than {min_hours_per_day} hours",
)

value_cols = [c for c in mc_daily if c.endswith(("_mean", "_min", "_max"))]
complete = mc_daily[mc_daily["complete_day"]].assign(
    month=lambda d: d["date"].dt.to_period("M")
)
mc_monthly = complete.groupby(["location", "month"], as_index=False).agg(
    n_days=("date", "count"),
    n_days_rh=("relative_humidity_mean", "count"),
    **{c: (c, "mean") for c in value_cols},
)
mc_monthly["complete_month"] = mc_monthly["n_days"] >= min_days_per_month
mc_monthly.loc[mc_monthly["n_days_rh"] < min_days_per_month, humid_cols] = np.nan

print(
    f"{n_raw:,} raw rows, {len(hourly):,} plot-hours, {len(mc_daily):,} plot-days, "
    f"{mc_monthly['complete_month'].sum():,} complete plot-months"
)

# ============================================================
# 3.1 LOGGER SITES
# ============================================================
# One row per logger plot, with its coordinates, record period and distance
# to the grid.
mc_sites = (
    mc.groupby("location")
    .agg(first_record=("time_local", "min"), last_record=("time_local", "max"))
    .reset_index()
    .merge(gazetteer, on="location", how="left")
)
mc_sites[["site_group", "habitat"]] = [
    habitat_from_plot(p) for p in mc_sites["location"]
]
mc_sites["comparable_to_maliau_2"] = comparable_to_maliau_2(mc_sites["habitat"])
mc_sites["logger_type"] = mc_sites["location"].map(logger_type)
mc_sites["dataset"] = mc_source["source_id"]
mc_sites["location_type"] = "point"
mc_sites["coordinate_source"] = np.where(
    mc_sites["latitude"].notna(), "gazetteer", "missing"
)
mc_sites = mc_sites.merge(
    mc_monthly[mc_monthly["complete_month"]]
    .groupby("location")
    .size()
    .rename("complete_months"),
    on="location",
    how="left",
).fillna({"complete_months": 0})
mc_sites = add_scenario_overlap(mc_sites)
print(
    mc_sites.groupby(["site_group", "habitat"])["complete_months"].agg(["size", "sum"])
)
print(
    "Sites inside the maliau_2 grid:",
    mc_sites.loc[mc_sites["in_scenario_grid"], "location"].tolist(),
)

# ============================================================
# 4. SAFE FLUX TOWER
# ============================================================
# Two files from the same tower (`abiotic_sources.toml`): the meteorology
# (`SAFE_FluxTower_MetData_2012-2017 .xlsx`) and the eddy covariance output
# (`SAFE_EC_byYear.xlsx`). Each sheet has metadata rows above the `field_name`
# row (`header_row`). Times are local (UTC+8) and mark the end of each 30 min
# period, so each value is placed in the hour and day in which its period ends
# one minute before the stamp.
#
# Meteorology, quality control and aggregation:
#
# * values outside the limits below are set to missing (the above-canopy logger
#   has spikes such as -79 °C and 12 mbar during power failures);
# * half-hourly values are averaged per local hour, put on a regular hourly
#   index and gaps up to `max_fill_gap_hours_flux_tower` hours are filled;
# * daily and monthly means use `min_hours_per_day` and `min_days_per_month`,
#   checked for each variable on its own;
# * vapour pressure and VPD above the canopy are calculated hourly as for the
#   loggers;
# * net radiation is stored with sources of energy to the atmosphere positive
#   (the readme), so the sign is reversed to give the energy absorbed by the
#   ecosystem, as in the VE;
# * pressure in mbar / 10 = kPa.
#
# Eddy covariance:
#
# * `-9999` and `NA` are missing; repeated time stamps (2017, 2018) keep the
#   first row;
# * LE and H half-hours are kept when their quality flag is at most
#   `flux_qc_max` and the value is within the limits below; wind speed has no
#   flag;
# * periods listed in `ec_exclude_periods` are set missing;
# * the monthly value is the mean of the mean diurnal course: the mean of each
#   hour of the day over the month, then the mean of the 24 hours, used only
#   when every hour has at least `min_values_per_hour_slot` valid half-hours.
#   This avoids a bias towards the daytime, when most valid fluxes are.

met_source = sources["safe_flux_tower_met_2012_2017"]
ec_source = sources["safe_flux_tower_ec_2012_2018"]
tower_location = "Flux_tower"

# column: (VE variable, unit, valid min, valid max, level)
MET_COLUMNS = {
    "data_above canopy": {
        "AirTC_Avg": ("air_temperature", "degC", 10, 45, "50 m"),
        "RH": ("relative_humidity", "percent", 0, 100, "50 m"),
        "NR_Wm2_Avg": ("net_radiation", "W m-2", -1500, 300, "50 m"),
        "BP_mbar_Avg": ("atmospheric_pressure", "mbar", 900, 1100, "50 m"),
    },
    "data_below canopy": {
        "TCAV_C_1_Avg": ("soil_temperature", "degC", 15, 40, "-5 cm"),
        "TCAV_C_2_Avg": ("soil_temperature", "degC", 15, 40, "-10 cm"),
        "TCAV_C_3_Avg": ("soil_temperature", "degC", 15, 40, "-20 cm"),
    },
}
EC_COLUMNS = {
    # column: (VE variable, unit, valid min, valid max, quality flag column)
    "LE": ("latent_heat_flux", "W m-2", -200, 1000, "qc_LE"),
    "H": ("sensible_heat_flux", "W m-2", -200, 1000, "qc_H"),
    "wind_speed": ("wind_speed", "m s-1", 0, 30, None),
}


def read_tower_sheet(source: dict, sheet: str) -> pd.DataFrame:
    """Read one flux tower sheet below its metadata rows."""
    table = pd.read_excel(
        safe_path / source["file"],
        sheet_name=sheet,
        header=source["header_row"] - 1,
        na_values=source.get("missing_values", []),
    )
    return table.drop(columns="field_name")


def period_hour(stamp: pd.Series) -> pd.Series:
    """Return the local hour in which a period ending at the stamp lies."""
    return (pd.to_datetime(stamp) - pd.Timedelta(minutes=1)).dt.floor("h")


def tower_daily_monthly(hourly: pd.DataFrame, columns: list) -> tuple:
    """Return daily and monthly means per column with completeness rules."""
    hourly = hourly.assign(date=hourly["hour"].dt.normalize())
    daily = hourly.groupby("date")[columns].agg(["mean", "count"])
    daily_mean = daily.xs("mean", axis=1, level=1)
    daily_mean = daily_mean.where(
        daily.xs("count", axis=1, level=1) >= min_hours_per_day
    )
    month = daily_mean.index.to_period("M")
    monthly = daily_mean.groupby(month).agg(["mean", "count"])
    monthly_mean = monthly.xs("mean", axis=1, level=1)
    n_days = monthly.xs("count", axis=1, level=1)
    monthly_mean = monthly_mean.where(n_days >= min_days_per_month)
    return daily_mean, monthly_mean, n_days


tower_monthly_frames = []  # tidy rows: column, month, value, count
tower_daily_frames = []
for sheet, columns in MET_COLUMNS.items():
    met = read_tower_sheet(met_source, sheet)
    met["hour"] = period_hour(met["TIMESTAMP"])
    for col, (var, unit, vmin, vmax, level) in columns.items():
        met[col] = pd.to_numeric(met[col], errors="coerce")
        out = (met[col] < vmin) | (met[col] > vmax)
        log_qc(
            "flux_tower_met",
            sheet,
            f"{col} outside {vmin}-{vmax} set missing",
            out.sum(),
        )
        met.loc[out, col] = np.nan
    hourly_met = met.groupby("hour")[list(columns)].mean().asfreq("h")
    for col in columns:
        hourly_met[col], flag = fill_short_gaps(
            hourly_met[col], max_fill_gap_hours_flux_tower
        )
        log_qc(
            "flux_tower_met",
            sheet,
            f"{col} hours filled by interpolation",
            flag.sum(),
            f"gaps up to {max_fill_gap_hours_flux_tower} h",
        )
    hourly_met = hourly_met.reset_index()
    if sheet == "data_above canopy":
        t, rh = hourly_met["AirTC_Avg"], hourly_met["RH"]
        es = saturation_vapour_pressure(t)
        hourly_met["vapour_pressure_ref"] = es * rh / 100
        hourly_met["vapour_pressure_deficit_ref"] = (
            es - hourly_met["vapour_pressure_ref"]
        )
        columns = {
            **columns,
            "vapour_pressure_ref": ("vapour_pressure_ref", "kPa", None, None, "50 m"),
            "vapour_pressure_deficit_ref": (
                "vapour_pressure_deficit_ref",
                "kPa",
                None,
                None,
                "50 m",
            ),
        }
    daily_mean, monthly_mean, n_days = tower_daily_monthly(hourly_met, list(columns))
    tower_daily_frames.append(daily_mean.add_prefix(f"{sheet.split()[1]}__"))
    for col, (var, unit, _, _, level) in columns.items():
        tower_monthly_frames.append(
            pd.DataFrame(
                {
                    "dataset": met_source["source_id"],
                    "sheet": sheet,
                    "column": col,
                    "var_canonical": var,
                    "unit_original": unit,
                    "level": level,
                    "month": monthly_mean.index,
                    "value_original": monthly_mean[col].to_numpy(),
                    "n": n_days[col].to_numpy(),
                    "count_unit": "complete days",
                }
            )
        )

ec = pd.concat(
    [
        read_tower_sheet(ec_source, s)
        for s in ec_source["sheets"]
        if s.startswith("Raw_data")
    ],
    ignore_index=True,
)[["date", "time", *EC_COLUMNS, "qc_LE", "qc_H"]]
ec["end"] = pd.to_datetime(
    pd.to_datetime(ec["date"]).dt.strftime("%Y-%m-%d") + " " + ec["time"].astype(str)
)
dup = ec["end"].duplicated()
log_qc(
    "flux_tower_ec",
    tower_location,
    "drop repeated time stamps",
    dup.sum(),
    "2017 and 2018 sheets",
)
ec = ec.loc[~dup].copy()
ec["hour"] = period_hour(ec["end"])
for col, (var, unit, vmin, vmax, qc_col) in EC_COLUMNS.items():
    ec[col] = pd.to_numeric(ec[col], errors="coerce").replace(-9999, np.nan)
    keep = ec[col].between(vmin, vmax)
    log_qc(
        "flux_tower_ec",
        tower_location,
        f"{col} outside {vmin}-{vmax} set missing",
        (ec[col].notna() & ~keep).sum(),
    )
    if qc_col:
        flag = pd.to_numeric(ec[qc_col], errors="coerce").replace(-9999, np.nan)
        bad_flag = keep & ~(flag <= flux_qc_max)
        log_qc(
            "flux_tower_ec",
            tower_location,
            f"{col} with {qc_col} above {flux_qc_max} set missing",
            bad_flag.sum(),
            "quality flag threshold to agree",
        )
        keep &= flag <= flux_qc_max
    for start, end in ec_exclude_periods.get(col, []):
        period = keep & (ec["end"] > start) & (ec["end"] <= end)
        log_qc(
            "flux_tower_ec",
            tower_location,
            f"{col} {start} to {end} set missing",
            period.sum(),
            "excluded period (settings)",
        )
        keep &= ~period
    ec[col] = ec[col].where(keep)

ec["month"] = ec["hour"].dt.to_period("M")
ec["hour_of_day"] = ec["hour"].dt.hour
for col, (var, unit, _, _, _) in EC_COLUMNS.items():
    slots = ec.groupby(["month", "hour_of_day"])[col].agg(["mean", "count"]).unstack()
    slot_mean = slots["mean"].reindex(columns=range(24))
    slot_count = slots["count"].reindex(columns=range(24)).fillna(0)
    complete = (slot_count >= min_values_per_hour_slot).all(axis=1)
    tower_monthly_frames.append(
        pd.DataFrame(
            {
                "dataset": ec_source["source_id"],
                "sheet": "Raw_data",
                "column": col,
                "var_canonical": var,
                "unit_original": unit,
                "level": "52 m",
                "month": slot_mean.index,
                "value_original": slot_mean.mean(axis=1).where(complete).to_numpy(),
                "n": slot_count.sum(axis=1).astype(int).to_numpy(),
                "count_unit": "valid half-hours",
            }
        )
    )

tower_monthly = pd.concat(tower_monthly_frames, ignore_index=True)
tower_daily = pd.concat(tower_daily_frames, axis=1).reset_index()
tower_monthly["complete_month"] = tower_monthly["value_original"].notna()
print(
    tower_monthly[tower_monthly["complete_month"]]
    .groupby(["dataset", "column"])["month"]
    .agg(["count", "min", "max"])
)

# ============================================================
# 4.1 FLUX TOWER SITE
# ============================================================
# One row per flux tower file (meteorology and eddy covariance), with the
# tower coordinates, record period and distance to the grid.
tower_sites = pd.DataFrame(
    [
        {
            "location": tower_location,
            "dataset": src["source_id"],
            "site_group": "SAFE",
            "habitat": "logged forest (SAFE flux tower)",
            "location_type": "point",
            "latitude": src["latitude"],
            "longitude": src["longitude"],
            "coordinate_source": "fixed_metadata",
            "first_record": str(tower_monthly.loc[m, "month"].min()),
            "last_record": str(tower_monthly.loc[m, "month"].max()),
            "complete_months": tower_monthly.loc[m, "month"].nunique(),
        }
        for src in [met_source, ec_source]
        for m in [
            (tower_monthly["dataset"] == src["source_id"])
            & tower_monthly["complete_month"]
        ]
    ]
)
tower_sites["comparable_to_maliau_2"] = False  # logged forest
tower_sites = add_scenario_overlap(tower_sites)
print(tower_sites[["location", "dataset", "distance_to_grid_km", "complete_months"]])

# ============================================================
# 4.2 SOIL PLOTS (PRIMARY FOREST ONLY)
# ============================================================
# Soil temperature and soil moisture from spot surveys in safe_soil/, kept for
# primary (old-growth) forest only, as set in abiotic_sources.toml:
#
# * `safe_soil_respiration_2011_2018`: SAFE carbon plots, about monthly visits,
#   2012-2018; soil temperature at 10 cm and soil moisture (0-12 cm) next to
#   the total-respiration collars; Car_Bel and Car_Ser at Maliau, Car_D1 and
#   Car_D2 at Danum Valley (logged and oil palm plots dropped);
# * `safe_belian_soil_flux_2019`: Belian plot at Maliau, four days in February
#   2019, soil temperature at 12 cm and soil moisture (subplots averaged);
# * `safe_termite_maliau_2015_2016`: control plots at Maliau, soil moisture in
#   March 2016 (El Nino drought) and October 2016 (dates are months only).
#
# Cleaning: rows are kept only where the `[sources.keep]` columns match;
# readings outside `soil_temperature_limits` or `soil_moisture_limits` are set
# missing. Each plot gets one value per month and variable: the mean of all
# readings in that month (`visit_mean`), with the number of readings and visit
# days. These are spot surveys, not continuous records.
#
# Units: soil temperature stays in degC (VE `soil_temperature`; the probes at
# 10-12 cm sit in the VE top soil layer, 0-0.25 m). Soil moisture in volume %
# is divided by 100 to give theta (m3 m-3); the VE value is theta x 250 mm
# (`obs_in_ve_unit`, VE `soil_moisture`, a hydrology output that the abiotic
# model reads).

soil_sources = [
    s
    for s in sources.values()
    if "columns" in s and s.get("screening", {}).get("decision") == "proceed"
]
SOIL_LIMITS = {
    "soil_temperature": soil_temperature_limits,
    "soil_moisture": soil_moisture_limits,
}


def read_soil_source(src: dict) -> pd.DataFrame:
    """Read one soil source into rows of location, date, variable and value."""
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
    location = raw[src["location_column"]].astype(str).str.strip()
    if src.get("aggregate_to_plot"):  # subplots such as Car_Bel-01 to plot Car_Bel
        location = location.str.split("-").str[0]
    frames = []
    for col in src["columns"]:
        part = pd.DataFrame(
            {
                "location": location,
                "date": pd.to_datetime(raw[src["date_column"]], errors="coerce"),
                "var_original": col["name"],
                "unit_original": col["unit"],
                "var_canonical": col["var_canonical"],
                "level": col.get("level", ""),
                "value": pd.to_numeric(raw[col["name"]], errors="coerce"),
            }
        )
        low, high = SOIL_LIMITS[col["var_canonical"]]
        bad = part["value"].notna() & ~part["value"].between(low, high)
        part.loc[bad, "value"] = np.nan
        log_qc(
            src["source_id"],
            "all",
            f"{col['name']} outside {low}-{high} {col['unit']} set missing",
            bad.sum(),
        )
        missing = part["value"].isna() | part["date"].isna()
        log_qc(
            src["source_id"],
            "all",
            f"{col['name']} rows without value or date dropped",
            missing.sum(),
        )
        frames.append(part[~missing])
    data = pd.concat(frames, ignore_index=True)
    data["dataset"] = src["source_id"]
    data["habitat"] = src["habitat"]
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
        coordinate_source = "gazetteer"
    data = data.merge(
        locs[["location", "latitude", "longitude"]], on="location", how="left"
    )
    data["coordinate_source"] = np.where(
        data["latitude"].notna(), coordinate_source, "missing"
    )
    return data


soil_points = pd.concat([read_soil_source(s) for s in soil_sources], ignore_index=True)
soil_points["month"] = soil_points["date"].dt.to_period("M")
soil_monthly = soil_points.groupby(
    [
        "dataset",
        "location",
        "var_canonical",
        "var_original",
        "unit_original",
        "level",
        "month",
    ],
    as_index=False,
).agg(
    habitat=("habitat", "first"),
    latitude=("latitude", "first"),
    longitude=("longitude", "first"),
    coordinate_source=("coordinate_source", "first"),
    n_readings=("value", "count"),
    n_visit_days=("date", "nunique"),
    value_mean=("value", "mean"),
    value_sd=("value", "std"),
)

soil_sites = soil_monthly.groupby(["dataset", "location"], as_index=False).agg(
    habitat=("habitat", "first"),
    latitude=("latitude", "first"),
    longitude=("longitude", "first"),
    coordinate_source=("coordinate_source", "first"),
    first_record=("month", "min"),
    last_record=("month", "max"),
    complete_months=("month", "nunique"),
)
soil_sites["site_group"] = np.where(
    soil_sites["location"].isin(["Car_D1", "Car_D2"]), "Danum", "Maliau"
)
soil_sites["location_type"] = "plot"
soil_sites["comparable_to_maliau_2"] = comparable_to_maliau_2(soil_sites["habitat"])
soil_sites = add_scenario_overlap(soil_sites)
for col in ["first_record", "last_record"]:
    soil_sites[col] = soil_sites[col].astype(str)
print(soil_sites[["dataset", "location", "distance_to_grid_km", "complete_months"]])


# ============================================================
# 5. LITERATURE VALUES
# ============================================================
# `abiotic_literature_values.csv` holds one row per published value or range, with the
# VE variable it validates (`var_canonical`), units, site, period and citation.
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
# 6. LONG VALIDATION TABLE
# ============================================================
# One observation per row with the columns of the validation database
# (`docs/validation_database.md`), plus `location`, `habitat`, `site_group`,
# `level` (sensor height or depth), `statistic`, `n_days` (the count behind
# the value: complete days, or valid half-hours for the eddy covariance),
# `source_type` and `in_scenario_grid`. Times are UTC,
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
    "comparable_to_maliau_2",
    "level",
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
    long = pd.concat(frames, ignore_index=True).assign(level="")
    long["time_note"] = (
        "Local month (" + local_tz + "), " + long["n_days"].astype(str) + note_unit
    )
    return to_long_layout(long, sites, dataset)


def to_long_layout(long, sites, dataset):
    """Add times, site details and IDs to monthly rows in the long layout."""
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
                "comparable_to_maliau_2",
                "in_scenario_grid",
            ]
        ],
        on="location",
        how="left",
    )
    long["time_type"] = "interval"
    long["time_precision"] = "month"
    long["time_source"] = "source_columns"
    long["dataset"] = dataset
    long["source_type"] = "observed_time_series"
    level = long["level"].str.replace(" ", "")
    long["ID"] = (
        dataset
        + "__"
        + long["location"]
        + "__"
        + long["var_canonical"]
        + "__"
        + long["statistic"]
        + np.where(level != "", "__" + level, "")
        + "__"
        + long["month"].astype(str)
    )
    return long[LONG_COLUMNS]


mc_mapping = {
    # column: (var_original, unit_original, var_canonical, unit_canonical,
    #          statistic, factor)
    "air_temperature_mean": (
        "Temp",
        "degC",
        "air_temperature",
        "degC",
        "monthly_mean",
        1,
    ),
    "air_temperature_max": (
        "Temp",
        "degC",
        "air_temperature",
        "degC",
        "mean_daily_max",
        1,
    ),
    "air_temperature_min": (
        "Temp",
        "degC",
        "air_temperature",
        "degC",
        "mean_daily_min",
        1,
    ),
    "relative_humidity_mean": (
        "RH",
        "percent",
        "relative_humidity",
        "percent",
        "monthly_mean",
        1,
    ),
    "vapour_pressure_mean": (
        "Temp, RH (derived)",
        "kPa",
        "vapour_pressure",
        "kPa",
        "monthly_mean",
        1,
    ),
    "vapour_pressure_deficit_mean": (
        "Temp, RH (derived)",
        "kPa",
        "vapour_pressure_deficit",
        "kPa",
        "monthly_mean",
        1,
    ),
    "vapour_pressure_deficit_max": (
        "Temp, RH (derived)",
        "kPa",
        "vapour_pressure_deficit",
        "kPa",
        "mean_daily_max",
        1,
    ),
}
mc_long = monthly_long(mc_monthly, mc_sites, mc_mapping, mc_source["source_id"])

# Flux tower: original unit to the canonical unit.
TOWER_UNITS = {
    # unit_original: (unit_canonical, factor)
    "degC": ("degC", 1),
    "percent": ("percent", 1),
    "kPa": ("kPa", 1),
    "mbar": ("kPa", 0.1),
    "W m-2": ("W m-2", 1),
    "m s-1": ("m s-1", 1),
}
tower_frames = []
for dataset, part in tower_monthly[tower_monthly["complete_month"]].groupby("dataset"):
    part = part.rename(columns={"column": "var_original", "n": "n_days"}).copy()
    part["unit_canonical"] = part["unit_original"].map(lambda u: TOWER_UNITS[u][0])
    factor = part["unit_original"].map(lambda u: TOWER_UNITS[u][1])
    # Net radiation in the file is positive for energy to the atmosphere.
    factor = factor.where(part["var_canonical"] != "net_radiation", -factor)
    part["value_canonical"] = part["value_original"] * factor
    part["var_original"] = np.where(
        part["var_original"].str.startswith("vapour_pressure"),
        "AirTC_Avg, RH (derived)",
        part["var_original"],
    )
    part["statistic"] = np.where(
        part["count_unit"] == "valid half-hours", "monthly_mean_diurnal", "monthly_mean"
    )
    part["location"] = tower_location
    part["time_note"] = (
        "Local month ("
        + local_tz
        + "), "
        + part["n_days"].astype(str)
        + " "
        + part["count_unit"]
    )
    tower_frames.append(
        to_long_layout(part, tower_sites[tower_sites["dataset"] == dataset], dataset)
    )
tower_long = pd.concat(tower_frames, ignore_index=True)


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
                    "level": "",
                    "statistic": statistic,
                    "n_days": np.nan,
                    "source_type": "literature",
                    "in_scenario_grid": False,
                }
            )
    return pd.DataFrame(rows, columns=LONG_COLUMNS)


# Soil plots (section 4.2): one row per plot, month and variable.
soil_frames = []
for dataset, part in soil_monthly.groupby("dataset"):
    part = part.rename(columns={"n_visit_days": "n_days"}).drop(
        columns=["habitat", "latitude", "longitude", "coordinate_source"]
    )
    moisture = part["var_canonical"] == "soil_moisture"
    part["value_original"] = part["value_mean"]
    part["unit_canonical"] = np.where(moisture, "m^3 m^-3", "degC")
    part["value_canonical"] = np.where(
        moisture, part["value_mean"] / 100, part["value_mean"]
    )
    part["unit_original"] = part["unit_original"].replace({"%": "percent"})
    part["statistic"] = "visit_mean"
    part["time_note"] = (
        "Local month ("
        + local_tz
        + "), "
        + part["n_readings"].astype(str)
        + " readings on "
        + part["n_days"].astype(str)
        + " visit days"
    )
    soil_frames.append(
        to_long_layout(part, soil_sites[soil_sites["dataset"] == dataset], dataset)
    )
soil_long = pd.concat(soil_frames, ignore_index=True)

lit_long = literature_long(literature)
validation_long = pd.concat(
    [mc_long, tower_long, soil_long, lit_long], ignore_index=True
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
# 6.1 VE NAMES, UNITS AND VALUES
# ============================================================
# Validation plots use the VE variable names and units, so every row also gets
# `ve_variable`, `ve_unit` and `obs_in_ve_unit` (the observed value converted to
# the VE unit; this is not model output). `ve_formula` gives the VE outputs
# combined for a derived target and is blank when the VE writes the variable
# directly. `ve_note` says how to aggregate the monthly VE time steps to match
# the row. `ve_compare_at` says where on the grid to read the VE value (the grid
# mean for every abiotic variable) and `ve_compare_note` gives the detail.

VE_CONVERSIONS = {
    # unit_canonical: (factor to the VE unit, note)
    "degC": (1.0, ""),
    "percent": (1.0, ""),
    "kPa": (1.0, ""),
    "W m-2": (1.0, ""),
    "m s-1": (1.0, ""),
    # VE soil_moisture is water depth in the top soil layer (mm): theta x 250 mm.
    "m^3 m^-3": (topsoil_depth_m * 1000, "theta x 250 mm, the VE top soil layer"),
}


def add_ve_columns(long: pd.DataFrame) -> pd.DataFrame:
    """Add the VE variable name, unit, value, formula and note to the long table."""
    ve = registry.drop_duplicates("variable").set_index("variable")
    long = long.copy()
    long["ve_variable"] = long["var_canonical"]
    long["ve_unit"] = long["ve_variable"].map(ve["unit_ve"])
    factor = long["unit_canonical"].map(lambda u: VE_CONVERSIONS[u][0])
    # The VE stores sensible and latent heat flux as negative when energy goes
    # from the surface to the air (energy_balance.py); the eddy covariance
    # values are positive upward, so their sign is reversed here.
    flux_sign = np.where(
        long["var_canonical"].isin(["latent_heat_flux", "sensible_heat_flux"]), -1, 1
    )
    long["obs_in_ve_unit"] = (
        pd.to_numeric(long["value_canonical"], errors="coerce") * factor * flux_sign
    )
    long["ve_formula"] = ""
    stat_notes = {
        "monthly_mean": "Mean of the VE values over the month",
        "mean_daily_max": "Mean of the daily maxima of the VE values",
        "mean_daily_min": "Mean of the daily minima of the VE values",
        "monthly_mean_diurnal": "Mean of the VE values over the month",
    }
    long["ve_note"] = long["statistic"].map(stat_notes).fillna("")
    # Every cell has the same forcing, so the grid mean is the main target; the
    # cells holding the OG2 plots are a check.
    long["ve_compare_at"] = "grid mean"
    long["ve_compare_note"] = (
        "Grid mean of the VE layer nearest the logger height (1 m): the surface "
        "layer (0.1 m) or the lowest canopy layer, to agree; the cells holding "
        "the OG2 plots as a check"
    )
    tower = long["location"] == tower_location
    above = tower & long["level"].isin(["50 m", "52 m"])
    long.loc[above, "ve_compare_note"] = (
        "Grid mean of the VE value above the canopy; the tower measures 25-27 m "
        "above the canopy, so a range check only (regional site)"
    )
    flux = tower & long["var_canonical"].isin(
        ["latent_heat_flux", "sensible_heat_flux"]
    )
    long.loc[flux, "ve_compare_note"] = (
        "Grid mean of the VE flux from the whole canopy and soil (regional site); "
        "obs_in_ve_unit has the VE sign (negative from the surface to the air)"
    )
    for name in ["latent_heat_flux", "sensible_heat_flux"]:
        long.loc[tower & (long["var_canonical"] == name), "ve_formula"] = (
            f"sum of {name} over the canopy layers, surface layer and topsoil"
        )
    nr = tower & (long["var_canonical"] == "net_radiation")
    long.loc[nr, "ve_compare_note"] = (
        "Grid mean of the VE net radiation of the canopy and soil (regional site)"
    )
    long.loc[nr, "ve_formula"] = (
        "sum of net_radiation over the canopy layers, surface layer and topsoil"
    )

    long.loc[
        tower & (long["var_canonical"] == "atmospheric_pressure"), "ve_compare_note"
    ] = "Grid mean; the VE takes pressure from the forcing, so an input check"
    long.loc[
        tower & (long["var_canonical"] == "soil_temperature"), "ve_compare_note"
    ] = "Grid mean of the VE soil layer nearest the sensor depth (regional site)"
    soil_plot = long["location_type"] == "plot"
    long.loc[
        soil_plot & (long["var_canonical"] == "soil_temperature"), "ve_compare_note"
    ] = (
        "Grid mean of the VE top soil layer (0-0.25 m); the probe is at "
        "10-12 cm; Maliau plots next to the grid, Danum plots regional"
    )
    long.loc[
        soil_plot & (long["var_canonical"] == "soil_moisture"), "ve_compare_note"
    ] = (
        "Grid mean of VE soil_moisture in the top soil layer (mm); a hydrology "
        "output that the abiotic model reads, so an input check; the probe "
        "samples 0-12 cm of the 0-25 cm layer"
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
# 6.2 SPATIAL AND TEMPORAL MATCH WITH THE VE SCENARIO
# ============================================================
# Each row is classed against the scenario grid and run period read from the
# site definition (`maliau_grid_definition.toml`).
#
# Spatial match (`spatial_match`, detail in `spatial_match_detail`):
#
# * `match`: the site is inside the scenario grid (`inside_grid`);
# * `partial`: the site is outside the grid but within `regional_max_km` of it
#   (`regional`);
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
            distance <= regional_max_km,
        ],
        ["no_location", "inside_grid", "regional"],
        "outside_region",
    )
    long["spatial_match_detail"] = spatial
    long["spatial_match"] = pd.Series(spatial, index=long.index).map(
        {
            "no_location": "unknown",
            "inside_grid": "match",
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
# 7. DATA AVAILABILITY PER VE VARIABLE AND TRACKER TABLE
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
obs_summary = obs.groupby("var_canonical").agg(
    observed_dataset=("dataset", lambda s: ", ".join(sorted(s.unique()))),
    observed_variable=("var_original", lambda s: ", ".join(sorted(s.unique()))),
    observed_period_start=("month_local", "min"),
    observed_period_end=("month_local", "max"),
    n_sites=("location", "nunique"),
    site_kind=(
        "location_type",
        lambda s: "catchments" if (s == "catchment").all() else "plots",
    ),
    n_monthly_values=("value_original", "count"),
    n_canonical_values=("value_canonical", "count"),
    n_sites_in_scenario_grid=(
        "in_scenario_grid",
        lambda s: int(obs.loc[s.index].loc[s, "location"].nunique()),
    ),
    levels=("level", lambda s: ", ".join(sorted(v for v in s.unique() if v))),
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

# Data still needed or lacking to complete the validation of each VE variable,
# from the VE abiotic and abiotic simple model code (which layers and times the
# model reports) and the data in hand. Edit this when new data arrive.
DATA_NEEDED = {
    "absorbed_longwave_radiation": (
        "Upward and downward longwave radiation above and below the canopy "
        "(four-component radiometer); the tower measures net radiation only"
    ),
    "aerodynamic_resistance_canopy": (
        "In hand but not yet derived: wind speed and friction velocity (u.) in "
        "SAFE_EC_byYear.xlsx give r = u / u.^2 above the canopy; "
        "within-canopy values from literature"
    ),
    "air_temperature": (
        "A vertical profile through the canopy in old-growth forest at "
        "Maliau (the loggers are at 1 m only)"
    ),
    "atmospheric_co2": (
        "In hand but not yet read: co2_mole_fraction (ppm) in "
        "SAFE_EC_byYear.xlsx; a forcing check only"
    ),
    "atmospheric_pressure": (
        "None for a forcing check (flux tower barometer in hand); a barometer "
        "at Maliau's elevation would be better"
    ),
    "canopy_temperature": (
        "Leaf or canopy surface temperature (thermal camera, infrared "
        "thermometer or leaf thermocouples) in old-growth forest"
    ),
    "condensation": "None: follows from physical formulas, checked by unit tests",
    "density_air": "None: standard formula, checked by unit tests",
    "diurnal_temperature_range": (
        "In hand but not yet mapped: daily maximum and minimum from the "
        "loggers and the flux tower"
    ),
    "ground_heat_flux": (
        "Soil heat flux plates (about 5-8 cm deep) in old-growth forest; none in hand"
    ),
    "latent_heat_flux": (
        "Eddy covariance over old-growth forest (the SAFE tower is in logged "
        "forest, 70 km away); more valid months (9 pass the quality rule)"
    ),
    "latent_heat_vapourisation": "None: standard formula, checked by unit tests",
    "longwave_emission": (
        "Upward longwave radiation (radiometer) or canopy surface "
        "temperature; none in hand"
    ),
    "net_radiation": (
        "Incoming shortwave and longwave to check the ERA5-Land forcing; net "
        "radiation below the canopy and at the soil surface"
    ),
    "relative_humidity": (
        "A check of the unlabelled loggers that read above 100 %; a vertical "
        "profile, as air_temperature"
    ),
    "sensible_heat_flux": (
        "Eddy covariance over old-growth forest (the SAFE tower is in logged "
        "forest, 70 km away)"
    ),
    "soil_moisture": (
        "Continuous soil moisture in old-growth forest at Maliau (the surveys "
        "are spot visits), and at 0.25-1 m to match the VE soil layers"
    ),
    "soil_temperature": (
        "Soil temperature at 0.25-1 m to match the VE soil layers, and "
        "continuous records; old-growth spot readings at 10-12 cm are in hand "
        "(Car_Bel, Car_Ser at Maliau)"
    ),
    "specific_heat_air": "None: standard formula, checked by unit tests",
    "vapour_pressure": "A vertical profile, as air_temperature",
    "vapour_pressure_deficit": "A vertical profile, as air_temperature",
    "vapour_pressure_deficit_ref": (
        "None: flux tower values at 50 m in hand; this variable comes from the "
        "ERA5-Land forcing, so it checks the forcing"
    ),
    "vapour_pressure_ref": (
        "None: flux tower values at 50 m in hand; this variable comes from the "
        "ERA5-Land forcing, so it checks the forcing"
    ),
    "wind_speed": (
        "Wind speed at several heights within and below the canopy; only the "
        "52 m value above the canopy is in hand"
    ),
}
registry_out["data_needed"] = (
    registry_out["variable"].map(DATA_NEEDED).fillna("To be assessed")
)
for col in ["observed_period_start", "observed_period_end"]:
    registry_out[col] = (
        registry_out[col].astype(str).replace({"NaT": np.nan, "nan": np.nan})
    )
print(registry_out.groupby(["module", "status"]).size().rename("variables").to_frame())


# ============================================================
# 7. TRACKER TABLE FOR THE PLAN
# ============================================================
# Format the periods, sites and data columns of the tracker table that is
# written into Section 6 of abiotic_validation_plan.md.
def fmt_period(row) -> str:
    """Return the observed period of one registry row as text."""
    if pd.isna(row["observed_period_start"]):
        return ""
    return f"{row['observed_period_start']} to {row['observed_period_end']}"


SPATIAL_LABELS = {
    "inside_grid": "inside grid",
    "regional": "regional",
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


def data_location(src: dict) -> str:
    """Return the file of one observed source, under the dataset folder."""
    return f"`{src.get('file') or src['files']['data']}`"


# Where the data of each variable sit (observed file and literature table), the
# number of sites with their distance to the grid, and the match classes.
located = []
for var in registry_out["variable"].unique():
    rows = validation_long[validation_long["var_canonical"] == var]
    observed_rows = rows[rows["source_type"] == "observed_time_series"]
    places = [
        data_location(sources[d]) for d in sorted(observed_rows["dataset"].unique())
    ]
    lit = literature[literature["var_canonical"] == var]
    if (lit["status"] == "extracted").any():
        places.append("`abiotic_literature_values.csv`")
    elif (lit["status"] == "to_extract").any():
        places.append("`abiotic_literature_values.csv` (to extract)")
    elif len(lit):
        places.append("`abiotic_literature_values.csv` (no source yet)")
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
            "spatial_simple": "; ".join(
                SPATIAL_LABELS[k]
                for k in SPATIAL_LABELS
                if k in set(observed_rows["spatial_match_detail"])
            ),
            "temporal_simple": "; ".join(
                TEMPORAL_LABELS[k]
                for k in TEMPORAL_LABELS
                if k in set(observed_rows["temporal_match_detail"])
            ),
        }
    )
registry_out = registry_out.merge(pd.DataFrame(located), on="variable", how="left")

tracker = registry_out.assign(
    observed_period=registry_out.apply(fmt_period, axis=1),
    predicted_period=scenario["period"],
    observed_spatial_extent=registry_out.apply(
        lambda r: (
            f"{int(r['n_sites'])} {r['site_kind']}, one value each"
            if pd.notna(r["n_sites"])
            else ""
        ),
        axis=1,
    ),
    predicted_spatial_extent=f"{scenario['name']} grid cells (to be pooled or matched)",
    observed_temporal_extent=np.where(
        registry_out["n_monthly_values"].notna(),
        "Monthly values from complete days",
        "",
    ),
    predicted_temporal_extent=f"{scenario['time_step'].capitalize()} time steps",
)
tracker_cols = {
    "module": "module",
    "variable": "predicted_variable",
    "observed_variable": "observed_variable",
    "observed_period": "observed_period",
    "predicted_period": "predicted_period",
    "observed_spatial_extent": "observed_spatial_extent",
    "predicted_spatial_extent": "predicted_spatial_extent",
    "observed_temporal_extent": "observed_temporal_extent",
    "predicted_temporal_extent": "predicted_temporal_extent",
    "unit_ve": "predicted_units",
    "validation_priority": "priority",
    "literature_sources": "literature_sources",
    "data_location": "data",
    "sites_simple": "sites (distance to grid)",
    "spatial_simple": "spatial match",
    "temporal_simple": "temporal match",
    "status": "status",
    "data_needed": "data needed / lacking",
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
# markers: one row per VE variable, with the modules that write it. It points to
# where the data sit; the full detail is in the workbook's variable_registry.
plan_cols = [
    "predicted_variable",
    "modules",
    "predicted_units",
    "priority",
    "data",
    "sites (distance to grid)",
    "spatial match",
    "observed_period",
    "temporal match",
    "status",
    "data needed / lacking",
]
plan_table = (
    tracker_table.groupby("predicted_variable", sort=True)
    .agg(
        modules=("module", lambda s: ", ".join(sorted(s.unique()))),
        **{
            c: (c, "first")
            for c in plan_cols
            if c not in ("predicted_variable", "modules")
        },
    )
    .reset_index()
)
plan_tracker = f"""<!-- tracker:start -->
<!-- Generated by abiotic_validation_data.py; do not edit this block. -->

Every VE value is predicted for {scenario["period"]} on the {scenario["name"]} grid
({scenario["name"]}: 10 x 10 cells of 100 m) at {scenario["time_step"]} time steps.
Data files are under the dataset folder (`data/primary/validation/dataset/`);
the literature values are in `abiotic_literature_values.csv`. Distances are
from the sites to the edge of the grid; the match classes are explained in
[Section 5](#5-processing-to-ve-units-and-monthly-values). Citations, every
site, sensor heights and the row counts are in the `variable_registry` sheet of
the workbook. *Data needed / lacking* is what is still missing to complete
the validation of each variable (`DATA_NEEDED` in the script).

<!-- markdownlint-disable MD013 -->

Status counts (per variable): {
    ", ".join(f"{k} {v}" for k, v in plan_table["status"].value_counts().items())
}.

{
    to_markdown(
        plan_table[plan_cols].rename(
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
# 8. WRITE THE WORKBOOK AND THE PLAN'S TRACKER TABLE
# ============================================================
# Write every table to one Excel workbook (output_file), with bold headers and
# a note on each sheet, then replace only the validation tracker (Section 6,
# between the tracker markers) in the plan (plan_file).


sheet_notes = {
    "README": "This sheet",
    "variable_registry": (
        "Full tracker: priority, data, citations, sites, status and the data "
        "still needed or lacking"
    ),
    "sites": (
        "Microclimate plots, the SAFE flux tower and the primary forest soil "
        "plots with coordinates, habitat and comparable_to_maliau_2"
    ),
    "sources": "Source datasets with screening decision (abiotic_sources.toml)",
    "qc_log": "Rows changed or removed by each quality-control step",
    "microclimate_monthly": "Monthly plot values from complete days (local time)",
    "microclimate_daily": "Daily plot values (local time); complete_day = used",
    "flux_tower_monthly": (
        "SAFE flux tower monthly values per column in the original unit; "
        "n = complete days (meteorology) or valid half-hours (eddy covariance)"
    ),
    "flux_tower_daily": "SAFE flux tower daily means (meteorology, local time)",
    "soil_plots_monthly": (
        "Primary forest soil plots: monthly mean of the visit readings per plot "
        "(soil temperature and soil moisture)"
    ),
    "literature_values": "Literature values from abiotic_literature_values.csv",
    "validation_long": (
        "Monthly observations and extracted literature values in the validation "
        "database layout (times in UTC), with the observed value in VE units, "
        "where to compare on the grid, and spatial and temporal match classes"
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
            "max_fill_gap_hours",
            "min_hours_per_day, min_days_per_month",
            "flux_qc_max, min_values_per_hour_slot",
            "created",
        ],
        "contents": [
            "",
            f"{scenario['name']} ({scenario['period']}, {scenario['time_step']})",
            max_fill_gap_hours_microclimate,
            f"{min_hours_per_day}, {min_days_per_month}",
            f"{flux_qc_max}, {min_values_per_hour_slot}",
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
    "comparable_to_maliau_2",
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
sites = pd.concat([mc_sites, tower_sites, soil_sites], ignore_index=True).reindex(
    columns=[c for c in site_cols if c not in ("catchment_area_km2", "notes")]
)

sheets = {
    "README": pd.concat([readme, readme_meta], ignore_index=True),
    "variable_registry": registry_out,
    "sites": sites,
    "sources": sources_table,
    "qc_log": pd.DataFrame(qc_log),
    "microclimate_monthly": mc_monthly.assign(month=mc_monthly["month"].astype(str)),
    "microclimate_daily": mc_daily,
    "flux_tower_monthly": tower_monthly.assign(
        month=tower_monthly["month"].astype(str)
    ),
    "flux_tower_daily": tower_daily,
    "soil_plots_monthly": soil_monthly.assign(month=soil_monthly["month"].astype(str)),
    "literature_values": literature,
    "validation_long": validation_long,
}

out_path = repo_path(output_file)
out_path.parent.mkdir(parents=True, exist_ok=True)
with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    for name, table in sheets.items():
        table = table.apply(lambda s: s.round(4) if s.dtype.kind == "f" else s)
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
# * Choose the VE layer to compare with the loggers (1 m above ground,
#   Zenodo record 12751374).
# * Extract the numbers for the `to_extract` rows in
#   `abiotic_literature_values.csv` and find sources for the `to_find` rows.
# * Agree the eddy covariance quality flag threshold (`flux_qc_max`).
# * Join VE outputs to `validation_long` (see `docs/abiotic_validation_plan.md`).
