---
jupytext:
  formats: md:myst
  main_language: R
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
kernelspec:
  display_name: R
  language: R
  name: ir
language_info:
  codemirror_mode: r
  file_extension: .r
  mimetype: text/x-r-source
  name: R
  pygments_lexer: r
  version: 4.4.2
---

# Experimental notebook

This is an experimental notebook

```{code-cell} r
# This is a code cell
library(MASS)
```

We're going to do some stuff

```{code-cell} r
x <- runif(100)
y <- runif(100)

plot(
    x, y,
    xlab="A variable",
    ylab="Another variable"
)
```
