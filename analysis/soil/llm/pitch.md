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

### Parameterisation / calibration

- Number of constant parameters: about 350
  - Some parameters are well-calibrated or have good source value, but we are
  thinking of including them in the search, because the known values can be use
  to validate the LLM responses
  - We will protoype with the soil module parameters first, then scale to full
    VE
  - **Important note:** the number of constants above is a huge underestimation
    because of "hidden parameters", including animal and plant functional
    group-specific trait and demographic parameters. These parameters also scale
    up multiplicatively with the number of functional groups added to VE. For
    example, each functional group of animals requires ~30 parameters, so even a
    simple simulation with only four functional groups would add >120
    parameters. Scaling up to the our most ambitious model with ~60 groups will
    cost an additional ~1,800 parameters.
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
- AI may be useful less as a replacement for direct analyses, but more as a
  complement: e.g., by finding auxiliary constraints, prior information,
  suggesting comparable systems, or identifying which unvalidated modules are
  most weakly constrained.

### Initialisation

- We might also expand the search to include initial values, since initial
  values can also be consider a type of parameters (there is uncertainty
  regarding to initial values).
- The additional challenge of finding initial values is that they have specific
  spatiotemporal coordinates
- Currently there are ~69 required initial values
- Initial values need to be more site- or scenario-specific than the constants,
  so the strength of LLM here may be to find very specific values (rather than
  more global values.) For some sites, many of the values may come from grey
  literature. LLM may be better at screening heterogenous data sources (e.g., a
  mix of peer-reviewed literature and grey literature.)

### Validation

- We can also expand the LLM search to include validation data, with the same
  caveats as above
- There are ~129 possible output variables directly out of VE for validation,
  not including a lot more derived outputs (e.g., animal density, total soil
  nutrient, stand biomass, diversity, network structure...)
- If is hard to obtain exact values for validation, can LLM obtain a *range* of
  values to validate if the VE predictions are within plausible bounds?
- Following the above, can LLM derive validation values from first principles,
  based on a set of authoritative, peer-reviewed literature? If so, we might be
  able to extend the literature search to include *theoretical* works.

### Mock reviewer persona (qualitative validation)

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
- There is no exact tool to do primary literature search in Anthropic Claude
  (unlike Perplexity)? Claude has a web search tool which I can call directly
  from my R session, but it's general purpose instead of scientific (not sure if
  configurable)?
- Units and scales: often we do have promising data for parameterisation,
  initialisation or validation, but the empirical data are in the wrong unit or
  scale of measurement. We spend a lot of human hours on deciding and
  harmonising these datasets, sometimes only to find that we need to discard the
  data. I think automating the harmonisation or analysis with LLM is not quite
  there yet(?), but at least the LLM could screen through these datasets and
  tell us which dataset *not* to use. Along this line, I wonder if LLM is better
  at *screening* than ingesting datasets.
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

- Some preliminary output can be found
  [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/llm/foundry/analysis/soil/llm/rendered/soil_search_first_pass.md).
- From the previous pilot though, I found that the LLM would simply read the
  constants' docstring and if they find a cited source, they would simply use
  that source and retrieve the same value... This is why I wrote something like
  "Do not simply echo a default or preset model value. When repo semantics and
  the literature do not line up cleanly, say so rather than forcing a value." in
  the prompt below.

## Appendix: LLM prompt (WIP)

See LLM core workflow
[here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/llm/foundry/analysis/soil/llm/chat.R).
