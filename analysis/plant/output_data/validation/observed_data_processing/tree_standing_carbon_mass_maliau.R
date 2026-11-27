#| ---
#| title: tree_standing_carbon_mass_maliau
#|
#| description: |
#|   This script prepares the observed validation data for tree standing carbon
#|   mass for Maliau. It calculates plot-level stem and leaf carbon mass for
#|   the available census years using allometric equations applied to tree census
#|   DBH data from OG plots within the maliau_2 grid.
#|
#| virtual_ecosystem_module:
#|   - Plant
#|
#| author:
#|   - Arne Scheire
#|
#| status: final
#|
#| input_files:
#|   - name: tree_census_11_20.xlsx
#|     path: data/primary/plant/tree_census
#|     description: |
#|       https://doi.org/10.5281/zenodo.14882506
#|       Tree census data from the SAFE Project 2011–2020.
#|       Data includes measurements of DBH and estimates of tree height for
#|       all stems, fruiting and flowering estimates, estimates of epiphyte
#|       and liana cover, and taxonomic IDs.
#|
#|   - name: maliau_grid_definition.toml
#|     path: data/derived/site/maliau
#|     description: Maliau-2 grid extent and dimensions.
#|   - name: gazetteer.geojson
#|     path: data/primary/site
#|     description: Plot centroid coordinates used to identify plots in the grid.
#|   - name: inagawa_nutrients_wood_density.xlsx
#|     path: data/primary/plant/traits_data
#|     description: Wood carbon content data used to derive the mean wood carbon fraction.
#|   - name: both_tree_functional_traits.xlsx
#|     path: data/primary/plant/traits_data
#|     description: Leaf carbon content data used to derive the mean leaf carbon fraction.
#|
#| output_files:
#|   - name: tree_standing_carbon_mass_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: |
#|       Plot-level stem and leaf carbon mass estimates for the 2011-recorded
#|       tree cohort in the selected Maliau-2 OG plots. Includes estimates and
#|       allometric standard errors for the 2011, 2014, 2015, 2017, and 2019
#|       census rounds, plot-specific mean census dates, elapsed intervals,
#|       and annualised net stem carbon changes between consecutive rounds.
#|     variables:
#|       - name: PlotID
#|         type: character
#|         units: dimensionless
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: SAFE identifier for the observed census plot.
#|       - name: plot_area_m2
#|         type: numeric
#|         units: m2
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot area in square metres (25 m by 25 m).
#|       - name: plot_area_ha
#|         type: numeric
#|         units: ha
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot area in hectares (0.0625 ha).
#|       - name: plot_x
#|         type: numeric
#|         units: degrees longitude
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot centroid longitude in WGS84, from the SAFE gazetteer.
#|       - name: plot_y
#|         type: numeric
#|         units: degrees latitude
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot centroid latitude in WGS84, from the SAFE gazetteer.
#|       - name: obs_stem_mass_2011_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2011-labelled census round.
#|         description: |
#|           Stem carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2011 DBH using Kenzo et al. (2009) allometry and a
#|           wood carbon fraction of 45.6%.
#|       - name: obs_stem_mass_2011_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2011-labelled census round.
#|         description: |
#|           Propagated standard error for stem carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_stem_mass_2014_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2014-labelled census round.
#|         description: |
#|           Stem carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2014 DBH using Kenzo et al. (2009) allometry and a
#|           wood carbon fraction of 45.6%.
#|       - name: obs_stem_mass_2014_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2014-labelled census round.
#|         description: |
#|           Propagated standard error for stem carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_stem_mass_2015_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2015-labelled census round.
#|         description: |
#|           Stem carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2015 DBH using Kenzo et al. (2009) allometry and a
#|           wood carbon fraction of 45.6%.
#|       - name: obs_stem_mass_2015_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2015-labelled census round.
#|         description: |
#|           Propagated standard error for stem carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_stem_mass_2017_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2017-labelled census round.
#|         description: |
#|           Stem carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2017 DBH using Kenzo et al. (2009) allometry and a
#|           wood carbon fraction of 45.6%.
#|       - name: obs_stem_mass_2017_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2017-labelled census round.
#|         description: |
#|           Propagated standard error for stem carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_stem_mass_2019_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2019-labelled census round.
#|         description: |
#|           Stem carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2019 DBH using Kenzo et al. (2009) allometry and a
#|           wood carbon fraction of 45.6%.
#|       - name: obs_stem_mass_2019_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2019-labelled census round.
#|         description: |
#|           Propagated standard error for stem carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_leaf_mass_2011_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2011-labelled census round.
#|         description: |
#|           Leaf carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2011 DBH using Kenzo et al. (2009) allometry and a
#|           leaf carbon fraction of 44.30682%.
#|       - name: obs_leaf_mass_2011_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2011-labelled census round.
#|         description: |
#|           Propagated standard error for leaf carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_leaf_mass_2014_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2014-labelled census round.
#|         description: |
#|           Leaf carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2014 DBH using Kenzo et al. (2009) allometry and a
#|           leaf carbon fraction of 44.30682%.
#|       - name: obs_leaf_mass_2014_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2014-labelled census round.
#|         description: |
#|           Propagated standard error for leaf carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_leaf_mass_2015_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2015-labelled census round.
#|         description: |
#|           Leaf carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2015 DBH using Kenzo et al. (2009) allometry and a
#|           leaf carbon fraction of 44.30682%.
#|       - name: obs_leaf_mass_2015_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2015-labelled census round.
#|         description: |
#|           Propagated standard error for leaf carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_leaf_mass_2017_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2017-labelled census round.
#|         description: |
#|           Leaf carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2017 DBH using Kenzo et al. (2009) allometry and a
#|           leaf carbon fraction of 44.30682%.
#|       - name: obs_leaf_mass_2017_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2017-labelled census round.
#|         description: |
#|           Propagated standard error for leaf carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: obs_leaf_mass_2019_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2019-labelled census round.
#|         description: |
#|           Leaf carbon mass per hectare for the 2011-recorded tree cohort,
#|           estimated from 2019 DBH using Kenzo et al. (2009) allometry and a
#|           leaf carbon fraction of 44.30682%.
#|       - name: obs_leaf_mass_2019_se_kg_ha
#|         type: numeric
#|         units: kg C ha-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2019-labelled census round.
#|         description: |
#|           Propagated standard error for leaf carbon mass due to uncertainty
#|           in the allometric coefficient and exponent; shared parameter
#|           uncertainty is applied to the plot total.
#|       - name: census_date_2011
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2011-labelled census round.
#|         description: Mean observed census date for the round labelled 2011.
#|       - name: census_date_2014
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2014-labelled census round.
#|         description: Mean observed census date for the round labelled 2014.
#|       - name: census_date_2015
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2015-labelled census round.
#|         description: Mean observed census date for the round labelled 2015.
#|       - name: census_date_2017
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2017-labelled census round.
#|         description: Mean observed census date for the round labelled 2017.
#|       - name: census_date_2019
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: 2019-labelled census round.
#|         description: Mean observed census date for the round labelled 2019.
#|       - name: census_2011_2014_interval_years
#|         type: numeric
#|         units: years
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2011- and 2014-labelled rounds.
#|         description: |
#|           Elapsed time between the plot's mean 2011 and 2014 census dates,
#|           calculated as the date difference divided by 365.25.
#|       - name: census_2014_2015_interval_years
#|         type: numeric
#|         units: years
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2014- and 2015-labelled rounds.
#|         description: |
#|           Elapsed time between the plot's mean 2014 and 2015 census dates,
#|           calculated as the date difference divided by 365.25.
#|       - name: census_2015_2017_interval_years
#|         type: numeric
#|         units: years
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2015- and 2017-labelled rounds.
#|         description: |
#|           Elapsed time between the plot's mean 2015 and 2017 census dates,
#|           calculated as the date difference divided by 365.25.
#|       - name: census_2017_2019_interval_years
#|         type: numeric
#|         units: years
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2017- and 2019-labelled rounds.
#|         description: |
#|           Elapsed time between the plot's mean 2017 and 2019 census dates,
#|           calculated as the date difference divided by 365.25.
#|       - name: obs_stem_increment_2011_2014_kg_ha_yr
#|         type: numeric
#|         units: kg C ha-1 y-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2011- and 2014-labelled rounds.
#|         description: |
#|           Annualised net change in standing stem carbon per hectare for the
#|           2011-recorded tree cohort, from the 2011 to 2014 census rounds.
#|           This is net standing-carbon change, not gross woody productivity.
#|       - name: obs_stem_increment_2014_2015_kg_ha_yr
#|         type: numeric
#|         units: kg C ha-1 y-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2014- and 2015-labelled rounds.
#|         description: |
#|           Annualised net change in standing stem carbon per hectare for the
#|           2011-recorded tree cohort, from the 2014 to 2015 census rounds.
#|           This is net standing-carbon change, not gross woody productivity.
#|       - name: obs_stem_increment_2015_2017_kg_ha_yr
#|         type: numeric
#|         units: kg C ha-1 y-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2015- and 2017-labelled rounds.
#|         description: |
#|           Annualised net change in standing stem carbon per hectare for the
#|           2011-recorded tree cohort, from the 2015 to 2017 census rounds.
#|           This is net standing-carbon change, not gross woody productivity.
#|       - name: obs_stem_increment_2017_2019_kg_ha_yr
#|         type: numeric
#|         units: kg C ha-1 y-1
#|         spatial_extent: One value per selected OG plot; currently OG2_720 to OG2_728.
#|         temporal_extent: Interval between the 2017- and 2019-labelled rounds.
#|         description: |
#|           Annualised net change in standing stem carbon per hectare for the
#|           2011-recorded tree cohort, from the 2017 to 2019 census rounds.
#|           This is net standing-carbon change, not gross woody productivity.
#|
#| package_dependencies:
#|   - readxl
#|   - sf
#|   - toml
#|   - dplyr
#|
#| usage_notes: |
#|   Mass values are standardised from 25 m x 25 m plots to kg C ha-1.
#|   Standard errors represent allometric parameter uncertainty only. The stem
#|   increment is net standing-carbon change, not gross woody productivity.
#| ---

# Load required packages
library(readxl)
library(sf)
library(toml)
library(dplyr)

# Steps:

# - load census data and clean up (keep only dbh columns across years, only
# trees that are still alive, subset to all OG plots, etc.)

date_columns <- c(64:75)
# The Census11_20 sheet contains 239 columns.
column_types <- rep("guess", 239)
column_types[date_columns] <- "date"

tree_census_11_20 <- read_excel(
  "../../../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  skip = 9,
  col_names = TRUE,
  col_types = column_types
)

names(tree_census_11_20)

# Subset to all OG plots
tree_census_11_20 <-
  tree_census_11_20[tree_census_11_20$Block %in% c("OG1", "OG2", "OG3"), ]

# Habit_IND should always be T (tree) - there are several vines so exclude these
unique(tree_census_11_20$Habit_IND)
sum(tree_census_11_20$Habit_IND == "V")
tree_census_11_20 <- tree_census_11_20[tree_census_11_20$Habit_IND == "T", ]

# Subset to columns 1:75 and 214:227
tree_census_11_20 <-
  tree_census_11_20[, c(1:75, 214:227)]

# - load maliau_2 grid definition and SAFE gazetteer, then define which OG plots
# are located within the maliau_2 grid (if none fit then use average across all OG plots)
# - based on the above, subset tree census to relevant OG plots only

grid_definition <-
  read_toml(
    "../../../../../data/derived/site/maliau/maliau_grid_definition.toml"
  )

safe_gazetteer <-
  st_read("../../../../../data/primary/site/gazetteer.geojson", quiet = TRUE)

# Unique PlotID
OG_PlotID <- unique(tree_census_11_20$PlotID)

# Copy x and y from gazetteer to census data
tree_census_11_20$centroid_x <- NA
tree_census_11_20$centroid_y <- NA

for (i in unique(OG_PlotID)) {
  tree_census_11_20$centroid_x[tree_census_11_20$PlotID == i] <-
    safe_gazetteer$centroid_x[safe_gazetteer$location == i]
  tree_census_11_20$centroid_y[tree_census_11_20$PlotID == i] <-
    safe_gazetteer$centroid_y[safe_gazetteer$location == i]
}

# Define which OG_PlotID falls within maliau_2 grid
# Bounds are ordered as minimum longitude, minimum latitude, maximum longitude,
# and maximum latitude.
maliau_2_bounds <- unlist(grid_definition$Scenario$maliau_2$wgs84_bounds)

in_simulation_grid <- with(
  tree_census_11_20,
  centroid_x >= maliau_2_bounds[1] &
    centroid_y >= maliau_2_bounds[2] &
    centroid_x <= maliau_2_bounds[3] &
    centroid_y <= maliau_2_bounds[4]
)

simulation_plot_ids <- unique(tree_census_11_20$PlotID[which(
  in_simulation_grid
)])
# Keep all OG plots when the gazetteer has no plot inside the grid.
if (length(simulation_plot_ids) == 0) {
  simulation_plot_ids <- OG_PlotID
}

print(simulation_plot_ids)

# We can see that 9 OG2 plots are included in the maliau_2 scenario
# Below we subset the tree census to focus on these 9 plots
tree_census_11_20 <-
  tree_census_11_20[tree_census_11_20$PlotID %in% simulation_plot_ids, ]

# Add a quick plot that plots the 9 OG2 plots on top of the maliau_2 grid

maliau_2_plot_data <-
  safe_gazetteer[safe_gazetteer$location %in% simulation_plot_ids, ]

plot(
  maliau_2_plot_data$centroid_x,
  maliau_2_plot_data$centroid_y,
  asp = 1,
  pch = 19,
  xlim = maliau_2_bounds[c(1, 3)],
  ylim = maliau_2_bounds[c(2, 4)],
  xlab = "Longitude",
  ylab = "Latitude",
  main = "Selected OG plots and Maliau-2 grid"
)

# Draw regular cell boundaries across the full grid extent. `seq()` spaces
# the boundaries evenly between the minimum and maximum coordinates. The
# number of boundaries is the number of cells plus one outer boundary.
abline(
  v = seq(
    maliau_2_bounds[1],
    maliau_2_bounds[3],
    length.out = grid_definition$Scenario$maliau_2$cell_nx + 1
  ),
  h = seq(
    maliau_2_bounds[2],
    maliau_2_bounds[4],
    length.out = grid_definition$Scenario$maliau_2$cell_ny + 1
  ),
  col = "grey80",
  lty = 3
)

rect(
  xleft = maliau_2_bounds[1],
  ybottom = maliau_2_bounds[2],
  xright = maliau_2_bounds[3],
  ytop = maliau_2_bounds[4],
  border = "red",
  lwd = 2
)
text(
  maliau_2_plot_data$centroid_x,
  maliau_2_plot_data$centroid_y,
  labels = maliau_2_plot_data$location,
  pos = 3,
  cex = 0.7
)

# Nice, from the plot above we can get an idea of how many cells we'll be able
# to validate. It looks like 12 cells total (since some overlap multiple cells)

# For this script, we can only use census years where all trees within the plot
# were measured. For example, if only half the plot was measured during a
# particular year, then we cannot use that year for calculating the total plot
# carbon mass for that particular validation date.
# Keep in mind that some NA values may be because the tree was recruited in a
# specific year (i.e. it didn't exist in early census years; in which case the
# NA value is valid).
# We should also check for any incorrect DBH entries for years where trees were
# already reported as dead.

# On closer inspection, it appears only 2014 has (new) recruits measured. This
# means that all the other years do not truly capture the TOTAL plot carbon mass.
# Therefore, we will subset to 2011 trees only. There is an issue however where
# some initial trees lost their tag in later years, so we need to make sure that
# these are counted too, else we are underestimating the total plot carbon mass.
# To account for this, we want to:
# - keep the trees with first record year being 2011
# - exclude those with first record year being 2014 (these are recruits)
# - exclude those with first record year being 2019 (some of these are 2011 trees
#   with lost tag - note that it's not possible to say which ones, hence exclude)
# - exclude those with first record year being `NA` (these are also 2014 recruits)

# Check census years to check
names(tree_census_11_20)

# For each plot, we should check which census years have complete data
# In terms of date, some variation is fine, as long as it fits within the same month

simulation_plot_ids
selected_columns <- c(4:6, 12:15, 40:51, 64:75, 88)

OG2_720 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_720",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_721 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_721",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_722 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_722",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_723 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_723",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_724 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_724",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_725 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_725",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_726 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_726",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_727 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_727",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

OG2_728 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_728",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019

# So, we can subset to 2011, 2014, 2015, 2017 and 2019 census data, and then
# only keep the trees with first record year being 2011

names(tree_census_11_20)
tree_census_11_20 <- tree_census_11_20[
  tree_census_11_20$PlotID %in% simulation_plot_ids,
  c(4:6, 12:15, 17:21, 40:51, 64:75, 90, 91)
]

tree_census_11_20$DBH2011_mm_clean <-
  as.numeric(tree_census_11_20$DBH2011_mm_clean)
tree_census_11_20$DBH2014_mm_clean <-
  as.numeric(tree_census_11_20$DBH2014_mm_clean)
tree_census_11_20$DBH2015_mm_clean <-
  as.numeric(tree_census_11_20$DBH2015_mm_clean)
tree_census_11_20$DBH2017_mm_clean <-
  as.numeric(tree_census_11_20$DBH2017_mm_clean)
tree_census_11_20$DBH2019_mm_clean <-
  as.numeric(tree_census_11_20$DBH2019_mm_clean)

tree_census_11_20$FirstRecord_year_IND <-
  as.numeric(tree_census_11_20$FirstRecord_year_IND)

tree_census_11_20 <- tree_census_11_20[
  !is.na(tree_census_11_20$FirstRecord_year_IND) &
    tree_census_11_20$FirstRecord_year_IND == 2011,
]

# - add wood density if using Riutta et al. (2018) (Chave) method (not used for now)
# - for Kenzo et al. (2009) method wood density is not required (so proceed)

# - then apply allometric equations from Kenzo et al. (2009)
# https://doi.org/10.1007/s10310-009-0149-1
# to the dbh values to obtain "observed" stem mass, leaf mass, aboveground mass,
# fine root mass.

#####

# Calculate sapwood carbon content (needed to convert wood density later on)

# Load wood nutrients data and clean up a bit

inagawa_data <- read_excel(
  "../../../../../data/primary/plant/traits_data/inagawa_nutrients_wood_density.xlsx",
  sheet = "Nutrients",
  col_names = FALSE
)

max(nrow(inagawa_data))
colnames(inagawa_data) <- inagawa_data[7, ]
inagawa_data <- inagawa_data[8:427, ]
names(inagawa_data)

inagawa_data <- inagawa_data[, c("Species", "TissueType", "C_total")]
colnames(inagawa_data) <- c("species", "TissueType", "C_total")

inagawa_data$C_total <- as.numeric(inagawa_data$C_total)

# Because we only have 10 unique species, we'll use the mean across species

temp <- inagawa_data[, c("species", "TissueType", "C_total")]
unique(temp$TissueType)
temp <- temp[temp$TissueType == "Wood", ]

temp <- temp %>%
  group_by(species) %>%
  mutate(C_total_mean = mean(as.numeric(C_total), na.rm = TRUE)) %>%
  ungroup()

temp <- temp[, c("species", "TissueType", "C_total_mean")]
temp <- unique(temp)

mean(temp$C_total_mean) # Use 45.6% carbon content for Wood

#####

# Load leaf carbon content dataset
both_tree_functional_traits <- read_excel(
  "../../../../../data/primary/plant/traits_data/both_tree_functional_traits.xlsx",
  sheet = "Tree_functional_traits",
  col_names = FALSE
)

both_data <- both_tree_functional_traits
max(nrow(both_data))
colnames(both_data) <- both_data[7, ]
both_data <- both_data[8:724, ]
names(both_data)

both_data <- both_data[,
  c(
    "forest_type",
    "forestplots_name",
    "branch_type",
    "tree_id",
    "C_perc"
  )
]

both_data$C_perc <- as.numeric(both_data$C_perc)
both_data <- na.omit(both_data)
mean(both_data$C_perc)
mean(both_data$C_perc[both_data$forestplots_name %in% c("MLA-01", "MLA-02")])
# Use 44.3% mean leaf carbon content

#####

# obs_stem_mass
# For allometric equations, see Kenzo et al. (2009)
# https://doi.org/10.1007/s10310-009-0149-1
# Stem dry biomass = 0.0822*dbh^2.48
# SE: a = 0.0152 and b = 0.08 (y = ax^b)
# carbon content used = 45.6%
# Calculate carbon mass for each tree. DBH is converted from millimetres to
# centimetres before applying the allometric equation.
# Returns carbon mass in kg C per tree.
calculate_allometric_carbon <- function(
  dbh_mm,
  coefficient,
  exponent,
  carbon_fraction
) {
  dbh_cm <- as.numeric(dbh_mm) / 10
  valid <- !is.na(dbh_cm) & dbh_cm > 0
  carbon_mass <- rep(NA_real_, length(dbh_cm))

  dry_mass <- coefficient * dbh_cm[valid]^exponent
  carbon_mass[valid] <- dry_mass * carbon_fraction

  carbon_mass
}

# Calculate one SE for the total mass of a plot. The same fitted parameters
# apply to every tree, so their uncertainty is shared rather than independent.
# The derivatives describe how much the total plot mass changes when parameter
# a or b changes. They are combined with the reported parameter SEs.
# Returns the SE of total plot carbon mass in kg C per plot, before area scaling.
calculate_plot_se <- function(
  dbh_mm,
  coefficient,
  exponent,
  coefficient_se,
  exponent_se,
  carbon_fraction
) {
  dbh_cm <- as.numeric(dbh_mm) / 10
  valid <- !is.na(dbh_cm) & dbh_cm > 0
  dbh_cm <- dbh_cm[valid]

  derivative_a <- carbon_fraction * sum(dbh_cm^exponent)
  derivative_b <- carbon_fraction *
    sum(
      coefficient * dbh_cm^exponent * log(dbh_cm)
    )

  sqrt(
    (derivative_a * coefficient_se)^2 +
      (derivative_b * exponent_se)^2
  )
}

stem_2011_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2011_mm_clean,
  coefficient = 0.0822,
  exponent = 2.48,
  carbon_fraction = 0.456
)
stem_2014_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2014_mm_clean,
  coefficient = 0.0822,
  exponent = 2.48,
  carbon_fraction = 0.456
)
stem_2015_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2015_mm_clean,
  coefficient = 0.0822,
  exponent = 2.48,
  carbon_fraction = 0.456
)
stem_2017_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2017_mm_clean,
  coefficient = 0.0822,
  exponent = 2.48,
  carbon_fraction = 0.456
)
stem_2019_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2019_mm_clean,
  coefficient = 0.0822,
  exponent = 2.48,
  carbon_fraction = 0.456
)

tree_census_11_20$obs_stem_mass_2011_kg_c_tree <- stem_2011_kg_c_tree
tree_census_11_20$obs_stem_mass_2014_kg_c_tree <- stem_2014_kg_c_tree
tree_census_11_20$obs_stem_mass_2015_kg_c_tree <- stem_2015_kg_c_tree
tree_census_11_20$obs_stem_mass_2017_kg_c_tree <- stem_2017_kg_c_tree
tree_census_11_20$obs_stem_mass_2019_kg_c_tree <- stem_2019_kg_c_tree

#####

# obs_leaf_mass
# For allometric equations, see Kenzo et al. (2009)
# https://doi.org/10.1007/s10310-009-0149-1
# Leaf dry biomass = 0.0442*dbh^1.67
# SE: a = 0.0148 and b = 0.14 (y = ax^b)
# carbon content used = 44.30682% (see Both et al., above)
leaf_2011_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2011_mm_clean,
  coefficient = 0.0442,
  exponent = 1.67,
  carbon_fraction = 0.4430682
)
leaf_2014_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2014_mm_clean,
  coefficient = 0.0442,
  exponent = 1.67,
  carbon_fraction = 0.4430682
)
leaf_2015_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2015_mm_clean,
  coefficient = 0.0442,
  exponent = 1.67,
  carbon_fraction = 0.4430682
)
leaf_2017_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2017_mm_clean,
  coefficient = 0.0442,
  exponent = 1.67,
  carbon_fraction = 0.4430682
)
leaf_2019_kg_c_tree <- calculate_allometric_carbon(
  tree_census_11_20$DBH2019_mm_clean,
  coefficient = 0.0442,
  exponent = 1.67,
  carbon_fraction = 0.4430682
)

tree_census_11_20$obs_leaf_mass_2011_kg_c_tree <- leaf_2011_kg_c_tree
tree_census_11_20$obs_leaf_mass_2014_kg_c_tree <- leaf_2014_kg_c_tree
tree_census_11_20$obs_leaf_mass_2015_kg_c_tree <- leaf_2015_kg_c_tree
tree_census_11_20$obs_leaf_mass_2017_kg_c_tree <- leaf_2017_kg_c_tree
tree_census_11_20$obs_leaf_mass_2019_kg_c_tree <- leaf_2019_kg_c_tree

#####

# Now calculate the mass and se per plot and standardize to kg per hectare

# Each OG plot is 25 m by 25 m. Scale its 625 m2 total by 10000 / 625 = 16.
plot_area_m2 <- 25 * 25
plot_to_hectare <- 10000 / plot_area_m2

tree_mass_columns <- c(
  "obs_stem_mass_2011_kg_c_tree",
  "obs_stem_mass_2014_kg_c_tree",
  "obs_stem_mass_2015_kg_c_tree",
  "obs_stem_mass_2017_kg_c_tree",
  "obs_stem_mass_2019_kg_c_tree",
  "obs_leaf_mass_2011_kg_c_tree",
  "obs_leaf_mass_2014_kg_c_tree",
  "obs_leaf_mass_2015_kg_c_tree",
  "obs_leaf_mass_2017_kg_c_tree",
  "obs_leaf_mass_2019_kg_c_tree"
)

plot_mass_columns <- c(
  "obs_stem_mass_2011_kg_c_plot",
  "obs_stem_mass_2014_kg_c_plot",
  "obs_stem_mass_2015_kg_c_plot",
  "obs_stem_mass_2017_kg_c_plot",
  "obs_stem_mass_2019_kg_c_plot",
  "obs_leaf_mass_2011_kg_c_plot",
  "obs_leaf_mass_2014_kg_c_plot",
  "obs_leaf_mass_2015_kg_c_plot",
  "obs_leaf_mass_2017_kg_c_plot",
  "obs_leaf_mass_2019_kg_c_plot"
)

hectare_mass_columns <- c(
  "obs_stem_mass_2011_kg_ha",
  "obs_stem_mass_2014_kg_ha",
  "obs_stem_mass_2015_kg_ha",
  "obs_stem_mass_2017_kg_ha",
  "obs_stem_mass_2019_kg_ha",
  "obs_leaf_mass_2011_kg_ha",
  "obs_leaf_mass_2014_kg_ha",
  "obs_leaf_mass_2015_kg_ha",
  "obs_leaf_mass_2017_kg_ha",
  "obs_leaf_mass_2019_kg_ha"
)

plot_summary <- aggregate(
  tree_census_11_20[tree_mass_columns],
  by = list(PlotID = tree_census_11_20$PlotID),
  FUN = sum,
  na.rm = TRUE
)

# Aggregation gives kg C per plot; area scaling converts it to kg C per hectare.
names(plot_summary)[match(tree_mass_columns, names(plot_summary))] <-
  plot_mass_columns
plot_summary$plot_area_m2 <- plot_area_m2
plot_summary$plot_area_ha <- plot_area_m2 / 10000

plot_summary[plot_mass_columns] <-
  plot_summary[plot_mass_columns] * plot_to_hectare
names(plot_summary)[match(plot_mass_columns, names(plot_summary))] <-
  hectare_mass_columns

# Plot SEs use the shared-parameter calculation above, rather than treating
# each tree SE as independent. Apply the same area conversion to the SE.
# For allometric equations, see Kenzo et al. (2009)
# https://doi.org/10.1007/s10310-009-0149-1
plot_groups <- split(tree_census_11_20, tree_census_11_20$PlotID)
plot_summary$obs_stem_mass_2011_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2011_mm_clean,
      coefficient = 0.0822,
      exponent = 2.48,
      coefficient_se = 0.0152,
      exponent_se = 0.08,
      carbon_fraction = 0.456
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_stem_mass_2014_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2014_mm_clean,
      coefficient = 0.0822,
      exponent = 2.48,
      coefficient_se = 0.0152,
      exponent_se = 0.08,
      carbon_fraction = 0.456
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_stem_mass_2015_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2015_mm_clean,
      coefficient = 0.0822,
      exponent = 2.48,
      coefficient_se = 0.0152,
      exponent_se = 0.08,
      carbon_fraction = 0.456
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_stem_mass_2017_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2017_mm_clean,
      coefficient = 0.0822,
      exponent = 2.48,
      coefficient_se = 0.0152,
      exponent_se = 0.08,
      carbon_fraction = 0.456
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_stem_mass_2019_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2019_mm_clean,
      coefficient = 0.0822,
      exponent = 2.48,
      coefficient_se = 0.0152,
      exponent_se = 0.08,
      carbon_fraction = 0.456
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_leaf_mass_2011_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2011_mm_clean,
      coefficient = 0.0442,
      exponent = 1.67,
      coefficient_se = 0.0148,
      exponent_se = 0.14,
      carbon_fraction = 0.4430682
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_leaf_mass_2014_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2014_mm_clean,
      coefficient = 0.0442,
      exponent = 1.67,
      coefficient_se = 0.0148,
      exponent_se = 0.14,
      carbon_fraction = 0.4430682
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_leaf_mass_2015_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2015_mm_clean,
      coefficient = 0.0442,
      exponent = 1.67,
      coefficient_se = 0.0148,
      exponent_se = 0.14,
      carbon_fraction = 0.4430682
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_leaf_mass_2017_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2017_mm_clean,
      coefficient = 0.0442,
      exponent = 1.67,
      coefficient_se = 0.0148,
      exponent_se = 0.14,
      carbon_fraction = 0.4430682
    ) *
      plot_to_hectare
  },
  numeric(1)
)
plot_summary$obs_leaf_mass_2019_se_kg_ha <- vapply(
  plot_groups,
  function(plot_data) {
    calculate_plot_se(
      plot_data$DBH2019_mm_clean,
      coefficient = 0.0442,
      exponent = 1.67,
      coefficient_se = 0.0148,
      exponent_se = 0.14,
      carbon_fraction = 0.4430682
    ) *
      plot_to_hectare
  },
  numeric(1)
)

# Also calculate the annual woody increment so that we can then compare this
# with the 7.7 Mg ha-1 y-1 reported by Miyamoto et al. (2024) for Maliau.
# Keep the calculated increment in kg C ha-1 y-1; divide by 1000 only when
# comparing it with the published value in Mg C ha-1 y-1.

# The census date columns were forced to load as dates above.

# Use each plot's mean census date because each census lasted several days.
plot_dates <- aggregate(
  tree_census_11_20[c(
    "Date_2011",
    "Date_2014",
    "Date_2015",
    "Date_2017",
    "Date_2019"
  )],
  by = list(PlotID = tree_census_11_20$PlotID),
  FUN = mean,
  na.rm = TRUE
)
plot_dates <- plot_dates[match(plot_summary$PlotID, plot_dates$PlotID), ]

plot_summary$census_date_2011 <- plot_dates$Date_2011
plot_summary$census_date_2014 <- plot_dates$Date_2014
plot_summary$census_date_2015 <- plot_dates$Date_2015
plot_summary$census_date_2017 <- plot_dates$Date_2017
plot_summary$census_date_2019 <- plot_dates$Date_2019

plot_summary$census_2011_2014_interval_years <-
  as.numeric(plot_dates$Date_2014 - plot_dates$Date_2011) / 365.25
plot_summary$census_2014_2015_interval_years <-
  as.numeric(plot_dates$Date_2015 - plot_dates$Date_2014) / 365.25
plot_summary$census_2015_2017_interval_years <-
  as.numeric(plot_dates$Date_2017 - plot_dates$Date_2015) / 365.25
plot_summary$census_2017_2019_interval_years <-
  as.numeric(plot_dates$Date_2019 - plot_dates$Date_2017) / 365.25

plot_summary$obs_stem_increment_2011_2014_kg_ha_yr <-
  (plot_summary$obs_stem_mass_2014_kg_ha -
    plot_summary$obs_stem_mass_2011_kg_ha) /
  plot_summary$census_2011_2014_interval_years
plot_summary$obs_stem_increment_2014_2015_kg_ha_yr <-
  (plot_summary$obs_stem_mass_2015_kg_ha -
    plot_summary$obs_stem_mass_2014_kg_ha) /
  plot_summary$census_2014_2015_interval_years
plot_summary$obs_stem_increment_2015_2017_kg_ha_yr <-
  (plot_summary$obs_stem_mass_2017_kg_ha -
    plot_summary$obs_stem_mass_2015_kg_ha) /
  plot_summary$census_2015_2017_interval_years
plot_summary$obs_stem_increment_2017_2019_kg_ha_yr <-
  (plot_summary$obs_stem_mass_2019_kg_ha -
    plot_summary$obs_stem_mass_2017_kg_ha) /
  plot_summary$census_2017_2019_interval_years

# Note that this is net change in standing stem carbon, not gross woody productivity.

# Add plot x and y before writing file
plot_coordinates <- unique(
  tree_census_11_20[c("PlotID", "centroid_x", "centroid_y")]
)
plot_summary$plot_x <-
  plot_coordinates$centroid_x[
    match(plot_summary$PlotID, plot_coordinates$PlotID)
  ]
plot_summary$plot_y <-
  plot_coordinates$centroid_y[
    match(plot_summary$PlotID, plot_coordinates$PlotID)
  ]

# Ordered with the predicted mass and its standard error for each year
variables <- c(
  "PlotID",
  "plot_area_m2",
  "plot_area_ha",
  "plot_x",
  "plot_y",
  "obs_stem_mass_2011_kg_ha",
  "obs_stem_mass_2011_se_kg_ha",
  "obs_stem_mass_2014_kg_ha",
  "obs_stem_mass_2014_se_kg_ha",
  "obs_stem_mass_2015_kg_ha",
  "obs_stem_mass_2015_se_kg_ha",
  "obs_stem_mass_2017_kg_ha",
  "obs_stem_mass_2017_se_kg_ha",
  "obs_stem_mass_2019_kg_ha",
  "obs_stem_mass_2019_se_kg_ha",
  "obs_leaf_mass_2011_kg_ha",
  "obs_leaf_mass_2011_se_kg_ha",
  "obs_leaf_mass_2014_kg_ha",
  "obs_leaf_mass_2014_se_kg_ha",
  "obs_leaf_mass_2015_kg_ha",
  "obs_leaf_mass_2015_se_kg_ha",
  "obs_leaf_mass_2017_kg_ha",
  "obs_leaf_mass_2017_se_kg_ha",
  "obs_leaf_mass_2019_kg_ha",
  "obs_leaf_mass_2019_se_kg_ha",
  "census_date_2011",
  "census_date_2014",
  "census_date_2015",
  "census_date_2017",
  "census_date_2019",
  "census_2011_2014_interval_years",
  "census_2014_2015_interval_years",
  "census_2015_2017_interval_years",
  "census_2017_2019_interval_years",
  "obs_stem_increment_2011_2014_kg_ha_yr",
  "obs_stem_increment_2014_2015_kg_ha_yr",
  "obs_stem_increment_2015_2017_kg_ha_yr",
  "obs_stem_increment_2017_2019_kg_ha_yr"
)

plot_summary <- plot_summary[, variables]

# Output directory and file path
output_dir <- "../../../../../data/derived/plant/output_data/validation/observed_data_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(output_dir, "tree_standing_carbon_mass_maliau.csv")

# Write cleaned CSV file
write.csv(plot_summary, output_file, row.names = FALSE)
