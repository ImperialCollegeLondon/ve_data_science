# Getting Started

1. In the `ve_data_science/notebooks` folder, create a new folder for your notebook.
2. Create a virtual environment and install the dependencies using the code below.

```
# Create and activate a new venv
python -m venv .ve_ds_venv
source .ve_ds_venv/bin/activate

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
4. Create a new `.ipynb` notebook and name it appropriately.
5. Click "File" -> "Jupytext" -> "Pair Notebook with Markdown"

Now you are ready to start your data analysis! Make sure you include any data files that you are using in the same folder that your notebook is in. 

# Pushing to Github

When you are ready to push your changes to GitHub, you will need to first export a rendered version of the markdown file. 

1. In your `.ipynb` file, click "Run" and "Run All Cells".
2. Click "File" -> "Save and Export Notebook As" -> "Markdown". This will save the rendered markdown file and any images (such as graphs) as a png. These files will be zipped.
3. Unzip the files and move them into a "Rendered" folder in the same place as your source files.
4. Commit the following files and push them to github:

* The markdown source file
* Any source data files used in your markdown notebook
* The "rendered" markdown file and the images.

Notably the `.ipynb` file should not be pushed to github.

Now you can create a Pull Request on github and request reviews. When you are reviewing the files online, it may be useful to view the rendered version of a notebook which you can do by clicking the three dots on the right of the file and click "View".

Any time you make changes to your original source file, you *will* need to re-render it using steps 1-4. This will not happen automatically, so you can delete the old contents of your "Rendered" folder and replace them with the new rendered files.



Here is a sample plot, so we can see what it'll be like to include plots and other visuals in the process.


```python
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


    
![png](output_1_0.png)
    




