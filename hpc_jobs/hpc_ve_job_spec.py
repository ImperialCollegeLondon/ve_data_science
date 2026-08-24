"""Validation and loading of HPC VE_run job specifications."""

import sys
import tomllib
from pathlib import Path
from typing import Any

from pydantic import Field, ValidationError
from pydantic.dataclasses import dataclass


@dataclass
class Job:
    """Defines an HPC VE_run job."""

    config_paths: list[str]
    name: str
    config: dict[str, Any]
    repeats: int = Field(default=1, ge=1)
    this_repeat: None | int = Field(init=False, default=None)


@dataclass
class JobSpec:
    """Defines a job specification."""

    common_config_paths: list[str]
    site_directory: str
    jobs: list[Job]

    n_jobs: int = Field(init=False)
    job_map: list[tuple[int, int]] = Field(init=False)

    def __post_init__(
        self,
    ) -> None:  
        """Populate the total number of jobs and map of jobs to repeats."""
        self.n_jobs = sum([j.repeats for j in self.jobs])
        self.job_map = [
            (n, i) for n, j in enumerate(self.jobs) for i in range(j.repeats)
        ]

    def get_job(self, array_index: int) -> Job:
        """Get the correct job for a job array index and make the name unique."""

        # I cant see how this would happen but just incase avoid a silent failure.
        if not 1 <= array_index <= self.n_jobs:
            raise ValueError(
                f"Job array index must be between 1 and {self.n_jobs}: {array_index}"
            )

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
    with open(job_file, "rb") as jobs:
        data = tomllib.load(jobs)

    if not data.get("jobs"):
        raise ValueError(
            "No jobs defined. Add at least one [[jobs]] section to the job configuration."
        )

    job_spec = JobSpec(**data)

    site_directory = Path(job_spec.site_directory)
    if not site_directory.is_dir():
        raise ValueError(
            f"Site directory does not exist or is not a directory: {site_directory}"
        )

    config_paths = {
        *job_spec.common_config_paths,
        *(path for job in job_spec.jobs for path in job.config_paths),
    }

    missing_paths = [
        str(site_directory / path)
        for path in config_paths
        if not (site_directory / path).is_file()
    ]

    if missing_paths:
        formatted_paths = "\n".join(f"  - {path}" for path in missing_paths)
        raise ValueError(f"Config files do not exist:\n{formatted_paths}")
    return job_spec


if __name__ == "__main__":
    try:
        spec = load_job_spec(Path(sys.argv[1]))
    except ValidationError as error:
        sys.stderr.write(f"Invalid job specification:\n{error}\n")
        sys.exit(1)
    except OSError as error:
        sys.stderr.write(f"Cannot open JOB_CONFIG.toml: {error}\n")
        sys.exit(1)
    except tomllib.TOMLDecodeError as error:
        sys.stderr.write(f"Invalid TOML syntax: {error}\n")
        sys.exit(1)
    except ValueError as error:
        sys.stderr.write(f"Invalid job specification:\n{error}\n")
        sys.exit(1)

    print(spec.n_jobs)

    sys.exit(0)
