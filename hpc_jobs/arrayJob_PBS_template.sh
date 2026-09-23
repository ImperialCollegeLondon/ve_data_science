#!/bin/bash  
#PBS -J 1-{n_subJobs}%{max_concurrent_jobs}  
#PBS -l select={select}  
#PBS -l walltime={walltime}  
#PBS -j oe  
#PBS -o {output_directory}/array_subJob_^array_index^/pbs.log  

set -euo pipefail  

JOB_OUTPUT_DIR="{output_directory}/array_subJob_$PBS_ARRAY_INDEX"  

cd "{root_directory}"  

{python_executable} -m hpc_jobs.run_subJob \
    "{arrayJob_config}" "$PBS_ARRAY_INDEX" "$JOB_OUTPUT_DIR"  
