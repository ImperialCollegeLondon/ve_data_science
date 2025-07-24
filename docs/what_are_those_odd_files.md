# What are all those odd files?

The `ve_data_science` repository contains an awful lot of odd files that are used for
configuring the data quality and formatting setup of the repositor. The listing below
shows all of the key files used to set up the repo and a short description. The list
includes 'hidden' files, which start with a dot.

<!-- markdownlint-disable MD013 -->
| File  | Description |
|-------------------------------| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.git`                       | Used by `git` to keep track of all of file changes. Ignore it. |
| `.github/workflows/ci.yaml`  | Defines a workflow that runs when a pull request is made on GitHub to add changes to the repository. It runs a standard set of checks that  validate the code quality. |
| `.gitignore`                 | Used to manage a set of files that `git` should not manage - these files will not be added and any changes will not be tracked. |
| `.lintr`                     | A configuration file for the R `lintr` package, used to enforce standard formatting in R files. |
| `.markdownlint.yaml`         | A configuration file for the `markdownlint` tool, used to enforce standard formatting in Markdown files. |
| `.pre-commit-config.yaml`    | A configuration file for the `pre-commit` tool, defining a set of quality checks that are run when `git commit` is run. |
| `.Rprofile`                  | A start up file used when R is started in the project. It automatically runs the configuration of the `renv` R environment manager. |
| `.vscode/extensions.json`    | Defines a recommended set of extensions for VSCode |
| `.vscode/settings.json`      | Define a recommended set of common settings for VSCode |
| `LICENSE`                    | The software licence used for the code in the project. |
| `poetry.lock`                | A file that records the Python packages being used in the project and the versions being used. |
| `pyproject.toml`             | A configuration file used to manage the Python packages used within the project. |
| `README.md`                  | The main project description details shown on the repository homepage. |
| `system_dependencies.R`      | This is used to declare the use of R packages that are used in the repository system and which are not used by actual analytical code. |
