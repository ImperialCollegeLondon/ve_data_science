"""
---
title: Shared tools for Virtual Ecosystem Morris and Sobol sensitivity analysis

description: |
  Provides shared, module-independent functions for Morris and Sobol global
  sensitivity analysis of Virtual Ecosystem (VE) constants. Constants can be
  included from any VE configuration section when their bounds are defined in
  sensitivity_parameters.toml.

  The module builds SALib sampling problems and designs, writes and reads VE
  array-job configurations, and verifies that design rows remain aligned with
  model outputs. It also provides functions used by analysis scripts to validate
  completed runs, extract scalar and spatial responses from VE NetCDF output,
  and create shared sensitivity figures.

  Keeping these operations in one module gives the Morris and Sobol stages a
  consistent definition of parameter bounds, sampling order, output responses,
  and reproducibility checks.

virtual_ecosystem_module: All

author:
  - Lelavathy

status: wip

input_files:
  - name: sensitivity_parameters.toml
    path: data/sensitivity/<module>/config/sensitivity_parameters.toml
    description: Bounds read by load_problem and load_design.
  - name: arrayJob_config_<run_name>.toml
    path: data/sensitivity/<module>/config/
    description: The job file (the design), read by load_design.
  - name: model_data.nc, compiled_configuration.toml and pbs.log
    path: data/sensitivity/<module>/out/<run_name>/<run folder>/
    description: VE output and run records, read by the run and response functions.

output_files:
  - name: arrayJob_config_<run_name>.toml
    path: data/sensitivity/<module>/config/
    description: Written by write_job_config for the sampling scripts.
  - name: Response cache and figures
    path: data/sensitivity/<module>/analysis/<run_name>/
    description: |
      responses.npz, response_spec.json and figures written for the analysis
      scripts that call these functions.

imported_files:
  - name: hpc_arrayJob_config_tools.py
    path: tools/python/src/ve_data_tools/hpc_arrayJob_config_tools.py
    description: Writes the [[subJobs]] entries of the job file.

package_dependencies:
  - numpy
  - pandas
  - xarray
  - scipy
  - matplotlib
  - SALib
  - tomli_w

usage_notes: |
  Import only, from analysis/abiotic/sensitivity/morris_sample.py,
  sobol_sample.py, the analysis scripts and their helper modules. Tests:

    uv run pytest tools/python/tests/test_sensitivity_tools.py.

  Do not reorder the sub-jobs of a job file: SALib uses only the order of the
  model outputs, and the structure check stops the analysis if it changed.

references: |
    Morris, M. D. (1991). Factorial sampling plans for preliminary computational
    experiments.technometrics, 33(2), 161-174.

    Sobol, I. M. (2001). Global sensitivity indices for nonlinear mathematical models
    and their Monte Carlo estimates. Mathematics and computers in simulation, 55(1-3),
    271-280.

    Iwanaga, T., Usher, W., & Herman, J. (2022). Toward SALib 2.0: Advancing the
    accessibility and interpretability of global sensitivity analyses.
    Socio-Environmental Systems Modelling, 4, 18155-18155.

Further information on SALib usage and supported sampling methods is available
in the SALib documentation: https://salib.readthedocs.io/en/latest/
---
"""  # noqa: D400, D205, D212, D415

from __future__ import annotations

import json
import tomllib
from pathlib import Path

import numpy as np
import pandas as pd

# -----------------------------------------------------------------------------
# 1. Problem
# -----------------------------------------------------------------------------


def load_problem(
    parameter_file: str | Path,
    groups: list[str],
    selected_parameters: list[str] | None = None,
    log10_parameters: list[str] | None = None,
) -> dict:
    """Build a SALib problem from sensitivity_parameters.toml.

    Args:
        parameter_file: TOML with [[<group>.constants]] name/bounds entries.
        groups: VE configuration sections to read, e.g. ["hydrology"].
        selected_parameters: Names to include, in this order. ``None`` = all
            parameters of the groups. Use "group.name" if a name occurs in
            more than one group.
        log10_parameters: Names sampled uniformly in log10 space (bounds must
            be positive). Use for ranges spanning more than about one order
            of magnitude.

    Returns:
        SALib problem (num_vars, names, bounds in SAMPLING space) plus
        ``config_keys`` (e.g. hydrology.constants.groundwater_loss),
        ``model_bounds`` (model units), ``scale`` and ``groups``.

    """
    log10_parameters = set(log10_parameters or [])
    with Path(parameter_file).open("rb") as handle:
        data = tomllib.load(handle)

    definitions = {}
    for group in groups:
        if group not in data:
            raise ValueError(f"Group {group!r} not in {parameter_file}")
        entries = data[group].get("constants", data[group].get("parameters"))
        if not entries:
            raise ValueError(f"Group {group!r} has no [[{group}.constants]] entries")
        for entry in entries:
            name, bounds = entry.get("name"), entry.get("bounds")
            if not name or bounds is None or len(bounds) != 2:
                raise ValueError(f"Invalid entry in {group}: {entry}")
            lower, upper = float(bounds[0]), float(bounds[1])
            if not lower < upper:
                raise ValueError(f"Invalid bounds for {group}.{name}: {bounds}")
            definitions[f"{group}.{name}"] = (group, name, lower, upper)

    by_name: dict[str, list[str]] = {}
    for key, (_, name, _, _) in definitions.items():
        by_name.setdefault(name, []).append(key)

    wanted = selected_parameters or [d[1] for d in definitions.values()]
    if len(wanted) != len(set(wanted)):
        raise ValueError(f"Duplicate selected parameters: {wanted}")

    keys = []
    for item in wanted:
        if item in definitions:
            keys.append(item)
        elif item in by_name and len(by_name[item]) == 1:
            keys.append(by_name[item][0])
        elif item in by_name:
            raise ValueError(
                f"{item!r} is in several groups; use one of {by_name[item]}"
            )
        else:
            raise ValueError(
                f"{item!r} has no bounds in {parameter_file}. "
                f"Available: {sorted(by_name)}"
            )

    names = [
        definitions[k][1] if len(by_name[definitions[k][1]]) == 1 else k for k in keys
    ]
    unknown_log = log10_parameters - set(names) - set(keys)
    if unknown_log:
        raise ValueError(f"log10_parameters not selected: {sorted(unknown_log)}")

    problem = {
        "num_vars": len(keys),
        "names": names,
        "bounds": [],
        "config_keys": [],
        "model_bounds": [],
        "scale": [],
        "groups": list(groups),
        "parameter_keys": keys,
    }
    for key, name in zip(keys, names):
        group, bare, lower, upper = definitions[key]
        log = name in log10_parameters or key in log10_parameters
        if log and lower <= 0:
            raise ValueError(f"log10 sampling needs positive bounds: {name}")
        problem["bounds"].append(
            [float(np.log10(lower)), float(np.log10(upper))] if log else [lower, upper]
        )
        problem["scale"].append("log10" if log else "linear")
        problem["config_keys"].append(f"{group}.constants.{bare}")
        problem["model_bounds"].append([lower, upper])
    return problem


def salib_problem(problem: dict) -> dict:
    """Keys SALib needs."""
    return {key: problem[key] for key in ("num_vars", "names", "bounds")}


def to_model_space(samples: np.ndarray, problem: dict) -> np.ndarray:
    """Back-transform sampling-space values (log10 -> value)."""
    model = np.array(samples, dtype=float, copy=True)
    for column, scale in enumerate(problem["scale"]):
        if scale == "log10":
            model[:, column] = 10.0 ** model[:, column]
    return model


def check_defaults_within_bounds(base_config: str | Path, problem: dict) -> list[str]:
    """Warn when a base-configuration value lies outside its sampled range."""
    with Path(base_config).open("rb") as handle:
        config = tomllib.load(handle)
    warnings = []
    for key, (lower, upper) in zip(problem["config_keys"], problem["model_bounds"]):
        section = config
        for part in key.split("."):
            section = section.get(part) if isinstance(section, dict) else None
        if section is None:
            warnings.append(f"{key}: not set in base config (VE default is used)")
        elif not lower <= float(section) <= upper:
            warnings.append(
                f"{key}: base value {section} is outside the sampled range "
                f"[{lower}, {upper}]"
            )
    return warnings


# -----------------------------------------------------------------------------
# 2. Sampling
# -----------------------------------------------------------------------------


def generate_morris_samples(problem: dict, settings: dict, seed: int) -> np.ndarray:
    """Morris design in sampling space.

    settings: trajectories (r), levels (p), candidate_trajectories (0 = off;
    >0 draws that many and keeps the r most spread-out, Campolongo 2007).
    Runs = r (D + 1).
    """
    from SALib.sample import morris

    candidates = int(settings.get("candidate_trajectories", 0))
    trajectories = int(settings["trajectories"])
    if candidates and candidates <= trajectories:
        raise ValueError("candidate_trajectories must exceed trajectories (or be 0)")
    return morris.sample(
        salib_problem(problem),
        N=candidates or trajectories,
        num_levels=int(settings["levels"]),
        optimal_trajectories=trajectories if candidates else None,
        seed=seed,
    )


def generate_sobol_samples(problem: dict, settings: dict, seed: int) -> np.ndarray:
    """Saltelli design in sampling space.

    settings: base_sample_size (N, power of 2), calculate_second_order,
    scramble. Runs = N (2D + 2) with second order, N (D + 2) without.
    """
    from SALib.sample import sobol

    n = int(settings["base_sample_size"])
    if n < 2 or n & (n - 1):
        raise ValueError(f"base_sample_size must be a power of 2, got {n}")
    return sobol.sample(
        salib_problem(problem),
        N=n,
        calc_second_order=bool(settings["calculate_second_order"]),
        scramble=bool(settings.get("scramble", True)),
        seed=seed,
    )


def sobol_block_size(num_vars: int, second_order: bool) -> int:
    """Rows per Saltelli base sample: 2D + 2 (with S2) or D + 2."""
    return 2 * num_vars + 2 if second_order else num_vars + 2


# -----------------------------------------------------------------------------
# 3. Job file (the design)
# -----------------------------------------------------------------------------
#
# The VE array-job file is the only design file. Its [[subJobs]] hold every
# sampled value in PBS array order, which is exactly the row order SALib needs,
# and a comment header records how it was made (method, settings, seed, ...).
# TOML comments are ignored by hpc_jobs, so the file runs unchanged on the HPC.
# The analysis scripts read the design back from this file and check that it
# has the structure of a Morris or Saltelli design, so no separate CSV or JSON
# record is needed.


def job_config_path(config_dir: str | Path, run_name: str) -> Path:
    """Return the standard job-file name for one experiment."""
    return Path(config_dir) / f"arrayJob_config_{run_name}.toml"


def _relative(path: str | Path, project_root: str | Path | None) -> str:
    if project_root is None:
        return str(path)
    try:
        return Path(path).resolve().relative_to(Path(project_root).resolve()).as_posix()
    except ValueError:
        return str(path)


def write_job_config(
    *,
    method: str,
    run_name: str,
    problem: dict,
    samples: np.ndarray,
    settings: dict,
    seed: int,
    parameter_file: Path,
    base_config: Path,
    site_directory: Path,
    config_dir: Path,
    project_root: Path,
    replicates: int = 0,
    notes: str = "",
) -> dict:
    """Write the VE array-job file (the design) and, optionally, replicates.

    Row i of ``samples`` becomes [[subJobs]] i, i.e. PBS array index i. The
    header comment records the settings; it is for readers and for the
    analysis summary, and is not needed to analyse the runs.
    """
    from importlib.metadata import version

    import tomli_w
    from ve_data_tools.hpc_arrayJob_config_tools import generate_arrayJob_config

    for path, label in ((base_config, "Base config"), (site_directory, "Site dir")):
        if not Path(path).exists():
            raise FileNotFoundError(f"{label} not found: {path}")

    job_file = job_config_path(config_dir, run_name)
    metadata = generate_arrayJob_config(
        samples=to_model_space(samples, problem),
        parameter_names=problem["config_keys"],
        common_config_paths=[base_config],
        site_directory=site_directory,
        output_file=job_file,
    )
    log10 = [n for n, sc in zip(problem["names"], problem["scale"]) if sc == "log10"]
    header = [
        f"# Sensitivity design written by {method}_sample.py. Do not edit:",
        "# change the script settings and regenerate. Sub-job i = PBS array",
        "# index i = design row i (SALib order).",
        "# common_config_paths and site_directory below are absolute paths on the",
        "# machine that ran the sampling script. VE runs on the HPC, so generate",
        "# this file on the HPC (from the repository root there).",
        f"# method: {method}",
        f"# run_name: {run_name}",
        f"# created: {pd.Timestamp.now():%Y-%m-%d %H:%M}",
        f"# parameter_file: {_relative(parameter_file, project_root)}",
        f"# base_config: {_relative(base_config, project_root)}",
        f"# parameters: {', '.join(problem['names'])}",
        f"# log10_parameters: {', '.join(log10) or 'none'}",
        "# settings: " + ", ".join(f"{k}={v}" for k, v in settings.items()),
        f"# seed: {seed}",
        f"# runs: {metadata['num_jobs']}",
        f"# salib_version: {version('SALib')}",
    ]
    header += [f"# notes: {line}" for line in notes.splitlines() if line.strip()]
    job_file.write_text(
        "\n".join(header) + "\n\n" + job_file.read_text(encoding="utf-8"),
        encoding="utf-8",
    )

    files = {"job_config": job_file}
    if replicates:
        files["replicate_config"] = replicate_config_path(job_file)
        with files["replicate_config"].open("wb") as handle:
            tomli_w.dump(
                {
                    "common_config_paths": [str(base_config)],
                    "site_directory": str(site_directory),
                    "subJobs": [
                        {
                            "config_paths": [],
                            "repeats": int(replicates),
                            "cli_config": {},
                        }
                    ],
                },
                handle,
            )
    return {"files": files, "n_runs": int(metadata["num_jobs"])}


def replicate_config_path(job_config: str | Path) -> Path:
    """Replicate job file that belongs to a design job file."""
    job_config = Path(job_config)
    return job_config.with_name(f"{job_config.stem}_replicates.toml")


def read_job_header(job_config: str | Path) -> dict[str, str]:
    """Read the "# key: value" lines at the top of a job file (empty if none)."""
    header = {}
    for line in Path(job_config).read_text(encoding="utf-8").splitlines():
        if not line.startswith("#"):
            if line.strip():
                break
            continue
        key, sep, value = line[1:].partition(":")
        if sep and " " not in key.strip():
            header[key.strip()] = value.strip()
    return header


def _flatten(section: dict, prefix: str = "") -> dict[str, float]:
    values = {}
    for key, value in section.items():
        name = f"{prefix}.{key}" if prefix else key
        if isinstance(value, dict):
            values.update(_flatten(value, name))
        else:
            values[name] = float(value)
    return values


def read_job_config(job_config: str | Path) -> tuple[list[str], np.ndarray, dict]:
    """Config keys, values (runs x parameters, model units) and file settings.

    Values are in [[subJobs]] order = PBS array index order. Every sub-job must
    set the same constants and run once (repeats = 1).
    """
    with Path(job_config).open("rb") as handle:
        data = tomllib.load(handle)
    keys, rows = None, []
    for index, subjob in enumerate(data["subJobs"], start=1):
        if int(subjob.get("repeats", 1)) != 1:
            raise ValueError(f"{job_config}: subJob {index} has repeats != 1")
        values = _flatten(subjob.get("cli_config", {}))
        if keys is None:
            keys = list(values)
        elif list(values) != keys:
            raise ValueError(f"{job_config}: subJob {index} sets different constants")
        rows.append([values[k] for k in keys])
    settings = {k: v for k, v in data.items() if k != "subJobs"}
    return keys or [], np.asarray(rows, dtype=float), settings


def _unit(samples: np.ndarray, problem: dict) -> np.ndarray:
    bounds = np.asarray(problem["bounds"], dtype=float)
    return (samples - bounds[:, 0]) / (bounds[:, 1] - bounds[:, 0])


def check_morris_structure(
    samples: np.ndarray, problem: dict, levels: int | None = None
) -> dict:
    """Prove the rows form Morris trajectories; return trajectories and levels.

    In the unit-scaled sampling space every value must lie on the p-level grid,
    and within each block of D + 1 rows each step must move exactly one
    parameter by delta = p / (2 (p - 1)), every parameter exactly once. A wrong
    row order, a wrong LOG10 setting or changed bounds all break this.
    """
    d = problem["num_vars"]
    n = len(samples)
    if n == 0 or n % (d + 1):
        raise ValueError(f"{n} runs is not a multiple of D + 1 = {d + 1}")
    unit = _unit(samples, problem)
    candidates = [int(levels)] if levels else range(2, 21)
    reasons = []
    for p in candidates:
        grid = unit * (p - 1)
        if not np.allclose(grid, np.round(grid), atol=1e-6):
            reasons.append(f"p={p}: values not on the grid")
            continue
        delta = p / (2 * (p - 1))
        steps = np.diff(unit.reshape(n // (d + 1), d + 1, d), axis=1)
        moved = ~np.isclose(steps, 0.0, atol=1e-6)
        if not (moved.sum(axis=2) == 1).all():
            reasons.append(f"p={p}: a step moves more or less than one parameter")
            continue
        if not np.allclose(np.abs(steps[moved]), delta, atol=1e-6):
            reasons.append(f"p={p}: step size is not delta = {delta:.4g}")
            continue
        if not (moved.sum(axis=1) == 1).all():
            reasons.append(f"p={p}: a parameter moves more than once per trajectory")
            continue
        return {"trajectories": n // (d + 1), "levels": p}
    off_grid = [
        f"{name} ({scale})"
        for column, (name, scale) in enumerate(zip(problem["names"], problem["scale"]))
        if not any(
            np.allclose(
                unit[:, column] * (p - 1),
                np.round(unit[:, column] * (p - 1)),
                atol=1e-6,
            )
            for p in candidates
        )
    ]
    raise ValueError(
        "The job file is not a Morris design for these bounds and scales "
        f"({'; '.join(reasons[:3])}). "
        + (f"Parameters off the Morris grid: {off_grid}. " if off_grid else "")
        + "Check log10_parameters (log10 vs linear), the levels and the bounds "
        "in sensitivity_parameters.toml."
    )


def check_sobol_structure(samples: np.ndarray, problem: dict) -> dict:
    """Prove the rows are Saltelli blocks; return N and the second-order flag.

    Each block is A, AB_1..AB_D, [BA_1..BA_D], B: AB_i is A with column i from
    B, and BA_i is B with column i from A.
    """
    d, n = problem["num_vars"], len(samples)
    for second in (True, False):
        size = sobol_block_size(d, second)
        if n == 0 or n % size:
            continue
        blocks = samples.reshape(n // size, size, d)
        a, b = blocks[:, 0], blocks[:, -1]
        ok = True
        for i in range(d):
            expected = a.copy()
            expected[:, i] = b[:, i]
            ok &= np.allclose(blocks[:, 1 + i], expected, rtol=1e-9, atol=1e-12)
            if second:
                expected = b.copy()
                expected[:, i] = a[:, i]
                ok &= np.allclose(blocks[:, 1 + d + i], expected, rtol=1e-9, atol=1e-12)
        if ok:
            return {"base_sample_size": n // size, "calculate_second_order": second}
    raise ValueError(
        f"The job file ({n} runs, D = {d}) is not a Saltelli design: rows are not "
        "in blocks of A, AB_i, [BA_i], B. Was it edited or re-ordered?"
    )


def load_design(
    job_config: str | Path,
    parameter_file: str | Path,
    method: str,
    *,
    log10_parameters: list[str] | None = None,
    levels: int | None = None,
    run_name: str | None = None,
    project_root: str | Path | None = None,
) -> tuple[dict, np.ndarray, dict]:
    """Read the design from the VE job file and check it.

    The constants and their order come from the job file, the bounds from
    ``parameter_file``. ``log10_parameters`` = None takes the log10 list from
    the job-file header written by the sample scripts; give a list (``[]`` for
    none) for job files without a header. Checks: every value within its
    bounds, and the rows have the Morris or Saltelli structure (see the
    check_* functions).

    Returns (problem, samples in sampling space, provenance). ``provenance``
    describes the design for the summaries (settings recovered from the rows;
    seed and SALib version from the job-file header when present).
    """
    job_config = Path(job_config)
    config_keys, values, file_settings = read_job_config(job_config)
    header = read_job_header(job_config)
    if header.get("method", method) != method:
        raise ValueError(f"{job_config} is a {header['method']} design, not {method}")

    selected, groups = [], []
    for key in config_keys:
        parts = key.split(".")
        if len(parts) != 3 or parts[1] != "constants":
            raise ValueError(f"{job_config}: {key} is not <group>.constants.<name>")
        selected.append(f"{parts[0]}.{parts[2]}")
        if parts[0] not in groups:
            groups.append(parts[0])
    if log10_parameters is None:
        if "log10_parameters" not in header:
            raise ValueError(
                f"{job_config.name} has no settings header (it was not written by "
                "morris_sample.py or sobol_sample.py), so say which "
                "parameters were sampled in log10: set log10_parameters in the "
                "analysis script ([] if none)."
            )
        recorded = header["log10_parameters"]
        log10_parameters = (
            [] if recorded == "none" else [n.strip() for n in recorded.split(",")]
        )
    log10 = [
        name
        for name in log10_parameters
        if name in selected or any(k.endswith(f".{name}") for k in selected)
    ]
    problem = load_problem(parameter_file, groups, selected, log10)

    lower, upper = np.asarray(problem["model_bounds"], dtype=float).T
    tolerance = 1e-9 * (upper - lower)
    outside = [
        name
        for column, name in enumerate(problem["names"])
        if (values[:, column] < lower[column] - tolerance[column]).any()
        or (values[:, column] > upper[column] + tolerance[column]).any()
    ]
    if outside:
        raise ValueError(
            f"Values in {job_config.name} lie outside the bounds in "
            f"{Path(parameter_file).name} for {outside}: the bounds were changed "
            "after sampling. Restore them to analyse this design."
        )
    samples = values.copy()
    for column, scale in enumerate(problem["scale"]):
        if scale == "log10":
            samples[:, column] = np.log10(samples[:, column])

    if method == "morris":
        settings = check_morris_structure(samples, problem, levels)
    elif method == "sobol":
        settings = check_sobol_structure(samples, problem)
    else:
        raise ValueError(f"Unknown method {method!r}")

    base_config = ""
    for recorded in file_settings.get("common_config_paths", [])[:1]:
        candidates = [
            Path(recorded),
            job_config.parent / Path(recorded.replace("\\", "/")).name,
        ]
        found = next((c for c in candidates if c.exists()), None)
        base_config = _relative(found, project_root) if found else recorded
    replicate_file = replicate_config_path(job_config)
    replicates = 0
    if replicate_file.exists():
        with replicate_file.open("rb") as handle:
            replicates = sum(
                int(j.get("repeats", 1)) for j in tomllib.load(handle)["subJobs"]
            )

    provenance = {
        "method": method,
        "run_name": run_name or header.get("run_name", job_config.stem),
        "groups": groups,
        "parameters": problem["names"],
        "config_keys": problem["config_keys"],
        "scale": problem["scale"],
        "log10_parameters": [
            n for n, sc in zip(problem["names"], problem["scale"]) if sc == "log10"
        ],
        "model_bounds": problem["model_bounds"],
        "settings": settings,
        "seed": header.get("seed", "not recorded"),
        "n_runs": len(samples),
        "replicates": replicates,
        "files": {"job_config": _relative(job_config, project_root)},
        "parameter_file": _relative(parameter_file, project_root),
        "base_config": base_config,
        "salib_version": header.get("salib_version", "not recorded"),
        "notes": header.get("notes", ""),
    }
    return problem, samples, provenance


def design_tables(problem: dict, provenance: dict) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Design summary (item, value) and parameter ranges, for the analysis output."""
    settings = ", ".join(f"{k} = {v}" for k, v in provenance["settings"].items())
    summary = pd.DataFrame(
        {
            "item": [
                "run name",
                "method",
                "job file (the design)",
                "parameter file",
                "base configuration",
                "parameters (D)",
                "design settings (read from the job file)",
                "model runs",
                "seed",
                "log10-sampled parameters",
                "SALib version used for sampling",
            ],
            "value": [
                provenance["run_name"],
                provenance["method"],
                provenance["files"]["job_config"],
                provenance["parameter_file"],
                provenance["base_config"],
                len(provenance["parameters"]),
                settings,
                provenance["n_runs"],
                provenance["seed"],
                ", ".join(provenance["log10_parameters"]) or "none",
                provenance["salib_version"],
            ],
        }
    )
    ranges = pd.DataFrame(
        {
            "parameter": problem["names"],
            "config_key": problem["config_keys"],
            "lower": [b[0] for b in problem["model_bounds"]],
            "upper": [b[1] for b in problem["model_bounds"]],
            "scale": problem["scale"],
        }
    )
    return summary, ranges


# -----------------------------------------------------------------------------
# 4. Runs and model output on the x/y grid
# -----------------------------------------------------------------------------
#
# A response specification (written in each module's analysis script) is a
# dict with:
#
#   simulation_start : "YYYY-MM" of the first monthly output
#   n_months         : expected number of time steps
#   grid_shape       : (ny, nx) expected, or None to skip the check
#   spinup_months    : months dropped from the start of every run
#   layers           : {name: {"source": var, "dimension": dim,
#                              "role": "topsoil" | "position": 0,
#                              "reduce": "mean" (if several layers match)}}
#   fields           : {name: "mean" | "outlet"}  how each field becomes a
#                      monthly series (domain mean, or sum over the outlet
#                      cells)
#   outlet           : None, or how the outlet cell(s) are chosen:
#                      {"method": "cells", "xy": [[x, y], ...]}  cells given
#                       by the analysis script (e.g. found with a module's own
#                       rule, such as the hydrology drainage sinks)
#                      {"method": "max_mean", "variable": name}
#                      {"method": "xy", "x": value, "y": value}
#                      Optional keys used only for labels: "label" (legend
#                      text for the outlet markers on maps) and "series"
#                      (short name of the outlet series, e.g. in titles).
#                      Other keys are recorded but not used by these tools.
#   responses        : [{"name", "variable", "statistic", "group",
#                        optional "months": [..], "years": [..]}]
#                      statistic: mean | sum | q10 | q90 | min | max | std
#                      group: primary | secondary
#                      months/years restrict the post-spin-up series to a
#                      period (e.g. months [2, 3] = driest months) before the
#                      statistic is taken


def find_run_outputs(results_dir: Path, n_runs: int, file_name: str) -> list[Path]:
    """Model output of PBS array index i = 1..n_runs; fail on any gap.

    Accepts the folder names used by the different submit scripts:
      array_subJob_7, array_subJob_007 (zero-padded, any width) and the raw
      PBS names such as 4061306[7].pbs-7.
    submit_ve_array_job.py creates all folders before the jobs start, so only
    the output file shows that a run finished.
    """
    import re

    results_dir = Path(results_dir)
    pbs_folders = {}
    for folder in results_dir.iterdir() if results_dir.exists() else []:
        match = re.search(r"\[(\d+)\]", folder.name)
        if folder.is_dir() and match:
            pbs_folders[int(match.group(1))] = folder
    paths, missing = [], []
    for i in range(1, n_runs + 1):
        candidates = [
            results_dir / f"array_subJob_{i:0{width}d}" / file_name
            for width in range(1, 7)
        ]
        if i in pbs_folders:
            candidates.append(pbs_folders[i] / file_name)
        found = next((p for p in candidates if p.exists()), None)
        if found is None:
            missing.append(f"array_subJob_{i}")
        paths.append(found)
    if missing:
        raise FileNotFoundError(
            f"{len(missing)} of {n_runs} runs have no {file_name} in {results_dir}: "
            + ", ".join(missing[:20])
            + (" ..." if len(missing) > 20 else "")
        )
    return paths


def _parameters_from_pbs_log(log_file: Path) -> dict | None:
    """Read the cli_config that hpc_jobs printed in a run's pbs.log."""
    import ast

    for line in log_file.read_text(encoding="utf-8", errors="replace").splitlines():
        if "cli_config:" in line:
            try:
                return ast.literal_eval(line.split("cli_config:", 1)[1].strip())
            except (ValueError, SyntaxError):
                return None
    return None


def verify_run_parameters(
    paths: list[Path],
    problem: dict,
    samples: np.ndarray,
    config_name: str = "compiled_configuration.toml",
    rtol: float = 1e-9,
) -> pd.DataFrame:
    """Check that run i really used design row i.

    Reads the compiled configuration VE saved next to each output, or, if it
    is missing, the parameters hpc_jobs printed in the run's pbs.log, and
    compares every sampled constant with the design (model units). This catches
    runs copied into the wrong folder, re-submitted with another job file, or
    mixed ensembles, none of which the output files themselves reveal. Runs
    with neither file are reported, not failed.
    """
    model_values = to_model_space(samples, problem)
    rows = []
    for index, path in enumerate(paths):
        folder = Path(path).parent
        config, source = None, ""
        if (folder / config_name).exists():
            with (folder / config_name).open("rb") as handle:
                config, source = tomllib.load(handle), config_name
        elif (folder / "pbs.log").exists():
            config, source = _parameters_from_pbs_log(folder / "pbs.log"), "pbs.log"
        if config is None:
            rows.append({"run": index + 1, "status": "not checked (no record)"})
            continue
        mismatch = False
        for key, expected in zip(problem["config_keys"], model_values[index]):
            section = config
            for part in key.split("."):
                section = section.get(part, {}) if isinstance(section, dict) else {}
            if section == {} or not np.isclose(float(section), expected, rtol=rtol):
                mismatch = True
                rows.append(
                    {
                        "run": index + 1,
                        "status": "mismatch",
                        "source": source,
                        "parameter": key,
                        "design": expected,
                        "compiled": section,
                    }
                )
        if not mismatch:
            rows.append({"run": index + 1, "status": "ok", "source": source})
    report = pd.DataFrame(
        rows, columns=["run", "status", "source", "parameter", "design", "compiled"]
    )
    mismatches = report[report["status"] == "mismatch"]
    if not mismatches.empty:
        raise ValueError(
            f"{mismatches['run'].nunique()} runs used parameters that differ from "
            f"the design (first: run {int(mismatches['run'].iloc[0])}). The results "
            "folder does not belong to this design."
        )
    return report


def _select_layer(data_array, spec: dict, name: str):
    dimension = spec["dimension"]
    if dimension not in data_array.dims:
        raise ValueError(f"{name}: {dimension!r} not in {data_array.dims}")
    if "position" in spec:
        positions = np.atleast_1d(spec["position"]).astype(int)
    else:
        roles = np.asarray(data_array["layer_roles"].values).astype(str)
        positions = np.flatnonzero(roles == spec["role"])
        if len(positions) == 0:
            raise ValueError(f"{name}: no layer with role {spec['role']!r} ({roles})")
    selected = data_array.isel({dimension: positions})
    if len(positions) > 1:
        if spec.get("reduce", "mean") != "mean":
            raise ValueError(f"{name}: unsupported reduce {spec.get('reduce')!r}")
        # NaN-aware: unfilled canopy layers are NaN in VE output.
        selected = selected.mean(dimension, skipna=True)
    else:
        selected = selected.isel({dimension: 0})
    return selected.drop_vars(
        [
            c
            for c in selected.coords
            if dimension in selected[c].dims or c in (dimension, "layer_roles")
        ],
        errors="ignore",
    )


def read_fields(path: Path, spec: dict):
    """Read every field of one run as arrays (time, y, x), north-up.

    Returns (fields, x, y); y is descending (north first), x ascending.
    """
    import xarray as xr

    layers = spec.get("layers", {})
    fields = {}
    with xr.open_dataset(path) as dataset:
        for name in spec["fields"]:
            if name in layers:
                data_array = _select_layer(
                    dataset[layers[name]["source"]], layers[name], name
                )
            elif name in dataset:
                data_array = dataset[name]
            else:
                raise KeyError(f"{name!r} not in {path}")
            if set(data_array.dims) != {"time_index", "y", "x"}:
                raise ValueError(
                    f"{name}: dims {data_array.dims}; expected "
                    "(time_index, y, x). Add a layer rule for it."
                )
            data_array = (
                data_array.sortby("y", ascending=False)
                .sortby("x")
                .transpose("time_index", "y", "x")
            )
            values = np.asarray(data_array.values, dtype=float)
            if values.shape[0] != spec["n_months"]:
                raise ValueError(
                    f"{name}: {values.shape[0]} time steps, "
                    f"expected {spec['n_months']} ({path})"
                )
            if spec.get("grid_shape") and values.shape[1:] != tuple(spec["grid_shape"]):
                raise ValueError(
                    f"{name}: grid {values.shape[1:]}, "
                    f"expected {tuple(spec['grid_shape'])}"
                )
            if not np.isfinite(values).all():
                raise ValueError(f"{name}: non-finite values in {path}")
            fields[name] = values[int(spec["spinup_months"]) :]
        x = np.asarray(data_array["x"].values, dtype=float)
        y = np.asarray(data_array["y"].values, dtype=float)
    return fields, x, y


_statistics = {
    "mean": np.mean,
    "sum": np.sum,
    "min": np.min,
    "max": np.max,
    "std": lambda s: np.std(s, ddof=1),
    "q10": lambda s: np.quantile(s, 0.10),
    "q90": lambda s: np.quantile(s, 0.90),
}


def _outlet_cells(
    outlet: dict, fields: dict, x: np.ndarray, y: np.ndarray
) -> list[tuple[int, int]]:
    """Outlet cell(s) as (row, col) on the north-up grid."""
    method = outlet["method"]
    if method == "cells":
        cells = []
        spacing = min(
            np.min(np.abs(np.diff(x))) if len(x) > 1 else np.inf,
            np.min(np.abs(np.diff(y))) if len(y) > 1 else np.inf,
        )
        for x_cell, y_cell in outlet["xy"]:
            row = int(np.argmin(np.abs(y - float(y_cell))))
            col = int(np.argmin(np.abs(x - float(x_cell))))
            if max(abs(y[row] - float(y_cell)), abs(x[col] - float(x_cell))) > (
                spacing / 2
            ):
                raise ValueError(
                    f"Outlet cell ({x_cell}, {y_cell}) is not a cell centre of the "
                    "model output grid"
                )
            cells.append((row, col))
        if not cells:
            raise ValueError("Outlet method 'cells' was given no cells")
        return cells
    if method == "max_mean":
        grid = fields[outlet["variable"]].mean(axis=0)
        return [tuple(int(i) for i in np.unravel_index(np.argmax(grid), grid.shape))]
    if method == "xy":
        return [
            (
                int(np.argmin(np.abs(y - float(outlet["y"])))),
                int(np.argmin(np.abs(x - float(outlet["x"])))),
            )
        ]
    raise ValueError(f"Unknown outlet method {method!r}")


def _response_masks(spec: dict, dates: pd.DatetimeIndex) -> list[np.ndarray]:
    """Boolean month mask for every scalar response (months/years filters)."""
    masks = []
    for response in spec["responses"]:
        mask = np.ones(len(dates), dtype=bool)
        if response.get("months"):
            mask &= np.isin(dates.month, response["months"])
        if response.get("years"):
            mask &= np.isin(dates.year, response["years"])
        if not mask.any():
            raise ValueError(f"Response {response['name']!r} selects no months")
        masks.append(mask)
    return masks


def _reduce_run(path, spec: dict, outlet: list | None, masks: list):
    """Reduce one run to maps, series and scalar responses (used in parallel)."""
    fields, x, y = read_fields(path, spec)
    names = list(spec["fields"])
    maps = np.stack([fields[n].mean(axis=0) for n in names])
    series = []
    for name in names:
        values = fields[name]
        if spec["fields"][name] == "outlet":
            rows = [r for r, _ in outlet]
            cols = [c for _, c in outlet]
            series.append(values[:, rows, cols].sum(axis=1))
        else:
            series.append(values.mean(axis=(1, 2)))
    series = np.stack(series)
    scalars = np.array(
        [
            _statistics[r["statistic"]](series[names.index(r["variable"])][mask])
            for r, mask in zip(spec["responses"], masks)
        ]
    )
    return maps, series, scalars, x, y


def extract_responses(
    paths: list[Path],
    spec: dict,
    cache_file: Path,
    root: Path | None = None,
    n_workers: int = 1,
) -> dict:
    """Reduce every run to scalar responses, long-term-mean maps and series.

    "outlet" fields are summed over the outlet cells given by spec["outlet"];
    "mean" fields are averaged over all cells. The outlet cells are fixed from
    the first run and reused for all runs. ``root`` is kept for compatibility
    with existing callers and is not used.
    n_workers > 1 reads runs in parallel processes (useful for 4608 runs).
    """
    field_names = list(spec["fields"])
    responses = list(spec["responses"])
    bad = [r["variable"] for r in responses if r["variable"] not in field_names]
    if bad:
        raise ValueError(f"Responses use variables not listed in fields: {bad}")
    if any(v == "outlet" for v in spec["fields"].values()) and not spec.get("outlet"):
        raise ValueError("A field uses 'outlet' but no outlet rule is given")

    dates = pd.date_range(
        spec["simulation_start"], periods=spec["n_months"], freq="MS"
    )[int(spec["spinup_months"]) :]
    masks = _response_masks(spec, dates)

    outlet = None
    if spec.get("outlet"):
        fields, x, y = read_fields(paths[0], spec)
        outlet = _outlet_cells(spec["outlet"], fields, x, y)

    n_runs = len(paths)
    results = [None] * n_runs
    if n_workers > 1:
        from concurrent.futures import ProcessPoolExecutor
        from functools import partial

        work = partial(_reduce_run, spec=spec, outlet=outlet, masks=masks)
        with ProcessPoolExecutor(max_workers=n_workers) as pool:
            for index, result in enumerate(pool.map(work, paths, chunksize=8)):
                results[index] = result
                if index % 250 == 0:
                    print(f"  read run {index + 1}/{n_runs}", flush=True)
    else:
        for index, path in enumerate(paths):
            if index % 250 == 0:
                print(
                    f"  reading run {index + 1}/{n_runs}: {path.parent.name}",
                    flush=True,
                )
            results[index] = _reduce_run(path, spec, outlet, masks)

    x, y = results[0][3], results[0][4]
    data = {
        "scalars": np.stack([r[2] for r in results]),
        "scalar_names": np.array([r["name"] for r in responses], dtype=str),
        "scalar_groups": np.array([r["group"] for r in responses], dtype=str),
        "maps": np.stack([r[0] for r in results]),
        "series": np.stack([r[1] for r in results]),
        "fields": np.array(field_names, dtype=str),
        "x": x,
        "y": y,
        "dates": np.array(dates.strftime("%Y-%m"), dtype=str),
        "outlet_xy": (
            np.array([[x[c], y[r]] for r, c in outlet])
            if outlet
            else np.full((1, 2), np.nan)
        ),
        "outlet_label": np.array(
            (spec.get("outlet") or {}).get("label", default_outlet_label), dtype=str
        ),
        "outlet_series": np.array(
            (spec.get("outlet") or {}).get("series", default_outlet_series), dtype=str
        ),
    }
    Path(cache_file).parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(cache_file, **data)
    return data


def load_responses(
    paths_or_cache,
    spec: dict,
    cache_file: Path,
    use_cache: bool,
    root: Path | None = None,
    n_workers: int = 1,
) -> dict:
    """Use the cache when asked and present, else read the NetCDF files."""
    if use_cache and Path(cache_file).exists():
        with np.load(cache_file, allow_pickle=False) as data:
            return {key: data[key] for key in data.files}
    return extract_responses(paths_or_cache, spec, cache_file, root, n_workers)


def replicate_noise(
    results_dir: Path,
    n_repeats: int,
    file_name: str,
    spec: dict,
    cache_file: Path,
    root: Path | None = None,
) -> pd.DataFrame | None:
    """Calculate the standard deviation of each response across identical runs.

    Returns None when no replicate run exists.
    """
    if not n_repeats or not Path(results_dir).exists():
        return None
    data = extract_responses(
        find_run_outputs(results_dir, n_repeats, file_name), spec, cache_file, root
    )
    return pd.DataFrame(
        {
            "response": data["scalar_names"],
            "replicate_mean": data["scalars"].mean(axis=0),
            "replicate_std": data["scalars"].std(axis=0, ddof=1),
        }
    )


# -----------------------------------------------------------------------------
# 5. Plots
# -----------------------------------------------------------------------------


def pyplot():
    """matplotlib.pyplot with a non-interactive backend."""
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    return plt


def save_figure(fig, path: Path) -> None:
    """Save and close a figure."""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, dpi=200, bbox_inches="tight")
    pyplot().close(fig)


# Categorical colours (fixed order, validated for colour-vision deficiency on
# adjacent pairs). Colour follows the parameter, never its rank: one mapping is
# built per analysis and reused by every figure. Only the first 8 parameters get
# a colour; the rest are grey. Scatter plots and maps also use a distinct marker
# or hatch per parameter, because not every colour pair is distinguishable
# when all eight appear together.
categorical_colours = [
    "#2a78d6",  # blue
    "#eb6834",  # orange
    "#1baf7a",  # aqua
    "#eda100",  # yellow
    "#e87ba4",  # magenta
    "#008300",  # green
    "#4a3aa7",  # violet
    "#e34948",  # red
]
other_colour = "#9a9a96"
marker_shapes = ["o", "s", "^", "D", "v", "P", "X", "h"]
hatch_patterns = ["", "//", "\\\\", "xx", "..", "++", "oo", "--"]
sequential_cmap = "Blues"

# Default legend text and series name for the outlet cells. An analysis script
# can replace them with "label" and "series" in its response_spec["outlet"].
default_outlet_label = (
    "Outlet cell: fields with the 'outlet' rule are summed over these cells."
)
default_outlet_series = "sum over the outlet cells"


def outlet_text(data: dict) -> tuple[str, str]:
    """(legend label, series name) of the outlet cells recorded in ``data``.

    Falls back to the defaults for response caches written before these were
    recorded.
    """
    label = data.get("outlet_label", default_outlet_label)
    series = data.get("outlet_series", default_outlet_series)
    return str(np.asarray(label)), str(np.asarray(series))


def parameter_styles(ordered_names: list[str], n_colours: int = 8) -> dict:
    """Colour, marker and hatch per parameter, in the given order.

    Pass the parameters ordered by importance (e.g. the screening decision) so
    the most influential ones get the first colours. Parameters beyond
    ``n_colours`` are grey with a hollow marker.
    """
    styles = {}
    for i, name in enumerate(ordered_names):
        if i < min(n_colours, len(categorical_colours)):
            styles[name] = {
                "colour": categorical_colours[i],
                "marker": marker_shapes[i],
                "hatch": hatch_patterns[i],
                "coloured": True,
            }
        else:
            styles[name] = {
                "colour": other_colour,
                "marker": "o",
                "hatch": "",
                "coloured": False,
            }
    return styles


def _map_extent(x: np.ndarray, y: np.ndarray) -> list[float]:
    dx = (x[1] - x[0]) / 2 if len(x) > 1 else 50.0
    dy = abs(y[0] - y[1]) / 2 if len(y) > 1 else 50.0
    return [x.min() - dx, x.max() + dx, y.min() - dy, y.max() + dy]


def _format_map_axis(ax, *, left: bool, bottom: bool) -> None:
    ax.ticklabel_format(useOffset=False, style="plain")
    ax.tick_params(axis="x", labelrotation=45, labelsize=7, labelbottom=bottom)
    ax.tick_params(axis="y", labelsize=7, labelleft=left)
    if bottom:
        ax.set_xlabel("x (m)")
    if left:
        ax.set_ylabel("y (m)")


def draw_outlets(ax, marker_xy) -> bool:
    """White stars with black edge (visible on any fill); True if any drawn."""
    drawn = False
    if marker_xy is None:
        return drawn
    for mx, my in np.atleast_2d(marker_xy):
        if np.isfinite(mx) and np.isfinite(my):
            ax.plot(
                mx,
                my,
                marker="*",
                markersize=15,
                markerfacecolor="white",
                markeredgecolor="black",
                markeredgewidth=1.2,
                linestyle="none",
            )
            drawn = True
    return drawn


def outlet_legend_handle(label: str = default_outlet_label):
    """Legend entry explaining the star that marks an outlet cell."""
    from matplotlib.lines import Line2D

    return Line2D(
        [],
        [],
        marker="*",
        markersize=13,
        markerfacecolor="white",
        markeredgecolor="black",
        linestyle="none",
        label=label,
    )


def plot_maps(
    grids: dict[str, np.ndarray],
    x: np.ndarray,
    y: np.ndarray,
    *,
    title: str,
    colour_label: str,
    path: Path,
    marker_xy: np.ndarray | None = None,
    marker_label: str = default_outlet_label,
    vmax: float | None = 1.0,
    ncols: int = 2,
) -> None:
    """North-up x/y maps, one per entry of ``grids`` (each (ny, nx)).

    Laid out in ``ncols`` columns (2 x 2 for four maps) with one shared colour
    bar and a legend below explaining the outlet stars (``marker_label``).
    """
    plt = pyplot()
    n = len(grids)
    ncols = min(ncols, n)
    nrows = int(np.ceil(n / ncols))
    fig, axes = plt.subplots(
        nrows,
        ncols,
        figsize=(5.2 * ncols + 1.5, 4.9 * nrows + 1.3),
        squeeze=False,
        layout="constrained",
    )
    extent = _map_extent(x, y)
    image, drawn = None, False
    for index, (label, grid) in enumerate(grids.items()):
        ax = axes.flat[index]
        image = ax.imshow(
            grid,
            origin="upper",
            extent=extent,
            vmin=0,
            vmax=vmax,
            cmap=sequential_cmap,
            interpolation="nearest",
        )
        drawn |= draw_outlets(ax, marker_xy)
        ax.set_title(label, fontsize=11)
        row, col = divmod(index, ncols)
        _format_map_axis(
            ax, left=col == 0, bottom=row == nrows - 1 or index + ncols >= n
        )
    for ax in axes.flat[n:]:
        ax.set_visible(False)
    fig.colorbar(image, ax=axes, shrink=0.75, label=colour_label)
    fig.suptitle(title, fontsize=13)
    if drawn:
        fig.legend(
            handles=[outlet_legend_handle(marker_label)],
            loc="outside lower center",
            fontsize=9,
            frameon=False,
        )
    save_figure(fig, path)


def plot_heatmap(
    table: pd.DataFrame,
    *,
    title: str,
    colour_label: str,
    path: Path,
    xtick_step: int = 1,
    vmax: float | None = 1.0,
) -> None:
    """Heatmap of a parameter x column table (sequential, light = low)."""
    plt = pyplot()
    fig, ax = plt.subplots(
        figsize=(
            max(8, 0.55 * len(table.columns) / xtick_step + 5),
            0.42 * len(table) + 2.5,
        ),
        layout="constrained",
    )
    image = ax.imshow(
        table.to_numpy(float),
        aspect="auto",
        cmap=sequential_cmap,
        vmin=0,
        vmax=vmax,
        interpolation="nearest",
    )
    ax.set_yticks(range(len(table.index)))
    ax.set_yticklabels(table.index, fontsize=8)
    ticks = list(range(0, len(table.columns), xtick_step))
    ax.set_xticks(ticks)
    ax.set_xticklabels(
        [table.columns[i] for i in ticks], rotation=60, ha="right", fontsize=8
    )
    ax.set_title(title)
    fig.colorbar(image, ax=ax, label=colour_label)
    save_figure(fig, path)


# -----------------------------------------------------------------------------
# 6. Response specification record
# -----------------------------------------------------------------------------


def save_response_spec(spec: dict, path: Path) -> None:
    """Record the response specification used by an analysis."""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(
        json.dumps(spec, indent=2, sort_keys=True, default=str) + "\n"
    )


def compare_response_spec(spec: dict, other_path: Path | None) -> bool | None:
    """Compare with another analysis' recorded spec (e.g. Sobol vs Morris).

    Returns None when there is nothing to compare, else True/False and prints
    a warning when the two stages analysed different responses.
    """
    if not other_path or not Path(other_path).exists():
        print(f"Note: no recorded response spec at {other_path}; stages not compared.")
        return None
    same = json.loads(json.dumps(spec, sort_keys=True, default=str)) == json.loads(
        Path(other_path).read_text()
    )
    if not same:
        print(
            "Warning: the response specification differs from the one used in "
            f"{other_path}. Morris and Sobol results then describe different "
            "outputs and should not be compared directly."
        )
    return same
