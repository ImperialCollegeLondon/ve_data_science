"""Load and validate Virtual Ecosystem array job configurations."""

import tomllib
from pathlib import Path
from typing import Any, BinaryIO

from pydantic import DirectoryPath, Field
from pydantic.dataclasses import dataclass


@dataclass
class SubJob:
    """Defines a single sub-job."""

    config_paths: list[Path]
    cli_config: dict[str, Any]
    repeats: int = Field(default=1, ge=1)


@dataclass
class arrayJobSpec:
    """Defines the whole arrayJob."""

    common_config_paths: list[Path]
    site_directory: DirectoryPath
    subJobs: list[SubJob] = Field(min_length=1)

    n_subJobs: int = Field(init=False)
    subjob_repeats_map: list[int] = Field(init=False)

    def __post_init__(
        self,
    ) -> None:
        """Map each PBS array index to a configured job.

        Repeated jobs occupy consecutive array indices. For example, if job 1 has
        repeats = 3, and jobs 2 and 3 are not repeated the resulting map would be:
        ``[0, 0, 0, 1, 2]``.
        """
        self.subjob_repeats_map = [
            job_index
            for job_index, job in enumerate(self.subJobs)
            for _ in range(job.repeats)
        ]
        # calculate the total number of subJobs (inc repeats) based on the job map.
        self.n_subJobs = len(self.subjob_repeats_map)

    def get_subJob(self, array_index: int) -> SubJob:
        """Get the correct job for a job array index."""

        # Get the job index from the job map and return the corresponding job.
        job_index = self.subjob_repeats_map[array_index - 1]

        # Return the corresponding job.
        return self.subJobs[job_index]


def load_arrayJob_spec(arrayJob_file: BinaryIO) -> arrayJobSpec:
    """Load and validate an array job config file.

    Args:
        arrayJob_file: A TOML array job configuration as a binary file.

    Returns:
        An instance of ``arrayJobSpec`` representing the loaded array job configuration.

    """
    arrayJob_config = tomllib.load(arrayJob_file)
    # Validate the job specification using Pydantic
    # (calls the __post_init__ method to populate n_subJobs and subjob_repeats_map)
    arrayJob_spec = arrayJobSpec(**arrayJob_config)

    return arrayJob_spec
