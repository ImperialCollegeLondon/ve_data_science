# Notebook experiments

The two folders contain example workbooks generated using Jupyter and Quarto.

## Setup and installation

The notebooks need a Python and an R environment. I haven't got notes on the R
installation yet, but Python is setup up using a local virtual environment. This would
probably be the same as the local `venv` used for running VE - there aren't any problems
with using a single `venv` that I can see.

```bash

# Create and activate a new venv
python -m venv ve_ds_venv
source ve_ds_venv/bin/activate

# Install Jupyter and Myst notebook tools.
pip install "notebook<7"
pip install jupyterlab
pip install jupyterlab_myst
pip install jupyter_contrib_nbextensions
pip install jupytext

# Install packages used in notebooks
pip install numpy
pip install matplotlib
```

Quarto needs to be installed from here:

[https://quarto.org/docs/get-started/](https://quarto.org/docs/get-started/)

And to use Quarto with VSCode, you need to install the Quarto extension

[https://marketplace.visualstudio.com/items?itemName=quarto.quarto](https://marketplace.visualstudio.com/items?itemName=quarto.quarto)

## Jupyter

There are basically two format options here:

1. Just use `ipynb` as a single file that can contain the outputs.
2. Use markdown notebooks and export markdown versions of executed notebooks.

In more detail:

### The `ipynb` format

The default Jupyter format is `ipynb`, which is a complex JSON document that can contain
embedded outputs.

* ✅ GitHub does a decent but not perfect job of rendering it.
* ✅ The ReviewNB site does better rendering and allows per cell comments.
* ✅ It gives a single file containing the whole report.
* ✅ You can just edit the file in Jupyter and save it - quite Word-like in some ways.
* ❌ The ipynb file size can get very large
* ❌ Constant small changes from JSON updates to the file.
* ❌ It does need the external review site

### Markdown formats

We use this over on the VE website, specifically the MyST markdown variant, although
that isn't mandatory.

* ✅ Files are small - just contain text and code
* ✅ GitHub renders markdown files well
* ❌ The format does not include the outputs of running code, it is just the source
  code.

So, to actually generate something that shows the full report, we need to execute the
source notebook. That generates an `.ipynb` output and you can then execute and export
the notebook as a markdown format.

We have two markdown files: a source file and a rendered output. We can use `.myst.md`
on the source files and set up the worflow to generate a rendered file with the `.md` suffix.

```bash
# Convert md to ipynb
jupytext --to ipynb  --from .myst.md:myst Example_python.myst.md

# Execute the notebook and save to a notebook
jupyter nbconvert --to markdown --execute Example_python.ipynb
```

We do not want to keep the `.ipynb` (otherwise we might as well just use that) and then
we have a set of files:

```bash
Example_python.myst.md
Example_python.md
Example_python_files/
    Example_python_2.png
```

* ✅ Code files are small still small
* ✅ GitHub renders markdown files well and includes the graphics
* ✅ Can comment on individual lines in the files
* ❌ More files _but_ those image files are just hidden inside the `ipynb` format as
  binary blobs anyway, and it arguably makes it easier to point to/copy figures if they
  exist as actual files.
* ❌ Annoying naming clash - Jupyter expects `md` for the notebook source and we need to
  use `md` to get GitHub to render the file, hence the `_executed`.

## Quarto

The base Quarto format `.qmd` is a markdown format, very similar to the Jupyter markdown
notebook format.

* ✅ Files are small - just contain text and code
* ❌ GitHub does not render the source file - it doesn't know that `qmd` is just
  markdown.
* ❌ The format does not include the outputs of running code, it is just the source
  code.

Running Quarto in VSCode is typically a two-pane usage - you have a source file open and
then you can have two alternative panes:

* An interactive terminal where you can run code cells. This is different from building
  the report - it's basically having a Python or R terminal open so you can check your
  code runs.
* A preview window that shows the rendered report. You can set this up to regenerate
  when the source file is saved, but that does run everything again, so can be quite
  slow.

Quarto doesn't have a file format that contains outputs (well, it kinda does for Python:
`ipynb`!) so you have to render the source file to get an output:

```bash
quarto render Example_python.qmd
```

That both runs the code and exports to the rendered format. There are options for the
rendered format. Note that for Python notebooks, Quarto is actualy just running Jupyter
under the hood, so it is basically duplicating what `nbconvert` is doing above.

### HTML rendering

This is a bad option:

* ❌ The HTML files do not render in GitHub, you have to open them locally in a browser.
* ❌ The HTML format file is extremely bulky - HTML is not a compact markup.
* ❌ The HTML output requires a lot of other files - this is not just the figures as PNG
  (which is the same as the Markdown Jupyter notebooks) - but a whole array of CSS, JS
  and other files.

### Markdown rendering

We can set Quarto notebooks to just export markdown outputs (and specifically the
flavour of markdown used by GitHub, which is good). Again we end up with:

```bash
Example_python.qmd
Example_python.md
Example_python_files/figure-commonmark/
    Example_python_2.png
```

That's very similar to the markdown notebook approach from Jupyter:

* ✅ Code files are small still small
* ✅ GitHub renders markdown files well and includes the graphics
* ✅ Can comment on individual lines in the files
* ❌ More files _but_ those image files are just hidden inside the `ipynb` format as
  binary blobs anyway, and it arguably makes it easier to point to/copy figures if they
  exist as actual files.

But...

* ✅ No annoying naming clash - we have a single file name for the two version. The
  trade off is that the source file doesn't render nicely on GH.
