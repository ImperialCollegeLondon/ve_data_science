"""Python script to run one array job from a batch job array specification."""

import os
import shutil
import sys
from pathlib import Path

from hpc_ve_run_job_spec import load_job_spec
from virtual_ecosystem.main import ve_run

# Get the command line arguments
batch_file = Path(sys.argv[1])
job_array_index = int(sys.argv[1])

# Load batch job specification
batch_job_spec = load_job_spec(batch_file)

# 1. Stage the site directory to the runner location to avoid multiple reading problem
#    This could also be done from the shell script but the TOML is easier to parse in
#    here
local_dir = os.getcwd()
site_dir = shutil.copytree(batch_job_spec.site_directory, local_dir)
os.chdir(site_dir)

# 2. Extract the job from the jobs spec by index
job = batch_job_spec.get_job(job_array_index)

# 3. Build into args for ve_run function
config_paths = [*batch_job_spec.common_config_paths, *job.config_paths]
cli_config = job.config

# 4. Setup output directory alongside batch file using the specified job name. Repeat
#    runs of the same job are nested as run_1, etc within the job name
if job.this_repeat is None:
    out_dir = batch_file.parent / job.name
else:
    out_dir = batch_file.parent / job.name / f"run_{job.this_repeat}"

os.makedirs(out_dir)

# Update the config to use that as the output directory.
cli_config["core.data_output_options.out_path"] = out_dir

# 5. Start the run
ve_run(
    config_paths=config_paths,
    cli_config=cli_config,
    log_file=out_dir / f"{job.name}.log",
)
