"""Validation and loading of HPC VE_run job specifications."""

import sys
from dataclasses import field
from pathlib import Path
from typing import Any

import tomllib
from pydantic.dataclasses import dataclass


@dataclass
class Job:
    """Defines an HPC VE_run job."""

    config_paths: list[str]
    name: str
    repeats: int = 1
    config: dict[str, Any]
    this_repeat: None | int = field(init=False, default=None)


@dataclass
class JobSpec:
    """Defines a job specification."""

    common_config_paths: list[str]
    site_directory: str
    jobs: list[Job]

    n_jobs: int = field(init=False)
    job_map: list[tuple[int, int]] = field(init=False)

    def __post_init_post_parse__(self) -> None:
        """Populate the total number of jobs and map of jobs to repeats."""
        self.n_jobs = sum([j.repeats for j in self.jobs])
        self.job_map = [
            (n, i) for n, j in enumerate(self.jobs) for i in range(j.repeats)
        ]

    def get_job(self, array_index: int) -> Job:
        """Get the correct job for a job array index and make the name unique."""

        # The array index job numbers are 1-N
        job_idx, rep = self.job_map[array_index - 1]

        job = self.jobs[job_idx]

        if job.repeats > 1:
            job.this_repeat = rep

        return job


def load_job_spec(job_file: Path) -> JobSpec:
    """Load and validate a job specification file.

    Args:
        job_file: A path to a TOML job specification.

    """
    try:
        with open(job_file, "rb") as jobs:
            data = tomllib.load(jobs)
    except Exception:
        print("Error parsing TOML in job file.")
        raise

    try:
        job_spec = JobSpec.model_validate(data)
    except Exception:
        print("TOML job specification contains errors.")
        raise

    return job_spec


if __name__ == "__main__":
    try:
        spec = load_job_spec(Path(sys.argv[1]))
    except Exception:
        sys.stderr.write("Cannot load job specification\n")
        sys.exit(1)

    print(spec.n_jobs)

    sys.exit(0)
