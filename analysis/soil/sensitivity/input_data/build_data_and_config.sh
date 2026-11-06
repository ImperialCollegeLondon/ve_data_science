#!/bin/bash
#PBS -l select=1:ncpus=64:mem=64gb
#PBS -l walltime=0:30:00
#PBS -j oe
#PBS -o analysis/soil/sensitivity/input_data/pbs_logs/

set -euo pipefail

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is required}"

module load tools/prod
module load R/4.6.1-gfbf-2026.1

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript is unavailable; load the project's R environment before submitting."
  exit 1
fi

Rscript analysis/soil/sensitivity/input_data/build_data_sensitivity.R
Rscript analysis/soil/sensitivity/input_data/build_config_sensitivity.R

# submit this from the ve_data_science root directory with:
# cd ve_data_science
# Ensure the project R packages from renv.lock are restored first.
# mkdir -p analysis/soil/sensitivity/input_data/pbs_logs
# qsub analysis/soil/sensitivity/input_data/build_data_and_config.sh
