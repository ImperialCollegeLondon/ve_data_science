# What are all those odd files?

The `ve_data_science` repository contains a lot of small files that are used to
configure the tools that manage code quality and formatting. The listing below shows
the key files and a short description of each. The list includes 'hidden' files, which
start with a dot.

<!-- markdownlint-disable MD013 -->
| File | Description |
| ---- | ----------- |
| `.git` | Used by `git` to keep track of all file changes. Ignore it. |
| `.github/workflows/` | Workflows that GitHub runs automatically. `r-tests.yml` and `python-tests.yml` run the tests for the shared tools, `gh_deploy.yml` publishes this website when changes reach `main`, and `automerge.yml` merges automated dependency updates. |
| `.github/copilot-instructions.md`, `.github/instructions/`, `.github/skills/` | Guidance for AI coding assistants working in the repository. |
| `.gitignore` | A list of files that `git` should not manage. These files will not be added and changes to them will not be tracked. It is used to keep data files out of the repository. |
| `.markdownlint.yaml` | A configuration file for the `markdownlint` tool, used to enforce standard formatting in Markdown files. |
| `.pre-commit-config.yaml` | A configuration file for the `pre-commit` tool, defining a set of quality checks that are run when `git commit` is run. |
| `.python-version` | The version of Python used by the project. `uv` reads this file. |
| `.renvignore` | A list of files that the `renv` R environment manager should ignore. |
| `.ve_data_science` | A marker file that identifies the root of the repository. |
| `.vscode/extensions.json` | Defines a recommended set of extensions for VSCode. |
| `.vscode/settings_template.json` | A template for a recommended set of common settings for VSCode. |
| `AGENTS.md` | Guidance for AI coding assistants working in the repository. |
| `air.toml` | A configuration file for the `air` tool, used to enforce standard formatting in R files. |
| `CODE_OF_CONDUCT.md` | The standards of behaviour expected of everyone contributing to the project. |
| `CONTRIBUTING.md` | How to contribute changes to the repository. |
| `LICENSE` | The software licence used for the code in the project. |
| `mkdocs.yml` | The configuration for this website, including the navigation menu. |
| `pyproject.toml` | A configuration file used to manage the Python packages used within the project. |
| `README.md` | The main project description shown on the repository homepage. |
| `renv/` and `renv.lock` | Used by the `renv` R environment manager. `renv.lock` records the R packages and versions used by the automated checks. See [R with renv](renv.md). |
| `uv.lock` | A file that records the exact Python packages and versions being used. See [Python with uv](uv_setup.md). |
