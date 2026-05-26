
# Convert md to ipynb
jupytext --to ipynb  --from .myst.md:myst Example_python.myst.md

# Execute the notebook and save to a notebook
jupyter nbconvert --to markdown --execute Example_python.ipynb

# Convert md to ipynb
jupytext --to ipynb  --from .myst.md:myst Example_R.myst.md

# Execute the notebook and save to a notebook
jupyter nbconvert --to markdown --execute Example_R.ipynb


# To execute an ipynb notebook at the command line:
jupyter nbconvert --execute --inplace Example_R.ipynb
jupyter nbconvert --execute --inplace Example_python.ipynb
