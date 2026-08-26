# Using `renv` to create reproducible environments for R projects

This is a working draft. For full documentation, see the `renv`
[official website](https://rstudio.github.io/renv/articles/renv.html).

## Important note

Currently, we set up `renv` to manage R dependencies for GitHub actions and
[continuous integration](https://rstudio.github.io/renv/articles/ci.html), not
for collaborators to share the same R environment. At the moment we do not find
the need to enforce the same R environment among collaborators yet.

Therefore, the `.Rprofile` has been deliberately added to `.gitignore` to avoid
automatically initialising `renv` on your local project.

## If you do not need `renv`

Simple do nothing.

## If you need `renv`

Create an `.Rprofile` file in the project root, then write in it:

```r
source("renv/activate.R")

```

Or run `renv::restore()`.

Restart your R session afterwards.
