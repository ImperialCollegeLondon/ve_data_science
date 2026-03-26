#PBS -lselect=1:ncpus=1:mem=128gb
#PBS -lwalltime=24:00:00
#PBS -j oe

# This file should not be submitted directly, but should be submitted using
# hpc_ve_run_batch_submit.sh. This is used to correctly specify the directory to be used
# for PBS outputs (-o flag) and job array setup (-J flag) and to provide the location of
# the batch file

# Setup the environment
module load

# Send job details to the Python code to run the job
python hpc_ve_run_batch.py $VE_BATCH $PBS_ARRAY_INDEX
