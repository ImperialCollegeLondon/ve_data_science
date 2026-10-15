library(tidyverse)
library(readxl)


nottingham <- read_excel(
  "data/primary/soil/nottingham_2021/BALI_Nottingham_Girdling_Data_2021_rev.xlsx",
  sheet = 4,
  skip = 5
)

# Phase 1 (pre-girdle) daily CO2 efflux per subplot by calendar date, so it can
# be matched to dates in the model. Only days with all 24 hourly values are
# kept; the partial first/last day of each measurement block is dropped. I'm using Phase 1 pre-girdle as a "control" that more
# resembles undisturbed forest, though not as mature as Maliau. I am using
# plot-level aggregation although there were subplot measurement, because plot
# matches the VE scale more closely.

# Mean vs median: CO2 is right-skewed, but the mean is used at both stages
# (collars -> hour, hours -> day) because a daily flux is a time integral and
# only the mean conserves the total; a median would underestimate it.
# Median may still be useful, but I'll postpone this for later. Skew may
# reflect real hotspots/pulses, not only chamber artifacts. Caveat: with ~4
# collars per subplot-hour, a single bad reading can shift the hourly mean.

CO2_daily_control <-
  nottingham |>
  filter(phase == "Phase 1") |>
  # calculate plot-hour mean across collars
  group_by(PlotName, plot, date, time) |>
  summarise(CO2 = mean(CO2), .groups = "drop") |>
  # calculate plot mean across hours
  group_by(PlotName, plot, date) |>
  summarise(n_hours = n(), CO2_daily = mean(CO2), .groups = "drop") |>
  # drop incomplete days (start/end of each measurement block)
  filter(n_hours == 24)

# output data
write_csv(
  CO2_daily_control,
  "data/derived/soil/validation/datasets/nottingham_2021/data.csv"
)
