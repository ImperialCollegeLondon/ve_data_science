# Derived and emergent variables from the Virtual Ecosystem

Hao Ran Lai

<!-- markdownlint-disable MD046 -->

The Virtual Ecosystem outputs
[data variables](https://virtual-ecosystem.readthedocs.io/en/latest/using_the_ve/variables/variables.html)
according to the model specifications, such as soil carbon in separate
[pools](https://virtual-ecosystem.readthedocs.io/en/latest/virtual_ecosystem/theory/soil/soil_carbon.html#soil-carbon-pools)
(e.g., organic vs microbial). In practice, ecologists tend to measure *total*
carbon amount in their soils, and therefore they would need to manipulate
the simulation's output data to match empirical measurements.

We call the variables that are transformations, aggregations or summaries of
the original output variables as "derived variables".

## Functions to calculate derived variables

!!! TIP

    This is a growing section. We expect to include more derived variables
    as we develop the Virtual Ecosystem. Currently there is only R functions,
    but we expect to have python functions soon.

Currently, we derive variables using custom post-processing scripts. To try
it out, load the functions:

```r
# load dependencies
box::use(tools/R/R/convert_array_to_nc[...])
box::use(tools/R/R/get_data_variables[...])

# load the actual function to derive variables
box::use(tools/R/R/get_derived_variables[...])
```

We are using `box::use()` in place of `source()` to load a function, because
the functions have been documented in Roxygen2 formats that can be viewed
using `box::help(get_derived_variables)`.

We expect you to usually do
`get_derived_variables(<loaded netCDF arrays>, <loaded full model configuration TOML>)`
, which returns a list of derived-variable arrays.
See `box::help(get_derived_variables)` for a specific example using the
`maliau_2` scenario.
