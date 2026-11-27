#!/usr/bin/env bash
scenario_dir=data/scenarios/maliau/maliau_2
uv run --group dev ve_run \
	"$scenario_dir/config/main/data_config.toml" \
	"$scenario_dir/config/main/litter_config.toml" \
	"$scenario_dir/config/main/soil_config.toml" \
	"$scenario_dir/config/abiotic_simple_config.toml" \
	"$scenario_dir/config/animal_config.toml" \
	"$scenario_dir/config/plant_config.toml" \
	"$scenario_dir/config/hydrology_config.toml" \
	-o "$scenario_dir/out" \
	--logfile "$scenario_dir/out/logfile.log"
