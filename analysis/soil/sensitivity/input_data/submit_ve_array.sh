#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

DATA_DIR="data/sensitivity/soil_litter_inputs/data"
OUT_ROOT="data/sensitivity/soil_litter_inputs/out"
SCENARIO_COUNT_FILE="${DATA_DIR}/n_scenarios.txt"
MAX_CONCURRENT_JOBS=100

if [[ ! -f "${SCENARIO_COUNT_FILE}" ]]; then
  echo "Missing scenario count: ${SCENARIO_COUNT_FILE}"
  exit 1
fi

N_RUNS="$(cat "${SCENARIO_COUNT_FILE}")"
if [[ ! "${N_RUNS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid scenario count in ${SCENARIO_COUNT_FILE}: ${N_RUNS}"
  exit 1
fi
if [[ -e "${OUT_ROOT}" ]]; then
  echo "Refusing to overwrite existing output directory: ${OUT_ROOT}"
  exit 1
fi

# Install the locked PyPI VE release once before the array starts.
uv sync --locked
mkdir -p analysis/soil/sensitivity/input_data/pbs_logs
qsub -J "1-${N_RUNS}%${MAX_CONCURRENT_JOBS}" \
  analysis/soil/sensitivity/input_data/ve.sh
