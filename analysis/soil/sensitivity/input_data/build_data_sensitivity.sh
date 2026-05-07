#!/bin/bash
#PBS -lwalltime=1:MM:00
#PBS -lselect=1:ncpus=1:mem=8gb

# Initialise conda environment
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate r452

# run from the submission directory (typically path/to/ve_data_science)
cd ${PBS_O_WORKDIR}

Rscript analysis/soil/sensitivity/input_data/build_data_sensitivity.R
