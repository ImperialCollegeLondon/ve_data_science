"""Submit an array of Virtual Ecosystem jobs.

This file loads the job_array and resource configurations,
prepares the output directories, and submits an array using ``qsub``.
"""

import argparse
import subprocess
import sys
import tomllib
from collections.abc import Sequence
from pathlib import Path

from pydantic import ValidationError

from hpc_jobs.parse_arrayJob_config import load_arrayJob_spec
from hpc_jobs.parse_resources_config import load_resources_spec


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Submit Virtual Ecosystem runs as a PBS array job."
    )

    parser.add_argument(
        "arrayJob_config",
        type=Path,
        help="Path to the array job configuration TOML file.",
    )
    parser.add_argument(
        "pbs_resources_config",
        type=Path,
        help="Path to the PBS resources configuration TOML file.",
    )
    parser.add_argument(
        "output_directory",
        type=Path,
        help="New directory in which job outputs will be written.",
    )
    parser.add_argument(
        "--skip-ve-validation",
        action="store_true",
        help="Skip validation of individual Virtual Ecosystem configurations.",
    )
    return parser.parse_args(arguments)


def main() -> None:
    """Submit the PBS array job."""
    args = parse_args()
    print(f"Job configuration: {args.arrayJob_config}")
    print(f"Resources configuration: {args.pbs_resources_config}")
    print(f"Output directory: {args.output_directory}")

    # ensure output directory doesn't exist already
    if args.output_directory.exists():
        raise FileExistsError(
            f"Output directory exists: {args.output_directory}\n"
            "Exiting to avoid overwriting an existing directory."
        )

    # Validate the array job config and resources config using Pydantic
    # (as well as populate n_jobs and subjob_repeats_map)
    try:
        # load both configuration files
        with open(args.arrayJob_config, "rb") as arrayJob_file:
            arrayJob_spec = load_arrayJob_spec(arrayJob_file)
        with open(args.pbs_resources_config, "rb") as resources_file:
            resources_spec = load_resources_spec(resources_file)
    except OSError as error:
        sys.exit(f"Cannot read configuration file: {error}")
    except tomllib.TOMLDecodeError as error:
        sys.exit(f"Invalid TOML syntax: {error}")
    except ValidationError as error:
        sys.exit(f"Invalid configuration:\n{error}")

    # Validate that all config paths exist relative to the site directory.
    site_directory = arrayJob_spec.site_directory.resolve()

    # Optional to allow for running of arrays where not all configurations are valid.
    if not args.skip_ve_validation:
        print("Loading Virtual Ecosystem...", flush=True)

        from virtual_ecosystem.core.exceptions import ConfigurationError
        from virtual_ecosystem.core.logger import LOGGER
        from virtual_ecosystem.main import ve_run

        for subJob_index, subJob in enumerate(arrayJob_spec.subJobs, start=1):
            subJob_config_paths = [
                site_directory / path
                for path in (*arrayJob_spec.common_config_paths, *subJob.config_paths)
            ]
            try:
                LOGGER.disabled = True
                ve_run(
                    cfg_paths=subJob_config_paths,
                    cli_config=subJob.cli_config,
                    validate_only=True,
                )
            except ConfigurationError as error:
                raise ValueError(
                    f"Invalid Virtual Ecosystem config for subJob: {subJob_index} \n"
                    f"{error}"
                ) from error
            finally:
                LOGGER.disabled = False
        print("Virtual Ecosystem configurations validated.")
    else:
        print("Skipping Virtual Ecosystem configuration validation.")

    # Inform user of progress
    print("Configuration files processed and validated.")
    print(f"Number of subJobs: {arrayJob_spec.n_subJobs}")
    print("Per subJob Resources:")
    print(f"  Maximum concurrent subJobs: {resources_spec.max_concurrent_jobs}")
    print(f"  Number of CPUs: {resources_spec.ncpus}")
    print(f"  Memory: {resources_spec.mem_gb} GB")
    print(f"  Walltime: {resources_spec.walltime}")

    # Create the output directory now that configs and inputs have been validated.
    args.output_directory.mkdir(parents=True)
    print("Generated output directories")
    # create subdirectories for each job
    for pbs_array_index in range(1, arrayJob_spec.n_subJobs + 1):
        (args.output_directory / f"array_subJob_{pbs_array_index}").mkdir()

    # resolve paths before running qsub
    arrayJob_config = args.arrayJob_config.resolve()
    output_directory = args.output_directory.resolve()
    root_directory = Path(__file__).resolve().parent.parent

    # Define the PBS script for the array job
    pbs_script = f"""\
#!/bin/bash
set -euo pipefail

JOB_OUTPUT_DIR="$RUN_OUTPUT_DIR/array_subJob_$PBS_ARRAY_INDEX"

cd "$ROOT_DIRECTORY"

{sys.executable} -m hpc_jobs.run_subJob \
    "$VE_BATCH" "$PBS_ARRAY_INDEX" "$JOB_OUTPUT_DIR"
"""

    # define the qsub command with resource specifications and environment variables
    qsub_command = [
        "qsub",
        "-J",
        f"1-{arrayJob_spec.n_subJobs}%{resources_spec.max_concurrent_jobs}",
        f"-lselect={resources_spec.select}",
        f"-lwalltime={resources_spec.walltime}",
        "-j",
        "oe",
        "-o",
        str(output_directory / "array_subJob_^array_index^" / "pbs.log"),
        "-v",
        (
            f"VE_BATCH={arrayJob_config},"
            f"RUN_OUTPUT_DIR={output_directory},"
            f"ROOT_DIRECTORY={root_directory}"
        ),
    ]

    # submit the array job
    process = subprocess.run(
        qsub_command,
        input=pbs_script,
        capture_output=True,
        text=True,
        check=False,
    )
    if process.returncode != 0:
        sys.stderr.write(f"Failed to submit array job:\n{process.stderr}\n")
        sys.exit(1)
    else:
        print(f"Array job submitted successfully:\n{process.stdout}")


if __name__ == "__main__":
    main()