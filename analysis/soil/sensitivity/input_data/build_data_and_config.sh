#!/bin/bash
#PBS -lwalltime=0:30:00
#PBS -lselect=1:ncpus=16:mem=16gb
#PBS -j oe
#PBS -o /rds/general/user/hlai1/home/logs/

# Initialise conda environment
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

Rscript analysis/soil/sensitivity/input_data/build_data_sensitivity.R
Rscript analysis/soil/sensitivity/input_data/build_config_sensitivity.R
Rscript analysis/soil/sensitivity/input_data/build_hpc_job_config.R

# submit this from the ve_data_science root directory with:
# qsub analysis/soil/sensitivity/input_data/build_data_and_config.sh
