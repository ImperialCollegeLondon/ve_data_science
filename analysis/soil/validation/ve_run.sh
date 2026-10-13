#!/usr/bin/env bash
scenario_dir=data/scenarios/maliau/maliau_2
uv run --group dev ve_run \
	"$scenario_dir/config/config.toml" \
	-o "$scenario_dir/out" \
	--logfile "$scenario_dir/out/logfile.log"