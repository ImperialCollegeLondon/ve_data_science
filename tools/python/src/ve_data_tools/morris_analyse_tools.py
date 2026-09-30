"""
---
title: Morris screening tools for Virtual Ecosystem ensembles

description: |
    Provides shared, module-independent functions for Morris screening analysis
    of Virtual Ecosystem (VE) model ensembles. Module-specific analysis scripts
    pass in the Morris design and extracted model responses.

    The module calculates scalar, spatial, and temporal elementary-effect
    statistics with SALib. It applies the screening rule, estimates ranking
    stability through trajectory bootstrap resampling, identifies the dominant
    parameter in each grid cell, and writes tables, figures, and a summary.

    Effects are scaled by each parameter's sampled range, allowing parameters to
    be compared within a response. Relative mu-star compares influence across
    responses. Replicate runs, when available, estimate the response noise floor
    used to qualify the screening results.

virtual_ecosystem_module: All

author:
  - Lelavathy

status: wip

input_files:
  - name: none
    path: none
    description: Works on arrays and tables passed in by the analysis script.

output_files:
  - name: Morris tables, figures and summary.md
    path: data/sensitivity/<module>/analysis/<run_name>/
    description: Written for the calling analysis script.

imported_files:
    - name: sensitivity_tools.py
        path: tools/python/src/ve_data_tools/sensitivity_tools.py
        description: Provides parameter styles, map, and figure helpers.

package_dependencies:
  - numpy
  - pandas
  - SALib
  - matplotlib

usage_notes: |
    Import only from a module-specific analysis script, such as
    analysis/abiotic/sensitivity/morris_analyse_hydrology.py. The calling script
    supplies the verified Morris design, response arrays, output directory, and
    screening settings.

references: |
    Morris, M. D. (1991). Factorial sampling plans for preliminary computational
    experiments. Technometrics, 33(2), 161-174.
    https://doi.org/10.1080/00401706.1991.10484804

    Campolongo, F., Cariboni, J., and Saltelli, A. (2007). An effective screening
    design for sensitivity analysis of large models. Environmental Modelling and
    Software, 22(10), 1509-1518. https://doi.org/10.1016/j.envsoft.2006.10.004

    Herman, J. D., Kollat, J. B., Reed, P. M., and Wagener, T. (2013). From maps
    to movies: High-resolution time-varying sensitivity analysis for spatially
    distributed watershed models. Hydrology and Earth System Sciences, 17,
    2893-2903. https://doi.org/10.5194/hess-17-2893-2013

Further information on SALib usage and supported sampling methods is available
in the SALib documentation: https://salib.readthedocs.io/en/latest
---
"""  # noqa: D400, D205, D212, D415

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
from ve_data_tools.sensitivity_tools import (
    _format_map_axis,
    _map_extent,
    default_outlet_label,
    draw_outlets,
    other_colour,
    outlet_legend_handle,
    outlet_text,
    parameter_styles,
    plot_heatmap,
    plot_maps,
    pyplot,
    salib_problem,
    save_figure,
)


def morris_delta(num_levels: int) -> float:
    """Calculate the Morris step on the unit hypercube.

    With p = ``num_levels``, each parameter is sampled on p evenly spaced
    levels in [0, 1] and every elementary effect moves one parameter by the
    step p / (2 (p - 1)) (Morris, 1991); for p = 4 the step is 2/3.

    Args:
        num_levels: Number of levels p in the Morris sampling design.

    Returns:
        The step size p / (2 (p - 1)), where p = ``num_levels``.

    """
    return num_levels / (2.0 * (num_levels - 1))


def morris_indices(
    problem: dict,
    samples: np.ndarray,
    y: np.ndarray,
    *,
    num_levels: int,
    num_resamples: int,
    conf_level: float,
    seed: int,
) -> pd.DataFrame:
    """Calculate Morris indices for one response.

    Args:
        problem: SALib problem definition for the sampled parameters.
        samples: Morris design samples in sampling space.
        y: One response value for each sampled model run.
        num_levels: Number of levels in the Morris sampling design.
        num_resamples: Bootstrap resamples used for the confidence interval.
        conf_level: Confidence level for the mu-star confidence interval.
        seed: Random seed for bootstrap resampling.

    Returns:
        A table containing mu, mu-star, mu-star confidence interval, sigma,
        relative mu-star, sigma over mu-star, and rank for every parameter.

    """
    from SALib.analyze import morris

    result = morris.analyze(
        salib_problem(problem),
        samples,
        np.asarray(y, float),
        num_resamples=num_resamples,
        conf_level=conf_level,
        num_levels=num_levels,
        seed=seed,
    )
    table = pd.DataFrame(
        {
            "parameter": problem["names"],
            "mu": np.asarray(result["mu"], float),
            "mu_star": np.asarray(result["mu_star"], float),
            "mu_star_conf": np.asarray(result["mu_star_conf"], float),
            "sigma": np.asarray(result["sigma"], float),
        }
    )
    top = table["mu_star"].max()
    table["mu_star_rel"] = table["mu_star"] / top if top > 0 else 0.0
    table["sigma_over_mu_star"] = np.where(
        table["mu_star"] > 0, table["sigma"] / table["mu_star"], np.nan
    )
    table["rank"] = table["mu_star"].rank(ascending=False, method="min").astype(int)
    return table


def scalar_morris(
    problem,
    samples,
    data,
    *,
    num_levels,
    num_resamples,
    conf_level,
    seed,
    threshold,
    noise=None,
) -> pd.DataFrame:
    """Calculate Morris indices and screening flags for scalar responses.

    Args:
        problem: SALib problem definition for the sampled parameters.
        samples: Morris design samples in sampling space.
        data: Extracted scalar responses and their primary or secondary groups.
        num_levels: Number of levels in the Morris sampling design.
        num_resamples: Bootstrap resamples used for the confidence interval.
        conf_level: Confidence level for the mu-star confidence interval.
        seed: Random seed for bootstrap resampling.
        threshold: Relative mu-star threshold for an influential parameter.
        noise: Optional replicate-response table used to calculate a noise floor.

    Returns:
        A table of Morris indices and screening flags for every scalar response
        and sampled parameter.

    """
    tables = []
    for s, (name, group) in enumerate(zip(data["scalar_names"], data["scalar_groups"])):
        table = morris_indices(
            problem,
            samples,
            data["scalars"][:, s],
            num_levels=num_levels,
            num_resamples=num_resamples,
            conf_level=conf_level,
            seed=seed,
        )
        table.insert(0, "group", group)
        table.insert(0, "response", name)
        table["influential"] = table["mu_star_rel"] >= threshold
        if noise is not None:
            std = float(noise.set_index("response").loc[name, "replicate_std"])
            table["ee_noise_floor"] = np.sqrt(2.0) * std / morris_delta(num_levels)
            table["above_noise"] = table["mu_star"] > table["ee_noise_floor"]
            table["influential"] &= table["above_noise"]
        tables.append(table)
    return pd.concat(tables, ignore_index=True)


def screening_decision(scalar: pd.DataFrame, secondary_support: int) -> pd.DataFrame:
    """Select Sobol candidates from scalar Morris screening results.

    Args:
        scalar: Morris index table for the scalar responses.
        secondary_support: Number of influential secondary responses required for
            a candidate without primary-response support.

    Returns:
        A parameter table with influential-response counts, summary indices,
        Sobol candidate flags, and selection reasons.

    """
    primary = scalar[scalar["group"] == "primary"]
    secondary = scalar[scalar["group"] == "secondary"]
    decision = pd.DataFrame({"parameter": scalar["parameter"].unique()})

    def per_parameter(frame, column, how):
        return decision["parameter"].map(frame.groupby("parameter")[column].agg(how))

    decision["n_primary_influential"] = (
        per_parameter(primary, "influential", "sum").fillna(0).astype(int)
    )
    decision["n_secondary_influential"] = (
        per_parameter(secondary, "influential", "sum").fillna(0).astype(int)
    )
    decision["max_mu_star_rel_primary"] = per_parameter(primary, "mu_star_rel", "max")
    decision["max_mu_star_rel_any"] = per_parameter(scalar, "mu_star_rel", "max")
    decision["mean_sigma_over_mu_star_primary"] = per_parameter(
        primary, "sigma_over_mu_star", "mean"
    )
    decision["sobol_candidate"] = (decision["n_primary_influential"] >= 1) | (
        decision["n_secondary_influential"] >= secondary_support
    )
    decision["reason"] = np.select(
        [decision["n_primary_influential"] >= 1, decision["sobol_candidate"]],
        [
            "influential for a primary response",
            f"influential for >= {secondary_support} secondary responses",
        ],
        default="screened out",
    )
    return decision.sort_values(
        ["sobol_candidate", "max_mu_star_rel_primary"], ascending=[False, False]
    ).reset_index(drop=True)


def field_morris(
    problem, samples, data, kind: str, *, num_levels, num_resamples, conf_level, seed
) -> pd.DataFrame:
    """Calculate Morris indices for each map cell or month.

    Args:
        problem: SALib problem definition for the sampled parameters.
        samples: Morris design samples in sampling space.
        data: Extracted spatial maps and monthly response series.
        kind: ``"map"`` for map cells or ``"series"`` for monthly values.
        num_levels: Number of levels in the Morris sampling design.
        num_resamples: Bootstrap resamples used for the confidence interval.
        conf_level: Confidence level for the mu-star confidence interval.
        seed: Random seed for bootstrap resampling.

    Returns:
        A long table of Morris indices for each parameter and map cell or month.

    """
    rows = []
    for f, field in enumerate(data["fields"]):
        values = data["maps"][:, f] if kind == "map" else data["series"][:, f]
        flat = values.reshape(values.shape[0], -1)
        for j in range(flat.shape[1]):
            table = morris_indices(
                problem,
                samples,
                flat[:, j],
                num_levels=num_levels,
                num_resamples=num_resamples,
                conf_level=conf_level,
                seed=seed,
            ).drop(columns="rank")
            table.insert(0, "field", field)
            if kind == "map":
                row, col = np.unravel_index(j, values.shape[1:])
                table.insert(1, "x", data["x"][col])
                table.insert(2, "y", data["y"][row])
            else:
                table.insert(1, "date", data["dates"][j])
            rows.append(table)
    return pd.concat(rows, ignore_index=True)


# -----------------------------------------------------------------------------
# Figures
# -----------------------------------------------------------------------------


def morris_parameter_styles(decision: pd.DataFrame) -> dict:
    """Create a consistent colour style for each Morris parameter.

    Parameters that matter (Sobol candidates, or influential for any response)
    get the categorical colours, most influential first (at most 8); all other
    parameters are grey. The mapping never changes between figures.

    Args:
        decision: Parameter-level Morris screening decision table.

    Returns:
        A mapping from parameter names to plotting styles.

    """
    frame = decision.sort_values(
        ["sobol_candidate", "max_mu_star_rel_any"], ascending=[False, False]
    )
    matters = (
        frame["sobol_candidate"]
        | (frame["n_primary_influential"] > 0)
        | (frame["n_secondary_influential"] > 0)
    )
    return parameter_styles(frame["parameter"].tolist(), n_colours=int(matters.sum()))


def _panel_grid(plt, n: int, ncols: int, width: float, height: float):
    ncols = max(1, min(ncols, n))
    nrows = int(np.ceil(n / ncols))
    fig, axes = plt.subplots(
        nrows,
        ncols,
        figsize=(width * ncols, height * nrows + 1.6),
        squeeze=False,
        layout="constrained",
    )
    fig.get_layout_engine().set(w_pad=0.15, h_pad=0.2, wspace=0.12, hspace=0.12)
    for ax in axes.flat[n:]:
        ax.set_visible(False)
    return fig, axes


def _parameter_legend_handles(styles: dict, *, markers: bool) -> list:
    from matplotlib.lines import Line2D
    from matplotlib.patches import Patch

    handles = []
    for name, style in styles.items():
        if not style["coloured"]:
            continue
        if markers:
            handles.append(
                Line2D(
                    [],
                    [],
                    marker=style["marker"],
                    markersize=8,
                    color=style["colour"],
                    markeredgecolor="white",
                    linestyle="none",
                    label=name,
                )
            )
        else:
            handles.append(Patch(facecolor=style["colour"], label=name))
    if any(not s["coloured"] for s in styles.values()):
        if markers:
            handles.append(
                Line2D(
                    [],
                    [],
                    marker="o",
                    markersize=7,
                    markerfacecolor="none",
                    markeredgecolor=other_colour,
                    linestyle="none",
                    label="other parameters",
                )
            )
        else:
            handles.append(Patch(facecolor=other_colour, label="other parameters"))
    return handles


def plot_ranking_panels(
    scalar: pd.DataFrame,
    responses: list[str],
    styles: dict,
    path: Path,
    *,
    title: str,
    threshold: float,
    ncols: int = 2,
) -> None:
    """mu* bar chart per response, 2 columns (2 x 2 for four responses).

    Bars carry each parameter's colour; faded bars are below the screening
    threshold (or the noise floor). Whiskers are bootstrap confidence intervals.
    """
    from matplotlib.lines import Line2D
    from matplotlib.patches import Patch

    plt = pyplot()
    fig, axes = _panel_grid(plt, len(responses), ncols, 7.6, 5.0)
    has_noise = "ee_noise_floor" in scalar
    for ax, response in zip(axes.flat, responses):
        t = scalar[scalar["response"] == response].sort_values("mu_star")
        bars = ax.barh(t["parameter"], t["mu_star"], height=0.7)
        for bar, parameter, influential in zip(bars, t["parameter"], t["influential"]):
            colour = styles[parameter]["colour"]
            # influential: filled; not influential: outline only, same colour
            bar.set_facecolor(colour if influential else "white")
            bar.set_edgecolor(colour)
            bar.set_linewidth(1.2)
        ax.errorbar(
            t["mu_star"],
            np.arange(len(t)),
            xerr=t["mu_star_conf"],
            fmt="none",
            ecolor="#3a3a38",
            elinewidth=1.0,
            capsize=2.5,
        )
        ax.axvline(threshold * t["mu_star"].max(), color="#52514e", ls="--", lw=1.0)
        if has_noise:
            ax.axvline(t["ee_noise_floor"].iloc[0], color="black", ls=":", lw=1.2)
        ax.set_title(response, fontsize=11)
        ax.set_xlabel("mu* (response units per unit parameter range)", fontsize=9)
        ax.tick_params(axis="y", labelsize=8)
        ax.tick_params(axis="x", labelsize=8)
        ax.set_xlim(left=0)
        ax.grid(axis="x", color="#e6e5e1", lw=0.6)
        ax.set_axisbelow(True)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
    handles = _parameter_legend_handles(styles, markers=False)
    handles += [
        Patch(
            facecolor="white",
            edgecolor="#52514e",
            label="outline only: below threshold (not influential)",
        ),
        Line2D([], [], color="#3a3a38", lw=1.0, label="95% bootstrap CI of mu*"),
        Line2D(
            [],
            [],
            color="#52514e",
            ls="--",
            lw=1.0,
            label=f"screening threshold ({threshold:.0%} of max mu*)",
        ),
    ]
    if has_noise:
        handles.append(
            Line2D([], [], color="black", ls=":", lw=1.2, label="replicate noise floor")
        )
    fig.legend(
        handles=handles,
        loc="outside lower center",
        ncol=4,
        fontsize=8.5,
        frameon=False,
    )
    fig.suptitle(title, fontsize=13)
    save_figure(fig, path)


def plot_mu_sigma_panels(
    scalar: pd.DataFrame,
    responses: list[str],
    styles: dict,
    path: Path,
    *,
    title: str,
    ncols: int = 2,
) -> None:
    """mu*-sigma plane per response; colour and marker identify the parameter."""
    from matplotlib.lines import Line2D

    plt = pyplot()
    fig, axes = _panel_grid(plt, len(responses), ncols, 6.2, 5.2)
    for ax, response in zip(axes.flat, responses):
        t = scalar[scalar["response"] == response]
        lim = max(t["mu_star"].max(), t["sigma"].max()) * 1.08 or 1.0
        ax.plot([0, lim], [0, lim], color="#9a9a96", ls=":", lw=1.2)
        # grey (other) first so coloured markers sit on top
        for _, r in t.sort_values(
            "parameter", key=lambda c: c.map(lambda p: styles[p]["coloured"])
        ).iterrows():
            style = styles[r["parameter"]]
            ax.scatter(
                r["mu_star"],
                r["sigma"],
                s=64 if style["coloured"] else 36,
                marker=style["marker"],
                facecolors=style["colour"] if style["coloured"] else "none",
                edgecolors="white" if style["coloured"] else other_colour,
                linewidths=1.0,
                zorder=3,
            )
        ax.set(xlim=(0, lim), ylim=(0, lim))
        ax.set_title(response, fontsize=11)
        ax.set_xlabel("mu* (influence)", fontsize=9)
        ax.set_ylabel("sigma (non-linearity / interaction)", fontsize=9)
        ax.tick_params(labelsize=8)
        ax.grid(color="#e6e5e1", lw=0.6)
        ax.set_axisbelow(True)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
    handles = _parameter_legend_handles(styles, markers=True)
    handles.append(
        Line2D(
            [],
            [],
            color="#9a9a96",
            ls=":",
            lw=1.2,
            label="sigma = mu* (above: non-linear and/or interacting)",
        )
    )
    fig.legend(
        handles=handles,
        loc="outside lower center",
        ncol=4,
        fontsize=8.5,
        frameon=False,
    )
    fig.suptitle(title, fontsize=13)
    save_figure(fig, path)


def plot_scatter(
    problem,
    samples,
    data,
    response: str,
    parameters: list[str],
    path: Path,
    styles: dict | None = None,
    ncols: int = 2,
) -> None:
    """Response against each of the given parameters (visual check).

    Shows non-linearity, thresholds and outliers that summary indices hide.
    """
    plt = pyplot()
    y = data["scalars"][:, list(data["scalar_names"]).index(response)]
    fig, axes = _panel_grid(plt, len(parameters), ncols, 5.2, 4.0)
    for ax, parameter in zip(axes.flat, parameters):
        column = problem["names"].index(parameter)
        colour = styles[parameter]["colour"] if styles else "#2a78d6"
        ax.scatter(samples[:, column], y, s=12, alpha=0.55, color=colour, lw=0)
        ax.set_title(parameter, fontsize=10)
        ax.set_xlabel(
            "sampled value"
            + (" (log10)" if problem["scale"][column] == "log10" else ""),
            fontsize=8,
        )
        ax.set_ylabel(response, fontsize=8)
        ax.tick_params(labelsize=8)
        ax.grid(color="#e6e5e1", lw=0.6)
        ax.set_axisbelow(True)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
    fig.suptitle(f"{response} against its most influential parameters", fontsize=12)
    save_figure(fig, path)


def plot_field_maps(
    spatial: pd.DataFrame,
    field: str,
    parameters: list[str],
    data: dict,
    path: Path,
) -> None:
    """2 x 2 maps of per-cell mu* of the long-term mean of one field."""
    frame = spatial[spatial["field"] == field]
    scale = frame[frame["parameter"].isin(parameters)]["mu_star"].max() or 1.0
    grids = {
        p: frame[frame["parameter"] == p]
        .pivot(index="y", columns="x", values="mu_star")
        .sort_index(ascending=False)
        .to_numpy()
        / scale
        for p in parameters
    }
    plot_maps(
        grids,
        data["x"],
        data["y"],
        title=f"Morris mu* per grid cell: long-term mean {field}",
        colour_label="mu* / largest mu* in these maps",
        marker_xy=data["outlet_xy"],
        marker_label=outlet_text(data)[0],
        path=path,
    )


def plot_monthly_heatmap(
    monthly: pd.DataFrame, field: str, path: Path, *, series: str = "domain mean"
) -> None:
    """Parameter x month heatmap of mu* relative to the month's largest mu*."""
    month = monthly[monthly["field"] == field].copy()
    month["rel"] = month["mu_star"] / month.groupby("date")["mu_star"].transform(
        "max"
    ).replace(0, np.nan)
    pivot = month.pivot(index="parameter", columns="date", values="rel")
    pivot = pivot.loc[pivot.mean(axis=1).sort_values(ascending=False).index]
    plot_heatmap(
        pivot,
        title=f"Monthly Morris mu*: {field} ({series})",
        colour_label="mu* / largest mu* in the month",
        xtick_step=6,
        path=path,
    )


def plot_dominant_map(
    dominant: pd.DataFrame,
    field: str,
    x,
    y,
    path: Path,
    *,
    title: str,
    marker_xy=None,
    marker_label: str = default_outlet_label,
    styles: dict | None = None,
) -> None:
    """Categorical x/y map of the dominant parameter for one field.

    Each parameter has its colour (and hatch, so the categories stay distinct
    without colour); stars mark the outlet cells and are explained in the
    legend (``marker_label``).
    """
    from matplotlib.patches import Patch

    plt = pyplot()
    frame = dominant[dominant["field"] == field]
    names = sorted(frame["dominant_parameter"].unique())
    if styles is None:
        styles = parameter_styles(names)
    code = {n: i for i, n in enumerate(names)}
    grid = (
        frame.assign(code=frame["dominant_parameter"].map(code))
        .pivot(index="y", columns="x", values="code")
        .sort_index(ascending=False)
        .to_numpy(float)
    )
    extent = _map_extent(np.asarray(x), np.asarray(y))
    xs = np.sort(np.asarray(x))
    ys = np.sort(np.asarray(y))[::-1]
    dx = (extent[1] - extent[0]) / len(xs)
    dy = (extent[3] - extent[2]) / len(ys)
    fig, ax = plt.subplots(figsize=(10.5, 6.5), layout="constrained")
    for r in range(grid.shape[0]):
        for c in range(grid.shape[1]):
            if not np.isfinite(grid[r, c]):
                continue
            style = styles.get(names[int(grid[r, c])], {})
            ax.add_patch(
                plt.Rectangle(
                    (extent[0] + c * dx, extent[3] - (r + 1) * dy),
                    dx,
                    dy,
                    facecolor=style.get("colour", other_colour),
                    hatch=style.get("hatch", ""),
                    edgecolor="white",
                    linewidth=0.6,
                )
            )
    ax.set_xlim(extent[0], extent[1])
    ax.set_ylim(extent[2], extent[3])
    ax.set_aspect("equal")
    drawn = draw_outlets(ax, marker_xy)
    _format_map_axis(ax, left=True, bottom=True)
    ax.set_title(title, fontsize=12)
    counts = frame["dominant_parameter"].value_counts()
    handles = [
        Patch(
            facecolor=styles.get(n, {}).get("colour", other_colour),
            hatch=styles.get(n, {}).get("hatch", ""),
            edgecolor="white",
            label=f"{n} ({counts[n]} cells)",
        )
        for n in names
    ]
    ax.legend(
        handles=handles,
        title="dominant parameter",
        loc="upper left",
        bbox_to_anchor=(1.02, 1.0),
        fontsize=8.5,
        title_fontsize=9,
        frameon=False,
    )
    if drawn:
        fig.legend(
            handles=[outlet_legend_handle(marker_label)],
            loc="outside lower center",
            fontsize=9,
            frameon=False,
        )
    save_figure(fig, path)


def plot_all_response_heatmap(scalar: pd.DataFrame, path: Path) -> pd.DataFrame:
    """Parameter x response heatmap of mu*_rel; returns the table plotted."""
    pivot = scalar.pivot(index="parameter", columns="response", values="mu_star_rel")
    pivot = pivot[list(dict.fromkeys(scalar["response"]))]
    pivot = pivot.loc[pivot.mean(axis=1).sort_values(ascending=False).index]
    plot_heatmap(
        pivot,
        title="Morris relative mu* across all responses (primary first)",
        colour_label="mu* / largest mu* of the response",
        path=path,
    )
    return pivot


def plot_morris_overview(
    scalar: pd.DataFrame,
    styles: dict,
    figures_dir: Path,
    *,
    threshold: float,
) -> pd.DataFrame:
    """Overview figures for all scalar responses.

    01 ranking, primary responses (2 x 2)
    02 mu*-sigma, primary responses (2 x 2)
    03 ranking, secondary responses (2 columns)
    04 mu*-sigma, secondary responses (2 columns)
    05 mu*_rel heatmap, parameters x all responses
    """
    for number, group in ((1, "primary"), (3, "secondary")):
        part = scalar[scalar["group"] == group]
        responses = list(dict.fromkeys(part["response"]))
        if not responses:
            continue
        plot_ranking_panels(
            part,
            responses,
            styles,
            figures_dir / f"{number:02d}_morris_ranking_{group}.png",
            title=f"Morris ranking, {group} responses",
            threshold=threshold,
        )
        plot_mu_sigma_panels(
            part,
            responses,
            styles,
            figures_dir / f"{number + 1:02d}_morris_mu_star_sigma_{group}.png",
            title=f"Morris mu*-sigma, {group} responses",
        )
    return plot_all_response_heatmap(
        scalar, figures_dir / "05_morris_heatmap_all_responses.png"
    )


field_readme_template = """Morris screening: {field} ({group})

Responses of this field: {responses}

tables/
  morris_indices.csv             mu, mu*, CI, sigma, rank per scalar response
  spatial_sensitivity.csv        per-cell indices of the long-term mean
  monthly_sensitivity.csv        indices of the domain {series} per month
  dominant_parameter_by_cell.csv parameter with the largest mu* in each cell
figures/
  01_ranking.png                 mu* per scalar response (colours = parameters)
  02_mu_star_sigma.png           influence vs non-linearity/interaction
  03_spatial_top_parameters.png  per-cell mu* of the {n_top} highest-ranked parameters
  04_dominant_parameter_map.png  parameter with the largest mu* per cell
  05_monthly_sensitivity.png     relative mu* per month
  06_scatter_top_parameters.png  response against the top parameters

Stars on the maps mark the outlet cells: {outlet_label}
Parameters shown in the maps are the highest-ranked for this field; this is a
visual choice, not the Sobol selection (see ../../tables/morris_screening_decision.csv).
"""


def write_field_outputs(
    field: str,
    group: str,
    field_responses: list[str],
    series_rule: str,
    *,
    problem,
    samples,
    data,
    scalar,
    spatial,
    monthly,
    dominant,
    styles,
    root: Path,
    threshold: float,
    n_top: int = 4,
) -> None:
    """Tables and figures of one field in <root>/<group>/<field>/."""
    outlet_label, outlet_series = outlet_text(data)
    folder = Path(root) / group / field
    tables, figures = folder / "tables", folder / "figures"
    tables.mkdir(parents=True, exist_ok=True)
    figures.mkdir(parents=True, exist_ok=True)

    own = scalar[scalar["response"].isin(field_responses)]
    own.to_csv(tables / "morris_indices.csv", index=False)
    field_spatial = spatial[spatial["field"] == field]
    field_spatial.to_csv(tables / "spatial_sensitivity.csv", index=False)
    monthly[monthly["field"] == field].to_csv(
        tables / "monthly_sensitivity.csv", index=False
    )
    dominant[dominant["field"] == field].to_csv(
        tables / "dominant_parameter_by_cell.csv", index=False
    )

    if len(own):
        plot_ranking_panels(
            own,
            field_responses,
            styles,
            figures / "01_ranking.png",
            title=f"Morris ranking: {field}",
            threshold=threshold,
        )
        plot_mu_sigma_panels(
            own,
            field_responses,
            styles,
            figures / "02_mu_star_sigma.png",
            title=f"Morris mu*-sigma: {field}",
        )
    top = (
        field_spatial.groupby("parameter")["mu_star"]
        .mean()
        .sort_values(ascending=False)
        .head(n_top)
        .index.tolist()
    )
    plot_field_maps(
        spatial, field, top, data, figures / "03_spatial_top_parameters.png"
    )
    plot_dominant_map(
        dominant,
        field,
        data["x"],
        data["y"],
        figures / "04_dominant_parameter_map.png",
        title=f"Dominant parameter (largest mu*) per cell: long-term mean {field}",
        marker_xy=data["outlet_xy"],
        marker_label=outlet_label,
        styles=styles,
    )
    plot_monthly_heatmap(
        monthly,
        field,
        figures / "05_monthly_sensitivity.png",
        series=outlet_series if series_rule == "outlet" else "domain mean",
    )
    if len(own):
        first = field_responses[0]
        ranked = own[own["response"] == first].nsmallest(n_top, "rank")
        plot_scatter(
            problem,
            samples,
            data,
            first,
            ranked["parameter"].tolist(),
            figures / "06_scatter_top_parameters.png",
            styles,
        )
    (folder / "README.txt").write_text(
        field_readme_template.format(
            field=field,
            group=group,
            responses=", ".join(field_responses) or "none (maps and months only)",
            series=outlet_series if series_rule == "outlet" else "mean",
            n_top=n_top,
            outlet_label=outlet_label,
        ),
        encoding="utf-8",
    )


def write_morris_summary(
    path: Path, decision, provenance, data, noise, threshold: float
) -> None:
    """Short markdown summary of the screening result."""
    lines = [
        f"# Morris screening summary: {provenance['run_name']}",
        "",
        f"- Groups {provenance['groups']}; D = {len(provenance['parameters'])}, "
        f"r = {provenance['settings']['trajectories']}, "
        f"p = {provenance['settings']['levels']}, runs = {provenance['n_runs']}, "
        f"seed = {provenance['seed']}",
        f"- Log10-sampled: {provenance['log10_parameters'] or 'none'}",
        f"- Analysis period {data['dates'][0]} to {data['dates'][-1]}",
        f"- Influential: mu*/max mu* >= {threshold}"
        + (
            " and above the replicate noise floor"
            if noise is not None
            else " (no replicate run: noise floor NOT assessed)"
        ),
        "",
        "## Sobol candidates",
        "",
        "| parameter | primary | secondary | max mu*_rel (primary) | reason |",
        "|---|---|---|---|---|",
    ]
    for _, r in decision[decision["sobol_candidate"]].iterrows():
        lines.append(
            f"| {r['parameter']} | {r['n_primary_influential']} | "
            f"{r['n_secondary_influential']} | "
            f"{r['max_mu_star_rel_primary']:.2f} | {r['reason']} |"
        )
    screened = decision.loc[~decision["sobol_candidate"], "parameter"].tolist()
    lines += ["", f"Screened out: {', '.join(screened) or 'none'}", ""]
    if noise is not None:
        lines += ["## Replicate noise (identical parameters)", ""]
        for _, r in noise.iterrows():
            cv = (
                r["replicate_std"] / abs(r["replicate_mean"])
                if r["replicate_mean"]
                else np.nan
            )
            lines.append(f"- {r['response']}: CV = {cv:.3%}")
        lines.append("")
    lines += [
        "Morris separates influential from non-influential parameters; it",
        "does not measure variance shares. Treat the order inside the",
        "candidate set as approximate and confirm it with Sobol.",
    ]
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


# -----------------------------------------------------------------------------
# Additional diagnostics
# -----------------------------------------------------------------------------


def ranking_stability(
    problem,
    samples,
    data,
    *,
    num_levels: int,
    n_boot: int = 200,
    top_k: int = 5,
    seed: int = 2026,
) -> pd.DataFrame:
    """How stable is the mu* ranking? Resample whole trajectories.

    For each primary response, draw r trajectories with replacement (B times),
    recompute mu* and record each parameter's rank. Reports the median rank,
    its 5-95% range and P(top_k). A parameter whose rank interval spans the
    top_k boundary is not clearly in or out; more trajectories would decide.
    """
    from SALib.analyze import morris

    rng = np.random.default_rng(seed)
    d = problem["num_vars"]
    block = d + 1
    n_traj = len(samples) // block
    rows = []
    for s, (name, group) in enumerate(zip(data["scalar_names"], data["scalar_groups"])):
        if group != "primary":
            continue
        y = data["scalars"][:, s]
        ranks = np.empty((n_boot, d))
        for b in range(n_boot):
            pick = rng.integers(0, n_traj, n_traj)
            index = (pick[:, None] * block + np.arange(block)).ravel()
            result = morris.analyze(
                salib_problem(problem),
                samples[index],
                y[index],
                num_resamples=2,
                num_levels=num_levels,
                seed=seed,
            )
            ranks[b] = pd.Series(result["mu_star"]).rank(ascending=False).to_numpy()
        for p, parameter in enumerate(problem["names"]):
            rows.append(
                {
                    "response": name,
                    "parameter": parameter,
                    "median_rank": float(np.median(ranks[:, p])),
                    "rank_p05": float(np.percentile(ranks[:, p], 5)),
                    "rank_p95": float(np.percentile(ranks[:, p], 95)),
                    f"prob_top{top_k}": float(np.mean(ranks[:, p] <= top_k)),
                }
            )
    return pd.DataFrame(rows).sort_values(["response", "median_rank"])


def dominant_parameter_table(
    spatial: pd.DataFrame, value: str = "mu_star"
) -> pd.DataFrame:
    """Per field and cell: the parameter with the largest index and its share."""
    frame = spatial.copy()
    frame["share"] = frame[value] / frame.groupby(["field", "x", "y"])[value].transform(
        "sum"
    ).replace(0, np.nan)
    top = frame.loc[frame.groupby(["field", "x", "y"])[value].idxmax()]
    return (
        top[["field", "x", "y", "parameter", value, "share"]]
        .rename(columns={"parameter": "dominant_parameter"})
        .reset_index(drop=True)
    )
