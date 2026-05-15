library(tidyverse)
library(sensobol)
library(tidync)
library(arrow)
source("tools/R/sobol_indices2.R")

sobol_mat <- read_rds(
  "data/scenarios/sensitivity_soil_litter/data/sobol_matrix.rds"
)
pars <- colnames(sobol_mat)
n_samples <- nrow(sobol_mat) / (length(pars) + 2)

merged <-
  open_dataset(
    "data/scenarios/sensitivity_soil_litter/out/all_continuous_data_merged.parquet"
  ) |>
  filter(time_index == 131) %>%
  collect()

Y_vars <- unique(merged$variable) |> setdiff(c("timestamp"))

sens <- map(
  Y_vars,
  \(Y_var) {
    Y <-
      merged |>
      filter(variable == Y_var) |>
      mutate(scenario = as.numeric(scenario)) |>
      right_join(
        data.frame(scenario = seq_len(nrow(sobol_mat))),
        by = join_by(scenario)
      ) |>
      arrange(scenario) |>
      pull(value)
    sobol_indices2(Y = Y, N = n_samples, params = pars) |>
      pluck("results") |>
      as.data.frame() |>
      mutate(Y_var = Y_var)
  },
  .progress = TRUE
) |>
  list_rbind()


sens |>
  filter(sensitivity == "Ti", !is.na(original)) |>
  # "normalise" sobol indices for comparative visualisation
  group_by(Y_var) |>
  mutate(original_s = original / sd(original)) |>
  ggplot() +
  geom_raster(aes(y = parameters, x = Y_var, fill = original)) +
  scale_fill_viridis_c(option = "cividis", transform = "sqrt") +
  coord_fixed() +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))
