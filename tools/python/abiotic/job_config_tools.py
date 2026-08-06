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

usage_notes: |
  This module is intended to be imported by sensitivity analysis scripts
  and should not normally be executed directly.

  The generated configuration file is compatible with the existing
  Virtual Ecosystem HPC batch workflow.
---
"""  # noqa: D400, D205, D212, D415

from pathlib import Path

import numpy as np

# =============================================================================
# GENERATE JOB CONFIGURATION
# =============================================================================
# Create a `job_config.toml` file from sampled parameter values so that each
# sample becomes one HPC simulation job with shared and per-job settings.


def generate_job_config(
    samples: np.ndarray,
    parameter_names: list[str],
    common_config_paths: list[str],
    site_directory: str,
    output_file: str | Path,
    config_paths: list[str] | None = None,
    repeats: int = 1,
) -> None:
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

    Raises:
        ValueError:
            If the number of parameter names does not match the number of
            sample columns.

    """

    output_file = Path(output_file)

    output_file.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    if config_paths is None:
        config_paths = []

    if samples.shape[1] != len(parameter_names):
        raise ValueError("Number of parameter names does not match sample columns.")

    with open(output_file, "w") as file:
        # ==============================================================
        # Common configuration
        # ==============================================================
        # Write settings shared by all runs, including base config paths
        # and the scenario site directory.

        file.write("common_config_paths = [\n")

        for config in common_config_paths:
            file.write(f'    "{config}",\n')

        file.write("]\n\n")

        file.write(f'site_directory = "{site_directory}"\n\n')

        # ==============================================================
        # Individual simulation jobs
        # ==============================================================
        # Write one `[[jobs]]` block per sample with run name, repeats,
        # optional job-specific config paths, and parameter overrides.

        for run_id, values in enumerate(samples, start=1):
            file.write("[[jobs]]\n")

            file.write("config_paths = [")

            if config_paths:
                file.write(",".join(f'"{config}"' for config in config_paths))

            file.write("]\n")

            file.write(f'name = "run_{run_id:04d}"\n')

            file.write(f"repeats = {repeats}\n\n")

            file.write("[jobs.config]\n")

            for parameter, value in zip(
                parameter_names,
                values,
            ):
                if isinstance(
                    value,
                    (float, np.floating),
                ):
                    file.write(f'"{parameter}" = {value:.12g}\n')
                else:
                    file.write(f'"{parameter}" = {value}\n')

            file.write("\n")

    print("=" * 60)
    print("Virtual Ecosystem job configuration generated successfully")
    print("=" * 60)
    print(f"Simulation runs : {len(samples)}")
    print(f"Output file     : {output_file.resolve()}")
