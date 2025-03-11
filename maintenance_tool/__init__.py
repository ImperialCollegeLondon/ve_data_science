"""Global objects for the maintenance tool."""

import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)

LOGGER = logging.getLogger("ve_data_science")

# # Add a stream handler
# handler = logging.StreamHandler()
# handler.name = "sdv_stream_log"
# LOGGER.addHandler(handler)


# Get the local root for the ve_data_science repository:
# .../ve_data_science/maintenance_tool/__init__.py
REPOSITORY_ROOT = Path(__file__).parent.parent
