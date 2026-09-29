# Herbivore test: VE 0.2.1 vs VE 0.2.2

This notebook summarises the main patterns from the Level 1 herbivore test outputs for **Elephant** (slow-growing reference) and **Kancil** (faster-growing case). Currently, in our level 1 Maliau, we only have one herbivore, and default one was elephant. For simple testing, however, the choice of herbivore can affect how clearly model behaviour is observed over a relatively short simulation.

For this reason, both slow- and fast-growing herbivore cases were tested. A slow-growing case such as Elephant may show little change within a short run, whereas Kancil provides a faster-growing comparison where changes in body mass and population dynamics should become visible sooner. The intention was not to compare species biologically, but more to test behaviour and impact of using different input FG. 

Comparison of Virtual Ecosystem animal-module output for two representative herbivore tests used in Maliau Level 1:

- **Elephant**: slow-growing reference
- **Kancil**: faster-growing case

Population-density and body-mass trajectories are compared to assess changes in model output following fixes in VE 0.2.2.

**Author:** Siti Nor Baizurah · **Status:** Final

This notebook reuses the functions in `fg_population_density_local.py` and `fg_population_density_0.2.1_vs_0.2.2_metrics.py` so the numbers match the standalone script exactly.



## 1 Calculate metrics

Each run is split into its initial state (used for initialisation, and t=0) and its trajectory (the first updated state at `time_index` 0 onwards), then density and mean individual body mass are calculated per time step. The landscape is 1 km², so population density (individuals/km²) equals the total number of individuals.

```python
initial_tables, trajectory_tables = [], []
for (test, version), path in COHORT_FILES.items():
    initial, trajectory = fg_compare.process_run(
        pd.read_csv(path), test, version, **GRID
    )
    initial_tables.append(initial)
    trajectory_tables.append(trajectory)

initialisation = pd.concat(initial_tables, ignore_index=True)
trajectories = pd.concat(trajectory_tables, ignore_index=True)
trajectories.head()
```

```text
       test version  ... mean_individual_body_mass  n_cohorts
0  elephant   0.2.1  ...                       100         10
1  elephant   0.2.1  ...                     100.1         10
2  elephant   0.2.1  ...                     100.1         10
3  elephant   0.2.1  ...                     100.2         10
4  elephant   0.2.1  ...                     100.2         10

[5 rows x 9 columns]
```

## 2. Run coverage

```python
cohort_summary = fg_compare.build_cohort_summary(trajectories)
coverage = (
    trajectories.groupby(["test", "version"])
    .agg(
        start=("time", "min"),
        end=("time", "max"),
        time_steps=("time_index", "nunique"),
    )
    .reset_index()
    .merge(cohort_summary, on=["test", "version"])
)
coverage
```

```text
       test version       start  ... time_steps  initial_cohorts  final_cohorts
0  elephant   0.2.1  2010-01-01  ...         91               10              1
1  elephant   0.2.2  2010-01-01  ...         82               10              1
2    kancil   0.2.1  2010-01-01  ...        132              100            100
3    kancil   0.2.2  2010-01-01  ...        132              100             99

[4 rows x 7 columns]
```

The Elephant 0.2.2 run is 9 months shorter than 0.2.1. Both Elephant runs end with a single cohort, but Kancil keeps essentially all 100 cohorts. Longer here just means that simulation ran longer before it ended, not that necessarily means Kancil lived longer than Elephants. 

When exacly they die out? 
Elephant: dies out (down to 1) — 2017-01-31 in 0.2.1, 2015-04-02 in 0.2.2, and stays at 1 for months/years while the run keeps going. 
Kancil: never dies out in either version,still hundreds of individuals and still declining at the very last simulated step.

```python
initialisation[
    ["test", "version", "total_individuals", "population_density",
     "mean_individual_body_mass", "n_cohorts"]
]
```

```text
       test version  ...  mean_individual_body_mass  n_cohorts
0  elephant   0.2.1  ...                        100         10
1  elephant   0.2.2  ...                        100         10
2    kancil   0.2.1  ...                      0.155        100
3    kancil   0.2.2  ...                      0.155        100

[4 rows x 6 columns]
```

Note: I did not set empirical density here, so it will be by default "Madingley" that initialise the populations.

## 3. Change over the period shared by all four runs

```python
slow_fast_summary = fg_compare.build_slow_fast_summary(trajectories)
slow_fast_summary
```

```text
       test version  ... end_body_mass body_mass_change_over_common_period_percent
0  elephant   0.2.1  ...         103.4                                       3.346
1    kancil   0.2.1  ...        0.1769                                       13.55
2  elephant   0.2.2  ...         103.4                                        3.37
3    kancil   0.2.2  ...        0.2145                                        37.7

[4 rows x 10 columns]
```

Note: this summary table is a reasonable checkpoint, but not trustworthy on its own, the trajectory in the next section, is where the real story is.

## 4. How the versions diverge over time

End-point values can hide differences along the trajectory, so the percentage difference (of density and body mass) of 0.2.2 relative to 0.2.1 is calculated at every shared date (here means dates that both versions were still running on, so a real side-by-side comparison is possible.).

```python
def version_difference(test: str) -> pd.DataFrame:
    """Return 0.2.2-vs-0.2.1 percentage differences at each shared date."""
    wide = (
        trajectories.loc[trajectories["test"] == test]
        .pivot(index="time", columns="version",
               values=["population_density", "mean_individual_body_mass"])
        .dropna()
    )
    return pd.DataFrame({
        "density_0.2.1": wide[("population_density", "0.2.1")],
        "density_0.2.2": wide[("population_density", "0.2.2")],
        "density_diff_%": (wide[("population_density", "0.2.2")]
                           / wide[("population_density", "0.2.1")] - 1) * 100,
        "body_mass_0.2.1": wide[("mean_individual_body_mass", "0.2.1")],
        "body_mass_0.2.2": wide[("mean_individual_body_mass", "0.2.2")],
        "body_mass_diff_%": (wide[("mean_individual_body_mass", "0.2.2")]
                             / wide[("mean_individual_body_mass", "0.2.1")] - 1) * 100,
    })


differences = {test: version_difference(test) for test in ["elephant", "kancil"]}

largest = pd.DataFrame([
    {
        "test": test,
        "max_abs_density_diff_%": d["density_diff_%"].abs().max(),
        "density_diff_date": d["density_diff_%"].abs().idxmax(),
        "max_abs_body_mass_diff_%": d["body_mass_diff_%"].abs().max(),
        "body_mass_diff_date": d["body_mass_diff_%"].abs().idxmax(),
    }
    for test, d in differences.items()
])
largest
```

```text
       test  ...  body_mass_diff_date
0  elephant  ...           2016-10-01
1    kancil  ...           2016-05-02

[2 rows x 5 columns]
```

Legend

-max_abs_density_diff_% : The single biggest gap between 0.2.1 and 0.2.2's population density, found on any date across the whole run

-density_diff_date: The date that biggest density gap happened on

-max_abs_body_mass_diff_%: The single biggest gap between 0.2.1 and 0.2.2's body mass, found on any date across the whole run

-body_mass_diff_date: The date that biggest body-mass gap happened on

## 5. Kancil (fast-growing-medium sized herbivore)

Kancil year by year, seems like for the density barely differs between versions, but body mass tells a different story. Seems like they put weight faster for several years, and settle to similar value or both versions. 
Kancil, sampled roughly yearly:

```python
kancil_diff = differences["kancil"]
kancil_diff.iloc[:: max(1, len(kancil_diff) // 11)]
```

```text
            density_0.2.1  density_0.2.2  ...  body_mass_0.2.2  body_mass_diff_%
time                                      ...                                   
2010-01-01         90,704         90,748  ...           0.1558        -0.0001153
2011-01-01         56,558         56,684  ...           0.1636             4.172
2012-01-01         35,044         35,460  ...           0.1703             8.343
2012-12-31         21,575         22,202  ...           0.1777             12.68
2014-01-01         13,267         13,839  ...            0.186             16.85
2015-01-01          8,121          8,749  ...           0.1953             19.99
2016-01-01          5,076          5,467  ...           0.2058             21.74
2016-12-31          3,240          3,428  ...           0.2175             20.31
2018-01-01          2,096          2,170  ...           0.2299             17.66
2019-01-01          1,291          1,338  ...           0.2366              12.8
2020-01-01            821            843  ...            0.238              5.87

[11 rows x 6 columns]
```

## 6. Elephant (slow growing-large sized herbivore)

While for elephant, body mass identical between versions the whole way thorugh, but density surely looks wild. 
Elephant, sampled roughly every six months:

```python
elephant_diff = differences["elephant"]
elephant_diff.iloc[:: max(1, len(elephant_diff) // 13)]
```

```text
            density_0.2.1  density_0.2.2  ...  body_mass_0.2.2  body_mass_diff_%
time                                      ...                                   
2010-01-01             51             52  ...              100        -3.015e-07
2010-07-02             41             41  ...            100.3          0.002208
2011-01-01             35             30  ...            100.5          0.005194
2011-07-02             26             23  ...            100.8           0.00882
2012-01-01             20             19  ...              101           0.01267
2012-07-02             16             15  ...            101.3           0.01599
2012-12-31             14              9  ...            101.5            0.0186
2013-07-02             10              6  ...            101.8           0.02036
2014-01-01              7              5  ...              102           0.02167
2014-07-02              6              4  ...            102.3           0.02248
2015-01-01              6              2  ...            102.5             0.023
2015-07-02              6              1  ...            102.8           0.02326
2016-01-01              5              1  ...              103            0.0235
2016-07-02              4              1  ...            103.3           0.02357

[14 rows x 6 columns]
```

## 7. Trajectory plots

```python
def show_comparison(test: str) -> None:
    """Plot 0.2.1 and 0.2.2 density and body-mass trajectories inline."""
    data = trajectories.loc[trajectories["test"] == test]
    shared_dates = set.intersection(
        *[set(g["time"]) for _, g in data.groupby("version")]
    )
    shared = data.loc[data["time"].isin(shared_dates)]

    figure, axes = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
    for version, group in shared.groupby("version"):
        group = group.sort_values("time_index")
        axes[0].plot(group["time_index"], group["population_density"], label=version)
        axes[1].plot(group["time_index"], group["mean_individual_body_mass"], label=version)

    density = shared["population_density"]
    if (density > 0).all() and density.max() / density.min() >= 100:
        axes[0].set_yscale("log")

    axes[0].set_ylabel("Population density (individuals/km²)")
    axes[0].set_title("Population density")
    axes[1].set_ylabel("Mean individual body mass")
    axes[1].set_xlabel("Time index (months)")
    axes[1].set_title("Body mass")
    for axis in axes:
        axis.legend(title="VE version")
    figure.suptitle(f"{test.capitalize()}: VE 0.2.1 vs 0.2.2")
    figure.tight_layout()
    plt.show()


show_comparison("kancil")
```

```text
<Figure size 900x700 with 2 Axes>
```

![output 1](herbivore_0.2.1_vs_0.2.2_report_files/output_1.png)

```python
show_comparison("elephant")
```

```text
<Figure size 900x700 with 2 Axes>
```

![output 2](herbivore_0.2.1_vs_0.2.2_report_files/output_2.png)

## 8. Interpretation

### Kancil

- **Body mass:** This is where the main difference between the two versions shows up. In 0.2.1, body mass stays fairly flat for the first few years before increasing. In 0.2.2, growth starts straight away and then levels off later in the run.
- The final body mass is quite similar between the two runs, so looking only at the end point would miss this difference in the growth pattern.
- **Density:** Both versions show a similar steady decline, with 0.2.2 staying slightly higher.

### Elephant

- **Body mass:** There is very little difference between versions. Both show slow, gradual growth.
- **Density:** Both decline, although 0.2.2 reaches very low numbers a bit earlier. Since only a few individuals are left by then, the percentage difference looks larger than the actual difference in numbers.

### Overall

The clearest effect of the version change is on **Kancil body mass**, where the growth pattern changes quite noticeably. Elephant body mass is mostly unchanged, and both herbivores still show a strong decline in density.

So for this test, the biggest change between the two runs is in how the faster-growing Kancil gains mass, rather than in the overall population decline. (Note: since the runs also differ in configuration, this can't be attributed to the mass-transfer fix alone.)

Just from this testing, it seems like using Kancil as the representative for Maliau_1 now, seems more robust. 

## 9. Caveats

- The runs differ in VE version and configuration
- Elephant results rest on ≤52 individuals and a single stochastic run; differences of a few individuals should not be over-interpreted.
- Trajectory `time_index` 0 uses the first updated state, so Elephant starts at 51 (0.2.1) vs 52 (0.2.2) despite identical initialisation.
