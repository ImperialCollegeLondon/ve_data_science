"""Python script to run one subJob from a arrayJob specification."""

import os
import argparse 
from pathlib import Path

from virtual_ecosystem.main import ve_run

from hpc_jobs.parse_arrayJob_config import load_arrayJob_spec

# Get the command line arguments
def parse_args():  
    parser = argparse.ArgumentParser(  
        description="Process an array job configuration file for a given PBS array " \
        "index and write results to an output directory."  
    )  
    parser.add_argument(  
        "arrayJob_config_file",  
        type=Path,  
        help="Path to the array job configuration file."  
    )  
    parser.add_argument(  
        "pbs_array_index",  
        type=int,  
        help="PBS array job index (integer)."  
    )  
    parser.add_argument(  
        "output_dir",  
        type=Path,  
        help="Directory where output should be written."  
    )  
    return parser.parse_args()  


args = parse_args()  

arrayJob_config_file = args.arrayJob_config_file.resolve()
pbs_array_index = args.pbs_array_index  
output_dir = args.output_dir.resolve()


# Load ArrayJob specification
with arrayJob_config_file.open("rb") as array_job_file:
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
    raise NotADirectoryError(f"Sub-job output directory not found: \n{output_dir}")

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
