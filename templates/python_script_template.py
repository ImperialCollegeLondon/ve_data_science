"""
---
title: Descriptive name of the script

description: |
  Brief description of what the script does, its main purpose, and any important
  scientific context. Keep it concise but informative.

  This can include multiple paragraphs.

virtual_ecosystem_module: [Animal, Plant, Abiotic, Soil, None]

author:
  - David Orme

status: final or wip

input_files:
  - name: Input file name
    path: Full file path on shared drive
    description: |
      Source (short citation) and a brief explanation of what this input file
      contains and its use case in this script

output_files:
  - name: Output file name
    path: Full file path on shared drive
    description: |
      What the output file contains and its significance, are they used in any other
      scripts?

package_dependencies:
  - math

usage_notes: |
  Any known issues or bugs? Future plans for script/extensions or improvements
  planned that should be noted?
---
"""  # noqa: D400, D212, D205, D415

# A Python script template

import math


def my_function(value: float = 10) -> float:
    """Print and return a square root.

    This function simply prints out and returns the square root of a value. It is just a
    simple example to give a template for the function description syntax.

    Args:
      value: A value to be used in the function

    """

    value_square_root = math.sqrt(value)

    # Print the square root
    print(value_square_root)

    # Return the square root
    return value_square_root


# Now we can use the function.
my_value = my_function()
