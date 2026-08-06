---
jupyter:
  jupytext:
    cell_metadata_filter: all,-trusted
    formats: ipynb,md
    notebook_metadata_filter: settings,mystnb,language_info,ve_data_science,-jupytext.text_representation.jupytext_version
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
  language_info:
    codemirror_mode:
      name: ipython
      version: 3
    file_extension: .py
    mimetype: text/x-python
    name: python
    nbconvert_exporter: python
    pygments_lexer: ipython3
    version: 3.12.8
---

# Notebook Workflows

## Setting Everything Up

1. In the `ve_data_science/notebooks` folder, create a new folder for your notebook.
2. Create a virtual environment and install the dependencies using the code below.

```text
# Create and activate a new venv
python -m venv .ve_ds_venv
source .ve_ds_venv/bin/activate


# Install Jupyter and Myst notebook tools.
pip install "notebook<7"
pip install jupyterlab
pip install jupyterlab_myst
pip install jupyter_contrib_nbextensions
pip install jupytext

# Install pre-commit to check linting
pip install pre-commit

# Install packages used in notebooks
pip install numpy
pip install matplotlib
```

1. In your terminal, run `jupyter lab` and it should automatically open a browser.
2. Create a new `.ipynb` notebook and name it appropriately.
3. Click "File" -> "Jupytext" -> "Pair Notebook with Markdown"

Now you are ready to start your data analysis! Make sure you include any data files that
you are using in the same folder that your notebook is in.

## Pushing to Github

When you are ready to push your changes to GitHub, you will need to first export a
rendered version of the markdown file.

1. First you need to make sure your markdown file is properly formatted to pass the
linting. In your terminal run `pre-commit` and read through any errors. You will likely
have to fix them manually - this will be easiest to do in VSCode by opening the markdown
file there.
2. In your `.ipynb` file, click "Run" and "Run All Cells".
3. Click "File" -> "Save and Export Notebook As" -> "Markdown". This will save the
rendered markdown file and any images (such as graphs) as a png. These files will be zipped.
4. Unzip the files and move them into a "Rendered" folder in the same place as your
source files.
5. Commit the following files and push them to github:

* The markdown source file
* Any source data files used in your markdown notebook
* The "rendered" markdown file and the images.

Notably the `.ipynb` file should not be pushed to github.

Now you can create a Pull Request on github and request reviews. When you are reviewing
the files online, it may be useful to view the rendered version of a notebook which you
can do by clicking the three dots on the right of the file and click "View".

Any time you make changes to your original source file, you *will* need to re-render it
using steps 1-4. This will not happen automatically, so you can delete the old contents
of your "Rendered" folder and replace them with the new rendered files.

Here is a sample plot, so we can see what it'll be like to include plots and other
visuals in the process.

```python
import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(0, 10, 100)
y = np.sin(x) * np.exp(-x * 0.1)

plt.figure(figsize=(8, 4))
plt.plot(x, y, color="steelblue", linewidth=2)
plt.title("Funky Sine Wave")
plt.xlabel("x")
plt.ylabel("y")
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()
```
