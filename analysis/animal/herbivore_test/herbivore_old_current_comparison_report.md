# Herbivore old vs current output comparison

This notebook compares Level 1 herbivore test outputs for **Elephant** (slow-growing reference) and **Kancil** (faster-growing case). The original idea of using "fast vs slow" growing herbivores was testing whether replacing FG input with smaller, faster-growing herbivore such as Kancil. would change the population density trajectory, and perhaps improve persistence. This is especially true as when the simulation ended quickly, FG that requires more time to grow/changes in body mass will be tricky to interpret. The comparison focuses on population density / abundance, mean individual body mass, maturity and reproduction, and how the current outputs differ from the older runs. 

> **Important:** the old and current runs differ in Virtual Ecosystem version and configuration as well as recent animal-module changes. 
## Test setup

- **Virtual Ecosystem version:** 0.2.1
- **Virtual Ecosystem source commit:** `014b22149`
- **uv version:** 0.12.13
- **Platform:** Windows 11

## How the trajectories are calculated

The cohort exporter contains **two states at `time_index = 0`**:

1. the true initialized state at age 0 days, and
2. the state after the first model update at age 30 days.

The cohort files have two records at time_index = 0, so I used cohort age to make sure we start from the actual age-0 record. Mean body mass is calculated from carbon + nitrogen + phosphorus mass, taking into account the number of individuals in each cohort. The test area is 1 km², so the total number of individuals is also the population density in individuals/km².



```python
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

DATA_DIR = Path("path/to/herbivore_test")

FILES = {
    ("elephant", "old"): DATA_DIR / "animal_cohort_data_elephant_old.csv",
    ("elephant", "current"): DATA_DIR / "animal_cohort_data_elephant_new.csv",
    ("kancil", "old"): DATA_DIR / "animal_cohort_data_kancil_old.csv",
    ("kancil", "current"): DATA_DIR / "animal_cohort_data_kancil_new.csv",
}

MASS_COLUMNS = ["mass_carbon", "mass_nitrogen", "mass_phosphorus"]
REPRO_COLUMNS = [
    "reproductive_mass_carbon",
    "reproductive_mass_nitrogen",
    "reproductive_mass_phosphorus",
]

def summarise_cohort_output(path, test, version):
    data = pd.read_csv(path)
    data["body_mass"] = data[MASS_COLUMNS].sum(axis=1)

    rows = []
    for age_days, group in data.groupby("age", sort=True):
        total_individuals = group["individuals"].sum()

        mean_mass = (
            (group["body_mass"] * group["individuals"]).sum() / total_individuals
            if total_individuals > 0
            else float("nan")
        )

        rows.append(
            {
                "test": test,
                "version": version,
                "age_days": age_days,
                "elapsed_years": age_days / 365.25,
                "population_density": total_individuals,
                "mean_individual_body_mass": mean_mass,
                "n_cohorts": group["cohort_id"].nunique(),
                "n_mature_cohorts": int(group["is_mature"].sum()),
                "reproductive_mass": group[REPRO_COLUMNS].to_numpy().sum(),
            }
        )

    return pd.DataFrame(rows)

trajectories = pd.concat(
    [
        summarise_cohort_output(path, test, version)
        for (test, version), path in FILES.items()
    ],
    ignore_index=True,
)

```

## Comparison over the period shared by all four runs

The shortest run is the old Kancil output, ending at **420 days (about 1.15 years)**. The table below compares all four runs from their true initialized state (age 0) to this common endpoint.



```python
COMMON_END_DAYS = 420

shared_rows = []

for (test, version), data in trajectories.groupby(["test", "version"]):
    data = data.sort_values("age_days")
    start = data.loc[data["age_days"] == 0].iloc[0]
    end = data.loc[data["age_days"] == COMMON_END_DAYS].iloc[0]

    shared_rows.append(
        {
            "test": test,
            "version": version,
            "start_density": start["population_density"],
            "end_density": end["population_density"],
            "density_change_percent": (
                (end["population_density"] / start["population_density"]) - 1
            ) * 100,
            "start_body_mass": start["mean_individual_body_mass"],
            "end_body_mass": end["mean_individual_body_mass"],
            "body_mass_change_percent": (
                (end["mean_individual_body_mass"] / start["mean_individual_body_mass"]) - 1
            ) * 100,
        }
    )

shared_summary = pd.DataFrame(shared_rows)
shared_summary.round(3)

```

## Elephant

Over the common 420-day period, the Elephant outputs remain relatively similar in population decline, but differ more clearly in body-mass accumulation.

- **Current:** density declines from **52 to 35** individuals (**−32.7%**) and mean body mass increases by about **0.57%**.
- **Old:** density declines from **52 to 31** individuals (**−40.4%**) and mean body mass increases by about **1.8%**.

The current run therefore shows a somewhat slower decline in abundance and slower body-mass accumulation over the shared period. Across the full current run, however, the population continues to fall and eventually reaches **1 individual** at 2,730 elapsed days (about **7.5 years**). Neither old nor current Elephant cohorts become mature, and no reproductive mass is recorded.



```python
elephant = trajectories.loc[trajectories["test"] == "elephant"].copy()

fig, axes = plt.subplots(2, 1, figsize=(9, 8), sharex=True)

for version, data in elephant.groupby("version"):
    data = data.sort_values("elapsed_years")
    axes[0].plot(data["elapsed_years"], data["population_density"], label=version)
    axes[1].plot(
        data["elapsed_years"],
        data["mean_individual_body_mass"],
        label=version,
    )

axes[0].set_ylabel("Population density (individuals/km²)")
axes[0].set_title("Population density")
axes[0].legend(title="Output")

axes[1].set_xlabel("Elapsed simulation time (years)")
axes[1].set_ylabel("Mean individual body mass")
axes[1].set_title("Body mass")
axes[1].legend(title="Output")

fig.suptitle("Elephant: old vs current output")
fig.tight_layout()
plt.show()

```

### Elephant pattern

- Density decline is broadly similar between old and current outputs during the period where both runs overlap.
- Body mass increases in both runs, but the increase is slower in the current output.
- The current run lasts much longer, but this does **not** indicate stable persistence: abundance continues to decline to almost complete loss.
- No Elephant cohort reaches maturity and no reproduction is recorded in either run.


## Kancil

Kancil shows the distinct old-to-current comparison. At the true initialized state, both runs start at **94,375 individuals** with mean individual body mass of **0.155**.

### Old Kancil

The old run shows very rapid growth and population loss:

- body mass increases from **0.155 to about 0.396 in the first 30-day update**;
- all 100 cohorts are mature by **90 days**, when mean body mass is about **1.64**;
- by 420 days, density has fallen from **94,375 to 19 individuals** (**−99.98%**);
- mean body mass has increased to about **8.51** (**~5,390% above initialization**).

### Current Kancil

The current Kancil run looks quite different from the old run over the same 420-day period.
- density drops from 94,375 to 54,351 individuals (−42.4%);
- mean body mass only increases from 0.155 to about 0.157 (+1.3%);
- Interestingly, none of the cohorts reach maturity.
So compared with the old run, the population declines much more slowly and we no longer see the very fast growth and early maturity.

The population still keeps declining over the longer run. By 3,960 days (about 10.8 years), density is down to 525 individuals, around a 99.4% decline from the start. Mean body mass increases slowly to about 0.239, but the cohorts still do not reach maturity.



```python
kancil = trajectories.loc[trajectories["test"] == "kancil"].copy()

fig, axes = plt.subplots(2, 1, figsize=(9, 8), sharex=True)

for version, data in kancil.groupby("version"):
    data = data.sort_values("elapsed_years")
    axes[0].plot(data["elapsed_years"], data["population_density"], label=version)
    axes[1].plot(
        data["elapsed_years"],
        data["mean_individual_body_mass"],
        label=version,
    )

axes[0].set_yscale("log")
axes[0].set_ylabel("Population density (individuals/km²)")
axes[0].set_title("Population density")
axes[0].legend(title="Output")

axes[1].set_xlabel("Elapsed simulation time (years)")
axes[1].set_ylabel("Mean individual body mass")
axes[1].set_title("Body mass")
axes[1].legend(title="Output")

fig.suptitle("Kancil: old vs current output")
fig.tight_layout()
plt.show()

```

### Kancil pattern

- The old run combines **very rapid body-mass growth, early maturity, and near-total population loss** within about 14 months.
- In the current run, growth and population decline are much slower over the same period.
- Current Kancil cohorts **do not reach maturity**, even over the much longer simulation.
- The current population still declines substantially over the full run, so the change is better described as **slower and less extreme dynamics**, not stable coexistence.


## Reproduction and interpretation of density decline

No reproductive mass is recorded in any of the four runs (based on the animal_cohort.csv), and no new cohort IDs appear after initialization. So the density changes here mainly show how the original cohorts survive and decline over time. This means the continued drop in density should be interpreted with some care, because there is no recruitment happening in these runs to replace individuals that are lost.



```python
reproduction_check = (
    trajectories.groupby(["test", "version"])
    .agg(
        max_reproductive_mass=("reproductive_mass", "max"),
        max_mature_cohorts=("n_mature_cohorts", "max"),
        initial_cohorts=("n_cohorts", "first"),
        final_cohorts=("n_cohorts", "last"),
    )
    .reset_index()
)

reproduction_check

```

## Cohort count

The number of cohorts also changes quite differently between the runs.
- Current Kancil: all 100 cohorts are still there at the end, even though the total number of individuals has dropped a lot.
- Old Kancil: the number of cohorts drops from 100 to 17.
- Current Elephant: the number of cohorts drops from 10 to 1.
- Old Elephant: 9 of the 10 cohorts are still present at the end.
For current Kancil, the number of individuals declines while all 100 cohort IDs remain present. In the old Kancil run, both the number of individuals and the number of cohorts decline. Elephant shows a different pattern, with much more cohort loss in the current run. 

In the exported data, the rows that are still present are all marked is_alive = True. Cohorts that disappear later seem to simply drop out of the output, rather than staying in the file with is_alive = False.


## Main findings

1. Elephant changes are fairly small. Density declines in both old and recent runs, but body mass increases more slowly in the current run.
2. Kancil shows the biggest change. The old run grows very quickly, reaches maturity early, and almost completely collapses within about 14 months. The current run grows and declines much more slowly, and never reaches maturity.
3. The current runs still decline over time. Elephant drops from 52 to 1 individual, while Kancil drops from 94,375 to 525.
4. There is no reproduction in any run judging from the empty columns of reproductive C,N,P. So the density decline likely reflects loss of the original population, with no recruitment to replace it.
5. The true starting point matters. The exporter has two states at time_index = 0, so the age-0 record should be used as the real starting value. The current script handles this in order to avoid double-counting during initialisation. 


