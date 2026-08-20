# Running Virtual Ecosystem on the HPC

*Author: moi-taiga*
#### Note: this is an early draft, do suggest edits!

Tntroduction to submitting Virtual Ecosystem runs as a PBS array job on
the HPC cluster. The workflow was developed for the CX3 cluster, which uses the
PBS job scheduler. CX3 is scheduled to be shut down in May 2027.

### Before you start

You need:

- a terminal;
- access to CX3

## Connect to the HPC using SSH

Use SSH to access the cx3 cluster; you will be required to use your password for authentication.

```bash
ssh userid@login.cx3.hpc.imperial.ac.uk
```

See the [Imperial RCS documentation](https://icl-rcs-user-guide.readthedocs.io/en/latest/hpc/getting-started/) for further information about connecting to the cluster.
If you are new to HPC environments, do make sure that you familiarise yourself with the documentation. 

importantly: Login nodes are intended for tasks such as editing files, preparing jobs, and
submitting jobs. Computationally intensive work should be submitted to compute
nodes through PBS.

## Clone the repository

Keep a personal checkout (like you would locally) rather than working from a
shared project directory. This avoids conflicts with other users' files.

```bash
cd ~
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
cd ve_data_science
```

## Install `uv` and create a virtual environment

See .\docs\uv_setup.md for instructions about using uv.

**note:** If you are using R, conda may be better suited than uv.

**note:** for test runs with the example data I use:
```bash
uv venv
uv pip install virtual-ecosystem`
```
as it installs a version of Veco which is compatable with the example. 

## Install the example data/configs

For testing the HPC workflow, install the example data and configuration files:

```bash
ve_run --install-example .
```

## Create a batch job configuration

Create a TOML batch configuration using your prefered sampling method, e.g.
Morris, Sobol, or Latin hypercube sampling. A small example is available in
`hpc_jobs/job_config.toml`.

## Submit the PBS array job

The submission script takes two arguments:

1. the batch TOML file;
2. a new output directory for the complete array run.

The output directory must not already exist. The script creates it and then creates
one child directory per PBS array sub-job. You can submit from any working directory:

```bash
bash hpc_jobs/submit_ve_array_job.sh \
    hpc_jobs/job_config.toml \
    ve_example/<My-Experiement-OUTPUT>
```

The submission script validates the batch specification, calculates the PBS array size,
creates the requested output directory, and submits the array using `qsub`. The current
script limits the array to 20 concurrently running sub-jobs with `-J "1-N%20"`.

## Monitor jobs

Use PBS commands to inspect or cancel jobs:

List your active jobs:

```bash
qstat -u "$USER"
```

Inspect a completed job:

```bash
qstat -x -f <job_id>
```

Cancel a job:

```bash
qdel <job_id>
```

Each array sub-job receives its own directory named with its PBS job ID. The combined
PBS stdout and stderr are written to `pbs.log`; the Virtual Ecosystem log is written to
`ve.log` and model outputs are written in the same directory:

```text
ve_example/<My-Experiement-OUTPUT>/3818703[1].pbs-7/
    pbs.log
    ve.log
    compiled_configuration.toml
    model_data.zarr/
```

## Choose job resources

The PBS resource request is currently embedded in
`hpc_jobs/submit_ve_array_job.sh`. It uses a small allocation suitable for the
example data. Larger simulations may require more memory, CPUs, or wall time.

Update the PBS resource directives before submitting a larger job:

```bash
#PBS -lselect=1:ncpus=1:mem=1gb
#PBS -lwalltime=00:10:00
```

Resource requirements should eventually be made configurable per array job,
maybe in the config.toml?
