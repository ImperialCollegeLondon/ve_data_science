---
name: ve-config-summary
description: Summarise a Virtual Ecosystem run's configuration with tools/R/R/summarise_ve_config.R and render the generated Markdown in a Markdown-based report.
---

# VE configuration summary

Use this skill when a user wants a concise description of the Virtual
Ecosystem (VE) simulation settings in a Markdown-based report. By default, add
the summary at the bottom of the report as a final section, like session
information; use another location only when the user asks. Work from the
repository root and use `tools/R/R/summarise_ve_config.R`; do not recreate or
manually transcribe its summary.

## Add the summary to a report

1. Get the scenario as a shorthand name (for example, `maliau_2`) or a full
   output-directory path. For a shorthand name, search under
   `data/scenarios/` for an exact directory-name match and use that scenario's
   `out/` directory. If there is not exactly one match, ask for the full path
   rather than guessing. Use `compiled_configuration.toml` and `logfile.log`
   from that same output directory.
2. Source the helper in the report's setup chunk or notebook cell:

   ```r
   source(here::here("tools/R/R/summarise_ve_config.R"))
   ```

   The helper requires the R package `toml`. The report may also need `here`
   for repository-relative paths.
3. Resolve the scenario and validate its files in the setup chunk or notebook
   cell. This accepts a scenario shorthand, a repository-relative directory or
   a full path:

   ```r
   scenario <- "SCENARIO_NAME_OR_OUTPUT_DIRECTORY"
   if (dir.exists(scenario)) {
     out_dir <- scenario
   } else if (dir.exists(here::here(scenario))) {
     out_dir <- here::here(scenario)
   } else {
     scenario_dirs <- list.dirs(
       here::here("data/scenarios"),
       recursive = TRUE,
       full.names = TRUE
     )
     scenario_dirs <- scenario_dirs[basename(scenario_dirs) == scenario]
     if (length(scenario_dirs) != 1L) {
       stop("Supply a scenario name with one match or a full output path.")
     }
     out_dir <- file.path(scenario_dirs, "out")
   }

   config_path <- file.path(out_dir, "compiled_configuration.toml")
   log_path <- file.path(out_dir, "logfile.log")
   if (!all(file.exists(c(config_path, log_path)))) {
     stop("The selected output directory must contain both run files.")
   }
   ```

4. Add the summary at the bottom of the report, alongside existing session
   information rather than in a redundant section. Use the syntax for the
   report format:

   **Quarto** — set `results: asis` so knitr renders the emitted text as
   Markdown:

   ````markdown
   ## Virtual Ecosystem configuration

   ```{r}
   #| label: ve-config
   #| results: asis

   invisible(summarise_ve_config(config_path, log_path, dev = FALSE))
   ```
   ````

   **R Markdown** — use the equivalent chunk option:

   ````markdown
   ## Virtual Ecosystem configuration

   ```{r ve-config, results='asis'}
   invisible(summarise_ve_config(config_path, log_path, dev = FALSE))
   ```
   ````

   **Jupyter with an R kernel** — capture the helper's console output and
   display it as Markdown. This requires `IRdisplay`:

   ```r
   summary_markdown <- paste(
     capture.output(summarise_ve_config(config_path, log_path, dev = FALSE)),
     collapse = "\n"
   )
   IRdisplay::display_markdown(summary_markdown)
   ```

   For a Python-kernel notebook with an existing `rpy2` Jupyter extension,
   source the helper and define the paths in the R session, then export the
   captured text and display it in a Python cell:

   ```r
   %%R -o summary_markdown
   summary_markdown <- paste(
     capture.output(summarise_ve_config(config_path, log_path, dev = FALSE)),
     collapse = "\n"
   )
   ```

   ```python
   from IPython.display import Markdown, display

   display(Markdown(summary_markdown))
   ```

   Do not add a new R bridge solely for this summary.
   The helper writes with `cat()` and returns the text invisibly, so use the
   format-specific approach above rather than relying on automatic value
   display.
5. Render or run the report and confirm the summary appears as a Markdown
   list, not as code or quoted console output. Check that the VE version,
   models, grid, extent, period and input files match the selected run.

Set `dev = TRUE` only when the simulation used the VE develop version; this
adds a develop-version note to the version line. The helper reads only the
first 100 lines of the log. It identifies `.nc` and `.csv` strings in the
compiled configuration as input files and assumes `xoff` and `yoff` are the
lower-left origin of a square grid when calculating the bounding box. Preserve
these qualifications if explaining or interpreting the output.
