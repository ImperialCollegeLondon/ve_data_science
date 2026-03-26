"""Python script to run one array job from a batch job array specification."""

import sys

import tomllib
from virtual_ecosystem.main import ve_run

# Get the command line arguments
batch_file = sys.argv[1]
job_array_index = int(sys.argv[1])

# Load batch job specification
with open(batch_file, "rb") as batch:
    batch_job_spec = tomllib.load(batch)

# TODO:
# 1. Stage the site directory to the runner location to avoid multiple reading problem
#    This could also be done from the shell script but the TOML is easier to parse in
#    here


# 2. Extract the job from the jobs spec by index and do any formatting required
#   TODO - Currently comes in as a dictionary. If tomllib does not preserve dictionary
#          order on load this would shuffle jobs. Might be easier as an array in TOML
#          but the syntax is clumsier
job_spec = batch_job_spec["jobs"][job_array_index]

# 3. Setup the output directory for the job - basically make sure job_spec is a dict
#    that ve_run can use.


# 4. Start the run

ve_run(config_paths=batch_job_spec["config_paths"], cli_config=job_spec)
