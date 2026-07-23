<!-- markdownlint-disable MD059 -->

# Scoping report: using LLMs to parameterise VE

Lai, Hao Ran

## Aim

To examine the feasibility of using LLMs to search literature for model constants.

## GitHub Issues or PRs

- [#403](https://github.com/ImperialCollegeLondon/ve_data_science/issues/403)

## What I did

- I knew that we should do this programmatically. I would do this in R. So my
  option is the `ellmer` package.
- Before diving in I interacted with Claude to brainstorm implementation plans.
  Claude confirmed my general action plan using `ellmer`.
- For the literature search, I will use Google Gemini because that's the free
  option with the most generous allowance (but it soon became clear that this
  is still not enough; more on this later).
- I needed to provide context for the LLM, e.g., what does a constant mean in VE.
  I began by parsing the VE codebase to extract a TOML table of constant name, unit,
  docstring, and functions that use each constant. I started with abstract syntax tree
  (AST) parsing, which [did not work](https://github.com/ImperialCollegeLondon/ve_data_science/pull/412).
- So I tried static code analysis using the Python `jedi` package, with help
  from David and Jacob. It also [did not work](https://github.com/ImperialCollegeLondon/ve_data_science/issues/423),
  without major changes to the VE codebase.
- So I tried retrieval-augmented generation (RAG), which is a [technique](https://ragnar.tidyverse.org/articles/ragnar.html#why-rag-the-hallucination-problem)
  for improving LLM outputs by grounding them in a source of truth—in this case,
  the VE codebase. Unlike my earlier attempts, RAG does not try to parse that source
  material into tables or other structured formats. Instead, it breaks the codebase
  into chunks, embeds those chunks into a compressed representation, and lets the
  LLM retrieve the most relevant pieces when answering a query. This makes the process
  more reliable and controllable than simply giving the LLM the URL of the VE repository,
  which offers no assurance that it will read or interpret the site accurately.
- I did the RAG using the R package `ragnar`. I had to use a local LLM on my
  laptop (Ollama) to do the embedding, because it quickly ran out of quota when I
  used a cloud LLM. I also limited the search for only 6 soil constants.
  Ollama was slow on my laptop, but it managed to run. This won't scale up to all
  constants though.
- Once the background context was prepared, I began crafting the prompt. I improved
  the prompt iteratively by asking Copilot (with skills integrated on the `ve_data_science`)
  to review my drafts. The latest prompt can be found [here](https://github.com/ImperialCollegeLondon/ve_data_science/blob/e5853d1625f673345293aaed7fb3982ee81643f8/analysis/soil/llm/chat.R#L54-L130).
- Finally, I prompted Google Gemini programmatically using `ellmer`, feeding it
  both my engineered prompt and the RAG. The RAG retrieval step ran well, but the
  actual literature search step quickly capped my Gemini quota. I tried to reduce
  the search to only one constant, but I still hit my quota. I also reduced the
  RAG to only embed soil-related source codes, but I still hit my quota. I did a
  final test on Imperial's dAIsy platform; it does not let me use RAG technique,
  so I just uploaded VE's URL and slightly modified my prompt to use webfetch
  rather than RAG. The literature search proceeded, but the LLM returned lots of
  NAs (because I told it to be conservative) and there is no way to check how it
  read the VE repository.

So in principle our script seems to be working, but LLM free quota is the limiting
factor. It's very hard for me to do more testing, so I decided to stop here and
report back.

## Next steps

- I lodged a [work request](https://servicemgt.service-now.com/ask?id=csm_ticket&table=sn_customerservice_case&sys_id=304820548352cf10c01fc670deaad3b7&view=ask)
  on Imperial's ICT service to request for API access to the LLM that Imperial
  subscribes to, no response yet after 3 days. If I get this, then I can upgrade
  my free tier to business tier.
- Using local LLM with unlimited usage is an option only if we install it on a much
  powerful computer, then I remotely login to that computer's LLM.
- Or I register a paid account of a LLM provide with pay-as-you-go pricing (e.g.,
  Claude), and get some temporary quotas for this particular exploration only.
  But we have explored this option before and it does not feel right.
- Your thoughts...?

## Offshoot ideas

LLMs as expert reviewers who validate VE predictions. Very rough idea:

1. Ask group members to craft an "expert persona" by selecting a list of key review
   or landmark papers (say soil mycorrhizae)
2. Retrieve those papers, convert to markdown plain text, build a RAG store
3. Using the RAG, prompt the LLM something like "You are an expert in soil mycology,
   review the VE output to see if they make sense..." Jacob suggested that we can focus
   on *qualitative* assessments, which is what a human expert tends to do as a
   first-pass sanity check. For example, arbuscular have higher capacity for P uptake,
   ectomycorrhizal have higher capacity for N uptake.
