---
name: fill-script-metadata
description: Fill script and notebook metadata headers from repository templates.
---

# Document script metadata

Use this skill when asked to add, complete, or update the metadata header of an
analysis script or notebook in `ve_data_science`.

Invoke it as `/fill-script-metadata <filename or @reference>`. Treat the
argument as the target file or files; resolve `@reference` using the assistant's
file-reference mechanism.

## Workflow

1. Identify the requested file or files and inspect each file before editing.
   Read `templates/README.md` and the matching template. Check nearby files in
   the same analysis folder for established wording and conventions.
2. Derive metadata from the file's purpose, code, imports, paths, and directly
   referenced scripts. Read only related files needed to verify those details.
3. Add or complete the header in the format for that file type below. Preserve
   valid existing metadata unless it is demonstrably wrong; do not duplicate
   headers or rewrite unrelated metadata.
4. Keep the change limited to the header. Preserve code, notebook cells,
   execution counts, outputs, cell IDs, and notebook-level metadata.
5. Validate the header syntax and inspect the diff to confirm that only intended
   metadata changed. Do not execute notebooks as part of this task.

## Select the matching template

- Python `.py`: `templates/python_script_template.py`; a triple-quoted YAML
  docstring at the very start of the file.
- R `.R` or `.r`: `templates/R_script_template.r`; YAML at the start, with
  each line commented using `#|`.
- R Markdown `.Rmd`: `templates/R_markdown_template.Rmd`; YAML frontmatter
  containing a nested `ve_data_science:` mapping.
- MyST Markdown `.md` notebook: `templates/myst_markdown_template.md`; YAML
  frontmatter retaining Jupyter metadata and containing `ve_data_science:`.
- Jupyter `.ipynb`: `templates/Jupyter_notebook_R_template.ipynb`; metadata
  headings in the first Markdown cell, following that template.

Do not substitute the pure-YAML example in
`templates/yaml_metadata_specification.yaml` for a file-format template. For
`.ipynb`, edit the first Markdown cell's `source` in the notebook JSON; do not
add the header to the notebook's top-level `metadata` object.

When a requested format has no dedicated template, use the nearest supported
format and adapt only what is needed to preserve that format's conventions.
For example, use `templates/R_markdown_template.Rmd` for Quarto documents
(`.qmd`). Do not invent a new header structure.

## Preserve metadata through notebook conversion

Quarto and R Markdown documents must retain their metadata through the
`.qmd` or `.Rmd` -> `.ipynb` -> `.md` conversion chain. Using the R Markdown
template alone does not guarantee this: converters may drop custom frontmatter
or notebook metadata.

Inspect the conversion commands and metadata-preservation settings used for the
target document. Keep `ve_data_science` in the source frontmatter, preserving
unrelated rendering options. Verify that every field and value reaches both the
intermediate notebook and the final Markdown. Do not rely solely on notebook
JSON metadata unless the Markdown exporter preserves it.

If frontmatter is dropped, use the existing conversion workflow's supported
preservation mechanism. If none exists, retain a visible metadata section in
the document body following the Jupyter template's first-cell format. Keep it
consistent with the source frontmatter; do not allow conflicting copies.

Validate the chain on temporary copies using the actual converters without
executing code cells. Compare metadata fields and values at each stage,
including lists, file records, and multiline descriptions; formatting may
change, but information must not be lost. Leave source code, outputs, and
committed generated files untouched. If converters are unavailable or the
workflow cannot be established, report conversion survival as unverified, not
guaranteed.

## Fill fields from evidence

Use the field names and nesting shown in the selected template. Common fields
include:

- `title` and `description`: accurately summarize the script's purpose and
  relevant scientific context.
- `virtual_ecosystem_module`: choose the applicable module from the template's
  allowed values; use `None` (or `All` where the R template allows it) only
  when supported by the script's scope.
- `author` and `status`: preserve known values. Do not assume the current
  maintainer or Git committer is the author. Use `wip` when the file is
  explicitly incomplete; do not label it `final` without evidence.
- `input_files` and `output_files`: include files the code actually reads or
  writes, with paths and concise descriptions. Do not list hypothetical,
  temporary, or merely mentioned files as dependencies.
- `package_dependencies`: list packages used by the script, not every package
  installed in the environment.
- `source_files` for R or `imported_files` for Python: list directly sourced or
  imported project scripts when the corresponding template provides the field.
- `usage_notes`: include known setup requirements, caveats, limitations, or
  follow-up work; do not invent issues or plans.

Use repository-relative paths for files in the repository. Preserve an
established external path when it is present and verifiable; never fabricate a
shared-drive path. Keep YAML indentation and block scalars consistent with the
selected template. Replace example placeholders with evidence-based values.
When a value cannot be established, leave it explicitly empty in the format
appropriate to that field and report it as unresolved rather than guessing.

## Validation

- Check that the header is at the expected location and uses the correct
  template-specific field names and nesting.
- Parse YAML frontmatter or docstring YAML when a YAML parser is available.
  For `.ipynb`, confirm the edited file remains valid JSON and the header is in
  the first Markdown cell.
- Inspect the final diff to ensure executable code and notebook content outside
  the header are unchanged.
- For Quarto and R Markdown, verify metadata preservation through both
  conversion stages as described above, or report the specific blocker.
- Report the files updated and any metadata fields that remain unresolved.
