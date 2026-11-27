---
jupyter:
  jupytext:
    cell_metadata_filter: all,-trusted,-execution
    formats: ipynb,md
    notebook_metadata_filter: settings,mystnb,language_info,ve_data_science,-jupytext.text_representation.jupytext_version
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
  kernelspec:
    display_name: ve-data-science (3.14.3)
    language: python
    name: python3
  language_info:
    codemirror_mode:
      name: ipython
      version: 3
    file_extension: .py
    mimetype: text/x-python
    name: python
    nbconvert_exporter: python
    pygments_lexer: ipython3
    version: 3.14.3
---

# Morris screening of VE hydrology: main results

This notebook reports the results of one Morris screening run of the Virtual
Ecosystem (VE) hydrology module. It reads only the files written by
`analysis/abiotic/sensitivity/morris_analyse_hydrology.py`; it does not rerun the
model or recompute any index. The run, its design and its environment are listed in
*Report metadata and environment* below.

The notebook answers, in order:

1. Can the results be trusted? (design, runs and model health)
2. What did the runs produce? (output variables across runs, in time and in space)
3. Which parameters drive discharge at the site outlet? (primary responses)
4. How stable is that ranking?
5. Where and when do the parameters matter? (maps and months)
6. Which parameters drive the other hydrological processes? (secondary responses)
7. Which parameters go forward to the Sobol analysis?
8. What do the outputs and the Morris results reveal about the VE hydrology
   module?

Morris separates influential from non-influential parameters. It does not measure
shares of variance or interactions; that is the job of the Sobol stage.

The interpretation text is generated from the tables with fixed rules (for
example "strongly skewed" when the 95th percentile is more than five times the
median). The rules flag what to look at; the wording should still be checked by
hand before the results are reported.

<!-- #region tags=["remove-cell"] -->
## How to use this notebook for a new run

1. Sample and run the ensemble with `morris_sample.py`, then run the analysis for
   the new `run_name` in the same uv environment as the model runs, for example:

   ```text
   uv run --group dev-pinned python \
       analysis/abiotic/sensitivity/morris_analyse_hydrology.py \
       --run-name <run_name> --workers 8
   ```

2. Edit **only the Run settings cell below**: the run name, the data folder,
   the base configuration and site input data, the analyst, the uv group and VE
   version and commit the runs used, and the site.
3. Save the notebook and run all cells.

Everything else is read from the run's own outputs: the design, the base
configuration, the grid, the soil layers, the responses, the sinks and all the
numbers in the interpretation text. The other code cells are collapsed here. The
rendered copy starts with the report itself: this section, the settings and the
setup are run but left out of it, so nothing below the settings cell needs editing.
<!-- #endregion -->

```python tags=["parameters", "remove-cell"]
# =============================================================================
# RUN SETTINGS: the only cell to edit for a new run
# =============================================================================

# Morris run to report: the folder <data_directory>/analysis/<run_name>/ written
# by morris_analyse_hydrology.py. The rendered copy goes to ./<run_name>/.
run_name = "hydrology_morris_001"

# Module data folder (holds config/, data/ and analysis/): relative to the
# repository root, or an absolute path when the results live outside this
# repository, e.g. r"C:\path\to\ve_data_science\data\sensitivity\hydrology".
data_directory = "data/sensitivity/hydrology"

# Base configuration to report against, relative to data_directory. This is the
# current static_hydro_configuration.toml (grid origin xoff = 496400,
# yoff = 524100, matching maliau_2). Its [[core.data.variable]] file paths are
# resolved relative to the configuration folder.
base_config_file = "config/static_hydro_configuration.toml"

# Site input data (elevation, climate, soil), relative to data_directory. Used
# when a file named in the base configuration is not found at its own path.
site_data_directory = "data"

# Report author, shown in the report metadata.
analyst = "Lelavathy"

# VE the ensemble and the analysis were run with, recorded by hand: the uv
# dependency group, and the VE version and commit that group pinned for the runs
# (the dev-pinned commit). Update them when the runs use another environment.
uv_group = "dev-pinned"
run_ve_version = "0.2.1"
run_ve_commit = "22689f01a2460953865244f2d79f162a32ff2003"

# Site the base configuration should represent (from the site definition file).
# Used to check that the model grid sits where the site is.
site = {
    "name": "maliau_2",
    "epsg_code": 32650,
    "ll_x": 496400,
    "ll_y": 524100,
    "ur_x": 497400,
    "ur_y": 525100,
}

# Primary response variable (the analysis folder primary/<primary_variable>/).
primary_variable = "river_discharge_rate"

# Soil hydraulic parameters: checked in Section 8.3 for looking inert.
soil_hydraulic_parameters = [
    "saturated_hydraulic_conductivity",
    "van_genuchten_nonlinearily_parameter",
    "pore_connectivity_parameter",
    "air_entry_potential_inverse",
]

# Report options (usually left as they are).
top_n = 5  # parameters shown per response in the tables
health_tolerance = 5.0  # |water balance closure| allowed, % of rainfall
vertical_flow_min = 1e-3  # mm; below this soil vertical flow is "near zero"
render_output = True  # False: run the notebook without writing ./<run_name>/
```

```python tags=["remove-cell"] jupyter={"source_hidden": true}
# Setup: paths, tables and display helpers. No edits needed.
import calendar
import json
import re
import sys
import tomllib
from importlib import metadata
from io import BytesIO
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
from IPython.display import Image, Markdown, display
from PIL import Image as PILImage

max_figure_bytes = 450_000  # keep rendered PNGs under the 500 kB pre-commit limit


def find_repository_root(start: Path) -> Path:
    """Walk up from the notebook folder to the folder holding pyproject.toml."""
    for folder in [start, *start.parents]:
        if (folder / "pyproject.toml").exists():
            return folder
    raise FileNotFoundError("pyproject.toml not found above the notebook folder")


repo_root = find_repository_root(Path.cwd().resolve())
module_root = repo_root / data_directory
analysis_root = module_root / "analysis" / run_name
tables_dir = analysis_root / "tables"
figures_dir = analysis_root / "figures"
primary_field = analysis_root / "primary" / primary_variable

if not (tables_dir / "morris_scalar_indices.csv").exists():
    raise FileNotFoundError(
        f"No Morris results in {analysis_root}. Check run_name and data_directory, "
        "or run morris_analyse_hydrology.py for this run first."
    )

design_summary = pd.read_csv(tables_dir / "design_summary.csv")
parameter_ranges = pd.read_csv(tables_dir / "parameter_ranges.csv")
scalar = pd.read_csv(tables_dir / "morris_scalar_indices.csv")
decision = pd.read_csv(tables_dir / "morris_screening_decision.csv")
stability = pd.read_csv(tables_dir / "morris_ranking_stability.csv")
health = pd.read_csv(tables_dir / "model_health_by_run.csv")
run_check = pd.read_csv(tables_dir / "run_parameter_check.csv")

# Output-variable summaries (what the runs produced, before any index)
output_by_run = pd.read_csv(tables_dir / "output_responses_by_run.csv")
output_summary = pd.read_csv(tables_dir / "output_summary_by_response.csv")
output_temporal = pd.read_csv(tables_dir / "output_temporal_summary.csv")
output_spatial = pd.read_csv(tables_dir / "output_spatial_summary.csv")
drainage = pd.read_csv(analysis_root / "data" / "drainage_network.csv")
with np.load(analysis_root / "data" / "responses.npz") as cached:
    responses = {key: cached[key] for key in cached.files}
with (analysis_root / "data" / "response_spec.json").open() as file:
    response_spec = json.load(file)

# The analysis script labels the two routed secondary responses "*_outlet".
# Report them under their VE variable names (summed over the sinks).
response_names = {
    "surface_runoff_outlet": "surface_runoff_routed_plus_local",
    "subsurface_runoff_outlet": "subsurface_runoff_routed_plus_local",
}
for table in (scalar, stability, output_summary):
    table["response"] = table["response"].replace(response_names)
output_by_run = output_by_run.rename(columns=response_names)

# Run facts used throughout the text
design = dict(zip(design_summary["item"], design_summary["value"].astype(str)))
n_runs = len(health)
fields = [str(name) for name in responses["fields"]]
series = responses["series"]  # (runs, fields, months) after spin-up
months = pd.to_datetime([str(d) for d in responses["dates"]], format="%Y-%m")
period = f"{months[0]:%b %Y}-{months[-1]:%b %Y}"
n_cells = int(np.prod(response_spec["grid_shape"]))
n_sinks = len(responses["outlet_xy"])
primary_responses = list(scalar.loc[scalar["group"] == "primary", "response"].unique())
secondary_responses = list(
    scalar.loc[scalar["group"] == "secondary", "response"].unique()
)
design_text = design.get("design settings (read from the job file)", "")
match = re.search(r"trajectories\s*=\s*(\d+)", design_text)
n_trajectories = int(match.group(1)) if match else None

# Base configuration: the current file at <data_directory>/<base_config_file>.
# The design record names the file the runs started from. If that file has been
# edited since the runs (for example the grid origin), Sections 2.5 and 8.7 show
# it by comparing the configuration grid with the grid in the run's output.
recorded_base_config = design.get("base configuration", "not recorded")
base_config_path = module_root / base_config_file
base_config = {}
if base_config_path.exists():
    with base_config_path.open("rb") as file:
        base_config = tomllib.load(file)
core = base_config.get("core", {})
grid = core.get("grid", {})
cell_area = float(grid.get("cell_area", 10_000.0))
resolution = cell_area**0.5
soil_depths = [
    -float(d) for d in core.get("layers", {}).get("soil_layers", [-0.25, -1.0])
]
topsoil_mm = soil_depths[0] * 1000
subsoil_mm = (soil_depths[-1] - soil_depths[0]) * 1000

# Cell centres of the current base configuration grid
config_nx, config_ny = int(grid.get("cell_nx", 0)), int(grid.get("cell_ny", 0))
config_xoff = float(grid.get("xoff", np.nan))
config_yoff = float(grid.get("yoff", np.nan))
config_x = config_xoff + resolution * (np.arange(config_nx) + 0.5)
config_y = config_yoff + resolution * (np.arange(config_ny) + 0.5)

# Site input files named in the base configuration ([[core.data.variable]])
site_data_root = module_root / site_data_directory


def input_file(file_path: str) -> Path:
    """Resolve a configuration data path: as written, else in site_data_root."""
    path = Path(file_path)
    if not path.is_absolute():
        path = (base_config_path.parent / path).resolve()
    if not path.exists():
        path = site_data_root / Path(file_path).name
    return path


input_files: dict[Path, list[str]] = {}
for variable in core.get("data", {}).get("variable", []):
    input_files.setdefault(input_file(variable["file_path"]), []).append(
        variable["var_name"]
    )
elevation_file = next(
    (path for path, variables in input_files.items() if "elevation" in variables),
    site_data_root / "elevation_maliau_10x10.nc",
)


# ---- display helpers -------------------------------------------------------
def shown(path: Path) -> str:
    """Path relative to the repository root when inside it, else absolute."""
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def show_table(frame: pd.DataFrame, index: bool = False) -> None:
    """Display a table as Markdown, so the rendered notebook shows a clean table."""
    if index:
        frame = frame.reset_index()

    def cell(value) -> str:
        if isinstance(value, float):
            return f"{value:.3g}"
        return str(value)

    lines = [
        "| " + " | ".join(str(c) for c in frame.columns) + " |",
        "|" + "---|" * len(frame.columns),
    ]
    lines += [
        "| " + " | ".join(cell(v) for v in row) + " |"
        for row in frame.itertuples(index=False)
    ]
    display(Markdown("\n".join(lines)))


def show_figure(path: Path) -> None:
    """Display a pre-rendered figure, or note plainly when it isn't available.

    Figures larger than max_figure_bytes are reduced to a 256-colour PNG so the
    rendered copy passes the check-added-large-files hook.
    """
    if not path.exists():
        display(Markdown(f"*(figure not found: `{shown(path)}`)*"))
        return
    data = path.read_bytes()
    if len(data) > max_figure_bytes:
        with PILImage.open(path) as image:
            buffer = BytesIO()
            image.convert("RGB").quantize(colors=256).save(
                buffer, format="PNG", optimize=True
            )
            data = buffer.getvalue()
    display(Image(data=data, format="png"))


def say(*paragraphs: str) -> None:
    """Display generated interpretation text (empty items are skipped)."""
    display(Markdown("\n\n".join(p for p in paragraphs if p)))


def bullets(items: list[str], title: str = "**Interpretation.**") -> None:
    """Display generated interpretation bullets under a bold title."""
    items = [item for item in items if item]
    if items:
        say(title, "\n".join(f"- {item}" for item in items))


def num(value: float, digits: int = 2) -> str:
    """Readable number: thousands separators for large values, else sig. figs."""
    if value is None or not np.isfinite(value):
        return "n/a"
    if abs(value) >= 1000:
        return f"{value:,.0f}"
    if abs(value) >= 1:
        return f"{float(f'{value:.{digits}g}'):g}"
    return f"{value:.{digits}g}"


def ordinal(n: int) -> str:
    """1st, 2nd, 3rd, 4th ..."""
    suffix = (
        "th" if 10 <= n % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    )
    return f"{n}{suffix}"


def plural(n: int, word: str) -> str:
    """'1 sink', '4 sinks'."""
    return f"{n} {word}{'' if n == 1 else 's'}"


def pct(value: float) -> str:
    """Share as a whole percentage."""
    return f"{100 * value:.0f}%"


def of_runs(count: int) -> str:
    """'k of n runs' for the current run."""
    return f"{int(count)} of {n_runs} runs"


def names(items) -> str:
    """Comma list of code-formatted names."""
    items = [f"`{item}`" for item in items]
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


def summary_row(response: str) -> pd.Series:
    """Row of output_summary_by_response for one response."""
    return output_summary.set_index("response").loc[response]


def temporal_row(field: str) -> pd.Series:
    """Row of output_temporal_summary for one field."""
    return output_temporal.set_index("field").loc[field]


print(f"Results: {shown(analysis_root)}")
print(
    f"{n_runs} runs, {len(parameter_ranges)} parameters, "
    f"{len(primary_responses)} primary and {len(secondary_responses)} secondary "
    f"responses, analysis period {period}"
)
```


<!-- #region  -->
## Report metadata and environment

The report, the Morris run and its uv environment in one place. The run facts come
from the run's design record and analysis files. The VE version and commit of the
runs are recorded in the notebook's run settings and compared with the packages
installed in the kernel that rendered this report.
The site is set in the notebook's run settings; the grid, soil layers and modules
come from the current base configuration, whose input files are checked against
its grid.
<!-- #endregion -->


```python tags=["remove-input"] jupyter={"source_hidden": true}
def installed(package: str) -> tuple[str, str]:
    """Version of an installed package, and its git commit when recorded."""
    try:
        distribution = metadata.distribution(package)
    except metadata.PackageNotFoundError:
        return "not installed in this kernel", ""
    direct_url = json.loads(distribution.read_text("direct_url.json") or "{}")
    return distribution.version, direct_url.get("vcs_info", {}).get("commit_id", "")


def same_commit(a: str, b: str) -> bool:
    """Return True when two commit hashes agree on their common prefix."""
    n = min(len(a), len(b))
    return n >= 7 and a[:n].lower() == b[:n].lower()


# ---- report and run ----------------------------------------------------------
job_file = repo_root / design.get("job file (the design)", "")
if not job_file.is_file():
    job_file = module_root / "config" / Path(job_file).name
created = "not recorded"
if job_file.is_file():
    with job_file.open(encoding="utf-8") as file:
        for line in file:
            if line.startswith("# created:"):
                created = line.split(":", 1)[1].strip()
                break
            if not line.startswith("#"):
                break
modules = {
    name: section["static"]
    for name, section in base_config.items()
    if isinstance(section, dict) and "static" in section
}
display(Markdown("**Report and run**"))
show_table(
    pd.DataFrame(
        {
            "item": [
                "analyst",
                "date of report",
                "Morris run",
                "design created",
                "analysis results",
                "design (job file)",
                "parameter file",
                "base configuration of the runs (design record)",
                "base configuration read by this report",
                "design",
                "responses",
                "analysis period",
                "dynamic modules",
                "static modules",
                "grid and soil layers",
                "notebook",
            ],
            "value": [
                analyst,
                pd.Timestamp.today().strftime("%Y-%m-%d"),
                f"`{run_name}`",
                f"{created} (from the job file)",
                f"`{shown(analysis_root)}`",
                f"`{design.get('job file (the design)', 'not recorded')}`",
                f"`{design.get('parameter file', 'not recorded')}`",
                f"`{recorded_base_config}`",
                f"`{shown(base_config_path)}`"
                + ("" if base_config else " (**not found**)"),
                f"{n_runs} runs, {len(parameter_ranges)} parameters, "
                f"{design_text or 'settings not recorded'}, "
                f"seed {design.get('seed', '?')}",
                f"{len(primary_responses)} primary (`{primary_variable}`), "
                f"{len(secondary_responses)} secondary",
                f"{period}, after a {response_spec['spinup_months']}-month spin-up",
                ", ".join(f"`{m}`" for m, st in modules.items() if st is False)
                or "none",
                ", ".join(f"`{m}`" for m, st in modules.items() if st is True)
                or "none",
                f"{grid.get('cell_nx', '?')} x {grid.get('cell_ny', '?')} cells of "
                f"{resolution:.0f} m; soil layers {topsoil_mm:.0f} mm (topsoil) and "
                f"{subsoil_mm:.0f} mm (subsoil)",
                "`notebook/hydrology/morris_sensitivity/morris_hydrology_results.md`",
            ],
        }
    )
)
say(
    "Only modules with `static = false` are updated through time; static modules "
    "keep a fixed state, so the sensitivity reflects the dynamic module(s) alone."
)

# ---- environment -------------------------------------------------------------
kernel_version, kernel_commit = installed("virtual_ecosystem")
salib_version, _ = installed("SALib")

display(Markdown("**Environment**"))
show_table(
    pd.DataFrame(
        {
            "item": [
                "uv dependency group",
                "install",
                f"Virtual Ecosystem used by the runs (`{uv_group}`)",
                "Virtual Ecosystem in this kernel",
                "SALib used for sampling / in this kernel",
                "Python in this kernel",
            ],
            "value": [
                f"`{uv_group}`",
                f"`uv sync --group {uv_group}`",
                f"`{run_ve_version}`"
                + (f", commit `{run_ve_commit}`" if run_ve_commit else ""),
                f"`{kernel_version}`"
                + (f", commit `{kernel_commit[:12]}`" if kernel_commit else ""),
                f"`{design.get('SALib version used for sampling', 'not recorded')}` / "
                f"`{salib_version}`",
                f"`{sys.version.split()[0]}`",
            ],
        }
    )
)

notes = []
if not run_ve_commit:
    notes.append(
        "**Note:** no VE commit is recorded for the runs; set `run_ve_commit` in the "
        "run settings."
    )
if kernel_commit and run_ve_commit and not same_commit(kernel_commit, run_ve_commit):
    notes.append(
        f"**Note:** this kernel has VE commit `{kernel_commit[:12]}`, not the "
        f"`{run_ve_commit[:12]}` of the runs."
    )
say(*notes)

# ---- site, grid and input data -----------------------------------------------
say(
    f"**Data used: `{site['name']}` site**",
    "```toml\n"
    f"[Scenario.{site['name']}]\n"
    f"epsg_code = {site['epsg_code']}\n"
    f"ll_x = {site['ll_x']}\nll_y = {site['ll_y']}\n"
    f"ur_x = {site['ur_x']}\nur_y = {site['ur_y']}\n"
    "```",
)

if base_config:
    say(
        f"**Grid:** {grid.get('cell_nx', '?')} x {grid.get('cell_ny', '?')} cells of "
        f"{resolution:.0f} m, origin `xoff = {grid.get('xoff', '?')}`, "
        f"`yoff = {grid.get('yoff', '?')}` "
        + (
            f"(matches the `{site['name']}` lower-left corner)."
            if (grid.get("xoff"), grid.get("yoff")) == (site["ll_x"], site["ll_y"])
            else f"(**does not match** `ll_x = {site['ll_x']}`, "
            f"`ll_y = {site['ll_y']}`; see Section 2.5)."
        )
    )

    def grid_extent(path: Path) -> tuple[str, str, str]:
        """x and y centre ranges of a gridded input file, and whether they match."""
        if not path.exists() or path.suffix != ".nc":
            return "-", "-", "not checked"
        with xr.open_dataset(path) as data:
            if "x" not in data.coords or "y" not in data.coords:
                return "-", "-", "no x/y coordinates"
            x, y = np.sort(data["x"].values), np.sort(data["y"].values)
        match = (
            len(x) == config_nx
            and len(y) == config_ny
            and np.allclose(x, config_x)
            and np.allclose(y, config_y)
        )
        return (
            f"{x.min():.1f}-{x.max():.1f}",
            f"{y.min():.1f}-{y.max():.1f}",
            "yes" if match else "**no**",
        )

    say(
        f"**Site input data** (from `{shown(site_data_root)}` when a configured path "
        "is not found). A gridded file matches when its cell centres equal the "
        f"configuration grid: x {config_x.min():.1f}-{config_x.max():.1f}, "
        f"y {config_y.min():.1f}-{config_y.max():.1f}."
    )
    input_rows = []
    for path, variables in input_files.items():
        x_range, y_range, match = grid_extent(path)
        input_rows.append(
            {
                "file": f"`{path.name}`",
                "found": "yes" if path.exists() else "**no**",
                "variables": len(variables),
                "x centres": x_range,
                "y centres": y_range,
                "matches configuration grid": match,
            }
        )
    show_table(pd.DataFrame(input_rows))
else:
    say(f"*(base configuration not found: `{base_config_path}`)*")
```

## Responses, outlets and primary vs secondary

### How the outlets are defined

VE hydrology has no river channel and no outflow across the grid boundary. Water
is routed between cells by VE's drainage rule
(`hydrology.above_ground.calculate_drainage_map`):

- Each cell drains to the neighbour with the largest elevation drop, among its
  four edge neighbours and itself.
- A cell lower than all of its neighbours drains to itself. It is a **sink**:
  everything routed into it stays there. The sinks are therefore the only places
  where water leaves the site, and they are the **outlets** used here.
- Routing is instantaneous within the monthly step. For each cell,
  `surface_runoff_routed_plus_local` and `subsurface_runoff_routed_plus_local`
  are that month's local runoff summed over the cell and every cell upstream of
  it. Local subsurface runoff is `subsurface_flow + baseflow +
  subsurface_stormflow`.
- `river_discharge_rate` is the routed surface plus subsurface runoff, converted
  to m³ s⁻¹.

The analysis script does not re-derive the network from elevation. It recovers
the network VE actually used from the first run's output: routed runoff equals
an upstream matrix times local runoff, and non-negative least squares returns
that matrix exactly (`outlet = {"method": "ve_routing"}`, written to
`data/drainage_network.csv`). Elevation is not sampled, so all runs share this
network.

```python tags=["remove-input"] jupyter={"source_hidden": true}
sink_sizes = (
    drainage.loc[drainage["is_sink"], "n_cells_draining_through"]
    .astype(int)
    .sort_values(ascending=False)
    .tolist()
)
combine = response_spec.get("outlet", {}).get("combine", "sum")
say(
    f"The grid has **{plural(len(sink_sizes), 'sink')}**, draining "
    f"{', '.join(map(str, sink_sizes))} of the {n_cells} cells. With "
    f'`combine = "{combine}"`, each outlet series is '
    + (
        f"the **sum over the {len(sink_sizes)} sinks**: the total outflow of the "
        f'site. (`"largest"` would keep only the {sink_sizes[0]}-cell catchment.)'
        if combine == "sum"
        else f"taken from the {combine} sink only."
    ),
    f"Each response is one statistic of that monthly series after the "
    f"{response_spec['spinup_months']}-month spin-up:",
)

statistic_label = {"mean": "mean", "q90": "90th percentile", "q10": "10th percentile"}
show_table(
    pd.DataFrame(
        [
            {
                "response": response_names.get(r["name"], r["name"]),
                "group": r["group"],
                "VE variable": r["variable"],
                "monthly series": (
                    "sum over the sinks"
                    if response_spec["fields"][r["variable"]] == "outlet"
                    else "domain mean"
                ),
                "statistic": statistic_label.get(r["statistic"], r["statistic"])
                + (
                    " of " + ", ".join(calendar.month_abbr[m] for m in r["months"])
                    if "months" in r
                    else ""
                ),
            }
            for r in response_spec["responses"]
        ]
    )
)
```


<!-- #region  -->
### Why discharge is primary and the rest secondary

- **`river_discharge_rate` is the primary response.** It is the single
  catchment-scale outcome of the module: it combines surface and subsurface
  pathways and the effect of every store on what leaves the site, and it is the
  variable that can be compared with stream gauge data. Its statistics (table
  above) cover the flow regime: mean flow, high flow (q90), low flow (q10) and
  a dry-season window.
- **The other responses are secondary.** They are the parts discharge is made
  of (routed surface and subsurface runoff at the outlets) and the local fluxes
  and stores behind them. They show *which process* a parameter acts through,
  and they reveal implausible behaviour that discharge alone would hide
  (Section 8).
- **Only the routed fields are summed over the sinks.** They accumulate water
  from upstream, so their sink values add up to the site total. Local fluxes and
  stores hold only their own cell's water, so their domain mean is the
  meaningful site value.
- **Primary vs secondary sets the Sobol screening rule, not scientific
  importance.** A parameter goes forward if it is influential for at least one
  primary response, or for at least two secondary responses (Section 7).

### Checks on the outlet definition

Three checks on the cached monthly series and long-term maps:

1. **Does the outlet capture all the site's runoff?** Routed runoff summed over
   the sinks, divided by local runoff summed over all cells. The expected value
   is (cells + sinks) / cells, not 1: VE lists a sink in its own upstream set,
   so each sink counts its own local runoff twice.
2. **How is discharge shared between the sinks?** Each sink's share of the
   long-term mean discharge, compared with its catchment size.
3. **Which pathway carries the discharge?** The subsurface share of routed
   outlet runoff across runs, and its rank correlation with `discharge_mean`.
<!-- #endregion -->


```python tags=["remove-input"] jupyter={"source_hidden": true}
def field_series(name: str) -> np.ndarray:
    """Monthly series (runs, months): sink sum or domain mean, per the spec."""
    return series[:, fields.index(name)]


local_surface = n_cells * field_series("surface_runoff")
local_subsurface = n_cells * (
    field_series("subsurface_flow")
    + field_series("baseflow")
    + field_series("subsurface_stormflow")
)
with np.errstate(divide="ignore", invalid="ignore"):
    closure = {
        "surface": field_series("surface_runoff_routed_plus_local") / local_surface,
        "subsurface": field_series("subsurface_runoff_routed_plus_local")
        / np.where(local_subsurface > 0, local_subsurface, np.nan),
    }
expected_closure = (n_cells + n_sinks) / n_cells
display(Markdown("**1. Routed runoff at the sinks / local runoff over all cells**"))
show_table(
    pd.DataFrame(
        {
            "pathway": list(closure),
            "p05": [np.nanpercentile(v, 5) for v in closure.values()],
            "median": [np.nanpercentile(v, 50) for v in closure.values()],
            "p95": [np.nanpercentile(v, 95) for v in closure.values()],
            "expected": [expected_closure] * 2,
        }
    )
)

x_grid, y_grid = responses["x"], responses["y"]
discharge_maps = responses["maps"][:, fields.index(primary_variable)]
sink_cells = [
    (int(np.argmin(np.abs(y_grid - y))), int(np.argmin(np.abs(x_grid - x))))
    for x, y in responses["outlet_xy"]
]
sink_discharge = np.stack([discharge_maps[:, r, c] for r, c in sink_cells], axis=1)
sink_share = sink_discharge / sink_discharge.sum(axis=1, keepdims=True)
catchment = [
    int(
        drainage.loc[
            np.isclose(drainage["x"], x) & np.isclose(drainage["y"], y),
            "n_cells_draining_through",
        ].iloc[0]
    )
    for x, y in responses["outlet_xy"]
]
uniform_share = np.array([(n + 1) / (n_cells + len(catchment)) for n in catchment])
median_share = np.median(sink_share, 0)
share_range = np.percentile(sink_share, [5, 95], axis=0).T
display(Markdown("**2. Share of site discharge by sink**"))
show_table(
    pd.DataFrame(
        {
            "sink (x, y)": [f"{x:.1f}, {y:.1f}" for x, y in responses["outlet_xy"]],
            "cells draining through": catchment,
            "share if runoff is uniform": [f"{v:.3f}" for v in uniform_share],
            "median share over runs": [f"{v:.3f}" for v in median_share],
            "5-95% over runs": [f"{lo:.3f}-{hi:.3f}" for lo, hi in share_range],
        }
    )
)

routed_surface = output_by_run["surface_runoff_routed_plus_local"]
routed_subsurface = output_by_run["subsurface_runoff_routed_plus_local"]
subsurface_share = routed_subsurface / (routed_surface + routed_subsurface)
discharge = output_by_run["discharge_mean"]
rho_subsurface = discharge.corr(routed_subsurface, method="spearman")
rho_surface = discharge.corr(routed_surface, method="spearman")
display(Markdown("**3. Which pathway carries the discharge**"))
show_table(
    pd.DataFrame(
        {
            "check": [
                "subsurface share of routed outlet runoff (p05 / median / p95)",
                "runs where the subsurface carries more than half",
                "Spearman: discharge_mean vs subsurface_runoff_routed_plus_local",
                "Spearman: discharge_mean vs surface_runoff_routed_plus_local",
            ],
            "result": [
                " / ".join(
                    f"{v:.3f}" for v in subsurface_share.quantile([0.05, 0.5, 0.95])
                ),
                f"{(subsurface_share > 0.5).sum()} of {len(subsurface_share)}",
                f"{rho_subsurface:.2f}",
                f"{rho_surface:.2f}",
            ],
        }
    )
)

# ---- generated interpretation ----
closure_medians = {k: np.nanmedian(v) for k, v in closure.items()}
closure_ok = all(
    abs(v - expected_closure) < 0.02 * expected_closure
    for v in closure_medians.values()
)
share_fixed = (
    np.max(np.abs(median_share - uniform_share)) < 0.05
    and np.max(share_range[:, 1] - share_range[:, 0]) < 0.1
)
largest = int(np.argmax(catchment))
driver = "subsurface" if abs(rho_subsurface) > abs(rho_surface) else "surface"
bullets(
    [
        (
            f"**The outlet definition is complete.** Routed runoff at the "
            f"{n_sinks} sinks is about {num(closure_medians['surface'], 3)} "
            f"(surface) and {num(closure_medians['subsurface'], 3)} (subsurface) "
            f"times the local runoff of all {n_cells} cells, against "
            f"{expected_closure:.2f} expected from the sinks' double-counted own "
            "runoff. No water leaves the grid anywhere else, so the sink sum is the "
            f"whole site outflow. The double count adds about "
            f"{pct(expected_closure - 1)} to every outlet value in every run, so it "
            "does not change the Morris rankings."
            if closure_ok
            else f"**The outlet does not capture all the runoff as expected.** "
            f"Routed/local runoff is {num(closure_medians['surface'], 3)} (surface) "
            f"and {num(closure_medians['subsurface'], 3)} (subsurface) against "
            f"{expected_closure:.2f} expected. Check the drainage network and "
            "whether water leaves the grid elsewhere before using outlet responses."
        ),
        (
            f"**Each sink's share of discharge is fixed by its catchment size.** "
            f"The sinks carry {', '.join(pct(v) for v in median_share)} of site "
            "discharge, close to what catchment size alone predicts, and this "
            "hardly changes between runs. The parameters change how much water "
            "leaves the site, not which sink it leaves through, so summing the "
            "sinks loses no sensitivity information; using only the largest "
            f"catchment would scale every outlet value by about "
            f"{median_share[largest]:.2f}."
            if share_fixed
            else "**The sinks' shares of discharge differ from catchment size or "
            "vary between runs** (table 2). The parameters then also change where "
            "water leaves the site, and the choice of sink sum vs largest "
            "catchment matters for the outlet responses."
        ),
        f"**The {driver} pathway sets the discharge.** The subsurface share of "
        f"outlet runoff has a median of {pct(subsurface_share.median())} and is "
        f"more than half in {of_runs((subsurface_share > 0.5).sum())}. "
        f"`discharge_mean` has a Spearman correlation of {rho_subsurface:.2f} with "
        f"subsurface outlet runoff and {rho_surface:.2f} with surface outlet "
        "runoff. Parameters acting on that pathway are expected to dominate the "
        "primary responses (Sections 3 and 8.2).",
    ]
)
```

## 1. Can the results be trusted?

### Design and runs

The design record for this run, as written by the analysis script, the sampled
range of each parameter and the per-run design cross-check
(`run_parameter_check.csv`):

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_table(design_summary.rename(columns={"item": "setting"}))
show_table(parameter_ranges[["parameter", "lower", "upper", "scale"]])

check_counts = run_check["status"].value_counts()
show_table(check_counts.rename_axis("status").reset_index(name="n_runs"))
if set(check_counts.index) == {"not checked (no record)"}:
    say(
        "No `compiled_configuration.toml` records were retained for this run, "
        "so per-run design fidelity could not be cross-checked from the run "
        "outputs alone. This is a gap in provenance, not evidence of a problem."
    )
```

### Model health

Indices describe the model as it behaves. If the model does not conserve water, the
indices describe that behaviour rather than catchment hydrology. The table
summarises the health diagnostics over all runs; the thresholds are set in the
notebook's run settings (`health_tolerance`, `vertical_flow_min`).

```python tags=["remove-input"] jupyter={"source_hidden": true}
closure_failed = health["closure_percent_of_P"].abs() > health_tolerance
vertical_ok = health["mean_soil_vertical_flow_mm"].abs() >= vertical_flow_min
lower_negative = health["min_lower_groundwater_mm"] < 0
closure_median = health["closure_percent_of_P"].median()
runoff_ratio = health["runoff_over_precipitation"]
surface_share_P = health["surface_runoff_share_of_P"]
show_table(
    pd.DataFrame(
        {
            "check": [
                f"water balance closes within +/-{health_tolerance:g}% of rainfall",
                "lower groundwater store stays >= 0",
                f"mean soil vertical flow >= {vertical_flow_min:g} mm",
                "mean soil vertical flow, mm (median over runs)",
                "total runoff / rainfall (median over runs)",
                "surface runoff / rainfall (median over runs)",
                "water balance closure, % of rainfall (min / median / max)",
            ],
            "result": [
                of_runs((~closure_failed).sum()),
                of_runs((~lower_negative).sum()),
                of_runs(vertical_ok.sum()),
                f"{health['mean_soil_vertical_flow_mm'].median():.1e}",
                f"{runoff_ratio.median():.2f}",
                f"{surface_share_P.median():.2f}",
                f"{health['closure_percent_of_P'].min():.1f} / "
                f"{closure_median:.1f} / "
                f"{health['closure_percent_of_P'].max():.1f}",
            ],
        }
    )
)

# ---- generated interpretation ----
healthy = not closure_failed.any() and not lower_negative.any() and vertical_ok.all()
if healthy:
    say(
        "**Interpretation.** All runs close the water balance within the tolerance, "
        "the lower groundwater store never goes negative and soil water moves "
        "vertically. The rankings below can be read as sensitivities of the "
        "hydrology as modelled for the site."
    )
else:
    direction = (
        "more water leaves the site as runoff, evaporation and storage change than "
        "falls as rain"
        if closure_median < -health_tolerance
        else "less water leaves the site than falls as rain"
        if closure_median > health_tolerance
        else "the median run closes, but individual runs do not"
    )
    say(
        "**Interpretation.** "
        + (
            f"The model does not conserve water in this run. Only "
            f"{of_runs((~closure_failed).sum())} close the water balance, and the "
            f"median closure of about {closure_median:.0f}% of rainfall means that "
            f"{direction}. Total runoff is about {runoff_ratio.median():.1f} times "
            f"rainfall in the median run, and surface runoff alone is "
            f"{pct(surface_share_P.median())} of rainfall. "
            if closure_failed.any()
            else "The water balance closes in every run. "
        )
        + (
            f"The lower groundwater store goes negative in "
            f"{of_runs(lower_negative.sum())}. "
            if lower_negative.any()
            else ""
        )
        + (
            f"Soil vertical flow is below {vertical_flow_min:g} mm in "
            f"{of_runs((~vertical_ok).sum())}. "
            if (~vertical_ok).any()
            else ""
        )
        + "Section 8 sets out what these symptoms and the Morris rankings together "
        "suggest about the hydrology module. Every ranking below is therefore a "
        "sensitivity of the model as currently implemented, not of the "
        f"{site['name']} catchment."
    )
if health["groundwater_loss_mm"].isna().all():
    say(
        "The water balance closure leaves out deep groundwater loss, because "
        "`groundwater_loss_mm` can only be filled from "
        "`compiled_configuration.toml`, which was not retained. Treat the closure "
        "figures as indicative."
    )
```

## 2. What did the runs produce?

Before reading any sensitivity index, look at what the model produced. A Morris
index says how much a response changes when a parameter changes; it does not say
whether the response itself is realistic. The tables below come from the
`output_*` summaries written by the analysis script, and describe the responses
across the runs, through time and in space.

### 2.1 Responses across the runs

Each response is a statistic of one run's monthly series after spin-up. The table
gives its spread across the runs. `p95 / p05` measures how much the parameters
move a response; `cv` is the coefficient of variation across runs.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_table(
    output_summary[
        [
            "response",
            "unit",
            "p05",
            "median",
            "p95",
            "cv_across_runs",
            "p95_over_p05",
            "n_runs_negative",
            "n_runs_zero",
        ]
    ].rename(columns={"cv_across_runs": "cv", "p95_over_p05": "p95 / p05"})
)
show_figure(figures_dir / "06_output_distributions.png")

# ---- generated interpretation ----
d = summary_row("discharge_mean")
surface = summary_row("surface_runoff_routed_plus_local")
subsurface = summary_row("subsurface_runoff_routed_plus_local")
skew = d["p95"] / d["median"]
sub_orders = np.log10(max(subsurface["p95"], 1e-30) / max(subsurface["p05"], 1e-30))
zero = output_summary[output_summary["n_runs_zero"] > 0]
tiny = output_summary[
    (output_summary["median"].abs() < 1e-6) & (output_summary["unit"] == "mm")
]
negative = output_summary[output_summary["n_runs_negative"] > 0]
bullets(
    [
        (
            f"**Discharge is {'strongly ' if skew > 5 else ''}skewed.** The median "
            f"run has a mean discharge of about {num(d['median'])} m³ s⁻¹, the 95th "
            f"percentile is about {num(d['p95'])} m³ s⁻¹ ({skew:.0f} times larger) "
            f"and the mean over runs ({num(d['mean'])} m³ s⁻¹) is "
            f"{d['mean'] / d['median']:.1f} times the median. A minority of "
            "parameter sets produce far more outflow than the rest."
            if skew > 2
            else f"**Discharge is fairly evenly spread across runs** (median "
            f"{num(d['median'])}, 95th percentile {num(d['p95'])} m³ s⁻¹)."
        ),
        f"**Surface runoff "
        f"{'hardly depends' if surface['cv_across_runs'] < 0.15 else 'depends'} "
        "on the parameters.** `surface_runoff_routed_plus_local` at the sinks has "
        f"a coefficient of variation of {pct(surface['cv_across_runs'])} across runs.",
        (
            f"**The subsurface carries the extremes.** "
            f"`subsurface_runoff_routed_plus_local` at the sinks spans about "
            f"{sub_orders:.0f} orders of magnitude (5-95% range about "
            f"{num(subsurface['p05'])} to {num(subsurface['p95'])} mm), so the "
            "high-discharge runs are those with large subsurface and groundwater "
            "outflow."
            if sub_orders >= 2
            else ""
        ),
        (
            "**Some flows are switched off.** "
            + "; ".join(
                f"`{r.response}` is exactly zero in {of_runs(r.n_runs_zero)}"
                for r in zero.itertuples()
            )
            + (
                ". Negligible (median below 1e-6 mm): " + names(tiny["response"])
                if len(tiny)
                else ""
            )
            + "."
            if len(zero) or len(tiny)
            else ""
        ),
        "; ".join(
            f"**`{r.response}` is negative on average in "
            f"{of_runs(r.n_runs_negative)}.**"
            for r in negative.itertuples()
        ),
    ]
)
```

### 2.2 Do the soil stores sit at their bounds?

If a soil layer is full, its water content equals `soil_moisture_saturation`
times its thickness; if it is at its lower bound, it equals
`soil_moisture_residual` times its thickness. The layer thicknesses come from
`core.layers.soil_layers` in the base configuration. The table compares each
run's mean soil moisture with these two bounds.

```python tags=["remove-input"] jupyter={"source_hidden": true}
top_label = f"topsoil / (saturation x {topsoil_mm:.0f} mm)"
sub_label = f"subsoil / (residual x {subsoil_mm:.0f} mm)"
soil_bounds = pd.DataFrame(
    {
        top_label: output_by_run["soil_moisture_topsoil"]
        / (output_by_run["soil_moisture_saturation"] * topsoil_mm),
        sub_label: output_by_run["soil_moisture_subsoil"]
        / (output_by_run["soil_moisture_residual"] * subsoil_mm),
    }
)
show_table(
    soil_bounds.describe(percentiles=[0.05, 0.5, 0.95])
    .loc[["min", "5%", "50%", "95%", "max"]]
    .rename_axis("statistic"),
    index=True,
)

# ---- generated interpretation ----
top_full = soil_bounds[top_label] >= 0.95
sub_residual = (soil_bounds[sub_label] - 1).abs() <= 0.01
soil_flat = all(
    temporal_row(f)["seasonal_range_rel"] < 0.01
    for f in ("soil_moisture_topsoil", "soil_moisture_subsoil")
)
soil_pinned = top_full.mean() > 0.9 and sub_residual.mean() > 0.75
say(
    "**Interpretation.** "
    + (
        f"The topsoil holds {pct(soil_bounds[top_label].min())}-"
        f"{pct(soil_bounds[top_label].max())} of its saturated capacity, and the "
        f"subsoil sits at its residual water content in "
        f"{of_runs(sub_residual.sum())}. "
        + (
            "Soil moisture also barely changes from month to month (Section 2.3). "
            if soil_flat
            else ""
        )
        + "The soil column is therefore not a dynamic store in this run: the "
        "topsoil is full, so rain that reaches it runs off, and the subsoil "
        "receives almost no water from above."
        if soil_pinned
        else f"The topsoil is at least 95% full in {of_runs(top_full.sum())} and "
        f"the subsoil is at its residual water content in "
        f"{of_runs(sub_residual.sum())}. The soil stores move between their "
        "bounds, so the soil column acts as a dynamic store."
    )
)
```

### 2.3 Through time

For each field: the month with the highest and lowest median value, the size of
the seasonal cycle relative to the mean, and the drift over the analysis period
(the change from the first to the last year relative to the run's mean). A run
counts as rising or falling when it drifts by more than 10% of its mean.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_table(
    output_temporal[
        [
            "field",
            "peak_month",
            "low_month",
            "seasonal_range_rel",
            "median_drift_rel",
            "n_runs_rising",
            "n_runs_falling",
            "share_months_negative",
        ]
    ].rename(
        columns={
            "seasonal_range_rel": "seasonal range / mean",
            "median_drift_rel": "median drift / mean",
            "share_months_negative": "share of run-months < 0",
        }
    )
)
show_figure(figures_dir / "07_output_monthly_series.png")

# ---- generated interpretation ----
q = temporal_row(primary_variable)
drifting = output_temporal[
    (output_temporal["n_runs_rising"] + output_temporal["n_runs_falling"]) > n_runs / 2
]
flat = output_temporal[
    (output_temporal["seasonal_range_rel"].fillna(0) < 0.01)
    & (output_temporal["median_drift_rel"].abs() < 0.01)
]
below_zero = output_temporal[output_temporal["share_months_negative"] > 0]
not_steady = len(drifting) > 0
bullets(
    [
        f"**Discharge has a {'modest' if q['seasonal_range_rel'] < 0.5 else 'strong'} "
        f"seasonal cycle.** It peaks in {q['peak_month']} and is lowest in "
        f"{q['low_month']}, with a seasonal range of {pct(q['seasonal_range_rel'])} "
        "of its mean.",
        (
            "**Not everything is at steady state.** More than half of the runs "
            "drift by over 10% of their mean for "
            + "; ".join(
                f"`{r.field}` ({r.n_runs_falling} falling, {r.n_runs_rising} "
                f"rising, median change {r.median_drift_rel:+.0%})"
                for r in drifting.itertuples()
            )
            + "."
            if not_steady
            else "**The fields are close to steady state:** no field drifts by more "
            "than 10% in more than half of the runs."
        ),
        (
            "Negative values: "
            + "; ".join(
                f"`{r.field}` is below zero in {pct(r.share_months_negative)} of "
                "all run-months"
                for r in below_zero.itertuples()
            )
            + "."
            if len(below_zero)
            else ""
        ),
        (
            f"**Flat fields** (no seasonal cycle, no drift): {names(flat['field'])}."
            if len(flat)
            else ""
        ),
        (
            f"**The {response_spec['spinup_months']}-month spin-up is too short.** "
            "The stores are still changing through the analysis period. The Morris "
            "responses are means and percentiles over a period with a trend, so "
            "they mix the parameters' effect on the level of a flow with their "
            "effect on how fast the stores drain."
            if not_steady
            else ""
        ),
    ]
)
```

### 2.4 In space

For each field, the median over runs of its long-term mean in each cell. For the
routed (outlet) fields, the last column compares the sink cells with the average
cell.

```python tags=["remove-input"] jupyter={"source_hidden": true}
spatial_table = output_spatial[
    [
        "field",
        "rule",
        "cell_min",
        "cell_max",
        "spatial_cv",
        "max_cell_is_outlet",
        "outlet_over_domain_mean",
    ]
].copy()
is_outlet = spatial_table["rule"] == "outlet"
spatial_table["max_cell_is_outlet"] = spatial_table["max_cell_is_outlet"].where(
    is_outlet, ""
)
spatial_table["outlet_over_domain_mean"] = spatial_table[
    "outlet_over_domain_mean"
].where(is_outlet, "")
show_table(
    spatial_table.rename(
        columns={
            "spatial_cv": "spatial cv",
            "max_cell_is_outlet": "largest at a sink",
            "outlet_over_domain_mean": "sink / mean cell",
        }
    )
)
show_figure(figures_dir / "08_output_median_maps.png")

# ---- generated interpretation ----
local = output_spatial[output_spatial["rule"] != "outlet"]
routed = output_spatial[output_spatial["rule"] == "outlet"]
uniform_local = local[local["spatial_cv"].fillna(0) < 0.01]
negative_map = output_spatial[output_spatial["n_cells_negative_median_map"] > 0]
uniform = len(uniform_local) >= len(local) / 2
say(
    "**Interpretation.** "
    + (
        f"Most local fluxes and stores are almost the same in every cell: "
        f"{names(uniform_local['field'])} vary by less than 1% across the grid. "
        if uniform
        else "Local fluxes and stores vary across the grid "
        f"(spatial cv up to {local['spatial_cv'].max():.2f}). "
    )
    + "".join(
        f"`{r.field}` is negative in {r.n_cells_negative_median_map} of {n_cells} "
        "cells of the median map. "
        for r in negative_map.itertuples()
    )
    + (
        f"The routed fields are largest at a sink, where they average about "
        f"{routed['outlet_over_domain_mean'].median():.1f} times the mean cell, "
        "because upstream runoff accumulates along the drainage paths. "
        if routed["max_cell_is_outlet"].all()
        else ""
    )
    + (
        "The spatial patterns in the Morris maps (Section 5) are therefore "
        "patterns of the drainage network, not of local differences in hydrology."
        if uniform
        else "The Morris maps (Section 5) combine the drainage network with real "
        "local differences in hydrology."
    )
)
```

### 2.5 Drainage network and grid location

The sinks recovered from the model output by the analysis script. The cell centres
written by this run are compared with the current base configuration, the elevation
input it names and the site definition in the notebook's run settings (`ll` + half a
cell to `ur` - half a cell). When the elevation input matches the current grid, the
sinks VE would find on it are listed too.

```python tags=["remove-input"] jupyter={"source_hidden": true}
sinks = drainage[drainage["is_sink"]].sort_values(
    "n_cells_draining_through", ascending=False
)
show_table(
    pd.DataFrame(
        {
            "x": [f"{value:.1f}" for value in sinks["x"]],
            "y": [f"{value:.1f}" for value in sinks["y"]],
            "cells draining through": sinks["n_cells_draining_through"].astype(int),
        }
    )
)

half = resolution / 2
site_x = (site["ll_x"] + half, site["ur_x"] - half)
site_y = (site["ll_y"] + half, site["ur_y"] - half)
run_x = (drainage["x"].min(), drainage["x"].max())
run_y = (drainage["y"].min(), drainage["y"].max())
with xr.open_dataset(elevation_file) as elevation_data:
    elevation_grid = elevation_data["elevation"].load()
show_table(
    pd.DataFrame(
        {
            "grid": [
                "this run (model output)",
                "current base configuration",
                f"elevation input (`{elevation_file.name}`)",
                f"{site['name']} site definition",
            ],
            "x centres": [
                f"{run_x[0]:.1f}-{run_x[1]:.1f}",
                f"{config_x.min():.1f}-{config_x.max():.1f}",
                f"{float(elevation_grid['x'].min()):.1f}-"
                f"{float(elevation_grid['x'].max()):.1f}",
                f"{site_x[0]:.1f}-{site_x[1]:.1f}",
            ],
            "y centres": [
                f"{run_y[0]:.1f}-{run_y[1]:.1f}",
                f"{config_y.min():.1f}-{config_y.max():.1f}",
                f"{float(elevation_grid['y'].min()):.1f}-"
                f"{float(elevation_grid['y'].max()):.1f}",
                f"{site_y[0]:.1f}-{site_y[1]:.1f}",
            ],
        }
    )
)


def offset(x0: float, y0: float) -> tuple[float, float]:
    """Offset of a grid's first cell centre from the site's first cell centre."""
    return x0 - site_x[0], y0 - site_y[0]


def direction(dx: float, dy: float) -> str:
    """'841 m west and 199 m north'."""
    return (
        f"{abs(dx):.0f} m {'east' if dx > 0 else 'west'} and "
        f"{abs(dy):.0f} m {'north' if dy > 0 else 'south'}"
    )


shift_x, shift_y = offset(run_x[0], run_y[0])
config_shift_x, config_shift_y = offset(config_x.min(), config_y.min())
run_mismatch = max(abs(shift_x), abs(shift_y)) > half
config_mismatch = max(abs(config_shift_x), abs(config_shift_y)) > half
elevation_matches = (
    elevation_grid.sizes.get("x") == config_nx
    and elevation_grid.sizes.get("y") == config_ny
    and np.allclose(np.sort(elevation_grid["x"].values), config_x)
    and np.allclose(np.sort(elevation_grid["y"].values), config_y)
)
# The run predates the current configuration when its grid differs from it
run_predates_config = run_mismatch and not config_mismatch
grid_mismatch = run_mismatch or config_mismatch


def ve_sinks(elevation: np.ndarray) -> dict[int, int]:
    """Sinks of VE's drainage rule on a north-up (y, x) elevation array.

    Follows hydrology.above_ground.calculate_drainage_map: each cell drains to
    the neighbour within one cell width (itself included) with the largest
    elevation drop; a cell that drains to itself is a sink. Returns each sink's
    cell_id and the number of cells in its catchment (the sink included).
    """
    n_rows, n_cols = elevation.shape
    flat = elevation.ravel()
    downstream = []
    for cell in range(flat.size):
        row, col = divmod(cell, n_cols)
        near = [cell] + [
            r * n_cols + c
            for r, c in ((row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1))
            if 0 <= r < n_rows and 0 <= c < n_cols
        ]
        near = np.array(sorted(near))
        downstream.append(int(near[np.argmax(flat[cell] - flat[near])]))

    def outlet(cell: int) -> int:
        while downstream[cell] != cell:
            cell = downstream[cell]
        return cell

    catchments = pd.Series([outlet(cell) for cell in range(flat.size)])
    return catchments.value_counts().to_dict()


# VE cell_id order: rows from north to south, x increasing within a row
elevation_north_up = (
    elevation_grid.transpose("y", "x").sortby("y", ascending=False).values
)
expected_sinks = ve_sinks(elevation_north_up)
if elevation_matches:
    display(
        Markdown(
            f"**Sinks expected under the current base configuration** (VE's "
            f"drainage rule applied to `{elevation_file.name}`)"
        )
    )
    show_table(
        pd.DataFrame(
            {
                "x": [f"{config_x[cell % config_nx]:.1f}" for cell in expected_sinks],
                "y": [
                    f"{config_y[::-1][cell // config_nx]:.1f}"
                    for cell in expected_sinks
                ],
                "elevation (m)": [
                    f"{elevation_north_up.ravel()[cell]:.1f}" for cell in expected_sinks
                ],
                "cells draining through": list(expected_sinks.values()),
            }
        )
    )

# ---- generated interpretation ----
if not run_mismatch:
    grid_text = f"The model grid matches the `{site['name']}` site definition."
elif run_predates_config:
    grid_text = (
        f"The cell centres written by this run are about {direction(shift_x, shift_y)} "
        f"of the `{site['name']}` grid. The current base configuration "
        f"(`xoff = {grid.get('xoff')}`, `yoff = {grid.get('yoff')}`) matches the "
        f"site, so this run was made before the configuration was corrected, with "
        f"a grid origin of about `xoff = {run_x[0] - half:.1f}`, "
        f"`yoff = {run_y[0] - half:.1f}`. VE maps input data onto the grid by their "
        "x/y coordinates, so the run read an elevation field for the shifted grid: "
        "its maps, sinks and catchments describe a different landscape from "
        f"`{site['name']}`. "
        + (
            f"Under the current configuration, `{elevation_file.name}` gives "
            f"{plural(len(expected_sinks), 'sink')} draining "
            f"{', '.join(map(str, expected_sinks.values()))} cells (table above), "
            f"instead of the {len(sinks)} found in this run. "
            if elevation_matches
            else ""
        )
        + "The Morris indices are computed from outlet sums and domain means, and "
        "local runoff is nearly uniform in space, so the rankings should carry "
        "over; the sink shares and maps will not. Rerun the ensemble with the "
        "current configuration to report the corrected grid."
    )
else:
    grid_text = (
        f"The cell centres written by this run are about {direction(shift_x, shift_y)} "
        f"of the `{site['name']}` grid: they follow `xoff = {grid.get('xoff', '?')}`, "
        f"`yoff = {grid.get('yoff', '?')}` in the base configuration rather than "
        f"`ll_x = {site['ll_x']}`, `ll_y = {site['ll_y']}`. The Morris indices are "
        "computed per cell and are not affected, but maps and sink positions are "
        "labelled on the shifted grid."
    )
say(
    f"**Interpretation.** {plural(len(sinks), 'sink')} drain "
    f"{', '.join(map(str, sinks['n_cells_draining_through'].astype(int)))} of the "
    f"{n_cells} cells in this run, and all water leaves the site through them. "
    + grid_text
    + (
        ""
        if elevation_matches
        else f" The elevation input `{elevation_file.name}` does not match the "
        "current configuration grid, so VE would not load it."
    )
)
```

### 2.6 Discharge compared with the runoff reaching the sinks

`river_discharge_rate` should be the runoff routed to the sinks, converted from
depth (mm per month over the cell area) to a flow rate (m³ s⁻¹). The ratio below
compares that conversion with the discharge the model reports, month by month.

```python tags=["remove-input"] jupyter={"source_hidden": true}
seconds_in_month = months.days_in_month.to_numpy() * 86400
routed_mm = field_series("surface_runoff_routed_plus_local") + field_series(
    "subsurface_runoff_routed_plus_local"
)
expected_discharge = routed_mm / 1000 * cell_area / seconds_in_month
with np.errstate(divide="ignore", invalid="ignore"):
    discharge_ratio = expected_discharge / field_series(primary_variable)
ratio_p05, ratio_median, ratio_p95 = np.nanpercentile(discharge_ratio, [5, 50, 95])
show_table(
    pd.DataFrame(
        {
            "statistic": ["5%", "median", "95%"],
            "routed runoff as m3 s-1 / reported discharge": [
                ratio_p05,
                ratio_median,
                ratio_p95,
            ],
        }
    )
)

# ---- generated interpretation ----
discharge_ok = abs(ratio_median - 1) < 0.05
days_factor = 27 <= ratio_median <= 33
say(
    "**Interpretation.** "
    + (
        "The reported discharge matches the runoff reaching the sinks."
        if discharge_ok
        else f"The runoff reaching the sinks corresponds to {ratio_p05:.0f}-"
        f"{ratio_p95:.0f} times the discharge the model reports"
        + (
            ", which is about the number of days in a month. The reported "
            "discharge is therefore very likely too small by that factor, pointing "
            "to a time-step problem in the conversion to m³ s⁻¹."
            if days_factor
            else ". The conversion to m³ s⁻¹ should be checked."
        )
        + (
            " Because the factor is nearly constant, the Morris ranking and the "
            "relative mu\\* are unaffected, but absolute discharge values and "
            "absolute mu\\* for the primary responses should not be compared "
            "with observations."
            if ratio_p95 / ratio_p05 < 1.5
            else ""
        )
    )
)
```

## 3. Which parameters drive discharge at the outlet?

The primary responses are statistics of the monthly site outflow after the
spin-up (see the response table above). Site discharge is the outflow summed over
the VE sinks (the lowest cell of each catchment); the spatial maps in Section 5
mark those sinks.

In the bar charts each parameter keeps the same colour. A filled bar is
influential (mu\* at least 10% of the largest mu\* for that response); an outline
bar is not. Whiskers are 95% bootstrap confidence intervals.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_figure(figures_dir / "01_morris_ranking_primary.png")
```

The top parameters for each primary response. `sigma/mu*` above about 1 means the
effect changes a lot across the parameter space (non-linear or interacting). The
mu\*-sigma plane below separates parameters with a steady effect (below the line)
from those whose effect depends on the other parameters (above the line).

```python tags=["remove-input"] jupyter={"source_hidden": true}
columns = ["rank", "parameter", "mu_star", "mu_star_conf", "mu", "sigma_over_mu_star"]
primary_scalar = scalar[scalar["group"] == "primary"]
for response, table in primary_scalar.groupby("response", sort=False):
    display(Markdown(f"**{response}**"))
    show_table(table.nsmallest(top_n, "rank")[columns])
show_figure(figures_dir / "02_morris_mu_star_sigma_primary.png")

# ---- generated interpretation ----
first = primary_scalar[primary_scalar["rank"] == 1]
top3 = {
    response: table.nsmallest(3, "rank")["parameter"].tolist()
    for response, table in primary_scalar.groupby("response", sort=False)
}
same_top3 = len({frozenset(v) for v in top3.values()}) == 1
mu_star_wide = primary_scalar.pivot(
    index="parameter", columns="response", values="mu_star"
)
rank_agreement = mu_star_wide.corr(method="spearman").min().min()
top_block = primary_scalar[primary_scalar["rank"] <= top_n]
paragraphs = []
if first["parameter"].nunique() == 1:
    lead = first.iloc[0]
    paragraphs.append(
        f"`{lead['parameter']}` ranks first for all {len(primary_responses)} "
        f"discharge responses. Its {'negative' if lead['mu'] < 0 else 'positive'} "
        f"mu means that a larger `{lead['parameter']}` gives "
        f"{'less' if lead['mu'] < 0 else 'more'} discharge."
    )
else:
    paragraphs.append(
        "The first-ranked parameter differs between the discharge responses: "
        + "; ".join(f"`{r.parameter}` for {r.response}" for r in first.itertuples())
        + "."
    )
if same_top3:
    order = next(iter(top3.values()))
    signs = primary_scalar[
        (primary_scalar["response"] == primary_responses[0])
        & primary_scalar["parameter"].isin(order)
    ].set_index("parameter")["mu"]
    paragraphs.append(
        f"All {len(primary_responses)} statistics share the same top three "
        f"({names(order)}; mu "
        + ", ".join("negative" if signs[p] < 0 else "positive" for p in order)
        + "), and the rank correlation of mu\\* between any two of them is at least "
        f"{rank_agreement:.2f}. "
        + (
            "They therefore carry largely the same information about the model: "
            "high flows, low flows and dry-season flows are not controlled by "
            "different processes (Section 8.6)."
            if rank_agreement > 0.9
            else "Lower places differ between the flow statistics."
        )
    )
else:
    paragraphs.append(
        "The top three differ between the flow statistics: "
        + "; ".join(f"{k}: {names(v)}" for k, v in top3.items())
        + ". Different parts of the flow regime are controlled by different "
        "parameters."
    )
min_ratio = top_block["sigma_over_mu_star"].min()
conf_width = (top_block["mu_star_conf"] / top_block["mu_star"]).median()
paragraphs.append(
    (
        f"Every top-{top_n} parameter has sigma/mu\\* above "
        f"{np.floor(min_ratio * 10) / 10:.1f}"
        if min_ratio > 1
        else f"sigma/mu\\* of the top-{top_n} parameters ranges from {min_ratio:.2f} "
        f"to {top_block['sigma_over_mu_star'].max():.2f}"
    )
    + f", and the 95% confidence interval on mu\\* is typically "
    f"{pct(conf_width)} of mu\\*. "
    + (
        "The effects are strongly non-linear or depend on the other parameters, "
        "so the Morris order is a screening result only; Sobol is needed to "
        "measure the interactions."
        if min_ratio > 1
        else "Some effects are close to linear and additive."
    )
)
say("**Interpretation.** " + paragraphs[0], *paragraphs[1:])
```

## 4. How stable is the ranking?

Each response was re-analysed by resampling trajectories with replacement. The
tables give each parameter's 5-95% rank range and the probability that it is in
the top `top_n`. A range that crosses the top-`top_n` boundary means more
trajectories would be needed to settle that parameter's place.

```python tags=["remove-input"] jupyter={"source_hidden": true}
top_k = next(c for c in stability.columns if c.startswith("prob_top"))
k_value = int(re.sub(r"\D", "", top_k) or top_n)
stable = stability[stability["median_rank"] <= top_n + 1].copy()
stable["rank_range"] = (
    stable["rank_p05"].astype(int).astype(str)
    + "-"
    + stable["rank_p95"].astype(int).astype(str)
)
display(Markdown("**5-95% rank range**"))
show_table(
    stable.pivot(index="parameter", columns="response", values="rank_range")
    .reindex(columns=primary_responses)
    .fillna(""),
    index=True,
)
display(Markdown(f"**Probability of being in the top {k_value}**"))
show_table(
    stable.pivot(index="parameter", columns="response", values=top_k)
    .reindex(columns=primary_responses)
    .fillna(0.0)
    .round(2),
    index=True,
)

# ---- generated interpretation ----
primary_stability = stability[stability["response"].isin(primary_responses)]
prob = primary_stability.pivot(index="parameter", columns="response", values=top_k)
settled = prob[(prob >= 0.9).all(axis=1)].index.tolist()
crossing = primary_stability[
    (primary_stability["rank_p05"] <= k_value)
    & (primary_stability["rank_p95"] > k_value)
]
unsettled = [p for p in crossing["parameter"].unique() if p not in settled]
candidate_set = set(decision.loc[decision["sobol_candidate"], "parameter"])
say(
    "**Interpretation.** "
    + (
        f"{names(settled)} {'is' if len(settled) == 1 else 'are'} in the top "
        f"{k_value} in at least {pct(prob.loc[settled].min().min())} of resamples "
        "for every primary response. "
        if settled
        else f"No parameter is in the top {k_value} in 90% of resamples for every "
        "response. "
    )
    + (
        ("The places below them are not: " if settled else "")
        + f"{names(unsettled)} have rank ranges that cross the top-{k_value} "
        f"boundary"
        + (f", so with {n_trajectories} trajectories" if n_trajectories else ", so")
        + " Morris cannot order them. "
        + (
            "This does not change the Sobol shortlist, because all of them go "
            "forward anyway."
            if set(unsettled) <= candidate_set
            else "Their place in the Sobol shortlist is therefore uncertain; more "
            "trajectories would settle it."
        )
        if unsettled
        else f"No rank range crosses the top-{k_value} boundary: the ranking is "
        "settled."
    )
)
```

## 5. Where and when do the parameters matter?

### Spatial pattern

Per-cell mu\* of the long-term mean primary variable. The stars are the VE sinks:
discharge in a cell includes everything routed through it, so sensitivity is
largest at the sinks and along their drainage paths.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_figure(primary_field / "figures" / "03_spatial_top_parameters.png")
display(Markdown("The parameter with the largest mu\\* in each cell:"))
show_figure(primary_field / "figures" / "04_dominant_parameter_map.png")
```

### Through time

mu\* of the site outflow in each month, relative to the month's most influential
parameter. Seasonal bands show parameters that matter in wet or dry months only.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_figure(primary_field / "figures" / "05_monthly_sensitivity.png")
```

**How to read these maps.** Discharge in a cell is the sum of the runoff generated
in every cell upstream of it within the same step. The spatial pattern therefore
mostly shows the drainage network: sensitivity grows along each flow path and
peaks at the sinks. It is a map of where each process is locally strongest only
if the local fluxes differ between cells (Section 2.4). The monthly pattern should
be read with Section 8.6 in mind: if outflow has no memory of earlier months, it
reflects when runoff is generated, together with the random daily rainfall
pattern, rather than travel times through the catchment.

## 6. Which parameters drive the other hydrological processes?

Secondary responses: the routed runoff fields summed over the sinks, domain means
of the flow components, and soil and groundwater stores. They show which process
each parameter acts through. The heatmap shows all responses at once, each column
scaled to its most influential parameter.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_figure(figures_dir / "03_morris_ranking_secondary.png")
show_figure(figures_dir / "05_morris_heatmap_all_responses.png")

display(
    Markdown(
        "The influential parameters of each secondary response, most influential first:"
    )
)
secondary = scalar[(scalar["group"] == "secondary") & scalar["influential"]]
show_table(
    secondary.sort_values(["response", "rank"])
    .groupby("response", sort=False)["parameter"]
    .agg(", ".join)
    .rename("influential parameters")
    .to_frame(),
    index=True,
)

# ---- generated interpretation ----
reach = (
    secondary.groupby("parameter")["response"].nunique().sort_values(ascending=False)
)
widest = reach.index[0]
widest_primary_rank = int(
    primary_scalar[primary_scalar["parameter"] == widest]["rank"].median()
)
single = [
    (p, secondary.loc[secondary["parameter"] == p, "response"].iloc[0])
    for p in reach[reach == 1].index
]
inert = sorted(
    set(parameter_ranges["parameter"])
    - set(scalar.loc[scalar["influential"], "parameter"])
)
lead_param = first["parameter"].mode().iloc[0]
lead_secondary = secondary.loc[
    secondary["parameter"] == lead_param, "response"
].tolist()
say(
    f"**Interpretation.** `{widest}` is influential for {reach.iloc[0]} of the "
    f"{len(secondary_responses)} secondary responses, the widest reach of any "
    "parameter"
    + (
        f", even though it ranks only {ordinal(widest_primary_rank)} for discharge"
        if widest_primary_rank > 1
        else ""
    )
    + ". "
    + (
        f"`{lead_param}`, the leading discharge parameter, is influential for "
        f"{names(lead_secondary)}"
        + (
            " and negligible for the other "
            f"{len(secondary_responses) - len(lead_secondary)} secondary responses."
            if len(lead_secondary) < len(secondary_responses)
            else "."
        )
        if lead_param != widest
        else ""
    ),
    (
        "Parameters that matter for a single secondary response: "
        + "; ".join(f"`{p}` ({r})" for p, r in single)
        + "."
        if single
        else ""
    ),
    (
        f"{names(inert)} {'is' if len(inert) == 1 else 'are'} influential for no "
        "response at all."
        if inert
        else "Every parameter is influential for at least one response."
    ),
)
```

## 7. Which parameters go forward to Sobol?

A parameter is a Sobol candidate if it is influential for at least one primary
response, or for at least two secondary responses.

```python tags=["remove-input"] jupyter={"source_hidden": true}
show_table(
    decision[
        [
            "parameter",
            "n_primary_influential",
            "n_secondary_influential",
            "max_mu_star_rel_primary",
            "mean_sigma_over_mu_star_primary",
            "sobol_candidate",
            "reason",
        ]
    ]
)

candidates = decision.loc[decision["sobol_candidate"], "parameter"].tolist()
print(f"{len(candidates)} Sobol candidates:")
for name in candidates:
    print(f"  - {name}")

# ---- generated interpretation ----
all_primary = decision[decision["n_primary_influential"] == len(primary_responses)]
via_primary = decision[
    decision["sobol_candidate"] & (decision["n_primary_influential"] > 0)
]
via_secondary = decision[
    decision["sobol_candidate"] & (decision["n_primary_influential"] == 0)
]
dropped = decision.loc[~decision["sobol_candidate"], "parameter"].tolist()
dropped_hydraulic = [p for p in dropped if p in soil_hydraulic_parameters]
say(
    f"**Interpretation.** {len(candidates)} parameters go forward: "
    f"{len(via_primary)} influential for at least one discharge response"
    + (
        f" ({len(all_primary)} of them for all {len(primary_responses)})"
        if len(all_primary)
        else ""
    )
    + (
        f", plus {names(via_secondary['parameter'])}, which "
        f"{'qualifies' if len(via_secondary) == 1 else 'qualify'} through secondary "
        "responses"
        if len(via_secondary)
        else ""
    )
    + f". {len(dropped)} {'is' if len(dropped) == 1 else 'are'} screened out"
    + (
        f", including {len(dropped_hydraulic)} of the "
        f"{len(soil_hydraulic_parameters)} soil hydraulic parameters"
        if dropped_hydraulic
        else ""
    )
    + ". The shortlist summarises the model as it runs now; check Section 8 "
    "before dropping any parameter permanently, because a parameter can look "
    "inert when the process it controls is switched off."
)
```

## 8. What the outputs and the Morris results reveal about the VE hydrology module

This section brings together the model health diagnostics (Section 1), the output
summaries (Section 2) and the Morris indices (Sections 3-7). Each check gives the
evidence first and then what it suggests, and is marked **not flagged** when the
run passes it. These are symptoms seen in this run's outputs, not a diagnosis of
the code; they should be raised with the VE developers and checked there before
being treated as definitive.

```python tags=["remove-input"] jupyter={"source_hidden": true}
flags = {}  # check -> next-step text, filled by the checks below

# ---- 8.1 water balance -------------------------------------------------------
flags["water"] = closure_failed.mean() > 0.5
say("### 8.1 Is water conserved?")
if flags["water"]:
    surface_cv = summary_row("surface_runoff_routed_plus_local")["cv_across_runs"]
    say(
        f"**Evidence.** {of_runs(closure_failed.sum())} fail to close the water "
        f"balance within ±{health_tolerance:g}% of rainfall, with a median closure "
        f"of about {closure_median:.0f}% (Section 1). In the median run the water "
        f"leaving as runoff is about {runoff_ratio.median():.1f} times the rainfall, "
        f"and up to about {runoff_ratio.max():.0f} times in the most extreme run "
        f"(table below). Surface runoff alone is about "
        f"{pct(surface_share_P.median())} of rainfall and its outlet total varies "
        f"by {pct(surface_cv)} between runs (Section 2.1).",
        (
            "**What it suggests.** Some part of the module releases more water than "
            "it receives. "
            + (
                "Because nearly all rainfall already leaves as surface runoff, the "
                "excess must come from the subsurface and groundwater flows, which "
                "are also where the runs differ most. "
                if surface_share_P.median() > 0.8
                else ""
            )
            + "Section 8.2 checks the groundwater stores as a likely source."
            if closure_median < 0
            else "**What it suggests.** Water is lost from the site without being "
            "accounted for as runoff, evaporation or storage."
        ),
    )
    show_table(
        pd.DataFrame(
            {
                "statistic": ["min", "median", "max"],
                "total runoff / rainfall": [
                    runoff_ratio.min(),
                    runoff_ratio.median(),
                    runoff_ratio.max(),
                ],
            }
        )
    )
else:
    say(f"**Not flagged:** {of_runs((~closure_failed).sum())} close the water balance.")
```

```python tags=["remove-input"] jupyter={"source_hidden": true}
# ---- 8.2 groundwater stores ----------------------------------------------------
lower = output_by_run["groundwater_storage_layer_2"]
negative_store = lower < 0
no_baseflow = output_by_run["baseflow"] <= 1e-9
loss_corr = output_by_run["groundwater_loss"].corr(lower)
lower_t = temporal_row("groundwater_storage_layer_2")
lower_s = output_spatial.set_index("field").loc["groundwater_storage_layer_2"]
flags["groundwater"] = bool(lower_negative.any())
say("### 8.2 Do the groundwater stores behave as reservoirs?")
if flags["groundwater"]:
    gw_params = [
        p
        for p in (
            "groundwater_loss",
            "groundwater_capacity",
            "reservoir_const_lower_groundwater",
            "reservoir_const_upper_groundwater",
        )
        if p in set(parameter_ranges["parameter"])
    ]
    gw_ranks = (
        primary_scalar[primary_scalar["parameter"].isin(gw_params)]
        .groupby("parameter")["rank"]
        .max()
        .astype(int)
    )
    say(
        "**Evidence.**",
        "\n".join(
            [
                f"- The lower groundwater store is negative at some point in "
                f"{of_runs(lower_negative.sum())}, negative on average in "
                f"{int(negative_store.sum())} runs, negative in "
                f"{int(lower_s['n_cells_negative_median_map'])} of {n_cells} cells of "
                f"the median map and in {pct(lower_t['share_months_negative'])} of all "
                f"run-months, and it falls in {int(lower_t['n_runs_falling'])} runs "
                "(Sections 1, 2.1, 2.3 and 2.4).",
                f"- Baseflow is exactly zero in {int(no_baseflow.sum())} runs, "
                f"{int((negative_store & no_baseflow).sum())} of which have a "
                "negative lower store (table below).",
                f"- Across runs, `groundwater_loss` and the mean lower store have a "
                f"correlation of {loss_corr:.2f} (table below).",
                "- Worst primary rank of the groundwater parameters: "
                + ", ".join(f"`{p}` {r}" for p, r in gw_ranks.items())
                + " (Section 3).",
            ]
        ),
    )
    show_table(
        pd.DataFrame(
            {
                "check": [
                    "runs with mean lower store < 0",
                    "runs with zero baseflow",
                    "runs with zero baseflow and lower store < 0",
                    "correlation: groundwater_loss vs mean lower store",
                ],
                "result": [
                    int(negative_store.sum()),
                    int(no_baseflow.sum()),
                    int((negative_store & no_baseflow).sum()),
                    round(loss_corr, 2),
                ],
            }
        )
    )
    capacity_mu = primary_scalar.loc[
        (primary_scalar["parameter"] == "groundwater_capacity")
        & (primary_scalar["response"] == primary_responses[0]),
        "mu",
    ]
    say(
        "**What it suggests.**",
        "\n".join(
            [
                "- A store that goes negative means water is removed from it whether "
                "or not there is any left, so the lower store has no lower bound. The "
                '"lost" water in those runs never existed.',
                "- `groundwater_loss` can act like a switch: depending on the balance "
                "of percolation and loss, the lower store either keeps baseflow going "
                "or collapses below zero and baseflow stops."
                if no_baseflow.any()
                else "",
                "- `groundwater_capacity` increases discharge. A capacity should limit "
                "storage; here it behaves more like the amount of water the store "
                "starts with, which then keeps feeding flow while the store drains."
                if len(capacity_mu) and capacity_mu.iloc[0] > 0
                else "",
                "- Together with Section 8.1, this points to the groundwater "
                "reservoirs as a place where water is created: their outflows do not "
                "appear to draw the stores down in a mass-conserving way."
                if flags["water"]
                else "",
            ]
        ).replace("\n\n", "\n"),
    )
else:
    say(
        "**Not flagged:** the lower groundwater store stays at or above zero in "
        "every run."
    )
```

```python tags=["remove-input"] jupyter={"source_hidden": true}
# ---- 8.3 soil column -------------------------------------------------------------
hydraulic = decision.loc[
    decision["parameter"].isin(soil_hydraulic_parameters),
    ["parameter", "max_mu_star_rel_any", "sobol_candidate"],
]
hydraulic_inert = (hydraulic["max_mu_star_rel_any"] < 0.01).all() and len(hydraulic)
flags["soil"] = bool(soil_pinned or (~vertical_ok).all())
say("### 8.3 Is the soil column active?")
if flags["soil"]:
    ksat = (
        parameter_ranges.set_index("parameter")
        .reindex(["saturated_hydraulic_conductivity"])
        .iloc[0]
    )
    say(
        "**Evidence.**",
        "\n".join(
            filter(
                None,
                [
                    f"- The topsoil holds {pct(soil_bounds[top_label].min())}-"
                    f"{pct(soil_bounds[top_label].max())} of its saturated capacity, "
                    f"and the subsoil sits at its residual water content in "
                    f"{of_runs(sub_residual.sum())}"
                    + (", with no seasonal cycle" if soil_flat else "")
                    + " (Sections 2.2 and 2.3).",
                    f"- Mean soil vertical flow is below {vertical_flow_min:g} mm in "
                    f"{of_runs((~vertical_ok).sum())}, with a median of about "
                    f"{health['mean_soil_vertical_flow_mm'].median():.1e} mm "
                    "(Section 1).",
                    f"- The {len(hydraulic)} soil hydraulic parameters have a largest "
                    "relative mu\\* below 0.01 for every one of the "
                    f"{scalar['response'].nunique()} responses (table below)."
                    if hydraulic_inert
                    else "",
                ],
            )
        ),
        "**What it suggests.** Water hardly moves between the soil layers or into "
        "groundwater, so the soil is a full bucket on top of an empty one. Rain that "
        "reaches the full topsoil runs off at the surface, and groundwater can be "
        "recharged mainly by bypass flow. "
        + (
            "The soil hydraulic parameters are screened out because the process "
            "they control is inactive, not necessarily because it is unimportant. "
            if hydraulic_inert
            else ""
        )
        + (
            f"The sampled saturated hydraulic conductivities correspond to about "
            f"{num(ksat['lower'] * 8.64e7)} to {num(ksat['upper'] * 8.64e7)} mm per "
            "day (if in m s⁻¹); a mean vertical flux of "
            f"{health['mean_soil_vertical_flow_mm'].median():.1e} mm is many orders "
            "of magnitude smaller, which suggests a unit or scaling problem rather "
            "than a physical result."
            if np.isfinite(ksat["lower"])
            else ""
        ),
    )
    show_table(
        hydraulic.rename(
            columns={"max_mu_star_rel_any": "largest mu*_rel, any response"}
        )
    )
else:
    say(
        "**Not flagged:** soil moisture moves between its bounds and soil water "
        "flows vertically."
    )
```

```python tags=["remove-input"] jupyter={"source_hidden": true}
# ---- 8.4 discharge conversion --------------------------------------------------
flags["discharge"] = not discharge_ok
say("### 8.4 Is the reported discharge consistent with the runoff?")
if flags["discharge"]:
    say(
        f"**Evidence.** Converting the runoff that reaches the sinks to m³ s⁻¹ gives "
        f"{ratio_p05:.0f}-{ratio_p95:.0f} times the discharge the model reports "
        f"(median {ratio_median:.1f}; Section 2.6).",
        "**What it suggests.** "
        + (
            "The conversion of runoff to `river_discharge_rate` probably divides by "
            "the number of days once too often. "
            if days_factor
            else "The conversion of runoff to `river_discharge_rate` should be "
            "checked. "
        )
        + (
            "The factor is nearly constant, so Morris rankings and relative mu\\* "
            "are unaffected, but absolute discharge and absolute mu\\* for the "
            "primary responses should not be compared with observations or with "
            "other studies."
            if ratio_p95 / ratio_p05 < 1.5
            else "The factor varies between months and runs, so it can also affect "
            "the rankings."
        ),
    )
else:
    say("**Not flagged:** reported discharge matches the routed runoff.")

# ---- 8.5 steady state -----------------------------------------------------------
flags["steady"] = not_steady
say("### 8.5 Is the model at steady state?")
if flags["steady"]:
    say(
        f"**Evidence.** Discharge falls over {period} in "
        f"{of_runs(q['n_runs_falling'])}. "
        + f"{len(drifting)} of {len(output_temporal)} fields drift by more than 10% "
        "in more than half of the runs "
        f"(median change {drifting['median_drift_rel'].min():+.0%} to "
        f"{drifting['median_drift_rel'].max():+.0%}), despite the "
        f"{response_spec['spinup_months']}-month spin-up (Section 2.3).",
        "**What it suggests.** The stores are still draining (or filling) from their "
        "initial state throughout the analysis period. Mean and percentile responses "
        "then depend on how much initial water is left to drain. A longer spin-up, "
        "or responses computed only once the stores have settled, would separate "
        "the parameters' effect on the flow regime from their effect on the initial "
        "drainage.",
    )
else:
    say("**Not flagged:** no field drifts in more than half of the runs.")

# ---- 8.6 structure ----------------------------------------------------------------
flags["structure"] = same_top3 and rank_agreement > 0.9 and uniform
say("### 8.6 Does discharge have process, time and spatial structure?")
if flags["structure"]:
    say(
        f"**Evidence.** The {len(primary_responses)} discharge responses rank the "
        f"parameters in almost the same order (rank correlation ≥ "
        f"{rank_agreement:.2f}), with the same top three (Sections 3 and 4). Local "
        "fluxes and stores are nearly identical in every cell, and only the routed "
        f"fields vary in space, following the drainage paths to the {n_sinks} sinks "
        "(Sections 2.4 and 2.5).",
        "**What it suggests.** In a real catchment, high flows are usually driven by "
        "fast surface and stormflow processes and low flows by slow groundwater "
        "drainage. Here the same parameters control all flow levels, which points to "
        "discharge being the same-step sum of upstream runoff, with no routing delay "
        "or channel storage. With spatially uniform local hydrology, the Morris maps "
        "show where water accumulates, not where processes differ. All outflow "
        "leaves through internal sinks, so the site outlet is defined by the lowest "
        "cells of the grid rather than by a river leaving the domain; whether the "
        "sink cells are handled correctly should be checked.",
    )
else:
    say(
        "**Not flagged:** the flow statistics or the grid cells respond differently "
        "to the parameters."
    )

# ---- 8.7 grid -------------------------------------------------------------------
flags["grid"] = grid_mismatch
flags["rerun_grid"] = run_predates_config
say(f"### 8.7 Does the configuration grid match the {site['name']} site?")
if run_predates_config:
    say(
        f"**Evidence.** The model output's cell centres are about "
        f"{direction(shift_x, shift_y)} of the `{site['name']}` grid (Section 2.5). "
        f"The current `{base_config_path.name}` now has `xoff = {grid.get('xoff')}`, "
        f"`yoff = {grid.get('yoff')}`, which matches the site, and "
        + (
            f"`{elevation_file.name}` matches its grid."
            if elevation_matches
            else f"`{elevation_file.name}` does **not** match its grid."
        ),
        "**What it suggests.** The configuration has been corrected since this run. "
        "Rerun the Morris ensemble from the current base configuration (a new "
        "`run_name`) so that maps, sinks and outlet shares refer to the "
        f"`{site['name']}` landscape"
        + (
            f"; the current grid has {plural(len(expected_sinks), 'sink')} instead "
            f"of {len(sinks)}."
            if elevation_matches
            else "."
        ),
    )
elif flags["grid"]:
    say(
        f"**Evidence.** The model output's cell centres are about "
        f"{direction(shift_x, shift_y)} of the `{site['name']}` grid "
        "(Section 2.5), matching `xoff` / `yoff` in the base configuration.",
        f"**What it suggests.** Set `xoff = {site['ll_x']}` and "
        f"`yoff = {site['ll_y']}` in `{base_config_path.name}` before the next run "
        f"so that the model grid matches the `{site['name']}` site definition.",
    )
else:
    say("**Not flagged:** the model grid matches the site definition.")

# ---- 8.8 noise floor ---------------------------------------------------------------
replicate_folder = module_root / "out" / f"{run_name}_replicates"
flags["noise"] = not any("replicate" in item.lower() for item in design) and not (
    replicate_folder.exists()
)
say("### 8.8 Is the noise floor known?")
say(
    "VE splits monthly rainfall into days at random, and this design has no "
    "replicate runs. The part of each index due to rainfall noise is therefore "
    "unknown, and small differences between parameters near the screening "
    "threshold should not be over-interpreted."
    if flags["noise"]
    else "**Not flagged:** replicate runs are available to estimate the noise floor."
)
```

### 8.9 Suggested next steps

Generated from the checks flagged above.

```python tags=["remove-input"] jupyter={"source_hidden": true}
steps = {
    "water": "Raise the water balance error with the VE developers, with the "
    "evidence in Section 8.1.",
    "groundwater": "Raise the negative groundwater storage (Section 8.2) with the VE "
    "developers.",
    "soil": "Raise the pinned soil moisture and near-zero vertical flow "
    "(Section 8.3), including the hydraulic conductivity units.",
    "discharge": "Check the conversion of routed runoff to `river_discharge_rate` "
    "(Section 8.4).",
    "grid": (
        "Rerun the Morris ensemble with the current base configuration, whose grid "
        f"now matches `{site['name']}` (Section 8.7)."
        if run_predates_config
        else f"Set `xoff = {site['ll_x']}`, `yoff = {site['ll_y']}` in the base "
        f"configuration so the model grid matches `{site['name']}` (Section 8.7)."
    ),
    "steady": "Use a longer spin-up, or compute the responses once the stores have "
    "settled (Section 8.5).",
    "noise": "Add a few replicate runs (`replicates` in `morris_sample.py`) to "
    "estimate the noise floor (Section 8.8).",
}
todo = [text for key, text in steps.items() if flags.get(key)]
if any(flags.get(k) for k in ("water", "groundwater", "soil", "discharge", "grid")):
    todo.append(
        "Once these are resolved, repeat the Morris screening before running Sobol. "
        "The influential set, and especially the role of any parameter whose "
        "process is switched off, is likely to change."
    )
if run_check["status"].eq("not checked (no record)").all():
    todo.append(
        "Keep `compiled_configuration.toml` for each run, so that the per-run design "
        "check and the groundwater loss term in the water balance can be computed."
    )
say("\n".join(f"- {t}" for t in todo) if todo else "No checks were flagged.")
```

## Interpretation notes

- Read the indices together with the outputs (Section 2): a parameter can be
  influential only because it controls a store that drifts, goes negative or is
  pinned at a bound (Section 8).
- The ranking inside the candidate set is approximate. Sobol quantifies each
  parameter's share of the output variance and its interactions.
- Parameters that look inert may be switched off by the model rather than
  unimportant (Section 8.3).
- VE splits monthly rain into days at random; without replicate runs the noise
  floor of the indices is not assessed (Section 8.8).
- Per-run design cross-checking depends on `compiled_configuration.toml` records
  being retained for the run; when they are not (Section 1), the design table and
  parameter ranges are the available provenance for the run.

<!-- #region tags=["remove-cell"] -->
## Rendering this notebook

This notebook follows `templates/Jupyter_notebook_tutorial`, with one change: the
rendered output goes into a folder named after `run_name` rather than a single
`rendered/` folder, so each Morris run keeps its own rendered copy:

```text
notebook/hydrology/morris_sensitivity/
├── morris_hydrology_results.md        # Markdown source (commit)
├── morris_hydrology_results.ipynb     # paired notebook (do not commit)
└── <run_name>/                        # rendered output for run_name (commit)
    ├── morris_hydrology_results.md
    └── morris_hydrology_results_*.png
```

The cell below does the rendering, so there is no separate export step. Save the
notebook first, then run all cells. The cell runs the saved notebook again in a
fresh kernel, with the saved settings, and writes the rendered Markdown and
figures to `<run_name>/`, replacing any earlier rendered copy there. In the
rendered copy starts with the report: cells tagged `remove-cell` (How to use,
Run settings, setup and this section) are run but left out, the other cells show
only their output, and the render cell is left out. Set `render_output = False`
in the settings cell to run the notebook without rendering it.

Rendering needs `nbconvert`. If the kernel running this notebook does not have it,
the cell uses the repository environment (`.venv`, created by `uv sync`) instead,
so it works whichever kernel is selected. It renders the most recently saved of the
paired files: the `.md` source (read with `jupytext`) or, when it was saved later or
`jupytext` is not available, the `.ipynb`. This way an edit saved only in the
`.ipynb` is still rendered.

Commit this source file and the run folder, not the `.ipynb` file. `show_figure`
reduces figures larger than 450 kB so that the exported PNGs pass the
`check-added-large-files` pre-commit hook, and the rendered Markdown has trailing
spaces removed and markdownlint turned off, so it passes the other hooks.
<!-- #endregion -->

```python tags=["remove-cell"] jupyter={"source_hidden": true}
# --- render cell: exports this notebook; left out of the rendered copy ---
import importlib.util
import subprocess
import sys

notebook_stem = "morris_hydrology_results"
notebook_dir = Path.cwd()

# Rendering runs as a separate Python process, so it can use the repository
# environment when this kernel lacks nbconvert. Arguments: notebook folder,
# notebook name, run_name (the output folder).
render_code = r"""
import importlib.util
import sys
from pathlib import Path

from nbconvert import MarkdownExporter
from nbconvert.preprocessors import ExecutePreprocessor
from traitlets.config import Config

notebook_dir, notebook_stem, run_name = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
output_dir = notebook_dir / run_name

# Render from the most recently saved copy: the .ipynb when it was edited after
# the paired .md (for example when jupytext pairing did not update the .md).
md_path = notebook_dir / f"{notebook_stem}.md"
ipynb_path = notebook_dir / f"{notebook_stem}.ipynb"
use_md = md_path.exists() and (
    not ipynb_path.exists() or md_path.stat().st_mtime >= ipynb_path.stat().st_mtime
)
if use_md and importlib.util.find_spec("jupytext") is not None:
    import jupytext

    notebook = jupytext.read(md_path)
else:
    import nbformat

    notebook = nbformat.read(ipynb_path, as_version=4)
print(f"Rendering from {md_path.name if use_md else ipynb_path.name}")

# Drop the render cell (so it does not run itself) and clear old outputs. Cells
# tagged remove-cell (settings, setup) still run; they are dropped at export.
notebook.cells = [
    cell for cell in notebook.cells if not cell.source.startswith("# --- render cell")
]
for cell in notebook.cells:
    if cell.cell_type == "code":
        cell.outputs = []

ExecutePreprocessor(timeout=600).preprocess(
    notebook, {"metadata": {"path": str(notebook_dir)}}
)

# Drop cells tagged remove-cell and hide the code of cells tagged remove-input.
config = Config()
config.TagRemovePreprocessor.enabled = True
config.TagRemovePreprocessor.remove_input_tags = {"remove-input"}
config.TagRemovePreprocessor.remove_cell_tags = {"remove-cell"}
body, resources = MarkdownExporter(config=config).from_notebook_node(
    notebook, resources={"unique_key": notebook_stem, "output_files_dir": "."}
)

output_dir.mkdir(exist_ok=True)
for old in output_dir.glob(f"{notebook_stem}_*.png"):
    old.unlink()
figures = resources.get("outputs", {})
for name, data in figures.items():
    (output_dir / Path(name).name).write_bytes(data)

text = "\n".join(line.rstrip() for line in body.splitlines()).strip("\n")
rendered_path = output_dir / f"{notebook_stem}.md"
rendered_path.write_text(
    "<!-- markdownlint-disable-file -->\n\n" + text + "\n", encoding="utf-8"
)
print(f"Wrote {rendered_path} and {len(figures)} figure(s)")
"""


def find_render_python() -> str | None:
    """Python with nbconvert: this kernel's, else the repository .venv's."""
    if importlib.util.find_spec("nbconvert") is not None:
        return sys.executable
    for relative in ("Scripts/python.exe", "bin/python"):
        candidate = repo_root / ".venv" / relative
        if candidate.exists():
            return str(candidate)
    return None


render_python = find_render_python()
if not render_output:
    print("render_output is False: rendered copy not updated")
elif render_python is None:
    print(
        "Rendered copy not updated: nbconvert is not installed in this kernel and "
        "no repository .venv was found. Run `uv sync` in the repository root, or "
        "`%pip install nbconvert jupytext` here, then rerun this cell."
    )
else:
    print(f"Rendering with {render_python} ...")
    result = subprocess.run(
        [render_python, "-c", render_code, str(notebook_dir), notebook_stem, run_name],
        capture_output=True,
        text=True,
    )
    print(result.stdout.strip())
    if result.returncode != 0:
        print("Rendering failed:")
        print(result.stderr.strip()[-3000:])
```
