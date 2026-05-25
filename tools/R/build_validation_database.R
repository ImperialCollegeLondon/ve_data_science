library(yaml)
library(tidyverse)


# load config ──────────────────────────────────────────────────────────────
logdir <- "data/derived/soil/validation/config/sources"
logfiles <- list.files(logdir, pattern = "\\.yaml$", full.names = TRUE)

configs <-
  logfiles |>
  map(read_yaml) |>
  # filter and keep only configs that has the source_id entry
  keep(~ pluck_exists(.x, "source_id"))

# testing only
cfg <- configs[[1]]


# ingest ────────────────────────────────────────────────────────────────────
raw <-
  read_csv(
    cfg$data_file,
    show_col_types = FALSE,
    skip = cfg$skip_rows
  ) |>
  select(all_of(c(cfg$dedup_key, names(cfg$variables)))) |>
  pivot_longer(cols = names(cfg$variables), names_to = "var_original") |>
  filter(!is.na(value)) |>
  left_join(
    cfg$variables |>
      enframe(name = "var_original") |>
      unnest_wider(value),
    by = join_by(var_original)
  )


# load unit conversions ─────────────────────────────────────────────────────
unit_conversions <-
  read_csv(
    "data/derived/soil/validation/config/unit_conversions.csv"
  ) |>
  mutate(
    convert_unit = map(
      `function`,
      ~ rlang::as_function(as.formula(paste("~", gsub("x", ".x", .x))))
    )
  )

units <-
  read_yaml("data/derived/soil/validation/config/units_canonical.yaml") |>
  enframe(name = "var_canonical") |>
  unnest_wider(value) |>
  select(var_canonical, unit_to = unit)

foo <- raw |>
  rename(unit_from = unit) |>
  left_join(units, by = join_by(var_canonical)) |>
  # fallback to NA is left_join resulted in zero match
  mutate(unit_to = coalesce(unit_to, NA)) |>
  mutate(
    unit_to = ifelse(
      is.na(unit_to) & !is.na(transform),
      unit_transform,
      unit_to
    )
  ) |>
  # join conversion function
  left_join(unit_conversions, by = join_by(unit_from, unit_to)) |>
  mutate(value_canonical = map2(value, convert_unit, ~ .y(.x)))


# write derived ─────────────────────────────────────────────────────────────
out_path <- glue(
  log_cfg$path |>
    {
      \(.) yaml::read_yaml("config/pipeline.yaml")$derived$path_pattern
    }(),
  source_id = cfg$source_id
)

write_csv(df, out_path)
