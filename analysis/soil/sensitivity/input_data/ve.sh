#!/bin/bash
#PBS -lwalltime=1:00:00
#PBS -lselect=1:ncpus=1:mem=4gb
#PBS -J 1-4800%100
#PBS -j oe
#PBS -o /rds/general/user/hlai1/home/logs/sensitivity/job_^array_index^.out

set -euo pipefail

# Initialise conda environment
module purge
eval "$(~/miniforge3/bin/conda shell.bash hook)"
# conda activate r452
conda activate /rds/general/project/virtual_rainforest/live/ve_data_science/hpc_jobs/virtual_ecosystem_py314

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR}" || exit

CONFIG_DIR="data/scenarios/sensitivity_soil_litter/config"
DATA_DIR="data/scenarios/sensitivity_soil_litter/data"
OUT_ROOT="data/scenarios/sensitivity_soil_litter/out"
truncate_update=24

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
  echo "PBS_ARRAY_INDEX is not set."
  exit 1
fi

SOIL_LITTER_FILE="${DATA_DIR}/soil_litter_data_${PBS_ARRAY_INDEX}.nc"
if [ ! -f "${SOIL_LITTER_FILE}" ]; then
  echo "Missing input file: ${SOIL_LITTER_FILE}"
  exit 1
fi
if [ ! -d "${CONFIG_DIR}" ]; then
  echo "Missing config directory: ${CONFIG_DIR}"
  exit 1
fi

# create output directory if it does not exist
OUTDIR="${OUT_ROOT}/${PBS_ARRAY_INDEX}"
mkdir -p "${OUTDIR}"

# Run VE
ve_run \
  "${CONFIG_DIR}" \
  -p SOIL_LITTER_DATA="${SOIL_LITTER_FILE}" \
  --out "${OUTDIR}" \
  --logfile "${OUTDIR}/logfile.log" \
  --config core.debug.truncate_run_at_update=${truncate_update}

# run R script
# Rscript analysis/soil/sensitivity/input_data/ve.R

# submit this from the ve_data_science root directory with:
# cd ../projects/virtual_rainforest/live/ve_data_science
# rm -rf data/scenarios/sensitivity_soil_litter/out/*
# qsub analysis/soil/sensitivity/input_data/ve.sh
