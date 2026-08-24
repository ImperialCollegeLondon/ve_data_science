"""Python script to run one array job from a batch job array specification."""

import os
import sys
from pathlib import Path

from virtual_ecosystem.main import ve_run

from hpc_jobs.hpc_ve_job_spec import load_job_spec

# Get the command line arguments
batch_file = Path(sys.argv[1])
job_array_index = int(sys.argv[2])
output_dir = Path(sys.argv[3])

# Load batch job specification
batch_job_spec = load_job_spec(batch_file)

# the output however contains MANY files
# so we will likley need to stage the output directory (set to $TMPDIR)
# then compress into tarball and copy back to the final output location 

# in the meantime... for small jobs, work from site dir.
os.chdir(batch_job_spec.site_directory)
print(f"[DEBUG] cd site dir: {os.getcwd()}", flush=True)

# 2. Extract the job from the jobs spec by index
job = batch_job_spec.get_job(job_array_index)

# 3. Build into args for ve_run function
config_paths = [*batch_job_spec.common_config_paths, *job.config_paths]
cli_config = job.config

print("[DEBUG] config_paths:", flush=True)
for p in config_paths:
    resolved = Path(p).resolve()
    print(f"  {p}  ->  {resolved}  exists={resolved.exists()}", flush=True)

# The PBS wrapper creates one output directory for each array sub-job.
# This tidy approach will scale up to the 5k+ jobs expected.
if not output_dir.is_dir():
    raise NotADirectoryError(f"Sub-job output directory not found: {output_dir}")
print(
    f"[DEBUG] output_dir: {output_dir.resolve()}  exists={output_dir.exists()}",
    flush=True,
)

# Update the config to use that as the output directory.
cli_config.setdefault("core", {})
cli_config["core"].setdefault("data_output_options", {})
cli_config["core"]["data_output_options"]["out_path"] = str(output_dir)
print(f"[DEBUG] cli_config: {cli_config}", flush=True)

# 5. Start the run
ve_run(
    cfg_paths=config_paths,
    cli_config=cli_config,
    logfile=output_dir / "ve.log",
)
