"""Python script to run one array job from a batch job array specification."""

import os
import sys
from pathlib import Path

from virtual_ecosystem.main import ve_run

from hpc_jobs.parse_arrayJob_config import load_arrayJob_spec

# Get the command line arguments
batch_file = Path(sys.argv[1])
pbs_array_index = int(sys.argv[2])
output_dir = Path(sys.argv[3])

# Load batch job specification
with batch_file.open("rb") as array_job_file:
    arrayJob_spec = load_arrayJob_spec(array_job_file)

# the output however contains MANY files
# so we will likley need to stage the output directory (set to $TMPDIR)
# then compress into tarball and copy back to the final output location
# generating compressed zarr may resolve this issue.
# in the meantime... for small jobs, work from site dir.
os.chdir(arrayJob_spec.site_directory)

# Extract the job from the jobs spec by index
subJob = arrayJob_spec.get_subJob(pbs_array_index)

# Build into args for ve_run function
config_paths = [*arrayJob_spec.common_config_paths, *subJob.config_paths]
cli_config = subJob.cli_config

# check that the output directory exists
if not output_dir.is_dir():
    raise NotADirectoryError(f"Sub-job output directory not found: {output_dir}")

# Update the configuration to set the output directory for this sub-job.
core_config = cli_config.setdefault("core", {})
output_options = core_config.setdefault("data_output_options", {})
output_options["out_path"] = str(output_dir)
# print(f"[DEBUG] cli_config: {cli_config}", flush=True)

# 5. Start the run
ve_run(
    cfg_paths=config_paths,
    cli_config=cli_config,
    logfile=output_dir / "ve.log",
)
