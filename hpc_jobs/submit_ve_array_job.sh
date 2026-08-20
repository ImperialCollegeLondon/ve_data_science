#!/bin/bash
set -euo pipefail # ensure script exits on error, unset variable, or failed pipe command
# add x to print every line, very helpful for debugging

# This script is used to submit a set of VE runs as an array job.
#
# Inputs:
# 1) the path to the batch submission TOML file
# 2) a new output directory for the array run
#
# Process:
# 1) hpc_ve_job_spec.py identifies the number of jobs to be submitted
# 2) qsub submits the array, with one PBS-ID output sub-directory per sub-job.
#

# ensure that the correct number of arguments are provided
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 JOB_CONFIG.toml OUTPUT_DIRECTORY" >&2
    exit 1
fi

# check that the job_config.toml file exists
if [[ ! -f "$1" ]]; then
    printf "Array job config file not found: %s\nPlease provide a valid path to the batch.\n" "$1" >&2
    exit 1
fi

# define the root of the repository, which is the parent directory of this script
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# activate virtual environment to access python, virtual ecosystem package, and dependencies.
source "$REPO_ROOT/.venv/bin/activate"
# confirm that the virtual environment is active.
echo "Activating virtual environment: $VIRTUAL_ENV"


VE_BATCH="$(realpath "$1")"
# print the job_config.toml file to the console for logging / debugging purposes
echo "Reading JOB-CONFIG.toml file: $VE_BATCH"

# Use hpc_jobs/hpc_ve_job_spec.py to get the number of jobs
NJOBS=$(cd "$REPO_ROOT" && python -m hpc_jobs.hpc_ve_job_spec "$VE_BATCH")
echo "Calculating number of jobs to submit... $NJOBS!"


# Use the user-provided path as the output directory for the complete array run.
RUN_OUTPUT_DIR="$(realpath -m "$2")"
echo "Run output directory selected: $RUN_OUTPUT_DIR"

# Do not overwrite an existing directory
if [[ -e "$RUN_OUTPUT_DIR" ]]; then
    printf "Output path already exists: %s\nPlease use a different path.\n" \
        "$RUN_OUTPUT_DIR" >&2
    exit 1
fi
mkdir -p "$RUN_OUTPUT_DIR"
echo "Run output directory created: $RUN_OUTPUT_DIR"


# Inform on what is about to happen
printf '%s\n' \
    "Submitting PBS array job" \
    "  Configuration File: $VE_BATCH" \
    "  Number of sub-jobs: $NJOBS" \
    "  Output directory: $RUN_OUTPUT_DIR" \
    "  Resources HARD-CODED: 1 CPU, 1 GB memory, 10 minutes walltime"

 # %20 limits the number of concurrently running array sub-jobs.
PBS_ARRAY_ID=$(qsub \
    -J "1-$NJOBS%20" \
    -o /dev/null \
    -e /dev/null \
    -v "VE_BATCH=$VE_BATCH,RUN_OUTPUT_DIR=$RUN_OUTPUT_DIR,REPO_ROOT=$REPO_ROOT" <<'PBS_SCRIPT'
#!/bin/bash
#PBS -lselect=1:ncpus=1:mem=1gb
#PBS -lwalltime=00:10:00

set -euo pipefail

JOB_OUTPUT_DIR="$RUN_OUTPUT_DIR/$PBS_JOBID"
mkdir "$JOB_OUTPUT_DIR"
exec >"$JOB_OUTPUT_DIR/pbs.log" 2>&1

cd "$REPO_ROOT"
source "$REPO_ROOT/.venv/bin/activate"

python -m hpc_jobs.hpc_ve_run_batch \
        "$VE_BATCH" "$PBS_ARRAY_INDEX" "$JOB_OUTPUT_DIR"
PBS_SCRIPT
)

printf '%s\n' \
    "Submitted." \
    "  PBS array ID: $PBS_ARRAY_ID" \
    "  Monitor with: qstat $PBS_ARRAY_ID" \
    "  Outputs will appear under: $RUN_OUTPUT_DIR"
