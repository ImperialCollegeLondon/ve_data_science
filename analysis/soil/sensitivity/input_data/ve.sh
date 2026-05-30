#!/bin/bash
#PBS -lwalltime=1:00:00
#PBS -lselect=1:ncpus=1:mem=4gb
#PBS -J 1-4800%100
#PBS -o /rds/general/user/hlai1/home/logs/
#PBS -e /rds/general/user/hlai1/home/logs/

# Initialise conda environment
module purge
eval "$(~/miniforge3/bin/conda shell.bash hook)"
# conda activate r452
conda activate /rds/general/project/virtual_rainforest/live/ve_data_science/hpc_jobs/virtual_ecosystem_py314

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

# create output directory if it does not exist
OUTDIR="data/scenarios/sensitivity_soil_litter/out/${PBS_ARRAY_INDEX}"
mkdir -p "${OUTDIR}"

# Run VE
ve_run \
  data/scenarios/sensitivity_soil_litter/config \
  -p SOIL_LITTER_DATA="data/scenarios/sensitivity_soil_litter/data/soil_litter_data_${PBS_ARRAY_INDEX}.nc" \
  --out "${OUTDIR}" \
  --logfile "${OUTDIR}/logfile.log" \
  --config core.debug.truncate_run_at_update=24

# run R script
# Rscript analysis/soil/sensitivity/input_data/ve.R

# submit this from the ve_data_science root directory with:
# cd ../projects/virtual_rainforest/live/ve_data_science
# qsub analysis/soil/sensitivity/input_data/ve.sh
