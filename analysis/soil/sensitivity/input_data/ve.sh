#!/bin/bash
#PBS -l select=1:ncpus=1:mem=4gb
#PBS -l walltime=1:00:00
#PBS -j oe

set -euo pipefail

# run from the submission directory (typically path/to/ve_data_science)
cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is required}"

CONFIG_DIR="data/sensitivity/soil_litter_inputs/config"
DATA_DIR="data/sensitivity/soil_litter_inputs/data"
OUT_ROOT="data/sensitivity/soil_litter_inputs/out"
TRUNCATE_AT_UPDATE=24

if [[ -z "${PBS_ARRAY_INDEX:-}" ]]; then
  echo "PBS_ARRAY_INDEX is not set."
  exit 1
fi

SOIL_LITTER_FILE="${DATA_DIR}/soil_litter_data_${PBS_ARRAY_INDEX}.nc"
OUTDIR="${OUT_ROOT}/array_subJob_${PBS_ARRAY_INDEX}"

if [ ! -f "${SOIL_LITTER_FILE}" ]; then
  echo "Missing input file: ${SOIL_LITTER_FILE}"
  exit 1
fi
if [ ! -f "${CONFIG_DIR}/config.toml" ]; then
  echo "Missing config file: ${CONFIG_DIR}/config.toml"
  exit 1
fi
if [ -e "${OUTDIR}" ]; then
  echo "Refusing to overwrite existing output directory: ${OUTDIR}"
  exit 1
fi

mkdir -p "${OUTDIR}"
exec > "${OUTDIR}/pbs.log" 2>&1

# Preserve Zarr output; the generic HPC runner converts it to NetCDF and removes
# the store after each run.

# Run the PyPI release pinned by uv.lock; the submitter prepares the environment.
uv run --locked --no-sync ve_run \
  "${CONFIG_DIR}/config.toml" \
  -p SOIL_LITTER_DATA="${SOIL_LITTER_FILE}" \
  -c "core.debug.truncate_run_at_update=${TRUNCATE_AT_UPDATE}" \
  --outpath "${OUTDIR}" \
  --logfile "${OUTDIR}/logfile.log"

# Submit from the repository root with:
# cd ve_data_science
# Generate the input data and compiled config before submitting this array.
# bash analysis/soil/sensitivity/input_data/submit_ve_array.sh
