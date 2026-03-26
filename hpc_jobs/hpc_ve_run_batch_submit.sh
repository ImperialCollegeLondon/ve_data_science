#! /bin/bash

# This script is used to batch submit a set of VE runs as an array job to run in
# parallel.
#
# This script is needed to set up the qsub with:
# 1) the number of array jobs to be specified and
# 2) the path for the qsub output files
#
# It should be called with the batch submission TOML as the only argument

if [ ! -f $1 ]; then
    echo "Batch job file not found!"
    exit 1
fi

# Count the number of job description lines in the input file and strip whitespace
NJOBS=$(grep '\[jobs\.' $1 | wc -l | xargs)

# Use a folder in the batch file location as the output directory and use this as
# canary for previous outputs to the same location.
ROOT_DIR=$(dirname $1)
PBS_OUT_DIR="$ROOT_DIR/pbs_outputs"

if [ -d $PBS_OUT_DIR ]; then
    echo "PBS output directory already present, remove previous results?"
    exit 1
fi

mkdir $PBS_OUT

# Create an output filename that contains the obscure PBS tag for the job array index
SCRIPT_NAME=$(basename $1)
SCRIPT_NAME=${SCRIPT_NAME//.toml/}
OUTPUT_FILES="$PBS_OUT_DIR/${SCRIPT_NAME}_^array_index^.out"

# Inform on what is about to happen
echo -e "Submitting $NJOBS jobs in:
$1

Executing:
qsub
   -J 1-$NJOBS
   -o $OUTPUT_FILES
   -v VE_BATCH=$1
   hpc_ve_run.sh
"


qsub -J 1-$NJOBS -o $OUTPUT_FILES -v VE_BATCH=$1 hpc_ve_run_batch.sh
