---
jupytext:
  formats: md:myst
  main_language: python
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.18.1
kernelspec:
  display_name: Python 3 (ipykernel)
  language: python
  name: python3
---

# Experimental notebook

This is an experimental notebook

```{code-cell} ipython3
# This is a code cell
import matplotlib.pyplot as plt
import numpy as np
```

We're going to do some stuff

```{code-cell} ipython3
x = np.random.uniform(size=100)
y = np.random.uniform(size=100)

plt.scatter(x, y)
plt.xlabel("A variable")
plt.ylabel("Another variable")
plt.tight_layout()
```

```{code-cell} ipython3

```
