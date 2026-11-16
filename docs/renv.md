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

Simply do nothing.

## If you need `renv`

Create an `.Rprofile` file in the project root, then write in it:

```r
source("renv/activate.R")

```

Or run `renv::restore()`.

Restart your R session afterwards.

## Restoring on CX3

Restore on a compute node, with system development libraries loaded before
starting R. Missing `nc-config` or `netcdf.h` requires a compatible NetCDF C
development module. `nloptr` and `RcppParallel` source builds also require CMake.
Manually downloading R packages does not supply these dependencies.

See the [soil sensitivity restore recipe](../analysis/soil/sensitivity/input_data/README.md#set-up-r-on-cx3)
for module discovery, build-tool checks, PBS resources, and install concurrency.
With renv 1.2.3, `options(renv.install.timeout = ...)` sets the worker-phase
deadline; R's download `timeout` option does not address
`worker process timed out`. Keep the worker deadline below the PBS walltime.
Fix root build failures before retrying dependent packages, and preserve the
lockfile rather than snapshotting an incomplete environment.

## Notes

- The `pizzarr` package uses r-universe build. I have found that a force rebuild
  is required to update it:

```r
renv::install(
  "pizzarr",
  repos = c("https://zarr-developers.r-universe.dev"),
  rebuild = TRUE
)
renv::snapshot()
```
