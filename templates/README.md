# Templates for the `ve_data_science` repository

This directory contains templates for scripts and notebooks used within the
`ve_data_science` repository. We are using these templates to record metadata about the
code files providing the analyses within the project and so these templates should be
used for all code files.

The metadata is in a format called [YAML](https://yaml.org/spec/1.2.2/), that is just a
markup language for structured data. It is machine readable, so we should be able to
extract metadata from script files to help with code and repository maintenance. YAML is
a bit like JSON data, but it is easier to read and you can include comments to help
explain the data.

The folder contains a pure YAML file (`yaml_metadata_specification.yaml`) that contains
an example of the metadata specification we want to adopt. This is to show what YAML
looks like and it should not be used directly as a template.

Each format has to include the YAML metadata in slightly different ways:

* Script files - whether in Python or R - cannot contain blocks of bare text at the
  start of the file and so these formats include the YAML metadata as a commented block
  at the very start of the file. The commented lines should use the format `#'` and
  then we use two lines `#' ---` to show the start and end of the YAML metadata.

* The RMarkdown notebook format (`.Rmd` files) is expecting a block of uncommented YAML
  data at the front, so here the YAML can be included more simply. Notebook formats call
  this 'frontmatter' and it can be used to control how the notebook is run as well as
  allowing additional metadata.

One thing to note with YAML is that it is extremely fussy about indent spacing - try to
follow the indentation of the templates carefully!
