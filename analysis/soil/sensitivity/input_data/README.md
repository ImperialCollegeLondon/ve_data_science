# Soil and litter input sensitivity analysis

This workflow generates a Sobol design, runs Virtual Ecosystem (VE) on the HPC,
and prepares the output for the report
[sensitivity.qmd](sensitivity.qmd).

Run the commands below from the **root of a personal HPC checkout** of
`ve_data_science`, for example `~/ve_data_science`. Paths below are relative to
that root unless stated otherwise. See
[HPC setup](../../../../docs/hpc_setup.md) for access and checkout instructions.

## Connect to CX3 using SSH

Use SSH to access the CX3 cluster. You will be asked for your password.

```bash
ssh userid@login.cx3.hpc.imperial.ac.uk
```

## Data locations and prerequisites

On the HPC, `cd` to your personal directory and `git clone` the repo if you have
not done so.

One-time setup in your personal checkout:

1. Python environment: run `uv sync`. Repeat `uv sync` only after
   `pyproject.toml` or `uv.lock` changes. See
   [uv setup](../../../../docs/uv_setup.md).
2. Set up R and its packages as described below.

### Set up R on CX3

CX3 provides R through its module system. Follow the
[Imperial R guide](https://icl-rcs-user-guide.readthedocs.io/en/latest/hpc/applications/guides/R/)
to inspect the production software stack:

```bash
module load tools/prod
module spider R
module spider R/4.6.1-gfbf-2026.1
```

Confirm that the module is available and note any prerequisite module loads
reported by `module spider`. The current `renv.lock` records R 4.6.0; the
example below uses R 4.6.1.

From the checkout root, open `.Rprofile` with a text editor. This command opens
the existing file, or creates it when you save if it does not exist:

```bash
nano .Rprofile
```

Keep any existing contents. Add this line if it is not already present:

```r
source("renv/activate.R")
```

In nano, press **Ctrl+O**, then **Enter** to save. Press **Ctrl+X** to exit.
Git ignores `.Rprofile`, so configure it in each checkout. This activates the
project R library; you must still load the R module in each job. See
[R with renv](../../../../docs/renv.md).

Submit the package restore from the checkout root as a PBS job:

```bash
qsub <<'EOF'
#!/bin/bash
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=2:00:00
#PBS -j oe
set -euo pipefail
cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is required}"
module load tools/prod
module load R/4.6.1-gfbf-2026.1
Rscript --version
Rscript -e 'renv::restore(prompt = FALSE); renv::status()'
Rscript -e '
  print(.libPaths())
  packages <- c("tidyverse", "sensobol", "tidync", "RNetCDF", "toml",
                "mirai", "arrow", "pizzarr", "here")
  stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))
  print(vapply(packages, find.package, character(1)))
'
EOF
```

Save the job ID and check its exit status with `qstat -x -f <job_id>`. Inspect
the PBS output for restore errors, package status, R version, library paths, and
package locations. Confirm that the project library is active and contains the
required packages. A successful package load alone does not prove that the
locked versions are in use. Resolve any discrepancies reported by
`renv::status()` before proceeding.

The restore runs on a compute node to avoid heavy work on login nodes. It may
need network access, compilation, system libraries, or more time. `pizzarr`,
needed for post-processing, may require Rust and OpenSSL when built from source.
Check compute-node access and missing dependencies if restore fails. Repeat the
restore when `renv.lock` changes or the library needs repair; do not run it
during jobs that use the library.

Before submitting the preparation or post-processing jobs, add the same
`tools/prod`, prerequisite, and R module loads to `build_data_and_config.sh` and
`post_process_outputs.sh`, before their `Rscript` checks. These scripts do not
currently load R. To check the runtime, also add these commands after the
checks and before the analysis scripts:

```bash
Rscript --version
Rscript -e 'print(.libPaths())'
```

Inspect each job's PBS output to confirm the R version and project library.
Keep the checkout, `.Rprofile`, and R library unchanged while jobs use them.
The preparation and post-processing scripts use 64 and 128 R workers,
respectively, matching their current PBS CPU requests. If you change a request,
adjust its worker count to match, and check that threaded libraries do not
oversubscribe the allocation.

The preparation scripts read these inputs:

| Relative path | Required files |
| --- | --- |
| `data/scenarios/maliau/maliau_2/data/` | `soil_maliau.nc`, `litter_maliau.nc`, `elevation_maliau_10x10.nc`, `era5_maliau_10x10_2010_2020.nc`, `plant_input_data_maliau_2.nc`, `cohort_data_1_cm_maliau_2.csv`, `animal_functional_groups_Maliau_level5.csv`, `plant_pft_definitions_maliau_2.csv` |
| `data/derived/plant/input_data/scenarios/maliau_2/` | `plant_constants_maliau_2.csv` |
| `data/derived/site/maliau/` | `maliau_grid_definition.toml`, tracked in Git |

## 1. Stage input data

`git pull` first. Git supplies the Maliau grid definition; the command below
copies the other nine non-Git inputs from shared RDS. Confirm all nine source
files are present and match the selected dataset and VE version in `uv.lock`.
If any input is unavailable through Globus or absent from shared RDS, do not
run this all-file command; obtain and stage that input from its data owner.

Run this command from the root of the personal checkout:

```bash
rsync -tv --files-from=- \
  /rds/general/project/virtual_rainforest/live/ve_data_science/ ./ <<'EOF'
data/scenarios/maliau/maliau_2/data/soil_maliau.nc
data/scenarios/maliau/maliau_2/data/litter_maliau.nc
data/scenarios/maliau/maliau_2/data/elevation_maliau_10x10.nc
data/scenarios/maliau/maliau_2/data/era5_maliau_10x10_2010_2020.nc
data/scenarios/maliau/maliau_2/data/plant_input_data_maliau_2.nc
data/scenarios/maliau/maliau_2/data/cohort_data_1_cm_maliau_2.csv
data/scenarios/maliau/maliau_2/data/animal_functional_groups_Maliau_level5.csv
data/scenarios/maliau/maliau_2/data/plant_pft_definitions_maliau_2.csv
data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv
EOF
```

## 2. Prepare inputs and configuration on CX3

Run:

```bash
qsub analysis/soil/sensitivity/input_data/build_data_and_config.sh
```

The job writes the Sobol matrix, `n_scenarios.txt`, numbered NetCDF inputs,
fixed inputs, and `data/sensitivity/soil_litter_inputs/config/config.toml`. The
current design uses base sample size 100 and seed 777.

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
Each task runs [ve.sh](ve.sh), selects its
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
render [sensitivity.qmd](sensitivity.qmd)
from the repository root:

```bash
quarto render analysis/soil/sensitivity/input_data/sensitivity.qmd --execute-dir .
```

Use the job sequence in this README rather than submitting the report's example
commands without waiting. The report contains unresolved scientific choices,
including the endpoint, input bounds, and uncertainty assessment.
