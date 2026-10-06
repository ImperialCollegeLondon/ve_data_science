# Study Sites

<!-- markdownlint-disable MD046 -->
<!-- The admonition syntax within mkdocs confuses markdownlint, because it thinks the
indented content of the admonition is code. -->

!!! note "Draft"

    This page is a first draft. Sections marked "To complete" need input from the team.

The work in this repository parameterises and tests the Virtual Ecosystem for two
areas of lowland tropical forest in Sabah, Malaysian Borneo:

* **Maliau**: the Maliau Basin Conservation Area, an area of old-growth forest.
* **SAFE**: the landscape of the Stability of Altered Forest Ecosystems (SAFE)
  Project, which spans a gradient of land use particularly logged forest.

All of the simulation grids for these sites use the UTM Zone 50N projection
(EPSG:32650). The grid definitions give the equivalent longitude and latitude bounds.

| Site | Approximate location of the simulation grids | Grid definition file |
| --- | --- | --- |
| Maliau | 116.92 to 116.97 °E, 4.71 to 4.75 °N | `data/derived/site/maliau/maliau_grid_definition.toml` |
| SAFE | 117.68 to 117.72 °E, 4.74 to 4.79 °N | `data/derived/site/safe/safe_grid_definition.toml` |

The [Scenarios](scenarios.md) page describes the grids in detail.

## Why these sites

!!! note "To complete"

    Explain why Maliau and SAFE were chosen: the role of each site in the project, the
    contrast between old-growth and altered forest, and the field programmes that make
    them suitable for parameterising and testing the model.

## Field data used

The table lists the main data sources that analysis scripts in this repository draw
on. It is not complete: each script records its own inputs in its metadata header, and
the soil and litter inputs are described variable by variable in
`data/scenarios/maliau/soil_litter_metadata.toml`.

EXAMPLE:

| Data | Used for | Where it is used |
| --- | --- | --- |
| ERA5-Land climate reanalysis, 2010 to 2020 | Climate forcing | `analysis/abiotic/` |

Named locations at the sites, such as plots and camps, are recorded in the gazetteer
file `data/primary/site/gazetteer.geojson`. The
[validation database](../validation_database.md) uses it to give observations a
location.

!!! note "To complete"

    Add additional site specific data sources (above is an example). We may split the site pages later. 

## Getting the data

Most data files are too large to keep in the GitHub repository. They are stored
separately and shared through Globus. See [Data with Globus](../using_globus.md) for
how to get access and download them.

## Learning about the model

This page describes the sites, not the model. For how the Virtual Ecosystem represents
a forest, see the
[Virtual Ecosystem documentation](https://virtual-ecosystem.readthedocs.io/en/latest/).
