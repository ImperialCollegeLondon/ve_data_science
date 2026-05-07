#!/bin/bash
#PBS -lwalltime=0:30:00
#PBS -lselect=1:ncpus=1:mem=8gb

# Initialise conda environment
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# Set custom output/error files (using absolute path)
#PBS -o /rds/general/user/hlai1/home/logs/build_data_and_config.o$PBS_JOBID
#PBS -e /rds/general/user/hlai1/home/logs/build_data_and_config.e$PBS_JOBID

# run from the submission directory (typically path/to/ve_data_science)
cd ${PBS_O_WORKDIR}

Rscript analysis/soil/sensitivity/input_data/build_data_sensitivity.R
Rscript analysis/soil/sensitivity/input_data/build_config_sensitivity.R

# submit this from the ve_data_science root directory with:
# qsub analysis/soil/sensitivity/input_data/build_data_and_config.sh
