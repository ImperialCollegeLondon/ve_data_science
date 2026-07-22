#PBS -lselect=1:ncpus=1:mem=128gb
#PBS -lwalltime=24:00:00
#PBS -j oe

# This file should not be submitted directly, but should be submitted using
# hpc_ve_run_batch_submit.sh.
#
# This submission script submits a job that extends the PBS spec above using command
# line arguments to:
#
# * specify the directory to be used for PBS outputs (-o flag)
# * set the job array setup (-J flag) to match the number of jobs in batch config, and
# * pass in the location of the batch file as an environment variable to this scripts
#   using "-v VE_BATCH=/path/to/batch.toml"

# Setup the environment activating the pre-built shared conda venv.
module load miniforge/3
conda activate /rds/general/project/virtual_rainforest/live/ve_data_science/hpc_jobs/virtual_ecosystem_py314

# Send job details to the Python code to run the job
python hpc_ve_run_batch.py $VE_BATCH $PBS_ARRAY_INDEX

# Tidy up
conda deactivate
module unload miniforge/3
