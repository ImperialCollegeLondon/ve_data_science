"""
---

title: Read Site Configuration.

description: |
  Provide helper functions for loading site configuration and
  scenario definitions from TOML files.

virtual_ecosystem_module:
  - All

author:
  - Lelavathy

status: final

package_dependencies:
  - pathlib
  - tomllib

usage_notes: |
  Import from workflow modules whenever scenario and grid
  settings need to be read from site TOML files.

---
"""  # noqa: D212

import tomllib
from pathlib import Path

# ============================================================
# SITE CONFIGURATION
# ============================================================
# Load the selected scenario definition from a site
# configuration TOML file for downstream workflows.


def read_site_configuration(
    toml_file: Path | str,
    scenario_name: str,
) -> dict:
    """Read a site configuration TOML file.

    Args:
      toml_file: Path to the site configuration TOML file.
      scenario_name: Name of the scenario to load.

    Returns:
      Dictionary containing the selected scenario configuration.

    """

    toml_file = Path(toml_file)

    with open(
        toml_file,
        "rb",
    ) as file:
        config = tomllib.load(file)

    return config["Scenario"][scenario_name]
