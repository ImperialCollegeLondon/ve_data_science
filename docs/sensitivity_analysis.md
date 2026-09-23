# Sensitivity Analysis

## Overview

Sensitivity analysis (SA) evaluates how uncertainty in model parameters
propagates to model outputs and quantifies the relative importance of model
parameters. It provides a systematic framework for understanding model
behaviour, identifying influential parameters, supporting uncertainty
quantification, and guiding model calibration (Saltelli et al., 2004;
Pianosi et al., 2016).

For the Virtual Ecosystem (VE), sensitivity analysis helps to:

- identify influential parameters;
- rank parameter importance;
- quantify parameter interactions;
- detect nonlinear model behaviour;
- reduce parameter dimensionality before calibration;
- prioritise field measurements;
- support uncertainty analysis.

Sensitivity analysis is particularly important for complex ecosystem models
because their behaviour is often nonlinear, involves interactions between
parameters, and represents multiple interconnected physical and biological
processes (Pianosi et al., 2016).

---

## Local versus Global Sensitivity Analysis

Sensitivity analysis methods are generally classified into **local** and
**global** approaches.

## Local Sensitivity Analysis (LSA)

Local sensitivity analysis evaluates the effect of changing one parameter
around a single point in parameter space, typically a calibrated parameter
set.

Characteristics:

- one parameter varied at a time;
- computationally inexpensive;
- ignores parameter interactions;
- suitable for preliminary model diagnostics.

Typical methods include:

- One-at-a-Time (OAT);
- finite difference methods;
- derivative-based approaches.

Local sensitivity analysis is useful for simple models but becomes less
representative for highly nonlinear systems because it only explores a small
region of the parameter space (Saltelli et al., 2004; Pianosi et al., 2016).

---

## Global Sensitivity Analysis (GSA)

Global sensitivity analysis evaluates parameter importance across the entire
parameter space.

Unlike local methods, all parameters vary simultaneously, allowing nonlinear
responses and parameter interactions to be quantified.

Characteristics:

- explores the complete parameter space;
- captures nonlinear behaviour;
- accounts for parameter interactions;
- provides robust parameter rankings;
- requires substantially more model evaluations.

Global sensitivity analysis is generally recommended for hydrological and
ecosystem models because these systems exhibit complex interactions between
parameters and processes (Pianosi et al., 2016).

---

## Common Global Sensitivity Analysis Methods

Several approaches are available for global sensitivity analysis.

| Method | Category | Captures interactions | Computational cost | Typical application |
| ------ | -------- | -------------------- | ------------------ | ------------------- |
| One-at-a-Time (OAT) | Local | No | Very low | Model debugging |
| Morris | Screening | Partial | Low | Initial parameter screening |
| Sobol | Variance-based | Yes | High | Detailed sensitivity analysis |
| eFAST | Variance-based | Yes | Moderate | Alternative to Sobol |
| Regression-based | Statistical | Limited | Low | Linear models |
| PAWN | Density-based | Yes | Moderate | Distribution-based analysis |
| Random Forest | Machine learning | Implicit | Moderate | Large simulation datasets |

For the Virtual Ecosystem, the **Morris** and **Sobol** methods are currently
implemented using the **SALib** Python library. Morris provides efficient
parameter screening, while Sobol performs a rigorous variance decomposition of
model outputs (Saltelli et al., 2004; Wang & Solomatine, 2019).

---

## Morris Method

The Morris method, also known as the **Method of Elementary Effects**, is a
computationally efficient screening technique designed to identify influential
parameters within high-dimensional parameter spaces (Morris, 1991).

Rather than providing exact variance contributions, Morris estimates the
overall importance of each parameter using repeated elementary effects
calculated across the parameter space.

### Morris Outputs

- **μ** — mean elementary effect;
- **μ\*** — mean absolute elementary effect (overall parameter importance);
- **σ** — variability of elementary effects, indicating nonlinear behaviour or
  parameter interactions.

### Morris Advantages

- computationally efficient;
- suitable for large parameter sets;
- identifies influential parameters quickly;
- ideal before calibration.

### Morris Limitations

- qualitative rather than quantitative;
- interaction effects are inferred indirectly;
- does not provide variance decomposition.

The Morris method has been widely applied in hydrological modelling as an
efficient first-stage screening tool before more computationally intensive
methods are applied (van Griensven et al., 2006; Zhan et al., 2013).

---

## Sobol Method

Sobol analysis is a variance-based global sensitivity analysis method that
decomposes model output variance into contributions from individual
parameters and their interactions (Sobol, 2001).

Unlike Morris, Sobol provides quantitative sensitivity indices and explicitly
measures parameter interactions.

### Sobol Outputs

- **S₁** — first-order sensitivity index;
- **S₂** — second-order interaction index;
- **ST** — total-order sensitivity index.

### Sobol Advantages

- quantitative parameter ranking;
- captures parameter interactions;
- suitable for highly nonlinear models;
- regarded as one of the most rigorous global sensitivity analysis methods.

### Sobol Limitations

- computationally expensive;
- requires substantially more model evaluations;
- less practical for large parameter sets without prior screening.

Sobol analysis is widely regarded as one of the most comprehensive methods for
quantifying parameter importance in nonlinear environmental models (Sobol,
2001; Saltelli et al., 2004).

---

## Morris versus Sobol

| Feature | Morris | Sobol |
| ------- | ------ | ----- |
| Method type | Screening | Variance decomposition |
| Parameter ranking | Qualitative | Quantitative |
| Parameter interactions | Indirect | Explicit |
| Computational cost | Low | High |
| Suitable for many parameters | Yes | Limited |
| Recommended stage | Before calibration | Detailed analysis |

Comparative studies consistently recommend Morris for efficiently identifying
influential parameters with relatively few model evaluations, while Sobol is
better suited for detailed quantitative analysis once the parameter space has
been reduced (van Griensven et al., 2006; Wang & Solomatine, 2019; Zhan et al.,
2013).

---

## Python Sensitivity Analysis Workflow

The current sensitivity-analysis workflow in this repository is set up for the
hydrology module, using a Morris screening pipeline and the associated HPC
execution pattern to produce reproducible sensitivity outputs for a real
hydrology case study.

The overall design is modular and can be replicated for other VE modules by
changing the parameter bounds, base configuration, and response specification.
The hydrology example is the active implementation, stored under
`data/sensitivity/hydrology/` and driven by scripts in
`analysis/abiotic/sensitivity/`.

The completed workflow is:

```text
Define parameter bounds
    │
    ▼
Generate Morris or Sobol design
    │
    ▼
Write array job configuration
    │
    ▼
Submit HPC array jobs
    │
    ▼
Run VE sub-jobs and write model_data.nc
    │
    ▼
Validate runs and design consistency
    │
    ▼
Extract hydrological responses
    │
    ▼
Compute Morris or Sobol indices
    │
    ▼
Rank parameters and write summary tables/figures
```

---

## Step 1. Define the hydrology parameter space

The parameter bounds are stored in

```text
data/sensitivity/hydrology/config/sensitivity_parameters.toml
```

This file defines the parameter groups and the lower/upper bounds used for
sampling. In the hydrology case, the relevant parameters include soil moisture
thresholds, hydraulic properties, groundwater storage parameters, and runoff
coefficients such as `groundwater_capacity`, `stormflow_coefficient`, and
`reservoir_const_lower_groundwater`.

The parameter file is the authoritative definition of the sampled uncertainty
space. Any change to the model parameter ranges must be reflected here before
re-generating the design.

---

## Step 2. Generate the Morris or Sobol design

The sample-generation step is driven by the analysis scripts in

```text
analysis/abiotic/sensitivity/
```

For the hydrology example, the usual pattern is:

```text
morris_sample.py
sobol_sample.py
```

These scripts use SALib to construct the parameter design for the selected
method and write a VE array-job configuration containing one sampled parameter
set per sub-job. The generated configuration file is stored under
`data/sensitivity/hydrology/config/` with names such as:

```text
arrayJob_config_hydrology_morris_001.toml
arrayJob_config_hydrology_sobol_001.toml
```

The generated job file stores the design in a reproducible form. The analysis
step later reconstructs the design from this file and verifies that the model
runs match the intended parameter combinations.

---

## Step 3. Build the HPC array job

The real HPC pipeline is implemented in

```text
ve_data_science/hpc_jobs/
```

with the key runtime files:

```text
submit_ve_array_job.py
run_subJob.py
parse_arrayJob_config.py
parse_resources_config.py
run_analyse_morris.pbs
```

The submission workflow works as follows:

1. `submit_ve_array_job.py` loads the array-job TOML and the PBS resource TOML.
2. It validates the VE configuration for each sub-job.
3. It creates the output directory and one sub-job directory per array task.
4. It submits a PBS array job using `qsub`.
5. Each sub-job runs `run_subJob.py`, which executes the VE model and converts
   the temporary Zarr output to NetCDF as `model_data.nc`.

For this repository, the array-job submission scripts are stored in the shared
HPC folder at `ve_data_science/hpc_jobs`, and the hydrology example uses the
same pattern with a module-specific configuration and output directory.

This is the main operational HPC pipeline used to run the full hydrology
sensitivity ensemble.

---

## Step 4. Execute the hydrology example on HPC

A practical hydrology example is shown below.

```bash
cd /rds/general/user/lsamikan/home/ve_data_science
source .venv/bin/activate
export PYTHONPATH="$PWD/data/sensitivity/hydrology:$PYTHONPATH"
H=data/sensitivity/hydrology
RES=$H/config/pbs_resources_config.toml
```

### Morris run

```bash
uv run --group dev-pinned python analysis/abiotic/sensitivity/morris_sample.py
uv run --group dev-pinned python -m hpc_jobs.submit_ve_array_job \
    $H/config/arrayJob_config_hydrology_morris_001.toml "$RES" \
    $H/out/hydrology_morris_001
```

This creates the Morris design and runs the ensemble through the HPC array job.
Each sub-job writes a `model_data.nc` file under the corresponding
`out/hydrology_morris_001/array_subJob_<n>/` directory.

### Morris analysis

Once the runs are complete, the screening analysis is performed using:

```bash
uv run --group dev-pinned python \
    analysis/abiotic/sensitivity/morris_analyse_hydrology.py \
    --run-name hydrology_morris_001 --workers 4
```

This script performs the completed Morris post-processing pipeline:

- validates the Morris design against the sampled bounds;
- checks that each completed run matches its intended design row;
- reads and validates the model outputs from `model_data.nc`;
- extracts the hydrology responses (including discharge and other VE outputs);
- removes the spin-up period;
- computes the Morris elementary effects (`μ`, `μ*`, `σ`);
- writes summary tables, figures, response caches and screening decisions.

After `morris_analyse_hydrology.py` has generated the Morris outputs, the
post-processing results are written to the analysis directory, for example:

```text
data/sensitivity/hydrology/analysis/hydrology_morris_001/
```

The final report for the hydrology Morris analysis is then produced in the
notebook/ directory:

```text
notebook/hydrology/morris_sensitivity/
```

This is where the researcher inspects the screening ranking, checks the model
health diagnostics, and decides which parameters should move forward to Sobol
analysis.

---

## Step 5. Complete the analysis pipeline for hydrology

The completed hydrology Morris analysis script is:

```text
analysis/abiotic/sensitivity/morris_analyse_hydrology.py
```

This script is the core of the completed pipeline. It is not just a placeholder:
it reads the array-job specification, reconstructs the Morris design, checks the
completed ensemble, and calculates the Morris statistics needed to identify the
most influential hydrology parameters.

Key functionality includes:

- reconstructing the SALib Morris trajectories from the saved job file;
- confirming that the completed runs used the intended parameter values;
- reading the hydrology model outputs from each NetCDF file;
- applying the hydrological response specification used by the analysis;
- computing scalar, field-wise and monthly Morris sensitivity measures;
- generating tables and plots for parameter ranking and screening.

The hydrology pipeline is therefore complete as a screening workflow: it takes
run outputs from the HPC ensemble, processes them, and produces a defensible
set of influential parameters for the next stage.

---

## Step 6. Sobol stage after Morris screening

After reviewing the Morris results, the next stage is a targeted Sobol analysis.
The same general HPC pattern is followed:

```bash
uv run --group dev-pinned python analysis/abiotic/sensitivity/sobol_sample.py
uv run --group dev-pinned python -m hpc_jobs.submit_ve_array_job \
    $H/config/arrayJob_config_hydrology_sobol_001.toml "$RES" \
    $H/out/hydrology_sobol_001
```

The Sobol analysis script then uses the same hydrology response specification to
compute first-order and total-order sensitivity indices, together with
convergence and uncertainty diagnostics.

This staged design is the recommended strategy in VE hydrology:

```text
Morris screening
    │
    ▼
Select important parameters
    │
    ▼
Sobol analysis (future implementation)
    │
    ▼
Calibration and validation
```

> Note: the completed, implemented workflow in this repository is the Morris
> screening pipeline with the HPC run and post-processing stages. The Sobol
> pipeline is planned as a future extension and is not yet part of the current
> hydrology implementation.

This reduces the computational burden of full variance decomposition while still
providing the detailed ranking information needed for later model refinement.

---

## Hydrology example summary

The hydrology example demonstrates the full implemented workflow:

- define the uncertain parameter ranges in
  `data/sensitivity/hydrology/config/sensitivity_parameters.toml`;
- generate an ensemble design with SALib;
- write a VE array-job configuration for HPC submission;
- run the ensemble through `submit_ve_array_job.py` and `run_subJob.py`;
- validate the design and run outputs using the analysis script;
- compute Morris sensitivity statistics and rank parameters;
- select a reduced parameter set for Sobol analysis;
- use the same overall pipeline to continue with detailed variance-based
  analysis.

For the hydrology module, this represents the completed sensitivity-analysis
pipeline in the current repository, rather than a future planned workflow.

---

## Recommended Strategy

For the Virtual Ecosystem, a staged sensitivity analysis strategy is
recommended.

```text
Morris screening
        │
        ▼
Reduce parameter set
        │
        ▼
Sobol analysis
        │
        ▼
Calibration
        │
        ▼
Model validation
```

This staged workflow combines the computational efficiency of Morris with the
rigorous variance decomposition of Sobol, reducing computational cost while
retaining robust parameter ranking and interaction analysis (van Griensven et
al., 2006; Wang & Solomatine, 2019; Pianosi et al., 2016).

---

## SALib

The Virtual Ecosystem sensitivity analysis workflow is implemented using
**SALib**, an open-source Python library for global sensitivity analysis
(Herman & Usher, 2017).

SALib currently provides implementations of:

- Morris;
- Sobol;
- FAST;
- eFAST;
- PAWN;
- Delta;
- DGSM;
- Fractional Factorial Sampling.

As sensitivity analysis becomes a core capability of the Virtual Ecosystem,
SALib is expected to become a core project dependency managed using the
project's `uv` environment, ensuring consistent package versions across local
development, continuous integration and HPC system.

### SALib Documentation

Official documentation: [SALib Documentation](https://salib.readthedocs.io/)

GitHub repository: [SALib GitHub](https://github.com/SALib/SALib)

---

## References

- Herman, J., & Usher, W. (2017). *SALib: An open-source Python library for
  sensitivity analysis.* Journal of Open Source Software, 2(9), 97.

- Iwanaga, T., Usher, W., & Herman, J. (2022). *Toward SALib 2.0: Advancing the
  accessibility and interpretability of global sensitivity analyses.*
  Socio-Environmental Systems Modelling, 4, 18155.

- Morris, M. D. (1991). *Factorial sampling plans for preliminary computational
  experiments.* Technometrics, 33(2), 161–174.

- Pianosi, F., Beven, K., Freer, J., Hall, J. W., Rougier, J., Stephenson, D.
  B., & Wagener, T. (2016). *Sensitivity analysis of environmental models: A
  systematic review with practical workflow.* Environmental Modelling & Software,
  79, 214–232.

- Saltelli, A., Tarantola, S., Campolongo, F., & Ratto, M. (2004). *Sensitivity
  Analysis in Practice: A Guide to Assessing Scientific Models.* John Wiley &
  Sons.

- Sobol, I. M. (2001). *Global sensitivity indices for nonlinear mathematical
  models and their Monte Carlo estimates.* Mathematics and Computers in
  Simulation, 55(1–3), 271–280.

- van Griensven, A., Meixner, T., Grunwald, S., Bishop, T., Di Luzio, M., &
  Srinivasan, R. (2006). *A global sensitivity analysis tool for the parameters
  of multi-variable catchment models.* Journal of Hydrology, 324(1–4), 10–23.

- Wang, A., & Solomatine, D. P. (2019). *Practical experience of sensitivity
  analysis: Comparing six methods on three hydrological models with three
  performance criteria.* Water, 11(5), 1062.

- Zhan, C. S., Song, X. M., Xia, J., & Tong, C. (2013). *An efficient integrated
  approach for global sensitivity analysis of hydrological model parameters.*
  Environmental Modelling & Software, 41, 39–52.
