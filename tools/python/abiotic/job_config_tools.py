"""
---
title: Utility functions for generating Virtual Ecosystem HPC job configuration

description: |
  This module provides reusable utility functions for generating Virtual
  Ecosystem High Performance Computing (HPC) job configuration files.

  The utilities convert sampled parameter values produced by global
  sensitivity analysis methods (e.g. Sobol or Morris sampling) into the
  `job_config.toml` format required by the Virtual Ecosystem HPC batch
  workflow.

  The generated configuration file defines the shared model configuration,
  scenario data directory and individual simulation runs.

  It is designed to bridge sampling outputs (for example Sobol or Morris sample
  generator) and the `job_config.toml` structure expected by the batch workflow.
  For each sampled parameter set, the module writes one `[[jobs]]` entry with a
  unique run name, repeat count, optional per-job configuration files, and a
  `[jobs.config]` block of parameter overrides.

  The generated file also includes shared settings (`common_config_paths` and
  `site_directory`) that apply to all runs. This allows large parameter sweeps
  to be generated reproducibly and consistently across experiments.

virtual_ecosystem_module: all

author:
  - Lelavathy

status: final

package_dependencies:
  - pathlib
  - numpy
  - tomli_w

usage_notes: |
  This module is intended to be imported by sensitivity analysis scripts
  and should not normally be executed directly.

  The generated configuration file is compatible with the existing
  Virtual Ecosystem HPC batch workflow.
---
"""  # noqa: D400, D205, D212, D415

from pathlib import Path

import numpy as np
import tomli_w

# =============================================================================
# GENERATE JOB CONFIGURATION
# =============================================================================
# Create a `job_config.toml` file from sampled parameter values so that each
# sample becomes one HPC simulation job with shared and per-job settings.


def generate_job_config(
    samples: np.ndarray,
    parameter_names: list[str],
    common_config_paths: list[str | Path],
    site_directory: str | Path,
    output_file: str | Path,
    config_paths: list[str | Path] | None = None,
    repeats: int = 1,
) -> dict:
    """Generate a Virtual Ecosystem HPC job configuration file.

    The generated TOML file contains one job definition for every sampled
    parameter set.

    Args:
        samples:
            Matrix of sampled parameter values.

        parameter_names:
            Virtual Ecosystem parameter names corresponding to the columns
            of ``samples``.

        common_config_paths:
            Configuration files shared by every simulation.

        site_directory:
            Scenario data directory copied to the compute node before
            execution.

        output_file:
            Path to the generated ``job_config.toml`` file.

        config_paths:
            Optional configuration files specific to each job.

        repeats:
            Number of repeated simulations for each parameter set.

    Returns:
        dict: Metadata including number of jobs, output file path, and parameter names.

    Raises:
        ValueError:
            If the number of parameter names does not match the number of
            sample columns.

    """

    output_file = Path(output_file)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    # Convert Path objects to strings for TOML serialization.
    common_config_paths = [str(path) for path in common_config_paths]

    site_directory = str(site_directory)

    if config_paths is None:
        config_paths = []
    else:
        config_paths = [str(path) for path in config_paths]

    if samples.shape[1] != len(parameter_names):
        raise ValueError("Number of parameter names does not match sample columns.")

    # Build structured TOML data
    jobs = []
    for run_id, values in enumerate(samples, start=1):
        job = {
            "name": f"run_{run_id:04d}",
            "repeats": repeats,
            "config": {
                parameter: (
                    float(value) if isinstance(value, (float, np.floating)) else value
                )
                for parameter, value in zip(parameter_names, values)
            },
        }

    if config_paths:
        job["config_paths"] = config_paths

    jobs.append(job)

    data = {
        "common_config_paths": [str(c) for c in common_config_paths],  # convert to str
        "site_directory": str(site_directory),  # ensure string
        "jobs": jobs,
    }

    # Write TOML file using tomli_w
    with open(output_file, "wb") as f:
        tomli_w.dump(data, f)

    # Return metadata instead of printing
    return {
        "num_jobs": len(samples),
        "output_file": str(output_file.resolve()),
        "parameters": parameter_names,
    }
