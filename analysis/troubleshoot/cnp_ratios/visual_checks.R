#| ---
#| title: Visual checks for soil and litter C:N and C:P ratios
#|
#| description: |
#|   Loads soil and litter NetCDF pool data for a Maliau scenario and creates
#|   faceted histograms of per-row C:N and C:P ratios for selected pool
#|   variables.
#|
#|   This script is intended as a troubleshooting/diagnostic visual check for
#|   CNP pool values across soil and litter data products.
#|
#| virtual_ecosystem_module: [Soil, Litter]
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|   - name: soil_maliau.nc
#|     path: data/scenarios/maliau/maliau_2/data/soil_maliau.nc
#|     description: |
#|       Soil pool NetCDF data used to extract C, N, and P values for selected
#|       soil CNP pool variables.
#|   - name: litter_maliau.nc
#|     path: data/scenarios/maliau/maliau_2/data/litter_maliau.nc
#|     description: |
#|       Litter pool NetCDF data used to extract C, N, and P values for selected
#|       litter CNP pool variables.
#|
#| output_files:
#|   - name: CN_ratio.png
#|     path: analysis/troubleshoot/cnp_ratios/CN_ratio.png
#|     description: |
#|       Faceted histograms of C:N ratios for selected soil and litter pool
#|       variables.
#|   - name: CP_ratio.png
#|     path: analysis/troubleshoot/cnp_ratios/CP_ratio.png
#|     description: |
#|       Faceted histograms of C:P ratios for selected soil and litter pool
#|       variables.
#|
#| source_files:
#|   - name: get_data_variables
#|     path: tools/R/get_data_variables.r
#|     description: |
#|       Shared data variable helper module imported with box::use().
#|
#| package_dependencies:
#|   - tidyverse
#|   - tidync
#|   - box
#|
#| usage_notes: |
#|   Run from the repository root so relative paths to data and output files
#|   resolve correctly. Confirm the expected NetCDF input files exist before
#|   running.
#| ---

library(tidyverse)
library(tidync)

# Open NetCDF sources for soil and litter pools
soil <- tidync("data/scenarios/maliau/maliau_2/data/soil_maliau.nc")
litter <- tidync("data/scenarios/maliau/maliau_2/data/litter_maliau.nc")

# Variables to inspect across both sources
vars <- c(
  "soil_cnp_pool_lmwc",
  "soil_cnp_pool_maom",
  "soil_cnp_pool_necromass",
  "soil_cnp_pool_pom",
  "litter_pool_above_metabolic_cnp",
  "litter_pool_above_structural_cnp",
  "litter_pool_below_metabolic_cnp",
  "litter_pool_below_structural_cnp",
  "litter_pool_woody_cnp"
)

# Extract one pool and reshape element values into C, N, and P columns
extract_cnp <- function(data, pool_var) {
  data |>
    activate(pool_var) |>
    hyper_tibble() |>
    pivot_wider(names_from = element, values_from = all_of(pool_var)) |>
    mutate(variable = pool_var)
}

# Build one long table and compute C:N and C:P ratios per row
cnp <-
  bind_rows(
    vars[str_detect(vars, "soil")] |>
      map(\(var) extract_cnp(soil, pool_var = var)) |>
      list_rbind() |>
      mutate(CN = C / N, CP = C / P),
    vars[str_detect(vars, "litter")] |>
      map(\(var) extract_cnp(litter, pool_var = var)) |>
      list_rbind() |>
      mutate(CN = C / N, CP = C / P)
  )

# Save faceted histograms for C:N ratios
png(
  "analysis/troubleshoot/cnp_ratios/CN_ratio.png",
  width = 6,
  height = 6,
  units = "in",
  res = 300
)
ggplot(cnp) +
  facet_wrap(~variable, scales = "free") +
  geom_histogram(aes(CN)) +
  labs(x = "C:N ratio") +
  theme_bw()
dev.off()

# Save faceted histograms for C:P ratios
png(
  "analysis/troubleshoot/cnp_ratios/CP_ratio.png",
  width = 6,
  height = 6,
  units = "in",
  res = 300
)
ggplot(cnp) +
  facet_wrap(~variable, scales = "free") +
  geom_histogram(aes(CP)) +
  labs(x = "C:P ratio") +
  theme_bw()
dev.off()
