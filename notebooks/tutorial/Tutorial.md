---
jupytext:
  formats: ipynb,md:myst
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.19.3
kernelspec:
  name: python3
  display_name: Python 3 (ipykernel)
  language: python
---

# Getting Started

1. In the `ve_data_science/notebooks` folder, create a new folder for your notebook.
2. Create a virtual environment and install the dependencies below.

```
# Create and activate a new venv
python -m venv ve_ds_venv
source ve_ds_venv/bin/activate

# Install Jupyter and Myst notebook tools.
pip install "notebook<7"
pip install jupyterlab
pip install jupyterlab_myst
pip install jupyter_contrib_nbextensions
pip install jupytext

# Install packages used in notebooks
pip install numpy
pip install matplotlib
```

3. In your terminal, run `jupyter lab` and it should automatically open a browser.
4. Create a new notebook and name it appropriately.
5. Click "File" -> "Jupytext" -> "Pair Notebook with MyST Markdown"

Now you are ready to start your data analysis! Make sure you include any data files that you are using in the same folder that your notebook is in.

Here is a sample plot, so we can see what it'll be like to include plots and other visuals in the process.

```{code-cell} ipython3
import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(0, 10, 100)
y = np.sin(x) * np.exp(-x * 0.1)

plt.figure(figsize=(8, 4))
plt.plot(x, y, color='steelblue', linewidth=2)
plt.title('Funky Sine Wave')
plt.xlabel('x')
plt.ylabel('y')
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()
```

Test change!

```{code-cell} ipython3

```

```{code-cell} ipython3

```
