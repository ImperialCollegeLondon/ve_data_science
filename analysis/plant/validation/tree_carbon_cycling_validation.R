#| ---
#| title: Tree carbon cycling validation
#|
#| description: |
#|     This script focuses on validating the tree carbon cycling outputs
#|     (standing carbon mass, respiration, litter production and other
#|     related carbon pools/sinks) from the VE simulation for the Maliau scenario.
#|
#| virtual_ecosystem_module:
#|   - Plants
#|
#| author:
#|   - Arne Scheire
#|
#| status: wip
#|
#|
#| input_files:
#|   - name: plants_cohort_data.csv
#|     path: data/scenarios/maliau/maliau_1\out
#|     description: |
#|       Plant cohort data obtained from VE simulation.
#|   - name: all_continuous_data.nc
#|     path: data/scenarios/maliau/maliau_1\out
#|     description: |
#|       All continuous data obtained from VE simulation.
#|   - name: SAFE_CarbonBalanceComponents.xlsx
#|     path: data/primary/plant/carbon_balance_components
#|     description: |
#|       https://doi.org/10.5281/zenodo.7307449
#|       Measured components of total carbon budget at the SAFE project.
#|       Values with standard errors for each 1-ha carbon plots for 11 plots
#|       investigated across a logging gradient from unlogged old-growth to
#|       heavily logged.
#|
#| output_files:
#|   - name: xx
#|     path: xx
#|     description: |
#|       xx
#|
#| package_dependencies:
#|     - readxl
#|     - dplyr
#|     - ggplot2
#|
#| usage_notes: |
#|   This script can be used for different simulations, just need to change the
#|   name/path of the plants_cohort_data.csv file - and also change the number
#|   of rows in plants_cohort_data that are seen as setup rows.
#| ---


# Load packages ----------------------------------------------------------------

library(readxl)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(reshape2)
library(lubridate)

# Load data --------------------------------------------------------------------

# Load all continuous NetCDF data
all_continuous_data <-
  nc_open("../../../data/scenarios/maliau/maliau_1/out/all_continuous_data.nc")

# Look at dims
names(all_continuous_data$dim)

time_index <- ncvar_get(all_continuous_data, "time_index")
cell_id <- ncvar_get(all_continuous_data, "cell_id")
element <- ncvar_get(all_continuous_data, "element")
pft <- ncvar_get(all_continuous_data, "pft")
layers <- ncvar_get(all_continuous_data, "layers")

groundwater_layers <- all_continuous_data$dim$groundwater_layers$vals
# string9 <- all_continuous_data$dim$string9$vals # nolint

# Look at vars
names(all_continuous_data$var)

# Define layer_color for plotting later on
cell_color <- hcl.colors(length(cell_id), palette = "Zissou 1")
cell_color <- setNames(cell_color, as.character(cell_id))

element_color <- hcl.colors(length(element), palette = "Zissou 1")
element_color <- setNames(element_color, as.character(element))

pft_color <- hcl.colors(length(pft), palette = "Zissou 1")
pft_color <- setNames(pft_color, as.character(pft))

layer_color <- hcl.colors(length(layers), palette = "Zissou 1")
layer_color <- setNames(layer_color, as.character(layers))

groundwater_layer_color <-
  hcl.colors(length(groundwater_layers), palette = "Zissou 1")
groundwater_layer_color <-
  setNames(groundwater_layer_color, as.character(groundwater_layers))

#####

# Load SAFE carbon balance components dataset and clean up a bit

safe_carbon <- read_excel(
  "../../../data/primary/plant/carbon_balance_components/SAFE_CarbonBalanceComponents.xlsx", # nolint
  sheet = "Data",
  col_names = FALSE
)

max(nrow(safe_carbon))
colnames(safe_carbon) <- safe_carbon[6, ]
safe_carbon <- safe_carbon[7:17, ]
names(safe_carbon)

safe_carbon[, 6:65] <- lapply(safe_carbon[, 6:65], as.numeric)

#####

# Load plants cohort data
# Note that the name/path need to be updated depending on which simulation is used
# For units see Post init allometry attributes in pyrealm/demography/tmodel.py
# Basically almost all mass units are in g C (not kg)

plants_cohort_data <- read.csv( # nolint
  "../../../data/scenarios/maliau/maliau_1/out/plants_cohort_data.csv", # nolint
  header = TRUE
)

names(plants_cohort_data)
plants_cohort_data <-
  plants_cohort_data[, c(
    "cell_id", "time", "time_index", "cohort_id", "n_individuals", "pft_names",
    "dbh", "stem_height", "crown_area", "crown_fraction",
    "stem_mass", "sapwood_mass", "foliage_mass", "reproductive_tissue_mass",
    "delta_dbh", "delta_stem_mass", "delta_foliage_mass",
    "whole_crown_gpp", "sapwood_respiration", "foliar_respiration",
    "fine_root_respiration", "reproductive_tissue_respiration",
    "npp",
    "foliage_turnover", "fine_root_turnover", "reproductive_tissue_turnover"
  )]

# Subset to desired number of cells (substantially speeds up processing)
# The code works for all cells but this takes very long to run

plants_cohort_data <- plants_cohort_data[plants_cohort_data$cell_id %in% c(0:10), ]

# check how many unique cohorts in the simulation

cohort_id <- unique(plants_cohort_data$cohort_id)
length(cohort_id)

plants_cohort_data$setup <- "no"

# Here need to manually check how many setup rows there are
# Basically check within time_index = 0 where cell_id resets to 0
# For all cell_id's the setup rows are 85000, which is 2500 cells * 34 unique
# cohorts per cell (e.g., cell_id = 0)
# However, this takes very long to run, so for now just use cell_id 0:10 example
# plants_cohort_data$setup[1:85000] <- "yes" # nolint

plants_cohort_data$setup[1:374] <- "yes"

# Exclude the setup rows for now until the issue with duplicated time_index = 0
# is solved
# This means that when changes during each timestep are calculated this will not
# be done for the first timestep (because it ignores the initial setup values;
# which represent the values at the start of the first timestep)
plants_cohort_data <- plants_cohort_data[plants_cohort_data$setup == "no", ]

### Standing tissue carbon mass per tree per cohort ----------------------------

# Calculate total aboveground carbon mass per tree (so summed across tissues)
# Note that we only focus on aboveground here as root carbon mass is not available
plants_cohort_data$tree_mass <-
  plants_cohort_data$stem_mass +
  plants_cohort_data$foliage_mass +
  plants_cohort_data$reproductive_tissue_mass

# Stem mass -----

# Observations:
# - stem mass = 84% of tree aboveground carbon mass on average
# - highest contribution for overstory > emergent > pioneer > understory
# - new recruits have much lower contribution
# - large trees (dbh >10cm) follow validation nicely
# - small trees (dbh <10cm) have slightly lower contribution compared to validation
# - VE total stem mass is lower than predictions from allometric equations

boxplot(plants_cohort_data$stem_mass / plants_cohort_data$tree_mass ~ plants_cohort_data$pft_names) # nolint
unique(plants_cohort_data$cohort_id[
  (plants_cohort_data$stem_mass / plants_cohort_data$tree_mass) < 0.3
])

mean(plants_cohort_data$stem_mass[plants_cohort_data$pft_names == "emergent"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "emergent"]) # nolint
mean(plants_cohort_data$stem_mass[plants_cohort_data$pft_names == "overstory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "overstory"]) # nolint
mean(plants_cohort_data$stem_mass[plants_cohort_data$pft_names == "understory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "understory"]) # nolint
mean(plants_cohort_data$stem_mass[plants_cohort_data$pft_names == "pioneer"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "pioneer"]) # nolint

mean(plants_cohort_data$stem_mass / plants_cohort_data$tree_mass)

mean(plants_cohort_data$stem_mass[plants_cohort_data$dbh > (10 / 100)] /
  plants_cohort_data$tree_mass[plants_cohort_data$dbh > (10 / 100)]) # nolint
mean(plants_cohort_data$stem_mass[plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)] / # nolint
  plants_cohort_data$tree_mass[plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)]) # nolint

# Compare to stem / (TAGB minus Branch) from Kenzo et al., 2015 (Balai Ringin site)
193.3 / (227.7 - 28.8) # For trees >10 cm dbh
11.5 / (14.9 - 1.7) # For trees 1 < dbh < 10 cm

# Also compare to predicted stem biomass using equation from Kenzo et al., 2015
# and using average tissue carbon content (50%)

test <- plants_cohort_data
test$stem_mass_predicted <-
  0.0822 * ((test$dbh * 100)^2.48) / 2 # convert dbh from m to cm

plot(test$stem_mass_predicted[test$stem_mass < 500] ~ test$stem_mass[test$stem_mass < 500], # nolint
  col = as.factor(test$pft_names[test$stem_mass < 500])
)
plot(test$stem_mass_predicted ~ test$stem_mass, col = as.factor(test$pft_names))
abline(a = 0, b = 1)

# Foliage mass -----

# Observations:
# - foliage mass = 15% of tree aboveground carbon mass on average
# - highest contribution for understory > pioneer > emergent > overstory
# - new recruits have much higher contribution
# - large trees (dbh >10cm) follow validation nicely
# - small trees (dbh <10cm) have slightly higher contribution compared to validation
# - VE total foliage mass is lower than predictions from allometric equations

boxplot(plants_cohort_data$foliage_mass / plants_cohort_data$tree_mass ~ plants_cohort_data$pft_names) # nolint
unique(plants_cohort_data$cohort_id[
  (plants_cohort_data$foliage_mass / plants_cohort_data$tree_mass) > 0.6
])

mean(plants_cohort_data$foliage_mass[plants_cohort_data$pft_names == "emergent"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "emergent"]) # nolint
mean(plants_cohort_data$foliage_mass[plants_cohort_data$pft_names == "overstory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "overstory"]) # nolint
mean(plants_cohort_data$foliage_mass[plants_cohort_data$pft_names == "understory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "understory"]) # nolint
mean(plants_cohort_data$foliage_mass[plants_cohort_data$pft_names == "pioneer"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "pioneer"]) # nolint

mean(plants_cohort_data$foliage_mass / plants_cohort_data$tree_mass)

mean(plants_cohort_data$foliage_mass[plants_cohort_data$dbh > (10 / 100)] /
  plants_cohort_data$tree_mass[plants_cohort_data$dbh > (10 / 100)]) # nolint
mean(plants_cohort_data$foliage_mass[
  plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
  ])

# Compare to foliage / (TAGB minus Branch) from Kenzo et al., 2015 (Balai Ringin site)
5.5 / (227.7 - 28.8) # For trees >10 cm dbh
1.6 / (14.9 - 1.7) # For trees 1 < dbh < 10 cm

# Also compare to predicted leaf biomass using equation from Kenzo et al., 2015
# and using average tissue carbon content (50%)

test <- plants_cohort_data
test$foliage_mass_predicted <-
  0.0442 * ((test$dbh * 100)^1.67) / 2 # convert dbh from m to cm

plot(test$foliage_mass_predicted[test$foliage_mass < 15] ~ test$foliage_mass[test$foliage_mass < 15], # nolint
  col = as.factor(test$pft_names[test$foliage_mass < 15])
)
plot(test$foliage_mass_predicted ~ test$foliage_mass, col = as.factor(test$pft_names))
abline(a = 0, b = 1)

# Sapwood mass -----
boxplot(plants_cohort_data$sapwood_mass / plants_cohort_data$tree_mass ~ plants_cohort_data$pft_names) # nolint
unique(plants_cohort_data$cohort_id[
  (plants_cohort_data$sapwood_mass / plants_cohort_data$tree_mass) < 0.3
])

mean(plants_cohort_data$sapwood_mass[plants_cohort_data$pft_names == "emergent"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "emergent"]) # nolint
mean(plants_cohort_data$sapwood_mass[plants_cohort_data$pft_names == "overstory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "overstory"]) # nolint
mean(plants_cohort_data$sapwood_mass[plants_cohort_data$pft_names == "understory"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "understory"]) # nolint
mean(plants_cohort_data$sapwood_mass[plants_cohort_data$pft_names == "pioneer"] /
  plants_cohort_data$tree_mass[plants_cohort_data$pft_names == "pioneer"]) # nolint

mean(plants_cohort_data$sapwood_mass / plants_cohort_data$tree_mass)

mean(plants_cohort_data$sapwood_mass[
  plants_cohort_data$dbh > (10 / 100)
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$dbh > (10 / 100)
  ])
mean(plants_cohort_data$sapwood_mass[
  plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
  ])

# To do: compare to existing studies

# Reproductive tissue mass -----
boxplot(plants_cohort_data$reproductive_tissue_mass /
  plants_cohort_data$tree_mass ~ plants_cohort_data$pft_names) # nolint
unique(plants_cohort_data$cohort_id[
  (plants_cohort_data$reproductive_tissue_mass /
    plants_cohort_data$tree_mass) > 0.05 # nolint
])

mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$pft_names == "emergent"
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$pft_names == "emergent"
  ])
mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$pft_names == "overstory"
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$pft_names == "overstory"
  ])
mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$pft_names == "understory"
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$pft_names == "understory"
  ])
mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$pft_names == "pioneer"
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$pft_names == "pioneer"
  ])

mean(plants_cohort_data$reproductive_tissue_mass / plants_cohort_data$tree_mass)

mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$dbh > (10 / 100)
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$dbh > (10 / 100)
  ])
mean(plants_cohort_data$reproductive_tissue_mass[
  plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
] /
  plants_cohort_data$tree_mass[
    plants_cohort_data$dbh > (1 / 100) & plants_cohort_data$dbh < (10 / 100)
  ])

# To do: compare to existing studies

# Note that reproductive tissues / foliage mass does nicely track the input data
# proportion used (0.073545706)
mean(plants_cohort_data$reproductive_tissue_mass / plants_cohort_data$foliage_mass)

### Total standing carbon mass at cell level -----------------------------------

# Now multiply tree_mass by n_individuals and sum across cohorts at PFT level and
# total cell level

# PFT level -----

# Observations:
# - PFT carbon storage greatest for emergent > overstory > pioneer > understory

plants_cohort_data$tree_mass_cohort <-
  plants_cohort_data$tree_mass * plants_cohort_data$n_individuals
plants_cohort_data$stem_mass_cohort <-
  plants_cohort_data$stem_mass * plants_cohort_data$n_individuals
plants_cohort_data$foliage_mass_cohort <-
  plants_cohort_data$foliage_mass * plants_cohort_data$n_individuals
plants_cohort_data$reproductive_tissue_mass_cohort <-
  plants_cohort_data$reproductive_tissue_mass * plants_cohort_data$n_individuals

for (k in unique(plants_cohort_data$cell_id)) {
  for (j in unique(plants_cohort_data$time_index)) {
    for (i in unique(plants_cohort_data$pft_names)) {
      plants_cohort_data$tree_mass_pft[
        plants_cohort_data$pft_names == i &
          plants_cohort_data$time_index == j &
          plants_cohort_data$cell_id == k
      ] <-
        sum(plants_cohort_data$tree_mass_cohort[
          plants_cohort_data$pft_names == i &
            plants_cohort_data$time_index == j &
            plants_cohort_data$cell_id == k
        ])
      plants_cohort_data$stem_mass_pft[
        plants_cohort_data$pft_names == i &
          plants_cohort_data$time_index == j &
          plants_cohort_data$cell_id == k
      ] <-
        sum(plants_cohort_data$stem_mass_cohort[
          plants_cohort_data$pft_names == i &
            plants_cohort_data$time_index == j &
            plants_cohort_data$cell_id == k
        ])
      plants_cohort_data$foliage_mass_pft[
        plants_cohort_data$pft_names == i &
          plants_cohort_data$time_index == j &
          plants_cohort_data$cell_id == k
      ] <-
        sum(plants_cohort_data$foliage_mass_cohort[
          plants_cohort_data$pft_names == i &
            plants_cohort_data$time_index == j &
            plants_cohort_data$cell_id == k
        ])
      plants_cohort_data$reproductive_tissue_mass_pft[
        plants_cohort_data$pft_names == i &
          plants_cohort_data$time_index == j &
          plants_cohort_data$cell_id == k
      ] <-
        sum(plants_cohort_data$reproductive_tissue_mass_cohort[
          plants_cohort_data$pft_names == i &
            plants_cohort_data$time_index == j &
            plants_cohort_data$cell_id == k
        ])
    }
  }
}

plot(plants_cohort_data$tree_mass_pft ~ plants_cohort_data$time_index,
  col = as.factor(plants_cohort_data$pft_names), pch = 16
)
legend("topright",
  legend = levels(as.factor(plants_cohort_data$pft_names)),
  col = 1:length(unique(plants_cohort_data$pft_names)), # nolint
  pch = 16
)

# Note: ranking of carbon across PFTs makes sense

# Cell level -----

# Observations:
# - total tree mass declines over time
# - total tree mass for large trees matches validation
# - total tree mass for small trees is much lower for VE than for validation (this
#   is because the VE cohort distribution does not include trees <10cm dbh)
# - this is also the case for stem_mass and foliage_mass
# - total tree mass is also lower than AGB for many other validation datasets
# - total tree mass is also less than half the Maliau validation dataset
# - should examine the effect of varying stem density / cohort distribution
# - very interesting to compare the dbh vs dbh + height allometric equation;
#   they give very different results

for (k in unique(plants_cohort_data$cell_id)) {
  for (j in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$tree_mass_cell[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$tree_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
      ])
    plants_cohort_data$stem_mass_cell[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$stem_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
      ])
    plants_cohort_data$foliage_mass_cell[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$foliage_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
      ])
    plants_cohort_data$reproductive_tissue_mass_cell[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$reproductive_tissue_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
      ])
  }
}

plot(plants_cohort_data$tree_mass_cell ~ plants_cohort_data$time_index, pch = 16)

# Calculate for trees >10 cm dbh and for 1 < dbh < 10 cm
for (k in unique(plants_cohort_data$cell_id)) {
  for (j in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$tree_mass_cell_large[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (10 / 100)
    ] <-
      sum(plants_cohort_data$tree_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (10 / 100)
      ])
    plants_cohort_data$tree_mass_cell_small[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (1 / 100) &
        plants_cohort_data$dbh < (10 / 100)
    ] <-
      sum(plants_cohort_data$tree_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (1 / 100) &
          plants_cohort_data$dbh < (10 / 100)
      ])

    plants_cohort_data$stem_mass_cell_large[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (10 / 100)
    ] <-
      sum(plants_cohort_data$stem_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (10 / 100)
      ])
    plants_cohort_data$stem_mass_cell_small[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (1 / 100) &
        plants_cohort_data$dbh < (10 / 100)
    ] <-
      sum(plants_cohort_data$stem_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (1 / 100) &
          plants_cohort_data$dbh < (10 / 100)
      ])

    plants_cohort_data$foliage_mass_cell_large[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (10 / 100)
    ] <-
      sum(plants_cohort_data$foliage_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (10 / 100)
      ])
    plants_cohort_data$foliage_mass_cell_small[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (1 / 100) &
        plants_cohort_data$dbh < (10 / 100)
    ] <-
      sum(plants_cohort_data$foliage_mass_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k &
          plants_cohort_data$dbh > (1 / 100) &
          plants_cohort_data$dbh < (10 / 100)
      ])
  }
}

# Note that this is carbon mass, so actual biomass will be much higher
# Multiply carbon mass by 2 to get biomass (assuming average 50% carbon content)
# Could also use PFT tissue carbon content to correct for this
# Values expressed per cell = per hectare (10000 m2)
mean(unique(plants_cohort_data$tree_mass_cell), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$tree_mass_cell_large), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$tree_mass_cell_small), na.rm = TRUE) * 2

# Compare to TAGB minus Branch from Kenzo et al., 2015 (Balai Ringin)
(227.7 - 28.8) * 1000 # Mg converted to kg
(14.9 - 1.7) * 1000 # Mg converted to kg

mean(unique(plants_cohort_data$stem_mass_cell), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$stem_mass_cell_large), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$stem_mass_cell_small), na.rm = TRUE) * 2

mean(unique(plants_cohort_data$foliage_mass_cell), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$foliage_mass_cell_large), na.rm = TRUE) * 2
mean(unique(plants_cohort_data$foliage_mass_cell_small), na.rm = TRUE) * 2

# Also compare against supplementary table in Slik et al., 2003
# For example, Danum Valley AGB = 315.5 Mg ha-1
# Divide by 1000 to convert kg to Mg, and multiply by 2 to get biomass
# Could also use PFT tissue carbon content to correct for this
mean(unique(plants_cohort_data$tree_mass_cell), na.rm = TRUE) / 1000 * 2

# Also compare this to AbovegroundBiomassCarbonStock from SAFE carbon dataset
mean(unique(plants_cohort_data$tree_mass_cell), na.rm = TRUE) / 1000
safe_carbon$AbovegroundBiomassCarbonStock[
  safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")
]

# Also take into account stem density when comparing, as this may explain why
# VE outputs could show lower carbon mass
# May need to try out different simulations with varying tree density
for (k in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    print(sum(plants_cohort_data$n_individuals[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ]))
    print(sum(plants_cohort_data$n_individuals[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (10 / 100)
    ]))
    print(sum(plants_cohort_data$n_individuals[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k &
        plants_cohort_data$dbh > (1 / 100) &
        plants_cohort_data$dbh < (10 / 100)
    ]))
    print("-")
  }
}

# Note that Kenzo et al., 2015 report average stem density for primary mixed
# dipterocarp forest = 610 +- 45 trees per hectare (average across 5 studies)
# Note that stem density for small trees is much lower compared to the value
# reported in Kenzo et al., 2015 (5000 trees per hectare)
# This matches the observed low carbon mass for small trees from the VE outputs,
# which actually makes sense because these were not included in the SAFE census,
# which was used to define the initial cohort distribution

# Slik et al., 2010 report average AGB for Borneo's mature mixed dipterocarp
# forests = 457 Mg per hectare for trees with dbh > 10 cm (across 81 studies)

# Also compare with moist forest equation from Chave et al. (2005)
# This equation works from dbh, so apply this to the initial dbh values for setup
# Then compare these predicted AGB values with the ones obtained from the VE
# This way we can eliminate any effect of varying stem density between studies

# Plot using the dbh equation from Table 2
test <- plants_cohort_data
test$stem_mass_predicted <- 0.0822 * ((test$dbh * 100)^2.48) / 2 # convert dbh from m to cm # nolint

plot(
  test$stem_mass_predicted[test$stem_mass < 500] ~ test$stem_mass[
    test$stem_mass < 500
  ],
  col = as.factor(test$pft_names[test$stem_mass < 500])
)
plot(test$stem_mass_predicted ~ test$stem_mass, col = as.factor(test$pft_names))
abline(a = 0, b = 1)

# Plot using the dbh and height equation from Table 2
test <- plants_cohort_data
test$stem_mass_predicted <-
  (0.0567 * ((test$dbh * 100)^2 * test$stem_height)^0.85) / 2 # convert dbh from m to cm

plot(
  test$stem_mass_predicted[test$stem_mass < 500] ~ test$stem_mass[
    test$stem_mass < 500
  ],
  col = as.factor(test$pft_names[test$stem_mass < 500])
)
plot(test$stem_mass_predicted ~ test$stem_mass, col = as.factor(test$pft_names))
abline(a = 0, b = 1)

# Also see old-growth mean biomass in Riutta et al. (2018)

### Gross primary productivity (NPP) at cell level ----------------------

# Calculate GPP at cell level (kg C)

names(plants_cohort_data)

for (k in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$whole_crown_gpp_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[
        plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
      ] *
        plants_cohort_data$whole_crown_gpp[
          plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
        ])
  }
}

# This is the kg C fixed by trees for the entire cell (1 hectare) per month
unique(plants_cohort_data$whole_crown_gpp_cell)
plot(plants_cohort_data$whole_crown_gpp_cell ~ plants_cohort_data$time_index)

# Convert units to Mg C ha-1 year-1
unique(plants_cohort_data$whole_crown_gpp_cell) * 12 / 1000
mean(plants_cohort_data$whole_crown_gpp_cell) * 12 / 1000

# Compare this to values in SAFE carbon balance components and Riutta et al. (2018)
# We can see that VE GPP is much much smaller than expected
safe_carbon$GPP_WithMycorrhiza[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")]

### So why is GPP so low? Check if too much carbon is given to
# plant_symbiote_carbon_supply or root_carbohydrate_exudation

# plant_symbiote_carbon_supply
plant_symbiote_carbon_supply <-
  ncvar_get(all_continuous_data, "plant_symbiote_carbon_supply")
sapply(all_continuous_data$var[["plant_symbiote_carbon_supply"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(plant_symbiote_carbon_supply) <- list(
  cell_id = cell_id,
  time_index = time_index
)

plant_symbiote_carbon_supply[1, ]

# Convert to long format
plant_symbiote_carbon_supply_long <- # nolint
  melt(plant_symbiote_carbon_supply, value.name = "plant_symbiote_carbon_supply")

# Subset to cell_id = 0:10 only
plant_symbiote_carbon_supply_long <- # nolint
  plant_symbiote_carbon_supply_long[
    plant_symbiote_carbon_supply_long$cell_id %in% c(0:10),
  ]

# Note that the unit of plant_symbiote_carbon_supply is kg C m-2 day-1
# So need to multiply this by cell area and timestep duration
as.Date(unique(plants_cohort_data$time)[2]) -
  as.Date(unique(plants_cohort_data$time)[1])

plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply <- # nolint
  plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply * 10000 * 30

# Plot
plot(plant_symbiote_carbon_supply ~ time_index,
  data = plant_symbiote_carbon_supply_long,
  type = "n",
  main = "plant_symbiote_carbon_supply",
  xlab = "Time index (month)",
  ylab = "plant_symbiote_carbon_supply (kg)"
)
points(plant_symbiote_carbon_supply_long$time_index,
  plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply,
  pch = 16
)

# Calculate mean fraction of GPP that was donated
# Note this is not per cell, just a quick check using mean
for (i in 0:(length(time_index) - 1)) {
  print(format(mean(plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply[
    plant_symbiote_carbon_supply_long$time_index == i
  ]) / mean(plants_cohort_data$whole_crown_gpp_cell[
    plants_cohort_data$time_index == i
  ]), scientific = FALSE))
}

# plant_symbiote_carbon_supply doesn't look like a major carbon sink
# This fraction is expected to be much higher

# Compare this with expected value reported in Riutta et al. (2018)
# L.K. Kho, Y. Malhi, & S. Tan, (unpublished analysis) estimate an allocation to
# mycorrhizae of 1.3–1.4 Mg C ha-1 year-1.
# Note this is not per cell, just a quick check using mean
mean(plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply) * 12 / 1000

###

# root_carbohydrate_exudation
root_carbohydrate_exudation <-
  ncvar_get(all_continuous_data, "root_carbohydrate_exudation")
sapply(all_continuous_data$var[["root_carbohydrate_exudation"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(root_carbohydrate_exudation) <- list(
  cell_id = cell_id,
  time_index = time_index
)

root_carbohydrate_exudation[1, ]

# Convert to long format
root_carbohydrate_exudation_long <- # nolint
  melt(root_carbohydrate_exudation, value.name = "root_carbohydrate_exudation")

# Subset to cell_id = 0:10 only
root_carbohydrate_exudation_long <- # nolint
  root_carbohydrate_exudation_long[
    root_carbohydrate_exudation_long$cell_id %in% c(0:10),
  ]

# Note that the unit of root_carbohydrate_exudation is kg C m-2 day-1
# So need to multiply this by cell area and timestep duration
as.Date(unique(plants_cohort_data$time)[2]) -
  as.Date(unique(plants_cohort_data$time)[1])

root_carbohydrate_exudation_long$root_carbohydrate_exudation <- # nolint
  root_carbohydrate_exudation_long$root_carbohydrate_exudation * 10000 * 30

# Plot
plot(root_carbohydrate_exudation ~ time_index,
  data = root_carbohydrate_exudation_long,
  type = "n",
  main = "root_carbohydrate_exudation",
  xlab = "Time index (month)",
  ylab = "root_carbohydrate_exudation (kg)"
)
points(root_carbohydrate_exudation_long$time_index,
  root_carbohydrate_exudation_long$root_carbohydrate_exudation,
  pch = 16
)

# Calculate mean fraction of GPP that was donated
# Note this is not per cell, just a quick check using mean
for (i in 0:(length(time_index) - 1)) {
  print(format(mean(root_carbohydrate_exudation_long$root_carbohydrate_exudation[
    root_carbohydrate_exudation_long$time_index == i
  ]) / mean(plants_cohort_data$whole_crown_gpp_cell[
    plants_cohort_data$time_index == i
  ]), scientific = FALSE))
}

# root_carbohydrate_exudation also doesn't seem to be a major carbon sink
# This fraction is expected to be much higher

# Compare this with expected value reported in Riutta et al. (2018)
# The allocation to root exudates and to mycorrhizae can account for 5%–10% of NPP
# in tropical forests (Doughty et al., 2018).
# So combine both values from VE and compare to NPP from VE (i.e., the fraction)
mean(plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply)
mean(root_carbohydrate_exudation_long$root_carbohydrate_exudation)

plants_cohort_data$npp_cohort <-
  plants_cohort_data$npp * plants_cohort_data$n_individuals

for (k in unique(plants_cohort_data$cell_id)) {
  for (j in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$npp_cell[
      plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$npp_cohort[
        plants_cohort_data$time_index == j & plants_cohort_data$cell_id == k
      ])
  }
}

unique(plants_cohort_data$npp_cell)
mean(unique(plants_cohort_data$npp_cell))

# Note this is not per cell, just a quick check using mean
format((mean(plant_symbiote_carbon_supply_long$plant_symbiote_carbon_supply) +
  mean(root_carbohydrate_exudation_long$root_carbohydrate_exudation)) / # nolint
  mean(unique(plants_cohort_data$npp_cell)), scientific = FALSE) # nolint

### Respiration at cell level --------------------------------------------------

# Verify if a reasonable amount of GPP is used for respiration across tissues
# Start with evaluating this at cell level and narrow down if needed

names(plants_cohort_data)

# Units are kg C

for (k in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$sapwood_respiration_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$sapwood_respiration[
          plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
        ])
    plants_cohort_data$foliar_respiration_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$foliar_respiration[
          plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
        ])
    plants_cohort_data$fine_root_respiration_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$fine_root_respiration[
          plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
        ])
    plants_cohort_data$reproductive_tissue_respiration_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$reproductive_tissue_respiration[
          plants_cohort_data$time_index == i &
            plants_cohort_data$cell_id == k
        ])
  }
}

plants_cohort_data$total_respiration_cell <-
  plants_cohort_data$sapwood_respiration_cell +
  plants_cohort_data$foliar_respiration_cell +
  plants_cohort_data$fine_root_respiration_cell +
  plants_cohort_data$reproductive_tissue_respiration_cell

mean(unique(plants_cohort_data$total_respiration_cell))

# Convert units to Mg C ha-1 year-1
plants_cohort_data$total_respiration_cell * 12 / 1000

mean(unique(plants_cohort_data$total_respiration_cell)) * 12 / 1000

# Can already see that respiration is much much higher than GPP
# Now the question is, is GPP too low or respiration too high
# GPP is too low for sure, but still need to check if respiration is realistic
# so compare to yearly respiration rates per hectare from SAFE carbon dataset

(safe_carbon$R_auto[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")]) -
  (safe_carbon$R_CoarseRoots[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")])

# Respiration is about 50% higher than expected
# Look at components of total respiration to see if it's driven by specific tissues

mean(unique(plants_cohort_data$sapwood_respiration_cell)) * 12 / 1000
mean(unique(plants_cohort_data$foliar_respiration_cell)) * 12 / 1000
mean(unique(plants_cohort_data$fine_root_respiration_cell)) * 12 / 1000
mean(unique(plants_cohort_data$reproductive_tissue_respiration_cell)) * 12 / 1000

# Total respiration is nearly 50% higher than expected
# Sapwood respiration is very high
# Need to check if sapwood mass is being overestimated and if that's what's
# causing the higher than expected respiration

### Litter production at cell level --------------------------------------------

# Verify if a reasonable amount of GPP is used for litter fall across tissues
# Start with evaluating this at cell level and narrow down if needed
# Note that turnover rates (tau) are the same across PFTs

names(plants_cohort_data)

# Units are kg C

for (k in unique(plants_cohort_data$cell_id)) {
  for (i in unique(plants_cohort_data$time_index)) {
    plants_cohort_data$foliage_turnover_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$foliage_turnover[plants_cohort_data$time_index == i & # nolint
          plants_cohort_data$cell_id == k]) # nolint
    plants_cohort_data$fine_root_turnover_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$fine_root_turnover[
          plants_cohort_data$time_index == i &
            plants_cohort_data$cell_id == k
        ])
    plants_cohort_data$reproductive_tissue_turnover_cell[
      plants_cohort_data$time_index == i & plants_cohort_data$cell_id == k
    ] <-
      sum(plants_cohort_data$n_individuals[plants_cohort_data$time_index == i &
        plants_cohort_data$cell_id == k] * # nolint
        plants_cohort_data$reproductive_tissue_turnover[
          plants_cohort_data$time_index == i &
            plants_cohort_data$cell_id == k
        ])
  }
}

plants_cohort_data$total_turnover_cell <-
  plants_cohort_data$foliage_turnover_cell +
  plants_cohort_data$fine_root_turnover_cell +
  plants_cohort_data$reproductive_tissue_turnover

mean(unique(plants_cohort_data$total_turnover_cell))

# Convert units to Mg C ha-1 year-1 and multiply by 2 to get biomass
mean(unique(plants_cohort_data$total_turnover_cell)) * 12 / 1000 * 2

mean(unique(plants_cohort_data$foliage_turnover_cell)) * 12 / 1000 * 2
mean(unique(plants_cohort_data$reproductive_tissue_turnover)) * 12 / 1000 * 2

# Compare this with expected value reported in the SAFE carbon balance dataset
safe_carbon$CanopyNPP_Leaf[
  safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")
]
safe_carbon$CanopyNPP_Reproductive[
  safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")
]

# Check if VE turnover rates match expectations
# tau_f = 0.588235294 so about 170% (1/0.588235294) of standing leaf carbon mass
# becomes leaf litter per year
# Since our timesteps are 1 month, divide this value by 12 (=0.1416667)
mean(plants_cohort_data$foliage_turnover_cell / plants_cohort_data$foliage_mass_cell)
# Matches expectations

# tau_rt = 0.1 so about 1000% (1/0.1) of standing reproductive tissue carbon mass
# becomes reproductive tissue litter per year
# Since our timesteps are 1 month, divide this value by 12 (=0.8333333)
mean(plants_cohort_data$reproductive_tissue_turnover_cell /
  plants_cohort_data$reproductive_tissue_mass_cell) # nolint
# Matches expectations

# tau_r = 1.42 so about 70% (1/1.42) of root carbon mass becomes root litter per year
# Since our timesteps are 1 month, divide this value by 12 (=0.05868545)
# mean(plants_cohort_data$fine_root_turnover_cell/plants_cohort_data$fine_root_mass_cell) # nolint
# Note that we do not have fine root mass as outputs for now
# However, we can access root turnover from all_continuous_data

# Repeat the comparison above but use turnover from all_continuous data
names(all_continuous_data$var)

# stem_turnover_cnp
stem_turnover_cnp <- ncvar_get(all_continuous_data, "stem_turnover_cnp")
sapply(all_continuous_data$var[["stem_turnover_cnp"]]$dim, `[`, c("name", "len"))

# Add dimension names
dimnames(stem_turnover_cnp) <- list(
  element = element,
  cell_id = cell_id,
  time_index = time_index
)

stem_turnover_cnp[1, 1, ]

# Convert to long format
stem_turnover_cnp_long <-
  melt(stem_turnover_cnp, value.name = "stem_turnover_cnp")
stem_turnover_cnp_long <-
  stem_turnover_cnp_long[
    stem_turnover_cnp_long$element == "C" & stem_turnover_cnp_long$cell_id %in% c(0:10),
  ]

# foliage_turnover_cnp
foliage_turnover_cnp <- ncvar_get(all_continuous_data, "foliage_turnover_cnp")
sapply(all_continuous_data$var[["foliage_turnover_cnp"]]$dim, `[`, c("name", "len"))

# Add dimension names
dimnames(foliage_turnover_cnp) <- list(
  element = element,
  cell_id = cell_id,
  time_index = time_index
)

foliage_turnover_cnp[1, 1, ]

# Convert to long format
foliage_turnover_cnp_long <-
  melt(foliage_turnover_cnp, value.name = "foliage_turnover_cnp")
foliage_turnover_cnp_long <-
  foliage_turnover_cnp_long[
    foliage_turnover_cnp_long$element == "C" &
      foliage_turnover_cnp_long$cell_id %in% c(0:10), # nolint
  ]

# root_turnover_cnp
root_turnover_cnp <- ncvar_get(all_continuous_data, "root_turnover_cnp")
sapply(all_continuous_data$var[["root_turnover_cnp"]]$dim, `[`, c("name", "len"))

# Add dimension names
dimnames(root_turnover_cnp) <- list(
  element = element,
  cell_id = cell_id,
  time_index = time_index
)

root_turnover_cnp[1, 1, ]

# Convert to long format
root_turnover_cnp_long <- melt(root_turnover_cnp, value.name = "root_turnover_cnp")
root_turnover_cnp_long <-
  root_turnover_cnp_long[
    root_turnover_cnp_long$element == "C" & root_turnover_cnp_long$cell_id %in% c(0:10),
  ]

# plant_reproductive_tissue_turnover
plant_reproductive_tissue_turnover <- ncvar_get(all_continuous_data, "plant_reproductive_tissue_turnover") # nolint
sapply(all_continuous_data$var[["plant_reproductive_tissue_turnover"]]$dim, `[`, c("name", "len")) # nolint

# Add dimension names
dimnames(plant_reproductive_tissue_turnover) <- list( # nolint
  cell_id = cell_id,
  time_index = time_index
)

plant_reproductive_tissue_turnover[1, ] # nolint

# Convert to long format
plant_reproductive_tissue_turnover_long <- # nolint
  melt(plant_reproductive_tissue_turnover, # nolint
    value.name = "plant_reproductive_tissue_turnover"
  ) # nolint
plant_reproductive_tissue_turnover_long <- # nolint
  plant_reproductive_tissue_turnover_long[ # nolint
    plant_reproductive_tissue_turnover_long$cell_id %in% c(0:10), # nolint
  ]

###

# Now repeat the comparison for turnover to standing tissue carbon mass
# Multiply by 12 to get yearly values and convert kg to Mg
# Comparing tissue mass to tissue turnover gives turnover time
# Also compare against SAFE carbon dataset

# Stem
unique(stem_turnover_cnp_long$stem_turnover_cnp) * 12 / 1000
mean(stem_turnover_cnp_long$stem_turnover_cnp) * 12 / 1000
mean(plants_cohort_data$stem_mass_cell) / (mean(stem_turnover_cnp_long$stem_turnover_cnp) * 12) # nolint

safe_carbon$WoodyNPP_Stem[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")]

# Leaf
unique(foliage_turnover_cnp_long$foliage_turnover_cnp) * 12 / 1000
mean(foliage_turnover_cnp_long$foliage_turnover_cnp) * 12 / 1000
mean(plants_cohort_data$foliage_mass_cell) / (mean(foliage_turnover_cnp_long$foliage_turnover_cnp) * 12) # nolint

safe_carbon$CanopyNPP_Leaf[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")]

# Root
unique(root_turnover_cnp_long$root_turnover_cnp) * 12 / 1000
mean(root_turnover_cnp_long$root_turnover_cnp) * 12 / 1000

safe_carbon$FineRootNPP[safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")]

# No total root mass available as outputs
# Calculate temporary fine root mass through foliage area and zeta
# fine root mass = zeta * foliage area
#                = zeta * foliage mass * sla
plants_cohort_data$fine_root_mass_cell <-
  0.09 * plants_cohort_data$foliage_mass_cell * 24
mean(plants_cohort_data$fine_root_mass_cell)

# Now compare root mass to root turnover, this gives turnover time
mean(plants_cohort_data$fine_root_mass_cell) / (mean(root_turnover_cnp_long$root_turnover_cnp) * 12) # nolint

# Reproductive tissue
unique(plant_reproductive_tissue_turnover_long$plant_reproductive_tissue_turnover) * 12 / 1000 # nolint
mean(plant_reproductive_tissue_turnover_long$plant_reproductive_tissue_turnover) * 12 / 1000 # nolint
mean(plants_cohort_data$reproductive_tissue_mass_cell) /
  (mean(plant_reproductive_tissue_turnover_long$plant_reproductive_tissue_turnover) * 12) # nolint

safe_carbon$CanopyNPP_Reproductive[
  safe_carbon$ForestPlotsCode %in% c("MLA-01", "MLA-02")
]
