#| ---
#| title: Combine estimates of litter stocks
#|
#| description: |
#|    This R script combines the aboveground, belowground and wood litter stocks
#|    estimated from three separate analyses. More information can be found in
#|    the metadata of each analysis source scripts.
#|
#| virtual_ecosystem_module:
#|   - Litter
#|
#| author:
#|   - Hao Ran Lai
#|
#| status: final
#|
#| input_files:
#|
#| output_files:
#|   - name: litter_stock.csv
#|     path: data/derived/litter/stock
#|     description: |
#|       Combined litter stock from three separate analyses
#|
#| source_files:
#|   - name: model_aboveground_C.R
#|     path: analysis/litter/stock/
#|     description: Code to estimate aboveground litter stocks
#|   - name: model_belowground_C.R
#|     path: analysis/litter/stock/
#|     description: Code to estimate belowground litter stocks
#|   - name: model_deadwood_C.R
#|     path: analysis/litter/stock/
#|     description: Code to estimate deadwood litter stocks
#|
#| package_dependencies:
#|     - tidyverse
#|     - readxl
#|     - glmmTMB
#|
#| usage_notes:
#| ---

# source the codes that estimate aboveground, belowground and wood litter stocks
source("analysis/litter/stock/model_aboveground_C.R")
source("analysis/litter/stock/model_belowground_C.R")
source("analysis/litter/stock/model_deadwood_C.R")

# combine stocks to a single dataframe
litter_stocks <-
  # aboveground stock with some housekeeping
  aboveground_stock |>
  select(Logging_grp, pool_raw = type, stock) |>
  mutate(
    pool_raw = recode_values(
      pool_raw,
      "metabolic" ~ "aboveground metabolic",
      "structural" ~ "aboveground structural",
      "wood" ~ "twig and branch"
    )
  ) |>
  # deadwood stock
  bind_rows(
    total_deadwood_stock |> mutate(pool_raw = "deadwood")
  ) |>
  # belowground stock
  bind_rows(belowground_stock) |>
  # aggregate to VE litter pools
  mutate(
    pool = replace_values(
      pool_raw,
      "twig and branch" ~ "wood",
      "deadwood" ~ "wood"
    )
  ) |>
  group_by(Logging_grp, pool) |>
  summarise(stock = sum(stock)) |>
  # add a column of methodology
  mutate(
    method = case_when(
      str_detect(pool, "belowground") ~ "equilibrium",
      .default = "field"
    )
  )

# save output
write_csv(
  litter_stocks,
  "data/derived/litter/stock/litter_stock.csv"
)
