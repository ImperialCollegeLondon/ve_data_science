"""
plot_tools.py

Reusable plotting tools for VE outputs.
"""

# =====================================================
# IMPORT PACKAGES
# =====================================================

import numpy as np
import matplotlib.pyplot as plt

from mpl_toolkits.mplot3d import Axes3D

from data_tools import reshape_to_xy


# =====================================================
# SCALAR SPATIAL MAP
# =====================================================

def plot_scalar_map(
    ds,
    variable,
    timestep=0,
    unit="",
    cmap="viridis",
    figsize=(7, 6)
):

    """
    Plot scalar variable spatial map.

    Dimensions:
    (time_index, cell_id)
    """

    data = ds[variable].isel(
        time_index=timestep
    )

    reshaped, x_vals, y_vals = reshape_to_xy(data)

    plt.figure(figsize=figsize)

    im = plt.imshow(
        reshaped,
        origin="lower",
        cmap=cmap,
        extent=[
            x_vals.min(),
            x_vals.max(),
            y_vals.min(),
            y_vals.max()
        ]
    )

    cbar = plt.colorbar(im)

    cbar.set_label(
        f"{variable} ({unit})"
    )

    plt.title(
        f"{variable}\n"
        f"Timestep = {timestep}"
    )

    plt.xlabel("Easting (m)")

    plt.ylabel("Northing (m)")

    plt.tight_layout()

    plt.show()


# =====================================================
# SCALAR TIMESERIES
# =====================================================

def plot_scalar_timeseries(
    ds,
    variable,
    unit=""
):

    """
    Plot all grid-cell timeseries.
    """

    data = ds[variable]

    plt.figure(figsize=(10, 5))

    for cell in data.cell_id.values:

        plt.plot(
            data.time_index,
            data.sel(cell_id=cell),
            alpha=0.7
        )

    mean_data = data.mean(dim="cell_id")

    plt.plot(
        data.time_index,
        mean_data,
        linewidth=3,
        color="black",
        label="Mean"
    )

    plt.xlabel("Time step")

    plt.ylabel(f"{variable} ({unit})")

    plt.grid(True)

    plt.tight_layout()

    plt.show()


# =====================================================
# LAYERED SPATIAL MAP
# =====================================================

def plot_layered_map(
    ds,
    variable,
    layer=0,
    timestep=0,
    unit="",
    cmap="turbo",
    figsize=(7, 6)
):

    """
    Plot layered variable spatial map.

    Dimensions:
    (time_index, layers, cell_id)
    """

    data = ds[variable].isel(
        layers=layer,
        time_index=timestep
    )

    reshaped, x_vals, y_vals = reshape_to_xy(data)

    plt.figure(figsize=figsize)

    im = plt.imshow(
        reshaped,
        origin="lower",
        cmap=cmap,
        extent=[
            x_vals.min(),
            x_vals.max(),
            y_vals.min(),
            y_vals.max()
        ]
    )

    cbar = plt.colorbar(im)

    cbar.set_label(
        f"{variable} ({unit})"
    )

    plt.title(
        f"{variable}\n"
        f"Layer = {layer}"
    )

    plt.xlabel("x (UTM50N)")

    plt.ylabel("y (UTM50N)")

    plt.tight_layout()

    plt.show()


# =====================================================
# LAYERED TIMESERIES
# =====================================================

def plot_layered_timeseries(
    ds,
    variable,
    layer=0,
    unit=""
):

    """
    Plot layered variable timeseries.
    """

    data = ds[variable].isel(
        layers=layer
    )

    plt.figure(figsize=(10, 5))

    for cell in data.cell_id.values:

        plt.plot(
            data.time_index,
            data.sel(cell_id=cell),
            alpha=0.7
        )

    mean_data = data.mean(dim="cell_id")

    plt.plot(
        data.time_index,
        mean_data,
        linewidth=3,
        color="black",
        label="Mean"
    )

    plt.title(
        f"{variable}\n"
        f"Layer = {layer}"
    )

    plt.xlabel("Time step")

    plt.ylabel(f"{variable} ({unit})")

    plt.grid(True)

    plt.tight_layout()

    plt.show()


# =====================================================
# 3D LAYERED SCATTER
# =====================================================

def plot_3d_layered_variable(
    ds,
    variable,
    timestep=0,
    unit="",
    cmap="turbo"
):

    """
    Plot layered variable in 3D.

    Dimensions:
    (time_index, layers, cell_id)
    """

    fig = plt.figure(figsize=(10, 8))

    ax = fig.add_subplot(
        111,
        projection="3d"
    )

    data = ds[variable].isel(
        time_index=timestep
    )

    x = data.x.values

    y = data.y.values

    layers = data.layers.values

    for layer in layers:

        layer_data = data.sel(
            layers=layer
        )

        sc = ax.scatter(
            x,
            y,
            np.full_like(x, layer),
            c=layer_data.values,
            cmap=cmap,
            s=40
        )

    cbar = plt.colorbar(sc)

    cbar.set_label(
        f"{variable} ({unit})"
    )

    ax.set_xlabel("x (UTM50N)")

    ax.set_ylabel("y (UTM50N)")

    ax.set_zlabel("Layer")

    ax.set_title(variable)

    plt.tight_layout()

    plt.show()


# =====================================================
# VERTICAL PROFILE
# =====================================================

def plot_vertical_profile(
    ds,
    variable,
    timestep=0,
    unit=""
):

    """
    Plot mean vertical profile.
    """

    data = ds[variable].isel(
        time_index=timestep
    )

    profile = data.mean(
        dim="cell_id"
    )

    plt.figure(figsize=(5, 6))

    plt.plot(
        profile,
        data.layers,
        marker="o"
    )

    plt.gca().invert_yaxis()

    plt.xlabel(
        f"{variable} ({unit})"
    )

    plt.ylabel("Layer")

    plt.title(
        f"Vertical Profile\n"
        f"{variable}"
    )

    plt.grid(True)

    plt.tight_layout()

    plt.show()


# =====================================================
# GROUNDWATER MAP
# =====================================================

def plot_groundwater_map(
    ds,
    variable,
    groundwater_layer=0,
    timestep=0,
    unit="",
    cmap="Blues",
    figsize=(7, 6)
):

    """
    Plot groundwater variable spatial map.

    Dimensions:
    (time_index, groundwater_layers, cell_id)
    """

    data = ds[variable].isel(
        groundwater_layers=groundwater_layer,
        time_index=timestep
    )

    reshaped, x_vals, y_vals = reshape_to_xy(data)

    plt.figure(figsize=figsize)

    im = plt.imshow(
        reshaped,
        origin="lower",
        cmap=cmap,
        extent=[
            x_vals.min(),
            x_vals.max(),
            y_vals.min(),
            y_vals.max()
        ]
    )

    cbar = plt.colorbar(im)

    cbar.set_label(
        f"{variable} ({unit})"
    )

    plt.title(
        f"{variable}\n"
        f"Groundwater Layer = {groundwater_layer}"
    )

    plt.xlabel("Easting (m)")

    plt.ylabel("Northing (m)")

    plt.tight_layout()

    plt.show()