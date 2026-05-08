#!/bin/bash
#PBS -lwalltime=4:00:00
#PBS -lselect=1:ncpus=128:mem=512gb
#PBS -j oe
#PBS -o /rds/general/user/hlai1/home/logs/

# Initialise conda environment
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

Rscript analysis/soil/sensitivity/input_data/ve.R

# submit this from the ve_data_science root directory with:
# cd ../projects/virtual_rainforest/live/ve_data_science
# qsub analysis/soil/sensitivity/input_data/ve.sh
