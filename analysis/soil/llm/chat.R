library(ellmer)
library(glue)
library(toml)

# Input files
data_folder <- "data/derived/soil/llm"
constant_file <- "soil_constant_usage.toml"
constant_filepath <- file.path(data_folder, constant_file)

# Upload files
constant_file_upload <- google_upload(
  constant_filepath,
  mime_type = "text/plain"
)

# Read data that needs to be passed to the LLM from R
constant_usage <- read_toml(constant_filepath)
constant_list <- purrr::map_chr(constant_usage, "name") |> unname()

# Prompt
# To add later:
# - Encourage to think deeper
# - Examples and counter-examples
prompt <- glue(
  "
You are an expert soil biogeochemist helping parameterise a process-based ecosystem model.

Your task is to review a TOML metadata file named `soil_constant_usage.toml`, use repository-grounded context to understand what each constant means inside `virtual_ecosystem`, use web-search-derived citation candidates to identify relevant external literature, and recommend plausible numerical values with citations.

<context>
The target model is `virtual_ecosystem`, a Python ecosystem model intended to simulate major ecosystem processes including plants, microclimate, hydrology, soils, animals, and microbes.

Repository root available to the workflow: `{ve_repo_root}`
The repo RAG store was built from a single checkout of the repository and includes code, docs source, tests, and config/schema files.
</context>

<evidence_policy>
Use `soil_constant_usage.toml` as the primary grounding artifact.
Use the retrieved repo RAG chunks only as secondary evidence for semantics: to clarify what a constant represents, how it is used in code, what units or bounds mean, and which ecological process it belongs to.
Use the web citation candidates only to identify and verify external literature or dataset sources.
Do not use repo code, repo docs, or preset values as evidence for the recommended numerical value itself.
</evidence_policy>

<instructions>
Each TOML entry name follows this structure:
`virtual_ecosystem.models.<module_name>.<py_script>.<constant_group>.<constant>`

For each constant:
1. Start from the TOML metadata.
2. Use the repo RAG context to disambiguate the scientific meaning of the constant and the model process it belongs to.
3. Use the web citation candidates to anchor or verify the external source you cite.
4. Recommend a plausible value only if there is external evidence for it.
5. If multiple plausible literature values exist, return one row per source.
6. If no supported value can be found with reasonable confidence, return `NA` in every field other than `name`.
</instructions>

<research_rules>
Ground every recommendation in a real external source. Do not invent citations. Preserve uncertainty when the literature is mixed.

Pay close attention to units. Report values in units consistent with the constant docstring. If the source uses a different unit, convert it carefully and explain the conversion.

Use the `referenced_in` caller information and the repo RAG context to avoid matching a constant to the wrong process.

If a citation appears in the metadata, do not treat it as sufficient unless it clearly supports a usable numerical value.

When the repo semantics and the literature do not line up cleanly, say so in the rationale rather than forcing a value.
</research_rules>

<output_format>
Return a table with one row per constant-source pair, using these columns in this order:
- `name`
- `suggested_value`
- `unit`
- `source_type`
- `citation`
- `year`
- `url_or_doi`
- `original_value_reported`
- `conversion_or_interpretation_notes`
- `relevance_to_model`
- `confidence`
- `rationale`
</output_format>

<final_checks>
Before finalizing, verify that:
- the recommended number is not simply the preset model value repeated back
- the cited source is external to the repository
- units are internally consistent
- repo RAG was used for semantics, not for numeric authority
- uncertainty is reflected proportionally to the evidence
</final_checks>

Take time to think through this carefully before responding.
"
)

# Define target output classes and types
type_output <- type_array(
  type_object(
    name = type_enum(
      constant_list,
      "Name of the constant.",
      required = TRUE
    ),
    value = type_number(
      "Suggested value of the constant.",
      required = FALSE
    ),
    unit = type_string(
      "Unit or dimension of the constant value.",
      required = FALSE
    ),
    citation = type_string(
      "The primary literature or dataset citation in bibtex format.",
      required = FALSE
    ),
    url = type_string(
      "URL to the literature or dataset source(s).",
      required = FALSE
    ),
    doi = type_string(
      "DOI to the literature or dataset source(s).",
      required = FALSE
    ),
    confidence = type_enum(
      c("low", "medium", "high"),
      "A confidence rating for the suggested value.",
      required = FALSE
    )
  )
)

# Prompt the LLM
chat <- chat_google_gemini(model = "gemini-3.5-flash")
tictoc::tic()
constant_search <- chat$chat_structured(
  constant_file_upload,
  prompt,
  type = type_output
)
tictoc::toc()
