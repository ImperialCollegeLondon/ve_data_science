"""Python script to run one array job from a batch job array specification."""

import os
import shutil
import sys

import tomllib
from virtual_ecosystem.main import ve_run

# Get the command line arguments
batch_file = sys.argv[1]
job_array_index = int(sys.argv[1])

# Load batch job specification
with open(batch_file, "rb") as batch:
    batch_job_spec = tomllib.load(batch)

# Should probably validate the config file here with a simple pydantic model.


# 1. Stage the site directory to the runner location to avoid multiple reading problem
#    This could also be done from the shell script but the TOML is easier to parse in
#    here
local_dir = os.getcwd()
site_dir = shutil.copytree(batch_job_spec["site_directory"], local_dir)
os.chdir(site_dir)

# 2. Extract the job from the jobs spec by index
job_spec = batch_job_spec["jobs"][job_array_index]

# 3. Build into args for ve_run function
config_paths = [*batch_job_spec["common_config_paths"], *job_spec["config_paths"]]
cli_config = job_spec["config"]  # Might need more work

# 3. Start the run
ve_run(config_paths=config_paths, cli_config=cli_config)

# 4. Stage the model outputs back to scenario directory.
