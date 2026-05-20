"""data_tools.py"""

import numpy as np
import xarray as xr

# =====================================================
# LOAD DATASET
# =====================================================


def load_dataset(nc_file):

    ds = xr.open_dataset(nc_file)

    return ds


# =====================================================
# SHOW SUMMARY
# =====================================================


def show_dataset_summary(ds):

    print(ds)


# =====================================================
# LIST VARIABLES
# =====================================================


def list_variables(ds):

    for var in ds.data_vars:
        print(f"\n{var}")

        print(f"Dimensions : {ds[var].dims}")

        print(f"Shape      : {ds[var].shape}")


# =====================================================
# CLASSIFY VARIABLE
# =====================================================


def classify_variable(variable):

    dims = variable.dims

    if dims == ("time_index",):
        return "time"

    elif dims == ("time_index", "cell_id"):
        return "scalar"

    elif "layers" in dims:
        return "layered"

    elif "groundwater_layers" in dims:
        return "groundwater"

    elif "element" in dims and "pft" not in dims:
        return "element"

    elif "pft" in dims:
        return "pft"

    else:
        return "other"


# =====================================================
# CATEGORISE ALL VARIABLES
# =====================================================


def categorise_all_variables(ds):

    categories = {}

    for var in ds.data_vars:
        category = classify_variable(ds[var])

        if category not in categories:
            categories[category] = []

        categories[category].append(var)

    return categories


# =====================================================
# RESHAPE TO X-Y
# =====================================================


def reshape_to_xy(data_array):

    x_vals = np.unique(data_array.x.values)

    y_vals = np.unique(data_array.y.values)

    nx = len(x_vals)

    ny = len(y_vals)

    reshaped = data_array.values.reshape(ny, nx)

    return reshaped, x_vals, y_vals
