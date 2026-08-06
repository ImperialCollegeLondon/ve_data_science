#!/bin/bash
# =============================================================================
# setup.sh
#
# PURPOSE: Set up a Python virtual environment, install the virtual_ecosystem
#          package from a specific GitHub commit, and run an example simulation.
#
# PLATFORM: Written for Windows (run via Git Bash or WSL).
#           - Git Bash ships with Git for Windows: https://gitforwindows.org/
#           - If using WSL (Windows Subsystem for Linux), Mac or Linux, change
#             the venv activation line (see comment below marked [UNIX]).
#
# USAGE: bash analysis/troubleshoot/zarr_test/setup.sh
#        Run this script from the folder where you want everything to live.
# =============================================================================

# cd into analysis/troubleshoot/zarr_test
cd "$(dirname "$0")" || exit

# --- 1. Create the Python virtual environment --------------------------------

echo "Creating virtual environment: ve_zarr_PR1667 ..."
python -m venv ve_zarr_PR1667
# NOTE: On some systems Python is called 'python3'. If the line above fails,
#       try:  python3 -m venv ve_zarr_PR1667


# --- 2. Activate the virtual environment -------------------------------------
# "Activating" makes the terminal use this environment's Python and pip.
#
# [WINDOWS - Git Bash] uses Scripts/activate  <-- this script uses this path
# [UNIX / WSL / macOS] change the line below to:
#   source ve_zarr_PR1667/bin/activate

echo "Activating virtual environment ..."
source ve_zarr_PR1667/Scripts/activate

# Confirm which Python is now in use (optional sanity check).
echo "Using Python at: $(which python)"


# --- 3. Upgrade pip ----------------------------------------------------------
# Keeps the package installer itself up to date; avoids some install warnings.

echo "Upgrading pip ..."
python -m pip install --upgrade pip


# --- 4. Install the virtual_ecosystem package from GitHub --------------------
# This installs a specific commit (86dadb1) directly from GitHub.
# No need to manually download anything.

echo "Installing virtual_ecosystem from GitHub (commit 86dadb1) ..."
pip install git+https://github.com/ImperialCollegeLondon/virtual_ecosystem.git@86dadb1


# --- 5. Install the example data ---------------------------------------------
# The 've_run --install_example' command downloads/copies example config files
# into the folder 've_example/' in your current directory.
# ENFORCED SKIP: if ve_example/ already exists, this step is skipped.
# Re-running --install-example into an existing folder may overwrite files.

if [ -d "ve_example" ]; then
    echo "ve_example/ already exists — skipping example install to avoid overwriting files."
else
    echo "Installing VE example files into ./ve_example/ ..."
    ve_run --install-example ./
fi



# --- 6. Create the output directory ------------------------------------------
# The simulation needs an output folder to write results into.
# 'mkdir -p' creates the folder and any missing parent folders without
# throwing an error if it already exists.

echo "Creating output directory: ve_example/out ..."
mkdir -p ve_example/out


# --- 7. Run the simulation ---------------------------------------------------

echo "Running virtual_ecosystem simulation ..."
ve_run ve_example/config/data_config.toml \
    ve_example/config/abiotic_config.toml \
    ve_example/config/animal_config.toml \
    ve_example/config/hydrology_config.toml \
    ve_example/config/litter_config.toml \
    ve_example/config/plant_config.toml \
    ve_example/config/soil_config.toml \
    --out ve_example/out \
    --logfile ve_example/out/logfile.log
