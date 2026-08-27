# Running Virtual Ecosystem on the HPC

Author: moi-taiga
Note: this is an early draft, do suggest edits!

Introduction to submitting Virtual Ecosystem runs as a PBS array job on
the HPC cluster. The workflow was developed for the CX3 cluster, which uses the
PBS job scheduler. CX3 is scheduled to be shut down in May 2027.

## Before you start

You need:

- a terminal;
- access to CX3

## Connect to the HPC using SSH

Use SSH to access the cx3 cluster; you will be required to use your password for authentication.

```bash
ssh userid@login.cx3.hpc.imperial.ac.uk
```

See the [Imperial RCS documentation](https://icl-rcs-user-guide.readthedocs.io/en/latest/hpc/getting-started/)
for further information about connecting to the cluster.
If you are new to HPC environments, do make sure that you familiarise yourself with the
documentation. It is highly recommended to attend the [Introduction to HPC at Imperial course](https://www.imperial.ac.uk/early-career-researcher-institute/learning-and-development/courses-by-programme/research-computing-and-data-science/introduction-to-hpc/), but if you cannot make it, the materials for the course are freely available and give a good overview of how to work with the system.

*Importantly: Login nodes are intended for tasks such as editing files, preparing jobs,
and submitting jobs. Computationally intensive work should be submitted to compute
nodes through PBS.*

## Clone the repository

Keep a personal checkout (like you would locally) rather than working from a
shared project directory. This avoids conflicts with other users' files.

```bash
cd ~
git clone https://github.com/ImperialCollegeLondon/ve_data_science.git
cd ve_data_science
```

## Install `uv` and create a virtual environment

See [uv setup](uv_setup.md) for instructions about using uv.

**note:** If you are using R, conda may be better suited than uv.
**note:** for test runs with the example data I use:

```bash
uv venv
uv pip install virtual-ecosystem
```

as it installs a version of Veco which is compatable with the example.

## Install the example data/configs

For testing the HPC workflow, install the example data and configuration files:

```bash
ve_run --install-example .
```

## Create a batch job configuration

Create a TOML job specification that describes the Virtual Ecosystem runs in
the array. You can produce the job entries with a sampling method such as Morris,
Sobol, or Latin hypercube sampling. A small example is available in
`hpc_jobs/job_config.toml`.

The specification has four parts:

- `site_directory`: the absolute path to the directory containing the shared
    configuration files and input data. Replace the path in the example
    with the path to your checkout's `ve_example` directory.
- `common_config_paths`: paths to configuration files, relative to
    `site_directory`, that every array sub-job uses.
- `[[jobs]]`: one or more job entries. Each can provide additional
    `config_paths` and a `config` table of values that override the loaded
    configuration.
- `repeats`: a positive integer on each job entry. The total number
    of PBS array sub-jobs is the sum of all `repeats` values.

## Submit the PBS array job

The submission script takes three arguments:

1. the job configuration TOML file;
2. the resources configuration TOML file (see [Choose job resources](#choose-job-resources));
3. a new output directory for the completed array run.

The output directory must not already exist. The script creates it and then creates
one child directory per PBS array sub-job. You can submit from any working directory:

```bash
bash hpc_jobs/submit_ve_array_job.sh \
    hpc_jobs/job_config.toml \
    hpc_jobs/resources_config.toml \
    ve_example/<experiment-output>
```

The submission script validates the job configuration and resources configuration,
calculates the PBS array size, creates the requested output directory, and submits the
array using `qsub`. It creates `arraySubJob_<index>` directories before submitting the
array. Validation happens before the output directory is created or any jobs are
submitted, so invalid configurations fail fast.

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

Each array sub-job receives an `arraySubJob_<index>` directory. The combined PBS stdout
and stderr are written to `pbs.log`; the Virtual Ecosystem log is written to `ve.log` and
model outputs are written in the same directory:

```text
ve_example/<experiment-output>/
    arraySubJob_1/
        pbs.log
        ve.log
        compiled_configuration.toml
        model_data.zarr/
```

## Choose job resources

The PBS resource request is defined in a resourse config TOML file.
`hpc_jobs/resources_config.toml` has a small allocation suitable for the example data

Every value applies to each individual array sub-job,
apart from `max_concurrent_jobs`, which caps how many sub-jobs the scheduler runs at once.

Larger datasets may require more memory, CPUs, or wall time.
More jobs don't need more resources as resources are set per job.

`hpc_jobs/resources.py` loads and validates the resource configuration, while
`hpc_jobs/hpc_ve_job_spec.py` validates the job configuration. Each resource field is
bounds checked, and an out-of-range or missing value aborts the submission with an error
rather than sending a bad request to `qsub`:

| Field | Allowed range |
| --- | --- |
| `ncpus` | 1–128 |
| `mem_gb` | 1–4000 |
| `walltime_hours` | 0–59 |
| `walltime_minutes` | 0–59 |
| `max_concurrent_jobs` | 1–100 |

The upper bounds match the largest CX3 nodes rather than realistic per-job requests, so
staying inside them does not guarantee that a job will be scheduled promptly. Check the
[Imperial RCS documentation](https://icl-rcs-user-guide.readthedocs.io/en/latest/hpc/queues/)
for more detail.
