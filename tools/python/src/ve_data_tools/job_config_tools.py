"""
---
title: Utility functions for generating Virtual Ecosystem HPC job configuration

description: |
  This module provides reusable utility functions for generating Virtual
  Ecosystem High Performance Computing (HPC) job configuration files.

  Its primary role is to take parameter samples produced by global sensitivity
  analysis methods (such as Sobol or Morris sampling) and translate them into
  the `job_config.toml` format required by the Virtual Ecosystem batch
  simulation workflow. Each row of sampled parameter values becomes a distinct
  simulation job definition, ensuring that large-scale sensitivity experiments
  can be executed consistently across HPC environments.

  The generated configuration file contains:
    - **Shared model configuration**: A list of `common_config_paths` pointing
      to base configuration files that apply to all runs.
    - **Scenario data directory**: The `site_directory` path, which specifies
      the input datasets (e.g. climate, soil, plant, animal) copied to compute
      nodes before execution.
    - **Individual job entries**: Each `[[jobs]]` block includes a unique run
      name, repeat count, optional per-job configuration files, and a
      `[jobs.config]` section with parameter overrides corresponding to the
      sampled values.

virtual_ecosystem_module:
    -All

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

    # Convert Path objects to strings for TOML serialization
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
        jobs.append(job)  # ✅ ensure this is inside the loop

    data = {
        "common_config_paths": common_config_paths,
        "site_directory": site_directory,
        "jobs": jobs,
    }

    # Write TOML file using tomli_w
    with open(output_file, "wb") as f:
        tomli_w.dump(data, f)

    # Return metadata
    return {
        "num_jobs": len(samples),
        "output_file": str(output_file.resolve()),
        "parameters": parameter_names,
    }
