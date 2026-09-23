"""Python script to run one subJob from a arrayJob specification."""

import os
import argparse 
from pathlib import Path
import shutil

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

# move to the site directory so any relative paths work correctly
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
# Use $TMPDIR as a staging area (due to the high file number of ZARR)
# Make a unique subdirectory for this sub-job within the staging area
staging_dir = Path(os.environ["TMPDIR"]).resolve() 
staging_dir = staging_dir / f"array_subJob_{pbs_array_index}"
staging_dir.mkdir(parents=True, exist_ok=True)

core_config = cli_config.setdefault("core", {})
output_options = core_config.setdefault("data_output_options", {})
output_options["out_path"] = str(staging_dir)

# using the try block to ensure cleanup of the staging directory
# even when ve_run fails.
try:

    # 5. Start the run
    ve_run(
        cfg_paths=config_paths,
        cli_config=cli_config,
        logfile=staging_dir / "ve.log",
        to_netcdf=True,
    )
finally:
    # remove the temporary Zarr output to reduce disk usage
    shutil.rmtree(staging_dir / "model_data.zarr", ignore_errors=True)

    # move outputs from the staging directory to the final output directory
    # this assumes the output_dir doesnt exist, but earlier we checked that it does not
    for item in staging_dir.iterdir():
        shutil.move(str(item), output_dir / item.name)
    staging_dir.rmdir()
