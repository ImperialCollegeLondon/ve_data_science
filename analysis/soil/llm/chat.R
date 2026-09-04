#| ---
#| title: Mine literature values for Virtual Ecosystem constants
#|
#| description: |
#|   Reads the deterministic parameter database built by
#|   `analysis/soil/llm/extract_constant_metadata.R` and asks a language model to
#|   propose empirically supported values for selected constants.
#|
#|   Code semantics are supplied deterministically rather than retrieved. Each
#|   constant is accompanied by its declaration, units, default value, and the
#|   functions that consume it, all extracted by static analysis. The model is
#|   therefore asked only to search the literature, not to work out what the
#|   constant means.
#|
#|   Constants are selected by `qualified_name` rather than bare name, because
#|   several Virtual Ecosystem configuration classes declare attributes sharing
#|   a name (for example `turnover_rate` on both `SoilEnzymeClass` and
#|   `SoilMicrobialGroup`).
#|
#|   One structured request is issued per constant, so the workflow scales to
#|   the full repository without a single prompt growing without bound.
#|
#| VE_module: All
#|
#| author: Hao Ran Lai
#|
#| status: wip
#|
#| input_files:
#|   - name: ve_constant_usage.toml
#|     path: data/derived/llm/
#|     description: |
#|       Parameter database created by extract_constant_metadata.R, providing
#|       constant metadata, classified usage sites, and function docstrings.
#|
#| output_files:
#|   - name: constant_literature_values.csv
#|     path: data/derived/llm/
#|     description: |
#|       One row per constant-source pair, with the suggested value, units,
#|       citation, and the analysed model commit for provenance.
#|
#| source_files:
#|
#| package_dependencies:
#|   - ellmer
#|   - tidyverse
#|   - here
#|   - glue
#|   - RcppTOML
#|
#| usage_notes: |
#|   Run extract_constant_metadata.R first. Values returned by this script are
#|   unverified proposals: the model has no literature search tool, so every
#|   citation must be checked by hand before use.
#| ---

library(tidyverse)
library(ellmer)
library(here)
library(glue)

data_folder <- here("data/derived/soil/llm")


# Read the parameter database --------------------------------------------

# `escape = FALSE` is required. RcppTOML's default re-escapes control
# characters, so newlines inside the model docstrings arrive as a literal
# backslash-n and render as one unreadable line in the prompt.
constant_database <- RcppTOML::parseTOML(
  file.path(data_folder, "ve_constant_usage.toml"),
  escape = FALSE
)

ve_commit <- constant_database$metadata$project_commit
function_docs <- constant_database$functions
constants <- constant_database$constants


# Select constants to assess ---------------------------------------------

# Constants are keyed by qualified name (module.Class.attribute), which is
# unique. Bare names are not: `turnover_rate`, `c_n_ratio`, `constants` and
# `static` are each declared on several configuration classes.
candidate_constants <- c(
  "virtual_ecosystem.models.soil.model_config.SoilConstants.maom_desorption_rate",
  "virtual_ecosystem.models.soil.model_config.SoilConstants.lmwc_sorption_rate",
  "virtual_ecosystem.models.soil.model_config.SoilConstants.litter_leaching_fraction_carbon",
  "virtual_ecosystem.models.soil.model_config.SoilConstants.litter_leaching_fraction_nitrogen",
  "virtual_ecosystem.models.soil.model_config.SoilConstants.litter_leaching_fraction_phosphorus",
  "virtual_ecosystem.models.soil.model_config.SoilConstants.necromass_decay_rate"
)

stopifnot(all(candidate_constants %in% names(constants)))


# Build the deterministic context for one constant -----------------------

# Render the usage sites of a constant as a readable block. Consumers are
# resolved through the shared function table, so each docstring appears once
# per prompt rather than once per site.
format_usage <- function(record) {
  if (length(record$referenced_in) == 0) {
    return("  (no usage sites found in the model code)")
  }

  record$referenced_in |>
    map_chr(\(site) {
      consumer <- site$consumer
      target <- if (nzchar(consumer)) consumer else site$caller
      doc <- function_docs[[target]] %||% ""

      glue(
        "- {site$usage_kind} at {site$file}:{site$line}",
        "    expression: {site$expression}",
        "    used by   : {target}",
        "    which does: {doc}",
        .sep = "\n"
      )
    }) |>
    paste(collapse = "\n")
}

# Assemble everything known about a constant from static analysis alone.
format_constant <- function(qualified_name) {
  record <- constants[[qualified_name]]

  glue(
    "
    Constant      : {record$name}
    Qualified name: {record$qualified_name}
    Declared in   : {record$file}:{record$line} (class {record$class_name})
    Declaration   : {record$declaration}
    Default value : {record$default_expression}
    Type          : {record$type_annotation}

    Documentation (verbatim from the model source):
    {record$docstring}

    Where this constant is used:
    {format_usage(record)}
    "
  )
}


# Prompt -----------------------------------------------------------------

system_prompt <-
  "
  You are an expert ecosystem biogeochemist helping parameterise the
  `virtual_ecosystem` process-based model from published literature.

  <task>
  You are given complete, verified information about one model constant,
  extracted directly from the model source code by static analysis. The
  meaning, units, default value, and usage of the constant are already
  established and are not in question.

  Your only task is to propose values supported by published empirical
  literature.
  </task>

  <evidence_policy>
  The supplied code context is authoritative for what the constant means, its
  units, and the process it belongs to. Do not contradict it or speculate
  beyond it.

  The supplied default value is NOT evidence. Model documentation frequently
  states that a default was chosen for convenience rather than measured. Never
  return the default value back as a recommendation.

  You have no literature search tool. Propose only values you can recall
  specifically and concretely. If you cannot recall a specific study, say so:
  report status `no_evidence` rather than constructing a plausible-looking
  citation. A fabricated citation is far more damaging than an admission of
  ignorance, because it will be acted upon.
  </evidence_policy>

  <units>
  Report values in the units implied by the code context. If a source uses
  different units or a differently parameterised functional form, convert
  explicitly, state the conversion factor, and show the reasoning.
  </units>

  <uncertainty>
  Give a plausible range wherever the literature supports one; a process model
  needs ranges for sensitivity analysis more than it needs point estimates.

  Record the measurement conditions, including soil type, temperature, biome,
  and method. A kinetic rate without its measurement temperature cannot be
  used.

  If several sources disagree materially, return one row per source rather
  than averaging them.
  </uncertainty>

  <confidence>
  high   : direct measurement of this exact quantity, same units, comparable
           system
  medium : conversion required, or conditions differ somewhat
  low    : inferred by analogy, or the source measures a related quantity
  </confidence>
  "

user_prompt <- function(qualified_name) {
  glue(
    "
    Propose literature-supported values for the following model constant.

    <constant>
    {format_constant(qualified_name)}
    </constant>
    "
  )
}


# Structured output ------------------------------------------------------

type_output <- type_array(
  type_object(
    status = type_enum(
      c("value_found", "no_evidence"),
      "Whether a specific published source could be recalled.",
      required = TRUE
    ),
    rationale = type_string(
      paste(
        "Why this value is appropriate, or if status is no_evidence,",
        "what is missing and what evidence would resolve it."
      ),
      required = TRUE
    ),
    suggested_value = type_number(
      "Suggested value, in the units implied by the code context.",
      required = FALSE
    ),
    value_low = type_number(
      "Lower end of the plausible range.",
      required = FALSE
    ),
    value_high = type_number(
      "Upper end of the plausible range.",
      required = FALSE
    ),
    unit = type_string(
      "Unit of the suggested value, matching the code context.",
      required = FALSE
    ),
    original_value = type_number(
      "Value exactly as reported by the source, before conversion.",
      required = FALSE
    ),
    original_unit = type_string(
      "Unit as reported by the source.",
      required = FALSE
    ),
    conversion_factor = type_number(
      "Multiplicative factor taking the original value to the suggested value.",
      required = FALSE
    ),
    conversion_notes = type_string(
      "How the conversion or functional-form mapping was performed.",
      required = FALSE
    ),
    quote = type_string(
      paste(
        "Verbatim sentence or table entry from the source that states the",
        "value. Leave empty if it cannot be recalled exactly."
      ),
      required = FALSE
    ),
    citation_authors = type_string(
      "Author list of the source.",
      required = FALSE
    ),
    citation_title = type_string("Title of the source.", required = FALSE),
    citation_journal = type_string(
      "Journal or publisher of the source.",
      required = FALSE
    ),
    citation_year = type_integer("Publication year.", required = FALSE),
    doi = type_string(
      "DOI of the source. Leave empty rather than guessing.",
      required = FALSE
    ),
    source_type = type_enum(
      c(
        "empirical study",
        "review",
        "dataset",
        "model paper",
        "textbook",
        "other"
      ),
      "Type of source.",
      required = FALSE
    ),
    measurement_conditions = type_string(
      "Soil type, temperature, biome, and method used in the source.",
      required = FALSE
    ),
    confidence = type_enum(
      c("low", "medium", "high"),
      "Confidence, following the rubric in the system prompt.",
      required = FALSE
    )
  )
)


# Query the model --------------------------------------------------------

# One request per constant. This keeps each prompt small and focused, and lets
# the workflow scale to the full repository by extending candidate_constants.
chat <- chat_openai_compatible(
  base_url = "https://ellmer.openai.azure.com/openai/v1",
  model = "gpt-5.6-terra",
  system_prompt = system_prompt
)

constant_values <-
  candidate_constants |>
  set_names() |>
  map(\(qualified_name) {
    chat$clone()$chat_structured(
      user_prompt(qualified_name),
      type = type_output
    )
  })


# Assemble and save ------------------------------------------------------

constant_values_table <-
  constant_values |>
  imap(\(rows, qualified_name) {
    if (length(rows) == 0) {
      return(NULL)
    }
    as_tibble(rows) |>
      mutate(qualified_name = qualified_name, .before = 1)
  }) |>
  list_rbind() |>
  mutate(
    name = constants[qualified_name] |> map_chr("name"),
    model_default = constants[qualified_name] |>
      map_chr("default_expression"),
    ve_commit = ve_commit,
    retrieved_at = Sys.time(),
    .after = qualified_name
  )

write_csv(
  constant_values_table,
  file.path(data_folder, "constant_literature_values.csv")
)


# Flag rows needing human checking ---------------------------------------

# Every citation is unverified: the model has no literature search tool. These
# checks catch the failure modes that can be detected mechanically.
constant_values_table |>
  mutate(
    missing_doi = status == "value_found" & (is.na(doi) | doi == ""),
    missing_quote = status == "value_found" & (is.na(quote) | quote == ""),
    echoes_default = !is.na(suggested_value) &
      map2_lgl(suggested_value, model_default, \(value, default) {
        parsed <- suppressWarnings(as.numeric(default))
        !is.na(parsed) && isTRUE(all.equal(value, parsed))
      })
  ) |>
  filter(missing_doi | missing_quote | echoes_default) |>
  select(name, suggested_value, missing_doi, missing_quote, echoes_default)
