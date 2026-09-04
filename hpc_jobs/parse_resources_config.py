"""Loading and validation of PBS resource requests for VE array jobs."""

import tomllib
from typing import BinaryIO

from pydantic import Field
from pydantic.dataclasses import dataclass


@dataclass
class Resources:
    """PBS resource request for a single array sub-job."""

    # maximums set at to match node maximums, rather than realistic maximum values
    ncpus: int = Field(default=1, ge=1, le=128)
    mem_gb: int = Field(default=1, ge=1, le=4000)
    walltime_minutes: int = Field(default=10, ge=0, le=59)
    walltime_hours: int = Field(default=0, ge=0, le=59)
    max_concurrent_jobs: int = Field(default=20, ge=1, le=100)

    @property
    def select(self) -> str:
        """The PBS select statement."""
        # Single node request.
        return f"1:ncpus={self.ncpus}:mem={self.mem_gb}gb"

    @property
    def walltime(self) -> str:
        """The PBS walltime in HH:MM:SS."""
        return f"{self.walltime_hours:02d}:{self.walltime_minutes:02d}:00"


def load_resources_spec(resources_config_file: BinaryIO) -> Resources:
    """Load and validate a resources configuration file.

    Args:
        resources_config_file: A path to a TOML resources configuration.

    """

    resources_spec = tomllib.load(resources_config_file)

    return Resources(**resources_spec.get("resources", {}))
