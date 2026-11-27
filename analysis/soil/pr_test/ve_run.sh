#!/usr/bin/env bash
# Run from the repository root after downloading the staged Globus bundle.
set -euo pipefail

scenario_dir=data/scenarios/maliau/maliau_2
config_dir="$scenario_dir/config"
out_dir="$scenario_dir/out/pr1958"

# Replace filenames with the staged individual configs; do not add combined TOML.
config_files=(
  "$config_dir/data_config.toml"
  "$config_dir/abiotic_simple_config.toml"
  "$config_dir/hydrology_config.toml"
  "$config_dir/pr1958/animal_config.toml"
  "$config_dir/plant_config.toml"
  "$config_dir/pr1958/soil_config.toml"
  "$config_dir/litter_config.toml"
)

for config_file in "${config_files[@]}"; do
  if [[ ! -f "$config_file" ]]; then
    printf 'Missing staged config: %s\n' "$config_file" >&2
    exit 1
  fi
done

if [[ -e "$out_dir" ]]; then
  printf 'Output already exists; choose a fresh out_dir: %s\n' "$out_dir" >&2
  exit 1
fi

mkdir -p "$out_dir"
uv run --group dev-pinned ve_run \
  "${config_files[@]}" \
  -o "$out_dir" \
  --logfile "$out_dir/logfile.log"
