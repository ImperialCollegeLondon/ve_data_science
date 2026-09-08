#| ---
#| title: Sanity check for inorganic nitrogen pool values
#|
#| description: |
#|     This R script performs a diagnostic check on the inorganic nitrogen
#|     pools (nitrate and ammonium) in the Maliau soil initialization data.
#|     It extracts both pools from the netCDF file, generates histogram
#|     visualizations to inspect value distributions, and prints summary
#|     statistics. This is part of troubleshooting high inorganic nitrogen
#|     values during model initialization.
#|
#| virtual_ecosystem_module: Soil
#|
#| author: [Author name to be updated]
#|
#| status: wip
#|
#| input_files:
#|   - name: soil_maliau.nc
#|     path: data/scenarios/maliau/maliau_1/data/
#|     description: |
#|         NetCDF file containing soil pool variables for the Maliau scenario,
#|         including the inorganic nitrogen pools to be checked.
#|
#| output_files:
#|   - name: histograms.png
#|     path: analysis/troubleshoot/inorganic_n_too_high/
#|     description: |
#|         PNG diagnostic plots showing the distribution of soil nitrate and
#|         ammonium values across the spatial domain.
#|
#| source_files:
#|   - name: get_ve_variables
#|     path: tools/R/R/
#|     description: |
#|         Provides get_data_variables_nc() helper to extract variables
#|         from netCDF files with flexible selection.
#|
#| package_dependencies:
#|   - tidync
#|
#| usage_notes: |
#|     Run this script from the repository root to ensure file paths resolve
#|     correctly. Examine the histograms and summary statistics to identify
#|     if nitrogen values are within expected ranges. If values appear
#|     anomalous (very high, very low, or with unexpected patterns), check
#|     the data sources and transformations in the Maliau initialization
#|     workflow.
#| ---

box::use(tools/R/R/get_ve_variables[...])

# Define path to the Maliau soil data file
input_data <- "data/scenarios/maliau/maliau_1/data/soil_maliau.nc"

# Extract the inorganic nitrogen pools from the netCDF file
inorg_n <-
  tidync::tidync(input_data) |>
  get_data_variables_nc(c("soil_n_pool_nitrate", "soil_n_pool_ammonium"))

# Generate histograms to visualize the spatial distribution of both pools
png(
  "analysis/troubleshoot/inorganic_n_too_high/histograms.png",
  width = 6,
  height = 3,
  units = "in",
  res = 120
)
par(mfrow = c(1, 2), mar = c(4, 4, 0.2, 0.2))
hist(inorg_n$soil_n_pool_nitrate, breaks = 100, main = "")
hist(inorg_n$soil_n_pool_ammonium, breaks = 100, main = "")
dev.off()

# Summary statistics for each pool to identify outliers and ranges
summary(as.numeric(inorg_n$soil_n_pool_nitrate))
summary(as.numeric(inorg_n$soil_n_pool_ammonium))
