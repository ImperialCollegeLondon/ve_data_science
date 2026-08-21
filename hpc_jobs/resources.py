"""Loading and validation of PBS resource requests for VE array jobs."""

import sys
import tomllib
from pathlib import Path

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


def load_resources(resources_config_file: Path) -> Resources:
    """Load and validate a resources configuration file.

    Args:
        resources_config_file: A path to a TOML resources configuration.
    """

    with open(resources_config_file, "rb") as handle:
        data = tomllib.load(handle)

    return Resources(**data.get("resources", {}))


if __name__ == "__main__":

    # this should not really be invoked because the script will be run in submit_ve_array_job.sh 
    # (with its own checks)
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: python resources.py <resources_config.toml>\n")
        sys.exit(1)

    resources_config_path = Path(sys.argv[1])

    try:
        resources = load_resources(resources_config_path)
    except Exception as excep:
        sys.stderr.write(f"config cannot be loaded from: {resources_config_path}:\n{excep}\n")
        sys.exit(1)

    # Emitted as shell assignments for eval by submit_ve_array_job.sh.
    print(f"PBS_SELECT='{resources.select}'")
    print(f"PBS_WALLTIME='{resources.walltime}'")
    print(f"MAX_CONCURRENT='{resources.max_concurrent_jobs}'")

    sys.exit(0)


