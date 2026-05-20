"""
analysis_tools.py

Reusable analysis functions for VE outputs.

Contains:
- statistics
- temporal analysis
- spatial analysis
- layer analysis
- summaries
"""

# =====================================================
# IMPORT PACKAGES
# =====================================================

import numpy as np
import pandas as pd


# =====================================================
# BASIC STATISTICS
# =====================================================

def calculate_mean(data):

    """
    Calculate mean value.
    """

    return np.nanmean(data)


def calculate_min(data):

    """
    Calculate minimum value.
    """

    return np.nanmin(data)


def calculate_max(data):

    """
    Calculate maximum value.
    """

    return np.nanmax(data)


def calculate_std(data):

    """
    Calculate standard deviation.
    """

    return np.nanstd(data)


# =====================================================
# TEMPORAL ANALYSIS
# =====================================================

def calculate_temporal_mean(ds, variable):

    """
    Mean across all timesteps.
    """

    return ds[variable].mean(dim="time_index")


def calculate_temporal_sum(ds, variable):

    """
    Sum across all timesteps.
    """

    return ds[variable].sum(dim="time_index")


def calculate_monthly_mean(ds, variable):

    """
    Monthly mean for time series.
    """

    return ds[variable].groupby(
        "time_index.month"
    ).mean()


def calculate_annual_mean(ds, variable):

    """
    Annual mean for time series.
    """

    return ds[variable].groupby(
        "time_index.year"
    ).mean()


# =====================================================
# SPATIAL ANALYSIS
# =====================================================

def calculate_spatial_mean(ds, variable):

    """
    Spatial mean across all cells.
    """

    return ds[variable].mean(dim="cell_id")


def calculate_spatial_sum(ds, variable):

    """
    Spatial sum across all cells.
    """

    return ds[variable].sum(dim="cell_id")


def calculate_spatial_max(ds, variable):

    """
    Spatial maximum.
    """

    return ds[variable].max(dim="cell_id")


def calculate_spatial_min(ds, variable):

    """
    Spatial minimum.
    """

    return ds[variable].min(dim="cell_id")


# =====================================================
# LAYER ANALYSIS
# =====================================================

def calculate_layer_mean(ds, variable):

    """
    Mean across all layers.
    """

    return ds[variable].mean(dim="layers")


def calculate_layer_sum(ds, variable):

    """
    Sum across all layers.
    """

    return ds[variable].sum(dim="layers")


def extract_single_layer(
    ds,
    variable,
    layer=0
):

    """
    Extract one layer.
    """

    return ds[variable].isel(layers=layer)


# =====================================================
# GROUNDWATER ANALYSIS
# =====================================================

def extract_groundwater_layer(
    ds,
    variable,
    groundwater_layer=0
):

    """
    Extract groundwater layer.
    """

    return ds[variable].isel(
        groundwater_layers=groundwater_layer
    )


def calculate_groundwater_mean(
    ds,
    variable
):

    """
    Mean groundwater storage.
    """

    return ds[variable].mean(
        dim="groundwater_layers"
    )


# =====================================================
# ELEMENT ANALYSIS
# =====================================================

def extract_element(
    ds,
    variable,
    element_index=0
):

    """
    Extract element component.

    Example:
    0 = Carbon
    1 = Nitrogen
    2 = Phosphorus
    """

    return ds[variable].isel(
        element=element_index
    )


# =====================================================
# PFT ANALYSIS
# =====================================================

def extract_pft(
    ds,
    variable,
    pft_index=0
):

    """
    Extract plant functional type.
    """

    return ds[variable].isel(
        pft=pft_index
    )


# =====================================================
# TIME SERIES EXTRACTION
# =====================================================

def extract_timeseries(
    ds,
    variable,
    cell_id=0
):

    """
    Extract time series for one cell.
    """

    return ds[variable].sel(
        cell_id=cell_id
    )


# =====================================================
# SUMMARY TABLE
# =====================================================

def create_summary_table(ds, variable):

    """
    Generate summary statistics table.
    """

    data = ds[variable].values.flatten()

    summary = pd.DataFrame({

        "Statistic": [
            "Mean",
            "Min",
            "Max",
            "Std"
        ],

        "Value": [

            np.nanmean(data),

            np.nanmin(data),

            np.nanmax(data),

            np.nanstd(data)
        ]
    })

    return summary


# =====================================================
# PRINT VARIABLE SUMMARY
# =====================================================

def print_variable_summary(ds, variable):

    """
    Print quick summary.
    """

    data = ds[variable].values

    print("\n")
    print("=" * 50)

    print(f"Variable : {variable}")

    print("=" * 50)

    print(f"Shape     : {data.shape}")

    print(f"Mean      : {np.nanmean(data):.4f}")

    print(f"Min       : {np.nanmin(data):.4f}")

    print(f"Max       : {np.nanmax(data):.4f}")

    print(f"Std       : {np.nanstd(data):.4f}")


# =====================================================
# CHECK MISSING VALUES
# =====================================================

def count_nan_values(ds, variable):

    """
    Count NaN values.
    """

    data = ds[variable].values

    return np.isnan(data).sum()


# =====================================================
# NORMALISE DATA
# =====================================================

def normalise_data(data):

    """
    Min-max normalisation.
    """

    return (
        (data - np.nanmin(data))
        /
        (np.nanmax(data) - np.nanmin(data))
    )


# =====================================================
# ANOMALY CALCULATION
# =====================================================

def calculate_anomaly(data):

    """
    Calculate anomaly from mean.
    """

    mean_val = np.nanmean(data)

    return data - mean_val