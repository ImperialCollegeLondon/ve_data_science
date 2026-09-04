# Using LLM to parameterise process-based ecological models

## Current LLM use in VE

- We are using Microsoft Foundry as the LLM platform
  - Imperial's subscription to Foundry grants access to the usual selection of
    LLM models, e.g., GPT, Claude...
- We interact with LLMs programmatically from R, using the `ellmer` package
- Also using the `ragnar` package to build RAG stores to provide context about
  VE, but we may or may not proceed with using RAGs
- Our draft prompt can be found at the end of this document; it will provide
  context for how we use LLM to mine parameters.

### Parameterisation

- Number of constant parameters: about 350
  - Some parameters are well-calibrated or have good source value, but we are
  thinking of including them in the search, because the known values can be use
  to validate the LLM responses
  - We will protoype with the soil module parameters first, then scale to full
    VE
- Basic list of what we're asking the LLM to search for:
  - Name or synonyms of the constant in the literature
  - Empirical or modelled values
  - Unit of measurement
  - Citation, DOI etc.
  - Rationale, confidence level etc. (free text)
- Bacially this is a *sturctured text* mining exercise (like mining cooking
  recipe from websites and organise them into a neat table)
- Need a reviewer-friendly format for human perusal, improve workflow before
  scaling up to the entire of VE

### Initialisation

- We might also expand the search to include initial values, since initial
  values can also be consider a type of parameters (there is uncertainty
  regarding to initial values).
- The additional challenge of finding initial values is that they have specific
  spatiotemporal coordinates
- Currently there are ~69 required initial values

### Validation

- We can also expand the LLM search to include validation data, with the same
  caveats as above
- There are ~129 possible output variables directly out of VE for validation,
  not including a lot more derived outputs (e.g., animal density, total soil
  nutrient, stand biomass, diversity, network structure...)

### Mock reviewer persona

- I have been playing with a rough idea of using LLMs as expert reviewers who
  validate VE predictions.
- Very rough idea:
  1. Ask group members to craft an "expert persona" by selecting a list of key
     review or landmark papers (say soil mycorrhizae)
  2. Retrieve those papers, convert to markdown plain text, build a RAG store
  3. Using the RAG, prompt the LLM something like "You are an expert in soil
     mycology, review the VE output to see if they make sense..." Jacob
     suggested that we can focus on *qualitative* assessments, which is what a
     human expert tends to do as a first-pass sanity check. For example,
     arbuscular have higher capacity for P uptake, ectomycorrhizal have higher
     capacity for N uptake.

## Why LLMs might outperform manual search

- To me, the LLM approach is a develop-once-fire-many-times tool. Once we build
  a good pipeline, we can reuse it, even when VE keep changing, adding
  constants, redefining constants etc. A human would find it harder to keep up
  with VE's pace.
- In reality, we don't simply obtain the constant value. We do this in two
  steps: screen the datasets, then hone in on the right one. To me the LLM is
  making step 1 much faster for us (if we can trust our pipeline), so the human
  can focus on step 2.
- When we use LLM progammatically (i.e., have R scripts of the pipeline,
  including the prompt text), then in a way this is more transparent and
  reproducible than each team member heading off and doing their web searches...
  Parts of the LLM is a blackbox, yes, but each of us is also a black box to one
  another whenever our actions are undocumented...

## Major challenges and concerns

- Microsoft Foundry
  - A diverse LLM ecosystem but very hard to navigate for first-time users
  - Even setting up an API key and endpoint base URL took a while to grasp
  - Hard to budget expenses, do not know how to estimate token usage
- Duplicated sources
  - If we use LLM to search for constant parameters, initial values *and*
    validation datasets, how do we ensure that the same source isn't used for
    multiple purposes (to avoid self-fulling prophecy)
  - In fact we already used some datasets for initialisation, so we need to let
    the LLM know about them so it doesn't reuse them for parameterisation
- False negative: how do we know what they LLM didn't find? There is always a
  nagging feeling that the LLM could have missed something.
- Back to the basics: how does a LLM even search the internet? I thought it
  mimics what I would do: Google and then go through the search results one by
  one. But I realise that an LLM does more of a random sampling of the search
  results rather than going through them exhaustively (which is understandable
  from an efficiency standpoint). If we want a more exhaustive search, then we
  probably want a web crawler instead. So what is the advantage of LLM over a
  conventional web crawler? Or should we go hybrid?
- Hallucination: I find LLM these days hallucinate less, but they still do a
  bit. Maybe I have improved my prompts. I have written some guards into the
  prompt below to *try* reducing hallucination but I am never sure if they ever
  worked.
- Recently I realise that you shouldn't ask an LLM to batch process many similar
  tasks in one conversation (e.g., find 100 constants for me using XXX method),
  because what could happen is that the LLM finds the first few constants really
  carefully, and then drifts off or lose earlier context for the vast majority
  or the remaining constants. What we should be doing is to send parallel chats,
  each sharing the same master prompt and context, and sends subagents or
  something along the line to do the 100 similar tasks. I am still exploring how
  to do this; there are some documentation about this in the R package `ellmer`.

## Preliminary outputs

- I don't have anything concrete to share at the moment, but will update you
  asap. I plan to revisit this project next week or so. Basically I just need to
  quickly learn how to send parallel chats.
- From the previous pilot though, I found that the LLM would simply read the
  constants' docstring and if they find a cited source, they would simply use
  that source and retrieve the same value... This is why I wrote something like
  "Do not simply echo a default or preset model value. When repo semantics and
  the literature do not line up cleanly, say so rather than forcing a value." in
  the prompt below.

## Appendix: LLM prompt (WIP)

```text
You are an expert soil biogeochemist helping parameterise a process-based ecosystem model.

Your task is to assess soil constants for `virtual_ecosystem`, using the repository RAG store as the authoritative source for understanding what each constant represents and how it is used.

<context>
The target model is `virtual_ecosystem`, a Python ecosystem model intended to simulate major ecosystem processes including plants, microclimate, hydrology, soils, animals, and microbes.

The repo RAG store was built from a checkout of the repository and is the main grounding source for code-level meaning. It includes model code, docs, and configuration or schema files.
</context>

<scope>
Restrict your analysis to ONLY the following constants:
{candidate_list}

Do not assess any other constants. Focus exclusively on these
{length(candidate_constants)} parameters.
</scope>

<evidence_policy>
Treat the repo RAG store as the source of truth for:
- what each constant represents
- where in the soil model it is used
- what process it belongs to
- what units, bounds, or transformations are implied by the implementation or documentation

Use external literature only for recommended numerical values and their justification. Do not use repo code, repo docs, or preset values as authority for the recommended number itself.
</evidence_policy>

<workflow>
For each constant, retrieve repository context before deciding what the constant means. Prefer multiple targeted retrievals over one broad guess. Use the constant name, nearby module or script names to triangulate the right code path.
</workflow>

<instructions>
For each of the specified constants:
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
- the cited source is external to the repository
- the recommended number is not merely a repository preset value repeated back
- units are internally consistent
- uncertainty is proportional to the evidence
- you have assessed only and all of the constants in the specified scope
</final_checks>

Think carefully, retrieve before concluding, and prefer `NA` over an unsupported value.
```
