#| ---
#| title: pft_cohort_data_maliau
#|
#| description: |
#|   Creates plot-level and regional mean plant functional type (PFT) cohort
#|   distributions from the 2011 SAFE Project Old Growth (OG1, OG2, and OG3)
#|   tree census plots at Maliau. Tree stems are assigned to PFTs, grouped into
#|   100 mm DBH classes, and converted to cohort densities for use as source
#|   data in Virtual Ecosystem plant initialisation workflows.
#|
#|   The plot-level output retains census-plot coordinates for downstream
#|   spatial prediction scripts. The regional output is the mean density across
#|   the sampled OG plots and is expressed in stems per hectare.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: in progress
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
#|   - name: pfts_maximum_height_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file containing an updated list of taxa and their respective
#|       pft. It contains both the base pft classification from pfts_maliau and
#|       additional assignments for previously unclassified taxa based on their
#|       maximum height relative to pft maximum height thresholds. Taxon maximum
#|       height is also included in the output file.
#|   - name: t_model_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       A CSV file listing T model parameters by pft.
#|   - name: safe_plot_coordinates.geojson
#|     path: data/primary/plant/safe_plot_coordinates
#|     description: |
#|       SAFE Project sampling-plot coordinates.
#|
#| output_files:
#|   - name: pft_cohort_data_maliau.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       Plot-level PFT cohort counts and densities for the 27 sampled Maliau
#|       OG census plots.
#|     variables:
#|       - name: plot_id
#|         type: character
#|         units: dimensionless
#|         description: |
#|           SAFE Project census plot identifier.
#|       - name: block
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Old Growth census block identifier.
#|       - name: plot
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plot identifier within the census block.
#|       - name: lon_wgs84
#|         type: numeric
#|         units: degrees_east
#|         description: |
#|           Census plot longitude in WGS84.
#|       - name: lat_wgs84
#|         type: numeric
#|         units: degrees_north
#|         description: |
#|           Census plot latitude in WGS84.
#|       - name: x_utm32650
#|         type: numeric
#|         units: m
#|         description: |
#|           Census plot easting in UTM zone 50N (EPSG:32650).
#|       - name: y_utm32650
#|         type: numeric
#|         units: m
#|         description: |
#|           Census plot northing in UTM zone 50N (EPSG:32650).
#|       - name: plant_cohorts_pft
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type assigned to the cohort.
#|       - name: plant_cohorts_dbh
#|         type: numeric
#|         units: m
#|         description: |
#|           Midpoint diameter at breast height of the 100 mm cohort class.
#|       - name: plant_cohorts_n
#|         type: integer
#|         units: stems
#|         description: |
#|           Number of recorded stems in the 25 by 25 m census plot.
#|       - name: plant_cohorts_n_per_ha
#|         type: numeric
#|         units: stems ha-1
#|         description: |
#|           Cohort stem density, scaled from the census plot to one hectare.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth forest"
#|             date: "2011"
#|         assumptions: |
#|           Each retained census record represents one living tree stem. Trees
#|           with missing DBH are excluded, and PFTs missing from the lookup are
#|           assigned from the measured height and PFT maximum-height thresholds.
#|   - name: pft_cohort_data_maliau_mean_per_ha.csv
#|     path: data/derived/plant/input_data/data_library
#|     description: |
#|       Mean PFT cohort stem density across all sampled Maliau OG census plots.
#|     variables:
#|       - name: plant_cohorts_n_per_ha
#|         type: numeric
#|         units: stems ha-1
#|         description: |
#|           Mean stem density for each PFT and DBH cohort across the sampled
#|           OG plots.
#|       - name: plant_cohorts_pft
#|         type: character
#|         units: dimensionless
#|         description: |
#|           Plant functional type assigned to the cohort.
#|       - name: plant_cohorts_dbh
#|         type: numeric
#|         units: m
#|         description: |
#|           Midpoint diameter at breast height of the 100 mm cohort class.
#|         references:
#|           - citation: "Svátek et al. (2025)"
#|             doi: "https://doi.org/10.5281/zenodo.14882506"
#|             url: "https://zenodo.org/records/14882506"
#|             origin: "SAFE Project, Sabah, Malaysia"
#|             biome: "tropical"
#|             vegetation_type: "lowland tropical rain forest"
#|             site_condition: "old-growth forest"
#|             date: "2011"
#|         assumptions: |
#|           The 27 sampled 25 by 25 m plots represent the Maliau old-growth
#|           forest community. Cohort densities are calculated from individual
#|           stems and do not include trees below the census DBH threshold.
#|
#| package_dependencies:
#|   - readxl
#|   - dplyr
#|   - sf
#|
#| usage_notes: |
#|   Run from this script's directory because input and output paths are
#|   relative. The script currently uses 2011, the earliest census year, and
#|   includes only tree records in the OG1, OG2, and OG3 blocks. It writes
#|   library inputs only; scenario-specific spatial prediction should be
#|   performed by a separate script.
#| ---

# Notes

# Initially, I started this script doing 3 things:
# - calculate the PFT cohort distributions for the OG plots
# - apply IDW spatial interpolation
# - apply spatial prediction using environmental/LIDAR drivers

# I now think I should split this script up into 3 separate scripts:
# - the first script (this one) calculates and writes the PFT cohort distribution
#   file for the OG plots for Maliau (non-scenario specific), in theory this can
#   be part of plant input data library
# - the second script is part of scenarios and tests out the IDW spatial interpolation
# - the third script is part of scenarios and actually does the (desired) spatial
#   prediction based on enviromental/LIDAR/remotely sensed data

# This will prevent this original script from becoming too long and chaotic
# It will also make it easier to rewrite the second and third script into
# spatial plant community tools, which can then be run for each scenario

# Note that the outputs of the first script do not need the spatial OG coordinates
# yet, however it may be nice to already include these here, so that this step
# doesn't need to be repeated in the scenario scripts (the focus can there then
# be on loading/subsetting/scaling to the actual grid used in the simulation)

library(readxl)
library(dplyr)
library(sf)
library(ggplot2)
library(gstat)

####################

# Step 1: load census data and pft species classification

# Load SAFE tree census data and clean up

tree_census_11_20 <- read_excel(
  "../../../../data/primary/plant/tree_census/tree_census_11_20.xlsx",
  sheet = "Census11_20",
  col_names = FALSE
)

colnames(tree_census_11_20) <- tree_census_11_20[10, ]
tree_census_11_20 <- tree_census_11_20[11:max(nrow(tree_census_11_20)), ]
names(tree_census_11_20)

# Load PFT maximum height classification and clean up

pfts_maximum_height_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/pfts_maximum_height_maliau.csv",
  header = TRUE
)

####################

# Step 2: apply pft classification to census data
# - decide on which year to use for cohort distribution
# - evaluate how many trees are alive (stem density) and dead
# - evaluate what % of stems alive have a pft assigned

# Ideally the pft distribution would be calculated for each year where the
# simulation starts however, for our use case this is not required, because we
# start from 2010 and 2011 is the earliest available
# this does carry the assumption that the pft cohort distribution is representative
# across years

# 194 trees are excluded from OG plots because no record when first observed
# most also have no dbh anyway so these are bad data entries
# Note that it is not ideal to exclude these, as we don't fully know how many
# should be removed, but due to lack of details in the census dataset this seems
# like the best option
check <- tree_census_11_20[is.na(tree_census_11_20$FirstRecord_year_IND), ]
check <- tree_census_11_20[tree_census_11_20$FirstRecord_year_IND == "NA", ]
check <- check[check$Block %in% c("OG1", "OG2", "OG3"), ]

# 931 trees to start with in OG plots
# good news is that almost all of these have dbh and height data
# so we should be able to assign a pft to all of these
check <- tree_census_11_20[tree_census_11_20$FirstRecord_year_IND == "2011", ]
check <- check[check$Block %in% c("OG1", "OG2", "OG3"), ]

# Habit_IND should always be T (tree) - there are 25 vines so exclude these
unique(check$Habit_IND)
sum(check$Habit_IND == "V")
check <- check[check$Habit_IND == "T", ]

# Each OG block contains several plots, which are not connected to each other
# Each plot (e.g., OG1_711) is 25mx25m
# so, do a quick calculation of stem density
unique(check$PlotID)
(931 - 25) / (25 * 25 * 27) * 10000
# so an average stem density of 536 trees per hectare (rounded down)
# Compared to 410-444-535-478-427-600 from Kenzo, Slik,
# Mills, Saner papers (especially Slik appendix, many locations)
# e.g. 507-608 reported for Sepilok

# Now subset pfts_maximum_height_maliau and add it to the tree_census_11_20
pfts_sub <- pfts_maximum_height_maliau[, c(
  "pft_name_h_max_taxa",
  "pft_name",
  "taxa_name",
  "h_max_taxa"
)]

census_data_2011 <- left_join(
  check,
  pfts_sub,
  by = c("TaxaName" = "taxa_name")
)

# Now filter columns to useful ones only

census_data_2011 <- census_data_2011[,
  c(
    "Block",
    "Plot",
    "PlotID",
    "TagStem_latest",
    "Stem_suffix",
    "X_m_IND",
    "Y_m_IND",
    "Habit_IND",
    "Dead_year_IND",
    "Dead_period_IND",
    "FirstRecord_year_IND",
    "NewRecruit_year_IND",
    "Family",
    "Genus",
    "Species",
    "TaxaName",
    "TaxaLevel",
    "Confidence",
    "Notes_to_distribution",
    "Species_group",
    "2011_number_of_living_stems_clean",
    "DBH2011_mm_clean",
    "Source_DBH2011",
    "Date_2011",
    "StemCode_2011",
    "Length_2011_m",
    "Source_length2011",
    "Climber_Lower_2011",
    "Climber_Upper_2011",
    "Epiphyte_2011",
    "Fruit_2011",
    "Flower_2011",
    "CanopyRadiusNorth_cm_2011",
    "CanopyRadiusEast_cm_2011",
    "CanopyRadiusSouth_cm_2011",
    "CanopyRadiusWest_cm_2011",
    "HeightTotal_m_2011",
    "HeightBranch_m_2011",
    "HeightLeaf_m_2011",
    "CrownCondition_2011",
    "CrownIlluminationIndex_2011",
    "TagStem_2011",
    "2011_Individual_Plot_level",
    "pft_name_h_max_taxa",
    "pft_name",
    "h_max_taxa"
  )
]

census_data_2011$HeightTotal_m_2011 <-
  as.numeric(census_data_2011$HeightTotal_m_2011)
census_data_2011$DBH2011_mm_clean <-
  as.numeric(census_data_2011$DBH2011_mm_clean)
census_data_2011$h_max_taxa <-
  as.numeric(census_data_2011$h_max_taxa)
census_data_2011$Stem_suffix <-
  as.numeric(census_data_2011$Stem_suffix)
census_data_2011$Dead_year_IND <-
  as.numeric(census_data_2011$Dead_year_IND)
census_data_2011$FirstRecord_year_IND <-
  as.numeric(census_data_2011$FirstRecord_year_IND)
census_data_2011$NewRecruit_year_IND <-
  as.numeric(census_data_2011$NewRecruit_year_IND)
census_data_2011$`2011_number_of_living_stems_clean` <-
  as.numeric(census_data_2011$`2011_number_of_living_stems_clean`)

# Now check how many trees have a pft assigned
# Also evaluate the assigned pft with available tree characteristics from census data
# this may provide some form of validation of the assigned pft

# Stem_suffix should mostly be 1 (see stem tag 2887)
# Treat this tree as 2 individuals
unique(census_data_2011$Stem_suffix)

# Number of living stems should mostly be 1
# There are 6 rows with values other than 1 but this doesn't seem to match
# with corresponding entries for multiple stem tags, so I've decided to ignore this
unique(census_data_2011$`2011_number_of_living_stems_clean`)

# Check trees that died during 2011 (0)
sum(census_data_2011$Dead_year_IND == "2011")

# Check if for new recruits in 2011 (0)
sum(census_data_2011$NewRecruit_year_IND == "2011")

# Check trees without dbh values
# There's 1 tree with NA (stem tag 3325-1)
sum(is.na(census_data_2011$DBH2011_mm_clean))
# Although not ideal, we will exclude this single tree and not worry about
# correcting for its exclusion
census_data_2011 <- census_data_2011[
  !is.na(census_data_2011$DBH2011_mm_clean),
]

# Check trees without pft_name
unique(census_data_2011$pft_name)
sum(is.na(census_data_2011$pft_name))
sum(census_data_2011$pft_name == "unknown", na.rm = TRUE)

# Check trees without pft_name_h_max_taxa
unique(census_data_2011$pft_name_h_max_taxa)
sum(is.na(census_data_2011$pft_name_h_max_taxa))
# So, we got 140 trees without final pft assigned
# Check why?

# The reason for this is because these individuals are only assigned a family
# The maximum height script assigns remaining pfts based on genus only
# The remaining trees with pft = NA do have dbh and height values
# So, we could assign them based on taxa maximum height but for family only this
# is a bit messier than when it is done for genus
# In this case, the logic is to assign a tree in a pft based on its current height,
# which ignores the possibility that it could grow taller than that pft max height
# But because we only have family data available for these trees it's the best
# we can do

# So, load t_model_maliau so that we can access the pft maximum height values

t_model_maliau <- read.csv(
  "../../../../data/derived/plant/input_data/data_library/t_model_maliau.csv",
  header = TRUE
)

emergent_h_max <- t_model_maliau$h_max[t_model_maliau$pft_name == "emergent"]
overstory_h_max <- t_model_maliau$h_max[t_model_maliau$pft_name == "overstory"]
understory_h_max <- t_model_maliau$h_max[
  t_model_maliau$pft_name == "understory"
]

# Now assign pft based on taxa (i.e. family) height
# Note that the large majority of these remaining ones are assigned understory
# In a way this works out well as it's the most conservative pft assignment

census_data_2011$pft_name_h_max_taxa[
  which(
    is.na(census_data_2011$pft_name_h_max_taxa) &
      census_data_2011$HeightTotal_m_2011 <= understory_h_max
  )
] <- "understory"

census_data_2011$pft_name_h_max_taxa[
  which(
    is.na(census_data_2011$pft_name_h_max_taxa) &
      census_data_2011$HeightTotal_m_2011 <= overstory_h_max &
      census_data_2011$HeightTotal_m_2011 > understory_h_max
  )
] <- "overstory"

census_data_2011$pft_name_h_max_taxa[
  which(
    is.na(census_data_2011$pft_name_h_max_taxa) &
      census_data_2011$HeightTotal_m_2011 > overstory_h_max
  )
] <- "emergent"

# So, our final summary

# Total trees across the OG plots that are alive in 2011 (905)
nrow(census_data_2011)

# Total trees without pft (0)
unique(census_data_2011$pft_name_h_max_taxa)

# Total trees without dbh values (0)
sum(is.na(census_data_2011$DBH2011_mm_clean))

# Clean up variables

names(census_data_2011)

census_data_2011 <- census_data_2011[, c(
  "Block",
  "Plot",
  "PlotID",
  "DBH2011_mm_clean",
  "pft_name_h_max_taxa"
)]

####################

# Step 3: Add SAFE plot coordinates to census_data_2011

# Load safe plot coordinates
safe_plot_coords <- st_read(
  "../../../../data/primary/plant/safe_plot_coordinates/safe_plot_coordinates.geojson"
)

# See summary of all geometry types in the dataset
table(st_geometry_type(safe_plot_coords))

# Note that the majority here are points, representing "single XY GPS coordinates"
# There are also some polygons for example representing the entire OG1 triangle
# There are also some linestrings which represent riparian transects
# The multipolygon is only used for the safe basecamp

# We only really need a subset of these coordinates
# Specifically, for Maliau we only need each SAFE sampling point in OG1, OG2 and OG3
# These points (the 27 blue points in the figure) correspond to:
unique(census_data_2011$PlotID)

# So, we will subset the safe_plot_coords, unpack the geometry column into X and Y,
# have separate columns that also express these with epsg_code = 32650
# and then add these 4 columns to census_data_2011
# Note that this approach will need adjusting if polygons are to be exported,
# because the geometry column structure is different

# DEFINE THE 27 TARGET CENSUS PLOT IDs
target_plots <- unique(census_data_2011$PlotID)

# FILTER & UNPACK COORDINATES FROM safe_plot_coords
# Subset rows matching target plots
sub_sf <- safe_plot_coords[safe_plot_coords$location %in% target_plots, ]

# Extract original WGS84 coordinates (EPSG:4326)
coords_wgs84 <- st_coordinates(sub_sf)
sub_sf$lon_wgs84 <- coords_wgs84[, 1]
sub_sf$lat_wgs84 <- coords_wgs84[, 2]

# Transform to UTM Zone 50N (EPSG:32650) and extract projected coordinates
# Note that the EPSG code here is hardcoded based on the one used in
# maliau_grid_definition.toml so if this changes then this script needs to be
# updated
sub_sf_utm <- st_transform(sub_sf, crs = 32650)
coords_utm <- st_coordinates(sub_sf_utm)

sub_sf$x_utm32650 <- coords_utm[, 1]
sub_sf$y_utm32650 <- coords_utm[, 2]

# Drop spatial geometry and select target columns
plot_coords_extracted <- st_drop_geometry(sub_sf)
plot_coords_extracted <- plot_coords_extracted[, c(
  "location",
  "lon_wgs84",
  "lat_wgs84",
  "x_utm32650",
  "y_utm32650"
)]

# MERGE COORDINATE COLUMNS INTO census_data_2011
census_data_2011 <- merge(
  x = census_data_2011,
  y = plot_coords_extracted,
  by.x = "PlotID",
  by.y = "location",
  all.x = TRUE
)

####################

# Step 4: Define pft cohort distribution for OG plots

# Define study parameters
n_total_plots <- length(unique(census_data_2011$PlotID[
  !is.na(census_data_2011$PlotID)
]))
subplot_area_ha <- (25 * 25) / 10000 # 0.0625 ha per subplot
total_sampled_ha <- n_total_plots * subplot_area_ha # 1.6875 ha total sampled area

# Define DBH classes (breaks every 100 mm, midpoint converted to meters)
max_dbh_mm <- 2000
dbh_breaks <- c(0, seq(100, max_dbh_mm + 100, 100))
dbh_midpoints_m <- c(100, seq(150, max_dbh_mm + 50, 100)) / 1000

# 1. Filter incomplete records
keep <- !is.na(census_data_2011$DBH2011_mm_clean) &
  !is.na(census_data_2011$pft_name_h_max_taxa) &
  !is.na(census_data_2011$x_utm32650) &
  !is.na(census_data_2011$y_utm32650) &
  !is.na(census_data_2011$lon_wgs84) &
  !is.na(census_data_2011$lat_wgs84)

d <- census_data_2011[keep, ]

# Ensure correct data types
d$DBH2011_mm_clean <- as.numeric(d$DBH2011_mm_clean)
d$x_utm32650 <- as.numeric(d$x_utm32650)
d$y_utm32650 <- as.numeric(d$y_utm32650)
d$lon_wgs84 <- as.numeric(d$lon_wgs84)
d$lat_wgs84 <- as.numeric(d$lat_wgs84)
d$pft_name_h_max_taxa <- as.character(d$pft_name_h_max_taxa)

# Bin DBH into class midpoints in meters
d$plant_cohorts_dbh <- as.numeric(as.character(cut(
  d$DBH2011_mm_clean,
  breaks = dbh_breaks,
  labels = dbh_midpoints_m
)))

d <- d[!is.na(d$plant_cohorts_dbh), ]

# 2. Local distribution per subplot (25m x 25m)
plot_cohort_counts <- aggregate(
  x = list(plant_cohorts_n = rep(1L, nrow(d))),
  by = list(
    PlotID = d$PlotID,
    Block = d$Block,
    Plot = d$Plot,
    lon_wgs84 = d$lon_wgs84,
    lat_wgs84 = d$lat_wgs84,
    x_utm32650 = d$x_utm32650,
    y_utm32650 = d$y_utm32650,
    plant_cohorts_pft = d$pft_name_h_max_taxa,
    plant_cohorts_dbh = d$plant_cohorts_dbh
  ),
  FUN = sum
)

# Convert subplot count to per-hectare density
plot_cohort_counts$plant_cohorts_n_per_ha <-
  plot_cohort_counts$plant_cohorts_n / subplot_area_ha

# 3. Regional mean distribution across all 27 subplots
og_mean_distribution <- aggregate(
  x = list(plant_cohorts_n_per_ha = rep(1, nrow(d))),
  by = list(
    plant_cohorts_pft = d$pft_name_h_max_taxa,
    plant_cohorts_dbh = d$plant_cohorts_dbh
  ),
  FUN = function(x) sum(x) / total_sampled_ha
)

# Quick diagnostics
cat("Rows in plot_cohort_counts:", nrow(plot_cohort_counts), "\n")
cat("Unique subplot points:", n_total_plots, "\n")
cat("Unique PFTs:", length(unique(plot_cohort_counts$plant_cohorts_pft)), "\n")
cat(
  "Unique DBH classes:",
  length(unique(plot_cohort_counts$plant_cohorts_dbh)),
  "\n"
)
cat(
  "Total Old Growth Stem Density (per ha):",
  sum(og_mean_distribution$plant_cohorts_n_per_ha),
  "\n"
)

str(plot_cohort_counts)

####################

# Step 5: Write the files in ve_data_science\data\derived\plant\input_data\data_library

# Clean and save mean OG cohort distribution

og_mean_distribution <- og_mean_distribution[, c(
  "plant_cohorts_n_per_ha",
  "plant_cohorts_pft",
  "plant_cohorts_dbh"
)]

colnames(og_mean_distribution) <- c(
  "plant_cohorts_n_per_ha",
  "plant_cohorts_pft",
  "plant_cohorts_dbh"
)

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  og_mean_distribution,
  "../../../../data/derived/plant/input_data/data_library/pft_cohort_data_maliau_mean_per_ha.csv",
  row.names = FALSE
)

# Clean and save plot_cohort_counts

colnames(plot_cohort_counts) <- c(
  "plot_id",
  "block",
  "plot",
  "lon_wgs84",
  "lat_wgs84",
  "x_utm32650",
  "y_utm32650",
  "plant_cohorts_pft",
  "plant_cohorts_dbh",
  "plant_cohorts_n",
  "plant_cohorts_n_per_ha"
)

dir.create(
  "../../../../data/derived/plant/input_data/data_library",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  plot_cohort_counts,
  "../../../../data/derived/plant/input_data/data_library/pft_cohort_data_maliau.csv",
  row.names = FALSE
)
