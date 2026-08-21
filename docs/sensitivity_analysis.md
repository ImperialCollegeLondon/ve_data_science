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

The current Python workflow implements **global sensitivity analysis for the
Virtual Ecosystem hydrology module**. However, the workflow has been designed
to be modular and reusable, allowing the same pipeline to be adapted for other
Virtual Ecosystem modules (e.g. abiotic, soil, plant, animal and litter) by
providing the appropriate parameter definitions and base configuration files.

The implemented workflow currently
covers parameter definition, sample generation, and creation of HPC job
configurations required to execute batch
simulations runs.

The workflow consists of the following stages.

```text
Define parameter ranges
    │
    ▼
Load parameter definitions
    │
    ▼
Generate parameter samples
(Morris / Sobol)
    │
    ▼
Generate HPC job configuration
(job_config.toml)
    │
    ▼
Submit HPC batch jobs
    │
    ▼
Run batch HPC simulations
    │
    ▼
Future work
(Output extraction, sensitivity analysis and reporting)
```

---

## Step 1. Define parameter ranges

Parameter names and sampling bounds are defined in

`sensitivity_parameters.toml`

Each parameter is identified using its full Virtual Ecosystem configuration
key (for example,

`hydrology.constants.groundwater_capacity`)

together with lower and upper sampling bounds.

### Step 1 Files

```text
data/sensitivity/hydrology/config/sensitivity_parameters.toml
```

### Step 1 Purpose

The parameter definition file specifies:

- parameter groups (e.g. hydrology, soil, abiotic);
- Virtual Ecosystem configuration keys;
- lower and upper sampling bounds.

Adding a new module simply requires defining a new parameter group within
`sensitivity_parameters.toml`.

---

## Step 2. Load parameter definitions

The helper function

```python
load_problem(...)
```

reads the selected parameter groups and constructs a SALib-compatible problem
definition containing:

- parameter names;
- sampling bounds;
- number of variables.

### Step 2 Tool

```text
tools/python/abiotic/sensitivity_tools.py
```

### Step 2 Output

```python
problem = {
    "num_vars": ...,
    "names": ...,
    "bounds": ...
}
```

This problem dictionary is then passed directly to SALib sampling routines.

---

## Step 3: Generate parameter samples

Parameter samples are generated using either

```python
generate_morris_samples(...)
```

or

```python
generate_sobol_samples(...)
```

implemented using the SALib Python package (Herman & Usher, 2017; Iwanaga et al., 2022).

### Step 3 Tool

```text
tools/python/abiotic/sensitivity_tools.py
```

### Step 3 Driver scripts

```text
analysis/abiotic/sensitivity/morris_sample.py

analysis/abiotic/sensitivity/sobol_sample.py
```

### Step 3 Output

The generated sample matrix contains one parameter combination per simulation.

---

## Step 4. Generate HPC job configuration

The sampled parameter combinations are converted into a Virtual Ecosystem
`job_config.toml` file using

```python
generate_job_config(...)
```

Each sampled parameter set becomes one independent Virtual Ecosystem
simulation.

### Step 4 Tool

```text
tools/python/abiotic/job_config_tools.py
```

### Step 4 Input files

The base configuration provides the default Virtual Ecosystem model settings.
Only the sampled parameters are overridden for each simulation.

```text
data/sensitivity/hydrology/config/hydrology_base_config.toml
```

### Step 4 Output

```text
data/sensitivity/hydrology/config/job_config_sobol.toml

or

data/sensitivity/hydrology/config/job_config_morris.toml
```

These job configuration files define the sensitivity analysis simulations and
are intended to be used by the Virtual Ecosystem HPC batch workflow to execute
ensembles of model runs. Each `[[jobs]]` entry represents a single simulation
with a unique set of sampled parameter values.

---

## Step 5: Execute Virtual Ecosystem simulations *(planned)*

This stage is **currently under development** and has **not yet been
implemented**. Once the sensitivity sampling workflow is complete, the
generated `job_config.toml` files will be submitted through the
Virtual Ecosystem HPC batch workflow to execute the sensitivity analysis
experiments.

```text
job_config.toml
        │
        ▼
PBS job array
        │
        ▼
Multiple Virtual Ecosystem simulations
```

Each `[[jobs]]` entry represents one simulation with a unique parameter set.

---

## Step 6: Post-processing sensitivity analysis *(planned)*

This stage has **not yet been implemented** and represents the next phase of
the sensitivity analysis pipeline.

Following successful execution of the HPC simulations, a post-processing
workflow will be developed to:

- extract Virtual Ecosystem model outputs;
- aggregate model outputs across simulations;
- compute Morris elementary effects (μ, μ*, σ);
- compute Sobol sensitivity indices (S₁, ST and S₂);
- rank influential parameters;
- identify parameter interactions;
- generate figures, tables and summary reports.

The completed workflow will support interpretation of sensitivity results and
provide a basis for selecting parameters for subsequent calibration and
validation.

The planned implementation will make use of the SALib analysis routines
(`SALib.analyze.morris` and `SALib.analyze.sobol`) (Herman & Usher, 2017;
Iwanaga et al., 2022).

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
