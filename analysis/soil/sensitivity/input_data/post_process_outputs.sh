#!/bin/bash
#PBS -lwalltime=12:00:00
#PBS -lselect=1:ncpus=128:mem=512gb
#PBS -o /rds/general/user/hlai1/home/logs/
#PBS -e /rds/general/user/hlai1/home/logs/

# Initialise conda environment
module purge
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

Rscript analysis/soil/sensitivity/input_data/post_process_outputs.R

# submit this from the ve_data_science root directory with:
# cd ../projects/virtual_rainforest/live/ve_data_science
# qsub analysis/soil/sensitivity/input_data/post_process_outputs.sh
# scp hlai1@dtn-c.cx3.hpc.ic.ac.uk:/rds/general/user/hlai1/projects/virtual_rainforest/live/ve_data_science/data/scenarios/sensitivity_soil_litter/out/all_continuous_data_merged.parquet data/scenarios/sensitivity_soil_litter/out/all_continuous_data_merged.parquet
