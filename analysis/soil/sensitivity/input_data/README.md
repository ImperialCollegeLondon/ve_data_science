# Soil and litter input sensitivity analysis

This workflow generates a Sobol design, runs Virtual Ecosystem (VE) on CX3,
and prepares outputs for [sensitivity.qmd](sensitivity.qmd). This setup covers
only the scripts in this directory and the helper functions they call. It does
not restore the repository-wide R environment or require `renv` or `uvr`.

Run commands from the **root of a personal HPC checkout** of `ve_data_science`,
not from this directory. See [HPC setup](../../../../docs/hpc_setup.md) for
access and checkout instructions.

## Connect and prepare the checkout

```bash
ssh userid@login.cx3.hpc.imperial.ac.uk
```

Clone the repository into your personal HPC directory if needed. From the
checkout root, prepare Python and the PBS log directory:

```bash
uv sync --locked
mkdir -p analysis/soil/sensitivity/input_data/pbs_logs
```

Python uses the repository's existing `uv.lock`. Do not change `.venv` while
array jobs use it. See [uv setup](../../../../docs/uv_setup.md).

## Set up R on CX3

Use a separate user library for this workflow. These exports bypass an existing
project `.Rprofile` that activates `renv`, without deleting it or changing other
projects. They also bypass user `.Renviron` settings; pass any required settings
through shell environment variables instead.

```bash
export R_LIBS_USER="$HOME/R/ve-soil-inputs/4.6"
export R_PROFILE_USER=/dev/null
export R_ENVIRON_USER=/dev/null
mkdir -p "$R_LIBS_USER"
```

Repeat these exports in each new shell before submitting R jobs. The `qsub -v`
commands below explicitly pass them to the jobs. Use the same library and R
module for installation, preparation, and post-processing. Do not install or
update packages while jobs use this library.

### Packages needed by this workflow

| Stage | Direct R packages, including called helpers |
| --- | --- |
| Prepare data and configuration | `tidyverse`, `sensobol`, `tidync`, `RNetCDF`, `toml`, `tomledit`, `mirai`, `here`, `reshape2`, `cli` |
| Post-process Zarr outputs | `tidyverse`, `mirai`, `arrow`, `pizzarr`, `here`, `reshape2`, `cli` |
| Render report | `tidyverse`, `sensobol`, `arrow`, `here`, `knitr`, `rmarkdown`; Quarto executable |

Install only these packages and their required dependencies, not their optional
`Suggests` or every package in `renv.lock`. The scripts currently load
`tidyverse`, so its imported packages remain necessary. Spatial packages such
as `sf`, `terra`, and `tmap` are not required by this workflow. Neither are
`brms`, `rstan`, or the dependencies of unrelated analyses. The Zarr reader
used here is `pizzarr`; the helper's animal-specific `reticulate` code is not
called by these scripts.

This user-library recipe installs available repository versions, **not the
versions in `renv.lock`**. Record package versions in the installation log and
keep the library unchanged for an analysis. A fresh installation may resolve
different versions; this is scoped setup, not a replacement reproducibility
system for the whole repository.

### Build environment

The existing R jobs load `R/4.6.1-gfbf-2026.1` and
`netCDF/4.10.0-gompi-2026.1`. Confirm their availability before installing:

```bash
module load tools/prod
module spider R/4.6.1-gfbf-2026.1
module spider netCDF/4.10.0-gompi-2026.1
module spider CMake/3.31.11-GCCcore-15.2.0
module spider Rust
module spider UDUNITS
module spider OpenSSL
module spider HarfBuzz
module spider FriBidi
module spider Pandoc
```

The additional names are discovery queries, not verified module versions.
Select versions compatible with R's compiler stack and follow prerequisites
reported by `module spider`. Add their versioned loads to the installation job
below before `module list`. Some libraries may already come with R or NetCDF.
Only source builds that lack these dependencies need additional modules:

| Dependency | Purpose |
| --- | --- |
| CMake >= 3.26 and C++20 compiler | Build Arrow locally; CMake also builds bundled libuv for `fs` |
| NetCDF C and UDUNITS-2 development libraries | `ncdf4`, `RNetCDF`, `tidync` |
| Rust >= 1.91, Cargo, OpenSSL development library | `pizzarr`; Rust and Cargo also build `tomledit` |
| HarfBuzz, FriBidi, Fontconfig, FreeType | `textshaping`, `systemfonts`, `ragg`, imported by `tidyverse` |
| PNG, JPEG, TIFF, WebP development libraries | `ragg` and its image support |
| libcurl and libxml2 development libraries | `curl`, `xml2`, imported by `tidyverse` |
| Pandoc | `reprex`, imported by `tidyverse`; report rendering uses Quarto |

If a required compatible development library is unavailable, ask RCS to provide
it. Installing fewer R packages does not eliminate native dependencies of the
packages actually used. Do not install Ubuntu system packages on CX3, mix
compiler generations, or replace system glibc.

### Install once on a compute node

Add any missing module loads identified above to this job before submitting.
The example keeps the R and NetCDF versions used by the existing job scripts.
It builds Arrow's C++ library locally to avoid the reported glibc-symbol
mismatch, and bundles static libuv for `fs`. Parquet remains enabled.

```bash
qsub -v R_LIBS_USER,R_PROFILE_USER,R_ENVIRON_USER <<'EOF'
#!/bin/bash
#PBS -l select=1:ncpus=4:mem=32gb
#PBS -l walltime=24:00:00
#PBS -j oe
#PBS -o analysis/soil/sensitivity/input_data/pbs_logs/
set -euo pipefail
cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is required}"
module load tools/prod
module load R/4.6.1-gfbf-2026.1
module load CMake/3.31.11-GCCcore-15.2.0
module load netCDF/4.10.0-gompi-2026.1
module list
for tool in Rscript cmake nc-config pkg-config rustc cargo; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing build tool: $tool; check the loaded modules." >&2
    exit 1
  fi
done
nc-config --all
cmake --version
rustc --version
cargo --version
for library in netcdf udunits2 openssl; do
  if ! pkg-config --exists "$library"; then
    echo "Missing development metadata: $library; check the loaded modules." >&2
    exit 1
  fi
done
export MAKEFLAGS=-j4
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export LIBARROW_BINARY=false
export LIBARROW_BUILD=true
export ARROW_USE_PKG_CONFIG=false
export ARROW_PARQUET=ON
export USE_BUNDLED_LIBUV=1
Rscript --version
Rscript -e '
  rust_version <- strsplit(system2("rustc", "--version", stdout = TRUE), " ")[[1]][2]
  stopifnot(numeric_version(rust_version) >= numeric_version("1.91"))
  packages <- c("tidyverse", "sensobol", "tidync", "RNetCDF", "toml",
                "tomledit", "mirai", "here", "reshape2", "cli", "arrow",
                "pizzarr", "knitr", "rmarkdown")
  install.packages(
    packages,
    lib = Sys.getenv("R_LIBS_USER"),
    repos = c(CRAN = "https://cloud.r-project.org",
              zarr = "https://zarr-developers.r-universe.dev"),
    dependencies = c("Depends", "Imports", "LinkingTo"),
    Ncpus = 1L,
    type = "source"
  )
'
Rscript -e '
  packages <- c("tidyverse", "sensobol", "tidync", "RNetCDF", "toml",
                "tomledit", "mirai", "here", "reshape2", "cli", "arrow",
                "pizzarr", "knitr", "rmarkdown")
  for (package in packages) library(package, character.only = TRUE)
  stopifnot(packageVersion("purrr") >= numeric_version("1.1.0"))
  print(.libPaths())
  print(vapply(packages, find.package, character(1)))
  print(vapply(packages, function(x) as.character(packageVersion(x)), character(1)))
  test_file <- tempfile(fileext = ".parquet")
  arrow::write_parquet(data.frame(value = 1L), test_file)
  stopifnot(identical(
    as.data.frame(arrow::read_parquet(test_file)), data.frame(value = 1L)
  ))
  unlink(test_file)
  print(sessionInfo())
'
EOF
```

Wait for installation to finish. Save the job ID, inspect the PBS log, and check
`qstat -x -f <job_id>` for a successful exit status. The second R process fails
if any required package cannot load, even if `install.packages()` only warned
about installation failures. Confirm package locations use the workflow
library or compatible module-provided libraries, not the old `renv` cache.
Keep the version log with the analysis. If installation fails, fix the first
build error rather than installing unrelated packages from the full lockfile.

## 1. Stage input data

The scripts use Maliau inputs under `data/scenarios/maliau/maliau_2/data/`, plant
constants under `data/derived/plant/input_data/scenarios/maliau_2/`, and the
Git-tracked grid definition
`data/derived/site/maliau/maliau_grid_definition.toml`.

`git pull` first. Git supplies the grid definition; the command below copies
the other nine non-Git inputs from shared RDS. Confirm all nine source files
are present and match the selected dataset and VE version in `uv.lock`. If an
input is unavailable through Globus or absent from shared RDS, obtain it from
its data owner before running this all-file command.

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

From a shell with the R library exports set, submit:

```bash
qsub -v R_LIBS_USER,R_PROFILE_USER,R_ENVIRON_USER \
  analysis/soil/sensitivity/input_data/build_data_and_config.sh
```

If installed packages need shared libraries from extra modules, add the same
runtime module loads to `build_data_and_config.sh` and
`post_process_outputs.sh`. Build tools such as CMake and Cargo are not needed
for ordinary package loading. The scripts' old comments about restoring
`renv.lock` do not apply to this scoped setup.

The job writes the Sobol matrix, `n_scenarios.txt`, numbered NetCDF inputs,
fixed inputs, and `data/sensitivity/soil_litter_inputs/config/config.toml`.
The current design uses base sample size 100 and seed 777. Its 64 R workers
match the PBS CPU request; adjust both together if changing resources.

Wait for successful completion before submitting VE. Inspect the PBS log and
exit status with `qstat -x -f <job_id>`. Check the scenario count, generated
files, and configuration. The count file alone does not prove preparation
completed. Keep the checkout and R library unchanged while jobs use them.

## 3. Submit the VE array

Check storage space and file-count quota. Each run preserves a Zarr store,
which can contain many files. `out/` must not exist: the submitter refuses to
reuse it. Move old output aside only after its jobs stop, and preserve its
matching inputs and Sobol matrix.

```bash
quota
bash analysis/soil/sensitivity/input_data/submit_ve_array.sh
```

The submitter runs `uv sync --locked` and submits one PBS array task per
scenario, with at most 100 tasks running concurrently. Save the array job ID.
Each task runs [ve.sh](ve.sh), selects its one-based input index, and requests
one CPU, 4 GB, and one hour. The task runs the locked PyPI VE release and stops
at update 24. The report currently selects time index 24; confirm that this
endpoint is appropriate for the analysis.

Keep the checkout, `uv.lock`, and `.venv` unchanged until every task finishes.
Monitor with `qstat -u "$USER"` and inspect completed status with
`qstat -x -f <job_id>`. Each task writes to
`data/sensitivity/soil_litter_inputs/out/array_subJob_<index>/`, including
`model_data.zarr` and `logfile.log`. Joined PBS stdout and stderr appear under
`analysis/soil/sensitivity/input_data/pbs_logs/` after tasks finish. Check exit
statuses and logs, not only the presence of a Zarr directory. Preserve partial
outputs when investigating failures; an existing task directory prevents retry.

The generic HPC runner converts and removes Zarr output. Do not substitute it
for this runner without adapting post-processing.

## 4. Post-process and analyse

Wait until every array task succeeds. From a shell with the R library exports
set, submit:

```bash
qsub -v R_LIBS_USER,R_PROFILE_USER,R_ENVIRON_USER \
  analysis/soil/sensitivity/input_data/post_process_outputs.sh
```

The job requests 128 CPUs, 512 GB, and 12 hours, matching its 128 R workers.
It requires the matching Sobol matrix and one `model_data.zarr` per scenario.
It checks scenario indices and writes
`data/sensitivity/soil_litter_inputs/out/all_continuous_data_merged.parquet`.
Inspect the PBS log and exit status before using the Parquet file.

Render the report on a machine with Quarto and the report packages installed,
from the repository root. On CX3, keep the R library exports set and use a
compute allocation rather than running the analysis on a login node:

```bash
quarto render analysis/soil/sensitivity/input_data/sensitivity.qmd --execute-dir .
```

Use this README's sequence rather than the report's older full-restore and
submission examples. The report contains unresolved scientific choices,
including the endpoint, input bounds, and uncertainty assessment.
