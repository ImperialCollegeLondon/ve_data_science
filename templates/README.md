# Templates for the `ve_data_science` repository

This directory contains templates for scripts and notebooks used within the
`ve_data_science` repository. We are using these templates to record metadata about the
code files providing the analyses within the project and so these templates should be
used for all code files.

The metadata is in a format called [YAML](https://yaml.org/spec/1.2.2/), that is just a
markup language for structured data. It is machine readable, so we can extract metadata
from script files to help with code and repository maintenance. We are using YAML
because the markdown notebook formats already use a YAML header block to store notebook
metadata, so we are just simplifying on a single format.

The folder contains a pure YAML file (`yaml_metadata_specification.yaml`) that contains
an example of the metadata specification we want to adopt. This is to show what YAML
looks like and it should not be used directly as a template.

Each script file format has to include the YAML metadata in slightly different ways:

* The RMarkdown notebook format (`.Rmd` files) and Myst Markdown notebook (`.md`) files
  both expect a block of YAML at the start of the notebook. This is called the
  'frontmatter' and is used to store notebook metadata. We simply add a new
  `ve_data_science` section into the frontmatter, that contains the expected script
  metadata.

* Python has a convenient mechanism where a string at the start of a script file is
  parsed as a file docstring. This is very easy to then import from a script file and so
  the docstring of Python scripts should be a multiline string simply contain the
  expected YAML.

<!-- markdownlint-disable MD038-->
* R scripts are not so simple. R does not have a built-in docstring mechanism and also
  does not have multiline comments. It does have multiline strings, but these would then
  be language objects within the script which is intrusive. So, following similar
  approaches used by ROxygen and by the `knitr` package to identify specific lines of
  comments as having a particular meaning, R files contain the YAML at the top of the
  file, with all lines commented out using `#| `. The trailing space is not needed for
  empty lines in the YAML, which can simply be `#|`.
<!-- markdownlint-enable MD038-->

One thing to note with YAML is that it is extremely fussy about indent spacing - try to
follow the indentation of the templates carefully!
