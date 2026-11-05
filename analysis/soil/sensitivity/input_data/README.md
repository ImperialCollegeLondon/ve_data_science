# Soil and litter input sensitivity analysis

This workflow generates a Sobol design, runs Virtual Ecosystem (VE) on CX3,
and prepares the output for [sensitivity.qmd](sensitivity.qmd). Each Sobol row
is one single-cell scenario. Soil and litter initial states vary. Other inputs
are fixed or prescribed.

Run the commands below from the **root of a personal HPC checkout** of
`ve_data_science`, for example `~/ve_data_science`. Paths below are relative to
that root unless stated otherwise. See
[HPC setup](../../../../docs/hpc_setup.md) for access and checkout instructions.

## Data locations and prerequisites

Globus provides access to files on the Research Data Store (RDS). It does not
store a separate copy. The shared checkout is at
`/rds/general/project/virtual_rainforest/live/ve_data_science/`. Keep that
checkout on `main` and do not run this analysis there. The personal checkout
holds the branch, its input copies, and its generated outputs.

You need CX3 and shared RDS access, PBS, `uv`, R, and the project's R packages.
The PBS jobs must find `Rscript` and `uv` on their compute-node `PATH`. Restore
the R environment from `renv.lock`, and make sure that its packages are
available to the jobs. The Zarr post-processing code also needs `pizzarr`.
See [uv setup](../../../../docs/uv_setup.md) and
[Globus instructions](../../../../docs/using_globus.md).

The preparation scripts read these inputs:

| Relative path | Required files |
| --- | --- |
| `data/scenarios/maliau/maliau_1/data/` | `soil_maliau.nc`, `litter_maliau.nc`, `elevation_maliau_2010_2020_100m.nc`, `era5_maliau_2010_2020_100m.nc`, `plant_input_data_Maliau_50x50.nc`, `plant_cohort_data_Maliau_50x50.csv`, `animal_functional_groups_Maliau_level3.csv`, `plant_pft_definitions_Maliau_50x50.csv` |
| `data/derived/plant/input_data/scenarios/maliau_2/` | `plant_constants_maliau_2.csv` |
| `data/derived/site/maliau/` | `maliau_grid_definition.toml`, tracked in Git |

Use the input versions compatible with this branch and the VE release in
`uv.lock`. Record the data provenance, the data-science commit, and the VE
version with the run. The shared data can change independently of Git.

## 1. Stage input data

1. Prepare new large input files locally as needed. Transfer agreed files from
   the local Globus collection to the corresponding shared RDS paths. Coordinate
   replacements with the team and preserve a backup before replacing shared
   data.
2. If colleagues update shared files, transfer the relevant files from the
   shared collection to your local collection for local work. Wait for the
   Globus transfer to succeed before using those files.
3. Copy the required shared input files to the same relative paths in the
   personal HPC checkout. This HPC copy is separate from the local transfer.
   Globus exposes the shared RDS files, so an HPC copy can read them directly.

For a Globus folder transfer, select the source folder and open its parent
folder at the destination. Review the transfer and its completion status in
Globus. Do not transfer the whole shared checkout over the personal checkout:
tracked files and branch-specific configurations can differ. The
[scenario version guide](https://github.com/ImperialCollegeLondon/ve_data_science/blob/453bc756244ca8be65b5a7aed634737fadb9d8a2/docs/managing_scenario_versions.md)
is a working document. This workflow does not assume its proposed version
folders.

### Copy from shared RDS to the personal checkout

The example below copies only the nine non-Git inputs listed above. It compares
file contents, preserves replaced personal files in a backup directory, and
does not delete files absent from the source. It does not update the Git-tracked
grid definition. Check the source files and destination paths first. Do not run
it if any relevant source, destination, or parent path is a symbolic link.
Agree the source version before copying. The shared paths and permissions must
be accessible from CX3. Use Bash and `rsync` for these commands.

From the personal checkout root, set the source list and preview the copy:

```bash
SHARED=/rds/general/project/virtual_rainforest/live/ve_data_science
BACKUP="$HOME/ve-data-sync-backups/$(date +%Y%m%d-%H%M%S)"
INPUTS=(
  "$SHARED/./data/scenarios/maliau/maliau_1/data/soil_maliau.nc"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/litter_maliau.nc"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/elevation_maliau_2010_2020_100m.nc"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/era5_maliau_2010_2020_100m.nc"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/plant_input_data_Maliau_50x50.nc"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/plant_cohort_data_Maliau_50x50.csv"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/animal_functional_groups_Maliau_level3.csv"
  "$SHARED/./data/scenarios/maliau/maliau_1/data/plant_pft_definitions_Maliau_50x50.csv"
  "$SHARED/./data/derived/plant/input_data/scenarios/maliau_2/plant_constants_maliau_2.csv"
)
rsync -rtcin --relative --backup --backup-dir="$BACKUP" "${INPUTS[@]}" ./
```

Review the file list and any errors. Stop if a source file is missing, a path is
unexpected, or the backup directory already exists. Then copy the files:

```bash
mkdir -p "$BACKUP" && \
  rsync -rtci --relative --backup --backup-dir="$BACKUP" "${INPUTS[@]}" ./
```

Repeat the preview and investigate any remaining differences or errors. Keep the
backup until the copied inputs are verified. For large files, checksum
comparison and copying can be intensive. Use a compute job if required by
cluster policy. Do not change inputs while preparation or array jobs are
running.

`build_data_and_config.sh` currently **does not sync data**. It only runs the
two R preparation scripts against files already in the personal checkout. A
future opt-in staging step can automate the copy, but it needs explicit source
selection, overwrite protection, provenance, and failure checks first.

## 2. Prepare inputs and configuration on CX3

Check out the intended branch in the personal checkout and record its commit:

```bash
cd ~/ve_data_science
git status --short --branch
git rev-parse HEAD
```

Restore the R environment according to [renv guidance](../../../../docs/renv.md)
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
Each task runs [ve.sh](ve.sh), selects its one-based input index, and requests
one CPU, 4 GB, and one hour. The task runs the locked PyPI VE release and stops
at update 24. The report currently selects time index 24. Confirm that this
endpoint is appropriate for the analysis.

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
render [sensitivity.qmd](sensitivity.qmd) from the repository root:

```bash
quarto render analysis/soil/sensitivity/input_data/sensitivity.qmd --execute-dir .
```

Use the job sequence in this README rather than submitting the report's example
commands without waiting. The report contains unresolved scientific choices,
including the endpoint, input bounds, and uncertainty assessment.
