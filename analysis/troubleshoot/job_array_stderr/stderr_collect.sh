#!/bin/bash
#PBS -lwalltime=00:30:00
#PBS -lselect=1:ncpus=1:mem=8gb
#PBS -o /rds/general/user/hlai1/home/logs/
#PBS -e /rds/general/user/hlai1/home/logs/

# Initialise conda environment
module purge
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

Rscript analysis/troubleshoot/job_array_stderr/stderr_collect.R

# submit this from the ve_data_science root directory with:
# cd ../projects/virtual_rainforest/live/ve_data_science
# qsub analysis/troubleshoot/job_array_stderr/stderr_collect.sh
