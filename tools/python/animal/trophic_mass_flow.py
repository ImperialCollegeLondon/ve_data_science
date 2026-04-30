"""The trophic_mass_flow analyses the animal_trophic_interactions.csv."""

import math

# these are from typing module and exit only for documentation and IDE linting
# they do nothing at runtime and notF
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


class TrophicFlowAnalysis:
    """A class defining the trophic mass flow analysis function.

    The goal of this class is to take in the animal trophic interaction output
    from Virtual Ecosystem and calculate the trophic mass flow according to
    carbon, nitrogen or phosphorus. This results in (various) graphs as visualisation
    output.

    Currently, by default it is tracking "C"
    calculated from the sum of resource pool (resource kind) of all
    consumer_cohort in each timestep.

    Args:
        config(dict): Configuration dictionary.
        df (dataframe): Raw input data which is loaded separately in your notebook
                        before calling this class.
        processed_df (dataframe): Processed data.
        grouped_df(dataframe): Grouped data according to resource_kind.
        pivoted_df(dataframe): Pivoted data for plotting.

    """

    def __init__(self, df: pd.dataframe, config: dict | None = None):
        """Initialise the analysis with dataframe and config."""
        self.df = df
        # returns a dict of standard settings
        self.config = self._default_config()
        # if config is provided, then update config
        if config:
            self.config.update(config)
        # create empty placeholders
        self.processed_df = None
        self.grouped_df = None
        self.pivoted_df = None

        print("trophic flow initialised")
        # print(f" Mass flow: {self.config['element']}")
        # print(f"  Data shape: {self.df.shape}")

        # self.process_data()

    def _default_config(self) -> dict:
        """Use default values for config.

        Create a dictionary (or list in R) for the default config values.
        note: using an underscore prefix above is a naming convention signaling
        internal use only and to keep public API clean.
        """
        return {
            "convert_to_grams": False,
            "time_column": "time",
            "column_values": ["C", "N", "P"],
            "group_by": ["time_index", "resource_kind"],
            "value_to_sum": "C",
            "fig_width": 20,
            "fig_height_per_row": 2,
            "n_cols": 2,
            "dpi": 300,
        }

    def load_data(self) -> None:
        """Load the animal trophic interaction output.

        Load data from the output CSV file from Virtual Ecosystem
        into a dataframe.

        Returns:
            A dataframe.

        """

        print("loading data...")
        self.df = pd.read_csv(self.file_path, parse_dates=["time"])
        print(f" Loaded {len(self.df)} rows, {len(self.df.columns)} columns")

    def convert_units(
        self, columns: list[str] | None = None, multiplier: float = 1000
    ) -> None:
        """Convert measurement units (default: from kg to g).

        Args:
            columns: columns to multiply.
            multiplier: multiplier factor.

        Returns:
            Updates the dataframe with units converted.

        """
        cols = columns or self.config["column_values"]
        if self.config["convert_to_grams"]:
            print(f"Converting {cols} by {multiplier} to grams")
            self.df[cols] = self.df[cols] * multiplier

    # TODO: when needed, add convert time to datetime for plotting against time
    # could consider using only month and year as time
    # convert "time" column to datetime objects
    # df['time'] = pd.to_datetime(df['time'])

    # ==========================================
    # Process data
    # ===========================================
    def group_and_aggregate(
        self, group_by: list[str] | None = None, agg_column: str | None = None
    ) -> None:
        """Group data and sum (aggregate) variables of interest.

        Args:
            group_by: Columns to group by.
            agg_column: Column to aggregate.

        Returns:
            Does not return but updates the dataframe.

        """

        groups = group_by or self.config["group_by"]
        agg_col = agg_column or self.config["value_to_sum"]

        print(f"Grouping by {groups} and summing {agg_col}...")

        self.group_df = (
            # group rows by time index and resource
            self.df.groupby(groups)
            # selects column C, sums up values in each group
            # TODO: add args/param to be more flexible? so user
            #   can specify sum,average...?
            .agg({agg_col: "sum"})
            # turns groups back into columns
            .reset_index()
        )
        print(f" Successfully grouped {len(self.group_df)} rows")

    def pivot_data(
        self,
        index_col: str | None = None,
        columns_col: str | None = None,
        values_col: str | None = None,
    ) -> None:
        """Pivoting dataframe from wide to long.

        Args:
            index_col: Column for index (rows).
            columns_col: Column for new columns.
            values_col: Column for new values.

        Returns:
             Does not return anything but populates self.pivoted_df

        """
        index = index_col or self.config["group_by"][0]
        columns = columns_col or self.config["group_by"][1]
        values = values_col or self.config["value_to_sum"]

        print(f"Pivoting by {index}, {columns}, {values}...")

        self.pivoted_df = self.group_df.pivot(
            index=index, columns=columns, values=values
        )
        print(f"{self.pivoted_df.shape[0]} rows x {self.pivoted_df.shape[1]} columns")

    def process_data(self) -> None:
        """Run all the processing steps in correct order.

        Returns:
            Does not return anything, only run processing

        """
        print("\nProcessing data...")
        self.convert_units()
        self.group_and_aggregate()
        self.pivot_data()
        print("Processing complete!")

    # =========================================================
    #  Plot data
    # =========================================================
    def _setup_figure(
        self, n_rows: int, n_cols: int, figsize: tuple | None = None
    ) -> tuple:
        """Create figure and axes.

        Returns:
            Setup for figure and axes.

        """
        if figsize is None:
            width = self.config["fig_width"]
            height = self.config["fig_height_per_row"] * n_rows
            figsize = (width, height)

        # Create a fig with grids (axes) of individual subplots:
        # N rows, 2 columns.
        fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize, sharex=True)
        # This returns a fig object and an axes object,
        # which is defined in the next step
        return fig, axes

    def _ensure_2d_axes(
        self, axes: np.ndarray, n_resources: int, n_rows: int, n_cols: int
    ) -> np.ndarray:
        """Ensure axes object has a 2D array for easy indexing.

        The following step uses np.array instead of subplots is optional
        but recommended.
        This is because array method can align dates better, completely remove
        empty slots and add indexing from 0 (and not 1, in subplots).

        Returns:
            Axes in 2D array.

        """

        if n_resources == 1:
            axes = np.array([[axes]])
            # if n_rows is 1, then reshape array to have 1 row and as many columns
        elif n_rows == 1:
            axes = axes.reshape(1, -1)
            # If n_cols is 1, reshape array to have N rows and 1 column
        elif n_cols == 1:
            axes = axes.reshape(-1, 1)
        return axes

    def _format_y_axis(self, ax: plt.Axes) -> None:
        """Format y-axis with comma separators."""
        ax.get_yaxis().set_major_formatter(
            plt.FuncFormatter(lambda x, p: format(int(x), ","))
        )

    def _style_subplot(self, ax: plt.Axes, title: str, ylabel: str = "C") -> None:
        """Apply styling to subplot."""

        # Set Title and Labels
        ax.set_title(f"{title}", fontsize=15, loc="left", fontweight="bold")
        ax.set_ylabel(ylabel, fontsize=15)
        ax.grid(True, linestyle="--", alpha=0.4)
        self._format_y_axis(ax)

    def _get_metric_name(self, column_code: str) -> str:
        """Convert column code (C, N, P) to readable metric name.

        Creates a dictionary metric_map for the variables
        that matches values to sum (key).
        Uses get() to return the mapped string value according to the key provided.

        Returns:
            The variable name of interest.

        """
        metric_map = {
            "C": "Carbon",
            "N": "Nitrogen",
            "P": "Phosphorus",
            "C_g": "Carbon (g)",
            "N_g": "Nitrogen (g)",
            "P_g": "Phosphorus (g)",
        }
        return metric_map.get(column_code, column_code)

    # =========================================================
    #  Plotting methods
    #     TODO: create an option to plot single graph with all resources (logged)
    # =========================================================

    def plot_faceted(
        self,
        n_cols: int | None = None,
        save_path: str | None = None,
        title: str | None = None,
        show: bool = False,
    ) -> "TrophicFlowAnalysis":
        """Create faceted plot with multiple subplots using a grid layout.

        Args:
            n_cols: Number of column (uses config if None).
            save_path: path to save figure (Optional).
            title: title of figure (Optional).
            show: whether to show or not to display plot.

        Returns:
            Save a faceted plot into destination.

        """
        print("Creating faceted plot...")

        # list of resource kinds (from columns of pivoted_df)
        resources = self.pivoted_df.columns.tolist()
        n_resources = len(resources)

        # Calculate grid dimensions for subplots
        # Define number of columns
        cols = n_cols or self.config["n_cols"]
        # Calculate the number of required rows using math.ceil() to round up
        # For example, 9 resources/2 = 4.5, hence 5 rows
        rows = math.ceil(n_resources / cols)

        # create fig with grids from _setup_figure
        fig, axes = self._setup_figure(rows, cols)
        # create an axes object with _ensure_2d_axes
        axes = self._ensure_2d_axes(axes, n_resources, rows, cols)

        # Loop through each resource and plot on its specific axis
        for i, resource in enumerate(resources):
            # Calculate row and column index for this resource using floor division
            # to round down
            row = i // cols
            # the remainder of the division of i/cols(e.g., 0%2 = 0, 1%2 = 1)
            col = i % cols

            # make an array
            ax = axes[row, col]

            # Plot the line
            ax.plot(
                self.pivoted_df.index,
                self.pivoted_df[resource],
                color="#2E86AB",
                linewidth=2,
            )

            # set style from _style_subplot
            self._style_subplot(ax, resource)

        # Set Title and Labels
        ax.set_title(f"{resource}", fontsize=15, loc="left", fontweight="bold")
        ax.set_ylabel("C", fontsize=15)
        ax.grid(True, linestyle="--", alpha=0.4)

        # hide any empty subplots (if we have odd number of resources)
        for j in range(n_resources, rows * cols):
            # find the right grid axes - same as above
            row = j // cols
            col = j % cols
            # fig.delaxes() remove axes object from those subplots
            fig.delaxes(axes[row, col])

        # Main Title
        if title is None:
            # Get the metric being plotted (C, N, or P)
            metric_code = self.config["value_to_sum"]
            metric_name = self._get_metric_name(metric_code)
            title = f"Mass Flow ({metric_name}) by Resource Pool"

        fig.suptitle(title, fontsize=20, fontweight="bold", y=1.02)

        if save_path:
            plt.savefig(save_path, dpi=self.config["dpi"], bbox_inches="tight")
            print(f"saved to: {save_path}")

    # =================================================================
    # Add helper functions
    # =================================================================
    def summary(self) -> None:
        """Print summary of loaded data."""
        print("\n" + "=" * 50)
        print("Data Summary")
        print("=" * 50)
        print(f"rows: {len(self.df)}")
        print(f"columns: {len(self.df.columns.tolist())}")
        print(
            f"\nTime Range: {self.df['time_index'].min()} to "
            f"{self.df['time_index'].max()}"
        )
        print(f"\nResource Types: {self.df['resource_kind'].unique().tolist()}")
        print("=" * 50 + "\n")

    def get_resource(self) -> list[str]:
        """Get list of resource types.

        TODO: check if this is necessary, if we printed resources above.
        """
        return self.pivoted_df.columns.tolist() if self.pivoted_df is not None else []
