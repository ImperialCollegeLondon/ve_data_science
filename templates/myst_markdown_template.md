---
jupytext:
  formats: md:myst
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
kernelspec:
  name: python3
  display_name: Python 3 (ipykernel)
  language: python
language_info:
  name: python
  version: 3.12.3
  mimetype: text/x-python
  codemirror_mode:
    name: ipython
    version: 3
  pygments_lexer: ipython3
  nbconvert_exporter: python
  file_extension: .py
ve_data_science:
  title: Descriptive name of the script
  description: |
    Brief description of what the script does, its main purpose, and any important
    scientific context. Keep it concise but informative.

    This can include multiple paragraphs.
  author:
  - David Orme
  virtual_ecosystem_module: [Animal, Plant, Abiotic, Soil, None]
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

  package_dependencies: [math]
  usage_notes: |
    Any known issues or bugs? Future plans for script/extensions or improvements
    planned that should be noted?
---

<!-- Markdownlint _insists_ that there are multiple top level headings -->
<!-- markdownlint-disable-next-line MD025 -->
# A Python script template

```{code-cell} ipython3
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
```

Now we can use the function.

```{code-cell} ipython3
my_value = my_function()
```
