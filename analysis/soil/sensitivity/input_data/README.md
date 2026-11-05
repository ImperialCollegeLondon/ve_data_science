# Soil and litter input sensitivity analysis

This workflow generates a Sobol design, runs Virtual Ecosystem (VE) on the HPC,
and prepares the output for the report
[sensitivity.qmd](analysis/soil/sensitivity/input_data/sensitivity.qmd).

Run the commands below from the **root of a personal HPC checkout** of
`ve_data_science`, for example `~/ve_data_science`. Paths below are relative to
that root unless stated otherwise. See
[HPC setup](docs/hpc_setup.md) for access and checkout instructions.

## Connect to CX3 using SSH

Use SSH to access the CX3 cluster. You will be asked for your password.

```bash
ssh userid@login.cx3.hpc.imperial.ac.uk
```

## Data locations and prerequisites

On the HPC, `cd` to your personal directory and `git clone` the repo if you have
not done so.

You need CX3 and shared RDS access, PBS, `uv`, R, and the project's R packages.
The PBS jobs must find `Rscript` and `uv` on their compute-node `PATH`.

One-time setup in your personal checkout:

1. Python environment: run `uv sync`. Repeat `uv sync` only after
   `pyproject.toml` or `uv.lock` changes. See [uv setup](docs/uv_setup.md).
2. R packages: run `renv::restore()` from the checkout root. Repeat it only
   after `renv.lock` changes. The Zarr post-processing code also needs
   `pizzarr`. See [R with renv](docs/renv.md).

## 1. Stage input data

### Copy from shared RDS to the personal checkout

`git pull` first. Git supplies the Maliau grid definition; the command below
copies the other nine required inputs from shared RDS. Confirm that the shared
inputs are the intended dataset and match the VE version in `uv.lock`.

Run this command from the root of the personal checkout:

```bash
rsync -tv --ignore-existing --files-from=- \
  /rds/general/project/virtual_rainforest/live/ve_data_science/ ./ <<'EOF'
data/scenarios/maliau/maliau_1/data/soil_maliau.nc
data/scenarios/maliau/maliau_1/data/litter_maliau.nc
data/scenarios/maliau/maliau_1/data/elevation_maliau_2010_2020_100m.nc
data/scenarios/maliau/maliau_1/data/era5_maliau_2010_2020_100m.nc
data/scenarios/maliau/maliau_1/data/plant_input_data_Maliau_50x50.nc
data/scenarios/maliau/maliau_1/data/plant_cohort_data_Maliau_50x50.csv
data/scenarios/maliau/maliau_1/data/animal_functional_groups_Maliau_level3.csv
data/scenarios/maliau/maliau_1/data/plant_pft_definitions_Maliau_50x50.csv
data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv
EOF
```

The command copies files, not moves: source files remain on RDS. It skips
existing destination files and does not delete other files. Existing files are
not checked against RDS; verify their versions before using them. To replace
one, first move the local file aside, then run the command again. Stop if rsync
reports an error. Do not stage inputs while jobs use them.

`build_data_and_config.sh` currently **does not sync data**. It only runs the
two R preparation scripts against files already in the personal checkout. A
future opt-in staging step can automate the copy, but it needs explicit source
selection, overwrite protection, provenance, and failure checks first.

## 2. Prepare inputs and configuration on CX3

Check the selected branch and commit in the personal checkout:

```bash
cd ~/ve_data_science
git status --short --branch
git rev-parse HEAD
```

Restore the R environment according to [renv guidance](docs/renv.md)
and local HPC policy. The restore can need network access and package
compilation. The project ignores `.Rprofile`, so make sure that batch R sessions
activate the restored library. Check that the selected input versions and
available storage are appropriate before submitting the preparation job.

**Do not reuse an old generated input directory without reviewing it.** The
generator writes into `data/sensitivity/soil_litter_inputs/data/` and can
overwrite files. Move existing data and configuration aside before a new design
to preserve the previous run. Do not move files while jobs use them.

```bash
qsub analysis/soil/sensitivity/input_data/build_data_and_config.sh
```

The job requests 64 CPUs, 64 GB, and 30 minutes. It writes the Sobol matrix,
`n_scenarios.txt`, numbered NetCDF inputs, fixed inputs, and
`data/sensitivity/soil_litter_inputs/config/config.toml`. The current design
uses base sample size 100 and seed 777.

Wait for the preparation job to finish successfully before proceeding. Inspect
its PBS output and exit status, for example with `qstat -x -f <job_id>`. Check
that the scenario count, generated files, and configuration exist. The count
file alone does not establish that preparation completed.

## 3. Submit the VE array

Before submission, check storage space and file-count quota. Each run preserves
a Zarr store, which can contain many files. `out/` must not exist: the submitter
refuses to reuse it. Move an old output directory aside only after all jobs that
use it have stopped. Keep its matching inputs and Sobol matrix with it.

```bash
quota
bash analysis/soil/sensitivity/input_data/submit_ve_array.sh
```

The submitter runs `uv sync --locked` and submits one PBS array task per
scenario, with at most 100 tasks running concurrently. Save the array job ID.
Each task runs [ve.sh](analysis/soil/sensitivity/input_data/ve.sh), selects its
one-based input index, and requests one CPU, 4 GB, and one hour. The task runs
the locked PyPI VE release and stops at update 24. The report currently selects
time index 24. Confirm that this endpoint is appropriate for the analysis.

Keep the checkout, `uv.lock`, and shared `.venv` unchanged until every task
finishes. Another `uv sync` can change the environment used by running tasks.

Monitor the array with `qstat -u "$USER"` and inspect completed job status with
`qstat -x -f <job_id>`. Each task writes to
`data/sensitivity/soil_litter_inputs/out/array_subJob_<index>/`, including
`model_data.zarr`, `pbs.log`, and `logfile.log`. Errors before the task creates
its directory appear in the PBS output instead. Check task exit statuses and
logs, not only the presence of a Zarr directory. Preserve partial outputs when
investigating failed tasks. An existing task directory prevents a retry.

The generic HPC runner converts and removes Zarr output. Do not substitute it
for this runner without adapting the post-processing step.

## 4. Post-process and analyse

Wait until all array tasks succeed before submitting post-processing:

```bash
qsub analysis/soil/sensitivity/input_data/post_process_outputs.sh
```

The job requests 128 CPUs, 512 GB, and 12 hours. It requires the matching Sobol
matrix and one `model_data.zarr` per scenario. It checks scenario indices and
writes
`data/sensitivity/soil_litter_inputs/out/all_continuous_data_merged.parquet`.
Inspect the PBS output and exit status before using the Parquet file. Then
render [sensitivity.qmd](analysis/soil/sensitivity/input_data/sensitivity.qmd)
from the repository root:

```bash
quarto render analysis/soil/sensitivity/input_data/sensitivity.qmd --execute-dir .
```

Use the job sequence in this README rather than submitting the report's example
commands without waiting. The report contains unresolved scientific choices,
including the endpoint, input bounds, and uncertainty assessment.
