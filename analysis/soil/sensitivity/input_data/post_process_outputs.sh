#!/bin/bash
#PBS -l select=1:ncpus=128:mem=512gb
#PBS -l walltime=12:00:00
#PBS -j oe
#PBS -o analysis/soil/sensitivity/input_data/pbs_logs/

set -euo pipefail

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is required}"

module load tools/prod
module load R/4.6.1-gfbf-2026.1
module load netCDF/4.10.0-gompi-2026.1

OUT_ROOT="data/sensitivity/soil_litter_inputs/out"
if [ ! -d "${OUT_ROOT}" ]; then
  echo "Missing output root directory: ${OUT_ROOT}"
  exit 1
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript is unavailable; load the project's R environment before submitting."
  exit 1
fi

Rscript analysis/soil/sensitivity/input_data/post_process_outputs.R

# submit this from the ve_data_science root directory with:
# Ensure the project R packages from renv.lock are restored first.
# mkdir -p analysis/soil/sensitivity/input_data/pbs_logs
# qsub analysis/soil/sensitivity/input_data/post_process_outputs.sh
