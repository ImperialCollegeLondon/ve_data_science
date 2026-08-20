---
title: Herbivore population-density test

description: |
  This notebook compares population-density trajectories from three Virtual Ecosystem animal-module test runs:

  - **Elephant** — the original Maliau_2, Level 1 herbivore input.
  - **Kancil** — a smaller, faster-growing herbivore input.
  - **Kancil + density override** — the Kancil input with the population-density override enabled.

virtual_ecosystem_module: Animal

author:
  - Siti Nor Baizurah

status: final

input_files:
  - name: animal_cohort_data_elephant.csv
    path: /ve_data_science/data/derived/animal/herbivore_test/
    description: |
      Animal cohort output from the Elephant herbivore test run, used as the
      larger and slower-growing herbivore comparison.

  - name: animal_cohort_data_kancil.csv
    path: /ve_data_science/data/derived/animal/herbivore_test/
    description: |
      Animal cohort output from the Kancil herbivore test run, used to examine
      the population-density trajectory of a smaller and faster-growing herbivore.

  - name: animal_cohort_data_kancildensity.csv
    path: /ve_data_science/data/derived/animal/herbivore_test/
    description: |
      Animal cohort output from the Kancil test with the population-density
      override enabled, used to assess whether the override changes the initial
      population density and subsequent trajectory.

output_files: []

package_dependencies:
  - pandas
  - matplotlib

usage_notes: |
  Side quest while updating the input data for Maliau, I test whether replacing the elephant input with kancil (deer) changes the population-density trajectory and improves persistence. The second aim is to test whether the population-density override produces a more plausible initial population density and changes the subsequent trajectory.

  Throughout this report, Elephant and Kancil are used as convenient labels for the test configurations. They should not be interpreted as restricting the comparison to these species specifically. The main contrast being tested is between a larger, slower-growing herbivore and a smaller, faster-growing herbivore over relatively short simulation runs that VE can produce. The simulations use a **10 × 10 grid of 100 m × 100 m cells**, giving a total landscape area of **1 km²**. For these landscape-scale tests, the summed number of individuals is therefore numerically equal to population density in individuals/km².

  The runs are not all the same length, so direct numerical comparison is made at the **last timestep shared by all three outputs**. Run using Virtual Ecosystem v0.2.1 on Windows 11.

---

## 1. Data preparation

The three cohort outputs are read directly and converted to landscape-scale functional-group population density using the pop density tool (#241 Github). All input and cohort data are stored in Globus.

```python
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

# Update this path if the cohort files are stored elsewhere locally.
DATA_DIR = Path("/ve_data_science/data/derived/animal/herbivore_test/")

cohort_files = {
    "Elephant": DATA_DIR / "animal_cohort_data_elephant.csv",
    "Kancil": DATA_DIR / "animal_cohort_data_kancil.csv",
    "Kancil + density override": DATA_DIR / "animal_cohort_data_kancildensity.csv",
}

LANDSCAPE_AREA_KM2 = 1.0

all_density_data = []
for test_name, cohort_file in cohort_files.items():
    cohort_df = pd.read_csv(cohort_file)

    density_df = (
        cohort_df.groupby(["time_index", "functional_group"], as_index=False)["individuals"]
        .sum()
        .rename(columns={"individuals": "total_individuals"})
    )
    density_df["population_density"] = (
        density_df["total_individuals"] / LANDSCAPE_AREA_KM2
    )
    density_df["test"] = test_name
    all_density_data.append(density_df)

combined_df = pd.concat(all_density_data, ignore_index=True)
combined_df.head()
```

**Output:**

|   | time_index | functional_group | total_individuals | population_density | test |
|---|---|---|---|---|---|
| 0 | 0 | Herbivorous_endotherms | 103 | 103.0 | Elephant |
| 1 | 1 | Herbivorous_endotherms | 47 | 47.0 | Elephant |
| 2 | 2 | Herbivorous_endotherms | 45 | 45.0 | Elephant |
| 3 | 3 | Herbivorous_endotherms | 45 | 45.0 | Elephant |
| 4 | 4 | Herbivorous_endotherms | 43 | 43.0 | Elephant |

## 2. Run coverage

The elephant output continues beyond the point where both Kancil outputs stop. Establishing the available run length is important because the final values from the three outputs are not directly comparable when the simulations end at different timesteps.

```python
run_coverage = (
    combined_df.groupby("test")
    .agg(
        first_time_index=("time_index", "min"),
        last_time_index=("time_index", "max"),
        n_time_steps=("time_index", "nunique"),
    )
    .reset_index()
)
run_coverage
```

**Output:**

|   | test | first_time_index | last_time_index | n_time_steps |
|---|---|---|---|---|
| 0 | Elephant | 0 | 28 | 29 |
| 1 | Kancil | 0 | 13 | 14 |
| 2 | Kancil + density override | 0 | 13 | 14 |

Both Kancil runs stop at **time index 13**, whereas the elephant run continues to **time index 28**. The cohort outputs alone do not establish why the Kancil runs stop, so this report does not interpret the shorter run as evidence of extinction or simulation failure without checking the corresponding model output/logs.

## 3. Comparison at the last shared timestep

The table below compares the initial density, density at the last timestep shared by all three runs (t=13), the percentage change to that shared timestep (t=0-13), and the final density available in each output. Using the last shared timestep avoids comparing the Kancil runs at time index 13 with the elephant run at time index 28. Here, the percentage change shows how much population density changed between the start of each run (time index 0) to the last shared (time index 13). The final density is shown separately because the Elephant run (larger herbivore and longer time required from young-adult) continues beyond time index 13, whereas time index 13 is already the final available timestep for both Kancil runs.

```python
shared_times = set.intersection(
    *[
        set(group["time_index"])
        for _, group in combined_df.groupby("test")
    ]
)
last_shared_time = max(shared_times)

summary_rows = []
for test_name, group in combined_df.groupby("test"):
    group = group.sort_values("time_index")
    first = group.iloc[0]
    last = group.iloc[-1]
    shared = group.loc[group["time_index"] == last_shared_time].iloc[0]

    summary_rows.append(
        {
            "test": test_name,
            "initial_density_ind_km2": first["population_density"],
            f"density_at_t{last_shared_time}_ind_km2": shared["population_density"],
            "change_to_shared_time_percent": (
                (shared["population_density"] - first["population_density"])
                / first["population_density"]
                * 100
            ),
            "last_time_index": int(last["time_index"]),
            "final_available_density_ind_km2": last["population_density"],
        }
    )

summary = pd.DataFrame(summary_rows)
summary.round(2)
```

**Output:**

|   | test | initial_density_ind_km2 | density_at_t13_ind_km2 | change_to_shared_time_percent | last_time_index | final_available_density_ind_km2 |
|---|---|---|---|---|---|---|
| 0 | Elephant | 103.0 | 31.0 | -69.90 | 28 | 14.0 |
| 1 | Kancil | 185969.0 | 19.0 | -99.99 | 13 | 19.0 |
| 2 | Kancil + density override | 185883.0 | 8.0 | -100.00 | 13 | 8.0 |

### Initial interpretation

The Kancil run declines from approximately **185,969 individuals/km²** to **19 individuals/km²** by time index 13. Surprisingly, the density-override run shows a similarly steep decline and reaches **8 individuals/km²** at the same timestep. A key point for review is that the two Kancil runs also begin at almost the same effective landscape density (**185,969** versus **185,883 individuals/km²**). Therefore, these outputs do **not yet demonstrate that the override substantially changed the initial population density represented in the cohort output**.

## 4. Population-density trajectories

A logarithmic y-axis is used because the initial Kancil densities are several orders of magnitude larger than the elephant density; a linear scale would make the elephant trajectory invisible on the graph.

```python
fig, ax = plt.subplots(figsize=(10, 6))

for test_name, group in combined_df.groupby("test"):
    group = group.sort_values("time_index")
    ax.plot(
        group["time_index"],
        group["population_density"],
        marker="o",
        label=test_name,
        linewidth=2,
    )

ax.set_xlabel("Time index", fontsize=12)
ax.set_ylabel("Population density (individuals/km²)", fontsize=12)
ax.set_title("Herbivore population-density trajectories", fontsize=14, fontweight="bold")
ax.set_yscale("log")
ax.legend(fontsize=10)
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()
```

**Output:** A logarithmic plot showing population density trajectories for all three test runs across time indices.
