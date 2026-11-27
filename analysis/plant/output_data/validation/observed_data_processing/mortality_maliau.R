#| ---
#| title: mortality_maliau
#|
#| description: |
#|   This script prepares the observed validation data for tree mortality
#|   for Maliau. It calculates tree mortality based on the SAFE census data,
#|   for the OG plots within the maliau_2 grid.
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
#|
#| output_files:
#|   - name: mortality_maliau.csv
#|     path: data/derived/plant/output_data/validation/observed_data_processing
#|     description: |
#|       One summary record per selected OG plot in Maliau-2, including
#|       interval mortality counts, annualised counts per hectare, and
#|       annualised fractions of the initial 2011 tree cohort.
#|     variables:
#|       - name: PlotID
#|         type: character
#|         units: dimensionless
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: SAFE identifier for each observed census plot.
#|       - name: centroid_x
#|         type: numeric
#|         units: degrees longitude
#|         spatial_extent: One centroid for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot centroid longitude in WGS84.
#|       - name: centroid_y
#|         type: numeric
#|         units: degrees latitude
#|         spatial_extent: One centroid for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Plot centroid latitude in WGS84.
#|       - name: plot_area_m2
#|         type: numeric
#|         units: m2
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Area of each OG census plot.
#|       - name: plot_area_ha
#|         type: numeric
#|         units: ha
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: null
#|         description: Area of each OG census plot in hectares.
#|       - name: initial_trees
#|         type: integer
#|         units: count
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: 2011 baseline cohort.
#|         description: Number of trees in the plot's initial 2011 cohort.
#|       - name: Date_2011
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot in Maliau-2.
#|         temporal_extent: Date of the 2011 census.
#|         description: Plot-specific date of the 2011 census.
#|       - name: Date_2014
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot in Maliau-2.
#|         temporal_extent: Date of the 2014 census.
#|         description: Plot-specific date of the 2014 census.
#|       - name: Date_2015
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot in Maliau-2.
#|         temporal_extent: Date of the 2015 census.
#|         description: Plot-specific date of the 2015 census.
#|       - name: Date_2017
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot in Maliau-2.
#|         temporal_extent: Date of the 2017 census.
#|         description: Plot-specific date of the 2017 census.
#|       - name: Date_2019
#|         type: date
#|         units: ISO 8601 date
#|         spatial_extent: One value per selected OG plot in Maliau-2.
#|         temporal_extent: Date of the 2019 census.
#|         description: Plot-specific date of the 2019 census.
#|       - name: interval_11_14_yr
#|         type: numeric
#|         units: year
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2011 and Date_2014.
#|         description: Elapsed duration between the plot's census dates in years.
#|       - name: interval_14_15_yr
#|         type: numeric
#|         units: year
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2014 and Date_2015.
#|         description: Elapsed duration between the plot's census dates in years.
#|       - name: interval_15_17_yr
#|         type: numeric
#|         units: year
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2015 and Date_2017.
#|         description: Elapsed duration between the plot's census dates in years.
#|       - name: interval_17_19_yr
#|         type: numeric
#|         units: year
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2017 and Date_2019.
#|         description: Elapsed duration between the plot's census dates in years.
#|       - name: mortality_count_11_14_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728, standardised to one hectare.
#|         temporal_extent: Per-plot interval between Date_2011 and Date_2014, annualised.
#|         description: Average annual death count per hectare for this interval.
#|       - name: mortality_count_14_15_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728, standardised to one hectare.
#|         temporal_extent: Per-plot interval between Date_2014 and Date_2015, annualised.
#|         description: Average annual death count per hectare for this interval.
#|       - name: mortality_count_15_17_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728, standardised to one hectare.
#|         temporal_extent: Per-plot interval between Date_2015 and Date_2017, annualised.
#|         description: Average annual death count per hectare for this interval.
#|       - name: mortality_count_17_19_ha_yr
#|         type: numeric
#|         units: count ha-1 year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728, standardised to one hectare.
#|         temporal_extent: Per-plot interval between Date_2017 and Date_2019, annualised.
#|         description: Average annual death count per hectare for this interval.
#|       - name: mortality_fraction_11_14_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2011 and Date_2014, annualised.
#|         description: Annualised fraction of the initial cohort reported dead.
#|       - name: mortality_fraction_14_15_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2014 and Date_2015, annualised.
#|         description: Annualised fraction of the initial cohort reported dead.
#|       - name: mortality_fraction_15_17_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2015 and Date_2017, annualised.
#|         description: Annualised fraction of the initial cohort reported dead.
#|       - name: mortality_fraction_17_19_yr
#|         type: numeric
#|         units: year-1
#|         spatial_extent: One value for each selected plot OG2_720 to OG2_728.
#|         temporal_extent: Per-plot interval between Date_2017 and Date_2019, annualised.
#|         description: Annualised fraction of the initial cohort reported dead.
#|
#| package_dependencies:
#|   - readxl
#|   - sf
#|   - toml
#|   - dplyr
#|
#| usage_notes: |
#|   Mortality counts are recorded per census interval and annualised using
#|   plot-specific census dates. The annualised counts are also standardised
#|   to per hectare. Mortality fractions use the initial 2011 tree cohort as
#|   the denominator and are annualised without area standardisation.
#| ---

# Load required packages
library(readxl)
library(sf)
library(toml)
library(dplyr)

# Steps:

# - load census data and clean up

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

# As seen below, only 2014 has (new) recruits measured. This means that all the
# other years do not truly capture the TOTAL amount of trees. However, these new
# recruits are not evaluated again, so we cannot calculate mortality for them.
# Therefore, we will subset to 2011 trees only and track their mortality across
# 2011-2014-2015-2017-2019.

# We should also check for any incorrect DBH entries for years where trees were
# already reported as dead.

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

# New notes:
# The trees initially measured in 2011 were remeasured in 2014, 2015, 2017 and 2019.
# The new recruits in 2014 were never remeasured afterwards.
# Some other trees (not part of the above) were only measured in 2019,
# but their dbh is too large for them to be new recruits. Some of these are part
# of the pre 2019 trees because their tag got lost, but it's not possible to
# link these to their original tag. Hence, these are excluded, since we cannot
# link to the correct census period, and cannot calculate mortality for these
# trees post 2019 either.
# Some trees have data starting in 2014 but are not marked as new 2014 recruits.

# Order based on Dead_year_IND
# 2707-1 dead in 2014
# 2715-1 dead in 2017
# 2716-1 dead in 2017
# 2717-1 dead in 2017
# Checked and ok, no unexpected dbh values (i.e., post period reported as dead)
# Then order based on first record year to check if trees not reported as dead
# still have dbh values in 2019.

OG2_721 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_721",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_722 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_722",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_723 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_723",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_724 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_724",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_725 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_725",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_726 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_726",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_727 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_727",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

OG2_728 <- tree_census_11_20[
  tree_census_11_20$PlotID == "OG2_728",
  c(selected_columns)
]
# Periods to use: 2011, 2014, 2015, 2017, 2019
# Only keep the trees with first record year being 2011

# Trees measured in 2011 were remeasured in 2014, 2015, 2017 and 2019
# 2014 trees contain 2011 trees with new recruits, however, these 2014 recruits
# were not remeasured, so we cannot obtain mortality from them
# Hence, we can really only focus on the 2011 trees, and track the mortality for
# these initial trees

# So, we can subset to trees measured in 2011 only
names(tree_census_11_20)
tree_census_11_20 <- tree_census_11_20[
  tree_census_11_20$PlotID %in% simulation_plot_ids,
  c(4:6, 12:15, 17:21, 40:51, 64:75, 90, 91)
]

tree_census_11_20$FirstRecord_year_IND <- as.numeric(
  tree_census_11_20$FirstRecord_year_IND
)

# Note that we need to exclude the NA's specifically, otherwise these get added
# as empty (NA) rows.
tree_census_11_20 <- tree_census_11_20[
  !is.na(tree_census_11_20$FirstRecord_year_IND) &
    tree_census_11_20$FirstRecord_year_IND == 2011,
]

# Here we need to decide how to quantify mortality
# The column Dead_year_IND shows the census year the tree was reported as dead
# The column Dead_period_IND shows the census interval the tree must have died
# in (i.e. the interval between reported as alive and dead)

# Note that different plots have different dates for their census
# This matters when calculating the mortality per unit time
# So, for each of these periods: "2011_2014" "2015_2017" "2017_2019" "2014_2015"
# we need to calculate the respective time between the censuses and use this
# to express mortality for each tree

# We can express mortality as an absolute count, and/or as a percentage/fraction
# of the initial 2011 trees, likely both

# For each plot, we should determine if the census dates are unique, if not then
# we should calculate an "average" date representative for that plot census year
# In the VE outputs, we will then count all the individuals that died during the
# timesteps that fell between the census period start and end date
# I have verified this and the plots have single dates for 2011, 2014, 2015,
# 2017 and 2019

# Now check across plots to see if we can simplify this date (i.e. just one date)
unique(tree_census_11_20$Date_2011)
unique(tree_census_11_20$Date_2014)
unique(tree_census_11_20$Date_2015)
unique(tree_census_11_20$Date_2017)
unique(tree_census_11_20$Date_2019)

# Not recommended to use just one date. Instead, use plot specific census dates
# because we want to standardize the mortality count to per year anyway.
# So we'll handle temporal resolution here by standardizing, and then in the
# comparison with VE outputs we can compare mortality that is area and time
# standardized (per hectare per year)

#####

# Now count the individuals that died during each census interval
# Note that this count has to be done per plot
# Here, also standardize the mortality per interval to a value per year by
# accounting for the interval duration (dividing by end date minus start date
# and multiplying by 365.25)
# Also express the mortality count as a fraction of the initial trees in 2011

# The raw mortality counts will only represent the plot area, so we should also
# standardize to per hectare
# Each OG plot is 25 m by 25 m. Scale its 625 m2 total by 10000 / 625 = 16.
plot_area_m2 <- 25 * 25
plot_to_hectare <- 10000 / plot_area_m2

tree_census_11_20$plot_area_m2 <- plot_area_m2
tree_census_11_20$plot_area_ha <- plot_area_m2 / 10000

tree_census_11_20$Dead_year_IND <- as.numeric(tree_census_11_20$Dead_year_IND)

# Calculate interval length between consecutive censuses and convert to years
tree_census_11_20$interval_11_14_yr <-
  as.numeric(
    (tree_census_11_20$Date_2014 - tree_census_11_20$Date_2011) / 365.25
  )
tree_census_11_20$interval_14_15_yr <-
  as.numeric(
    (tree_census_11_20$Date_2015 - tree_census_11_20$Date_2014) / 365.25
  )
tree_census_11_20$interval_15_17_yr <-
  as.numeric(
    (tree_census_11_20$Date_2017 - tree_census_11_20$Date_2015) / 365.25
  )
tree_census_11_20$interval_17_19_yr <-
  as.numeric(
    (tree_census_11_20$Date_2019 - tree_census_11_20$Date_2017) / 365.25
  )

for (i in unique(tree_census_11_20$PlotID)) {
  mortality_count_data <- tree_census_11_20[tree_census_11_20$PlotID == i, ]

  initial_trees <- nrow(mortality_count_data)
  tree_census_11_20$initial_trees[
    tree_census_11_20$PlotID == i
  ] <- initial_trees

  mortality_count_data <-
    mortality_count_data[!(mortality_count_data$Dead_period_IND == "NA"), ]

  mortality_count_2014 <-
    count(mortality_count_data[mortality_count_data$Dead_year_IND == 2014, ])
  mortality_count_2014$n
  mortality_count_2015 <-
    count(mortality_count_data[mortality_count_data$Dead_year_IND == 2015, ])
  mortality_count_2015$n
  mortality_count_2017 <-
    count(mortality_count_data[mortality_count_data$Dead_year_IND == 2017, ])
  mortality_count_2017$n
  mortality_count_2019 <-
    count(mortality_count_data[mortality_count_data$Dead_year_IND == 2019, ])
  mortality_count_2019$n

  # Note that the step above is a bit redundant, as we could just use the period
  # in the step below, but since it doesn't really matter here I'm keeping the
  # above. Also, we can do this because we know that e.g. 2014 mortality always
  # falls within 2011-2014 period (same for 2014-2015, etc.).

  # First calculate the raw count
  tree_census_11_20$mortality_count_11_14[tree_census_11_20$PlotID == i] <-
    mortality_count_2014$n
  tree_census_11_20$mortality_count_14_15[tree_census_11_20$PlotID == i] <-
    mortality_count_2015$n
  tree_census_11_20$mortality_count_15_17[tree_census_11_20$PlotID == i] <-
    mortality_count_2017$n
  tree_census_11_20$mortality_count_17_19[tree_census_11_20$PlotID == i] <-
    mortality_count_2019$n

  # Then standardize the count to per year
  tree_census_11_20$mortality_count_11_14_yr[tree_census_11_20$PlotID == i] <-
    tree_census_11_20$mortality_count_11_14[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_11_14_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_count_14_15_yr[tree_census_11_20$PlotID == i] <-
    tree_census_11_20$mortality_count_14_15[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_14_15_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_count_15_17_yr[tree_census_11_20$PlotID == i] <-
    tree_census_11_20$mortality_count_15_17[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_15_17_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_count_17_19_yr[tree_census_11_20$PlotID == i] <-
    tree_census_11_20$mortality_count_17_19[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_17_19_yr[tree_census_11_20$PlotID == i]

  # Then standardize the annualized count to per hectare
  tree_census_11_20$mortality_count_11_14_ha_yr <-
    tree_census_11_20$mortality_count_11_14_yr * plot_to_hectare
  tree_census_11_20$mortality_count_14_15_ha_yr <-
    tree_census_11_20$mortality_count_14_15_yr * plot_to_hectare
  tree_census_11_20$mortality_count_15_17_ha_yr <-
    tree_census_11_20$mortality_count_15_17_yr * plot_to_hectare
  tree_census_11_20$mortality_count_17_19_ha_yr <-
    tree_census_11_20$mortality_count_17_19_yr * plot_to_hectare

  # Also calculate the raw mortality fraction
  tree_census_11_20$mortality_fraction_11_14[tree_census_11_20$PlotID == i] <-
    mortality_count_2014$n / initial_trees
  tree_census_11_20$mortality_fraction_14_15[tree_census_11_20$PlotID == i] <-
    mortality_count_2015$n / initial_trees
  tree_census_11_20$mortality_fraction_15_17[tree_census_11_20$PlotID == i] <-
    mortality_count_2017$n / initial_trees
  tree_census_11_20$mortality_fraction_17_19[tree_census_11_20$PlotID == i] <-
    mortality_count_2019$n / initial_trees

  # Then standardize the fraction to per year
  tree_census_11_20$mortality_fraction_11_14_yr[
    tree_census_11_20$PlotID == i
  ] <-
    tree_census_11_20$mortality_fraction_11_14[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_11_14_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_fraction_14_15_yr[
    tree_census_11_20$PlotID == i
  ] <-
    tree_census_11_20$mortality_fraction_14_15[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_14_15_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_fraction_15_17_yr[
    tree_census_11_20$PlotID == i
  ] <-
    tree_census_11_20$mortality_fraction_15_17[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_15_17_yr[tree_census_11_20$PlotID == i]
  tree_census_11_20$mortality_fraction_17_19_yr[
    tree_census_11_20$PlotID == i
  ] <-
    tree_census_11_20$mortality_fraction_17_19[tree_census_11_20$PlotID == i] /
    tree_census_11_20$interval_17_19_yr[tree_census_11_20$PlotID == i]

  rm(initial_trees)
  rm(mortality_count_2014)
  rm(mortality_count_2015)
  rm(mortality_count_2017)
  rm(mortality_count_2019)
}

# Some simple plots
plot(
  tree_census_11_20$mortality_count_11_14_ha_yr ~ tree_census_11_20$DBH2011_mm_clean
)
plot(
  tree_census_11_20$mortality_count_14_15_ha_yr ~ tree_census_11_20$DBH2011_mm_clean
)
plot(
  tree_census_11_20$mortality_count_15_17_ha_yr ~ tree_census_11_20$DBH2011_mm_clean
)
plot(
  tree_census_11_20$mortality_count_17_19_ha_yr ~ tree_census_11_20$DBH2011_mm_clean
)

# Because these are counts from a census of the trees in each plot,
# the count is exact for those observed plots; hence there is no SE to add.

# As an add-on, we could add a PFT to each tree based on our PFT species
# classification. While this PFT species classification should not be seen as
# true validation data, it may be informative to look at mortality per PFT.
# Do note that mortality in VE is not PFT specific.
# Perhaps I'll leave the PFT link out for now, and we can focus on comparing
# total mortality first (and perhaps later per dbh classes)
# Note that for comparing dbh specific mortality the columns Dead_year_IND and
# Dead_period_IND can be used instead of the count.

# Final clean up, variable selection and write file
names(tree_census_11_20)

# Keep relevant only for now until we know which ones are not needed for validation
variables <- c(
  "PlotID",
  "centroid_x",
  "centroid_y",
  "plot_area_m2",
  "plot_area_ha",
  #  "TagStem_latest",
  "Dead_year_IND",
  "Dead_period_IND",
  "FirstRecord_year_IND",
  "NewRecruit_year_IND",
  #  "Family",
  #  "Genus",
  #  "Species",
  #  "TaxaName",
  #  "TaxaLevel",
  "initial_trees",
  "DBH2011_mm_clean",
  #  "DBH2012_mm_clean",
  #  "DBH2012B_mm_clean",
  #  "DBH2013_mm_clean",
  "DBH2014_mm_clean",
  #  "DBH2014B_mm_clean",
  "DBH2015_mm_clean",
  #  "DBH2016_mm_clean",
  "DBH2017_mm_clean",
  #  "DBH2018_mm_clean",
  "DBH2019_mm_clean",
  #  "DBH2020_mm_clean",
  "Date_2011",
  #  "Date_2012",
  #  "Date_2012B",
  #  "Date_2013",
  "Date_2014",
  #  "Date_2014B",
  "Date_2015",
  #  "Date_2016",
  "Date_2017",
  #  "Date_2018",
  "Date_2019",
  #  "Date_2020",
  "interval_11_14_yr",
  "interval_14_15_yr",
  "interval_15_17_yr",
  "interval_17_19_yr",
  "mortality_count_11_14",
  "mortality_count_14_15",
  "mortality_count_15_17",
  "mortality_count_17_19",
  "mortality_count_11_14_yr",
  "mortality_count_14_15_yr",
  "mortality_count_15_17_yr",
  "mortality_count_17_19_yr",
  "mortality_count_11_14_ha_yr",
  "mortality_count_14_15_ha_yr",
  "mortality_count_15_17_ha_yr",
  "mortality_count_17_19_ha_yr",
  "mortality_fraction_11_14",
  "mortality_fraction_14_15",
  "mortality_fraction_15_17",
  "mortality_fraction_17_19",
  "mortality_fraction_11_14_yr",
  "mortality_fraction_14_15_yr",
  "mortality_fraction_15_17_yr",
  "mortality_fraction_17_19_yr"
)

mortality_summary <- tree_census_11_20[, variables]

# Reduce mortality_summary even further to plot specific summary
# This additional cleanup can be changed/removed if more details are preferred
# in the summary csv file.

variables <- c(
  "PlotID",
  "centroid_x",
  "centroid_y",
  "plot_area_m2",
  "plot_area_ha",
  #  "TagStem_latest",
  #"Dead_year_IND",
  #"Dead_period_IND",
  #"FirstRecord_year_IND",
  #"NewRecruit_year_IND",
  #  "Family",
  #  "Genus",
  #  "Species",
  #  "TaxaName",
  #  "TaxaLevel",
  "initial_trees",
  #"DBH2011_mm_clean",
  #  "DBH2012_mm_clean",
  #  "DBH2012B_mm_clean",
  #  "DBH2013_mm_clean",
  #"DBH2014_mm_clean",
  #  "DBH2014B_mm_clean",
  #"DBH2015_mm_clean",
  #  "DBH2016_mm_clean",
  #"DBH2017_mm_clean",
  #  "DBH2018_mm_clean",
  #"DBH2019_mm_clean",
  #  "DBH2020_mm_clean",
  "Date_2011",
  #  "Date_2012",
  #  "Date_2012B",
  #  "Date_2013",
  "Date_2014",
  #  "Date_2014B",
  "Date_2015",
  #  "Date_2016",
  "Date_2017",
  #  "Date_2018",
  "Date_2019",
  #  "Date_2020",
  "interval_11_14_yr",
  "interval_14_15_yr",
  "interval_15_17_yr",
  "interval_17_19_yr",
  #"mortality_count_11_14",
  #"mortality_count_14_15",
  #"mortality_count_15_17",
  #"mortality_count_17_19",
  #"mortality_count_11_14_yr",
  #"mortality_count_14_15_yr",
  #"mortality_count_15_17_yr",
  #"mortality_count_17_19_yr",
  "mortality_count_11_14_ha_yr",
  "mortality_count_14_15_ha_yr",
  "mortality_count_15_17_ha_yr",
  "mortality_count_17_19_ha_yr",
  #"mortality_fraction_11_14",
  #"mortality_fraction_14_15",
  #"mortality_fraction_15_17",
  #"mortality_fraction_17_19",
  "mortality_fraction_11_14_yr",
  "mortality_fraction_14_15_yr",
  "mortality_fraction_15_17_yr",
  "mortality_fraction_17_19_yr"
)

mortality_summary <- mortality_summary[, variables]
mortality_summary <- unique(mortality_summary)

# Output directory and file path
output_dir <- "../../../../../data/derived/plant/output_data/validation/observed_data_processing"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(output_dir, "mortality_maliau.csv")

# Write cleaned CSV file
write.csv(mortality_summary, output_file, row.names = FALSE)
