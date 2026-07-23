library(ellmer)
library(ragnar)
library(glue)

data_folder <- "data/derived/soil/llm"


# Retrieve RAG store -----------------------------------------------------

store_location <- file.path(data_folder, "virtual_ecosystem_repo.ragnar.duckdb")
store <- ragnar_store_connect(store_location, read_only = TRUE)

# test the retrieval
# test_chunks <- ragnar_retrieve(store, "What is reference_cue_logit")
# cat(test_chunks$text)

# Prompt -----------------------------------------------------------------
prompt <- glue(
  "
You are an expert soil biogeochemist helping parameterise a process-based ecosystem model.

Your task is to assess soil constants for `virtual_ecosystem`, using the repository RAG store as the authoritative source for understanding what each constant represents and how it is used.

<context>
The target model is `virtual_ecosystem`, a Python ecosystem model intended to simulate major ecosystem processes including plants, microclimate, hydrology, soils, animals, and microbes.

Repository root available to the workflow: `{ve_repo_root}`
The repo RAG store was built from a checkout of the repository and is the main grounding source for code-level meaning. It may include model code, docs, tests, and configuration or schema files.
</context>

<evidence_policy>
Treat the repo RAG store as the source of truth for:
- what each constant represents
- where in the soil model it is used
- what process it belongs to
- what units, bounds, or transformations are implied by the implementation or documentation

Use external literature only for recommended numerical values and their justification. Do not use repo code, repo docs, or preset values as authority for the recommended number itself.
</evidence_policy>

<workflow>
For each constant, retrieve repository context before deciding what the constant means. Prefer multiple targeted retrievals over one broad guess. Use the constant name, nearby module or script names, and any `referenced_in` context to triangulate the right code path.

Each constant name follows this structure:
`virtual_ecosystem.models.<module_name>.<py_script>.<constant_group>.<constant>`
</workflow>

<instructions>
For each constant:
1. Use repo RAG retrieval first to determine the constant's role in the soil model, its units, and how it is used in the code.
2. Identify the most defensible unit from repository evidence.
3. Recommend a plausible value only if supported by a real external source.
4. If multiple plausible literature values exist for materially different conditions or sources, return one row per source.
5. If the repository semantics remain ambiguous, or no supported external value can be found, return `NA` in every field other than `name` and explain the ambiguity in `rationale`.
</instructions>

<research_rules>
Ground every recommendation in a real external source. Do not invent citations. Preserve uncertainty when the literature is mixed or only indirectly applicable.

Use repository evidence to avoid matching a constant to the wrong process. Pay close attention to whether the constant is a rate, fraction, threshold, half-saturation term, logit-scale parameter, modifier, or empirical coefficient.

Pay close attention to units. Report values in units consistent with the repository-grounded interpretation of the constant. If the source uses different units or a differently parameterised form, convert it carefully and explain the conversion or mapping.

Do not simply echo a default or preset model value. When repo semantics and the literature do not line up cleanly, say so rather than forcing a value.
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
- repo RAG, not TOML, determined the constant semantics
- the cited source is external to the repository
- the recommended number is not merely a repository preset value repeated back
- units are internally consistent
- uncertainty is proportional to the evidence
</final_checks>

Think carefully, retrieve before concluding, and prefer `NA` over an unsupported value.
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
    suggested_value = type_number(
      "Suggested value of the constant.",
      required = FALSE
    ),
    unit = type_string(
      "Unit or dimension of the constant value.",
      required = FALSE
    ),
    source_type = type_string(
      "Type of source, e.g. empirical study, review, dataset, or model paper.",
      required = FALSE
    ),
    citation = type_string(
      "External literature or dataset citation.",
      required = FALSE
    ),
    year = type_integer(
      "Publication year of the cited source.",
      required = FALSE
    ),
    url_or_doi = type_string(
      "Resolvable URL or DOI for the cited source.",
      required = FALSE
    ),
    original_value_reported = type_string(
      "Original reported value from the source before any conversion.",
      required = FALSE
    ),
    conversion_or_interpretation_notes = type_string(
      "Notes on unit conversion or interpretation.",
      required = FALSE
    ),
    relevance_to_model = type_string(
      "How the source maps to the model constant.",
      required = FALSE
    ),
    confidence = type_enum(
      c("low", "medium", "high"),
      "Confidence rating for the suggested value.",
      required = FALSE
    ),
    rationale = type_string(
      "Brief explanation of why the value is plausible.",
      required = FALSE
    )
  )
)

# Prompt the LLM ---------------------------------------------------------
chat <- chat_google_gemini(model = "gemini-3.5-flash")
ragnar_register_tool_retrieve(chat, store)

# Run a general chat first for tool calling (RAG)
tictoc::tic()
constant_search <- chat$chat(prompt)
tictoc::toc()

# Run a second chat to extract structured data
tictoc::tic()
constant_search_structured <- chat$chat_structured(type = type_output)
tictoc::toc()
