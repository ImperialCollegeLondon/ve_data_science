# Scenarios of data–prediction (mis)match for validation

## Background

For the Maliau scenarios, VE produces predictions of a state variable
$X(i, t)$, where $i$ indexes a spatial cell ID and $t$ indexes a monthly
time step. (Let’s ignore other dimensions such as element and PFT here.)
However, empirical data used for validation are heterogeneous: a given
dataset may or may not carry spatial coordinates and/or a time stamp.
Where coordinates exist, their resolution may not match that of our
model (i.e., the temporal resolution may not be monthly, or the spatial
resolution may not be $100 \times 100$ m^2^).

An old-growth forest dataset that resembles Maliau may also fall outside of the
Maliau spatial extent. We decided to include this sort of dataset (?) but will
need to decide how to link data to predictions spatially.

We need a decision tree of matching validation data to model
predictions. Currently the task is tracked as Issue
[\#340](https://github.com/ImperialCollegeLondon/ve_data_science/issues/340).

## Decision tree

Crossing the spatial and temporal dimensions — each with three levels
(absent, exact match, resolution mismatch) — yields a $3 \times 3$
matrix of nine validation scenarios. Please check if I’ve missed
anything.

|                                        | **T0: no time coord**                    | **T1: exact (monthly)**          | **T2: resolution mismatch/range only**          |
| :------------------------------------- | :--------------------------------------- | :------------------------------- | :---------------------------------------------- |
| **S0: no space coord**                 | Grand mean or discard data               | Spatial mean per $t$             | Spatial mean + agg finer side to coarser period |
| **S1: exact grid match**               | Temporal mean per cell                   | Direct match ⭐                  | Agg finer side temporally, per cell             |
| **S2: resolution mismatch/range only** | Agg finer side spatially + temporal mean | Agg finer side spatially per $t$ | Agg finer side in both dimensions               |

Note that “resolution mismatch” covers two sub-cases: data are finer
than predictions and therefore need upscaling, and vice versa. But this
is a detail that we can discuss next time.

The matrix translates directly into a decision tree. The first node
split by spatial coordinates, and the second nodes by temporal
coordinates.

``` mermaid
flowchart LR
    A[Spatial coords in data?]

    A -->|S0: No| B[Temporal coords?]
    B -->|T0: No| C["S0-T0: Grand mean or discard data"]
    B -->|T1: Exact| D["S0-T1: Spatial mean per t"]
    B -->|T2: Mismatch| E["S0-T2: Spatial mean +<br/>agg to coarser period"]

    A -->|S1: Exact grid| F[Temporal coords?]
    F -->|T0: No| G["S1-T0: Temporal mean per cell"]
    F -->|T1: Exact| H["S1-T1: Direct match ⭐"]
    F -->|T2: Mismatch| I["S1-T2: Agg temporally per cell"]

    A -->|S2: Mismatch/range| J[Temporal coords?]
    J -->|T0: No| K["S2-T0: Agg spatially<br/>+ temporal mean"]
    J -->|T1: Exact| L["S2-T1: Agg spatially per t"]
    J -->|T2: Mismatch| M["S2-T2: Agg in both<br/>dimensions"]
```

~~Discussing and deciding on this decision tree will help us map it
directly to a nested `if`-`else` chain in code.~~

## Possible solution

This is very rough idea for getting feedback:

- I imagine a function that finds the best-matching predicted data to each
  observed data
- For such a matching, each observed data will need
  - Spatial coordinates
    - xmin, xmax, ymin, ymax
    - for point coordinates, xmin = xmax and ymin = ymax
  - Temporal coordinates
    - time start, time end
    - for point coordinates, time start = time end
- Then search for best match prediction data
  - If observation space and time window span multiple prediction data points,
    aggregate the latter
