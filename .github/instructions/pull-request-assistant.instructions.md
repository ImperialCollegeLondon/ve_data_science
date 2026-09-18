---
description: 'Guidelines for creating pull request summary by Copilot.'
applyTo: '**'
---

<!-- markdownlint-disable MD036 MD013 -->
# Pull Request Assistant Instructions

## Purpose

Create PR descriptions that are fast to skim and easy to review.

## Reviewer First-Glance Rule

Lead with where to review first, not narrative background.

## Required PR Description Order

**One-liner summary**

- One line: the goal of the PR or what it does
- Example: "This PR addresses..." or "This PR aims to..."

**Review route**

- One line: where to start and review sequence
- Example: "Start in R scripts, then generated datasets, then tests"

**Changed files (focus map)**

- Add a table for the most important 5-10 files
- Group by feature area when possible
- Mark each file with priority

| File | Change type | Priority | Why focus here |
| --- | --- | --- | --- |
| path/to/file.ts | logic/refactor/test/config/docs | High/Med/Low | one-line reviewer context |

- Summarize remaining files as low-risk/mechanical
- Examples:
  - "8 files are formatting-only and low-risk"
  - ".gitignore only adds reproducible large files to exclude"

**Why (optional)**

- Include only if rationale is not obvious
- Prefer concise technical and UX tradeoff notes

**Testing**

- Include checklist for automated and manual testing
- Note gaps, known limitations, and untested paths
- We do not expect all functions to be tested

## Tone and Style

- Write in a professional, direct tone
- Avoid generic opening fluff
- Keep bullets punchy and specific
- Prefer concrete nouns over vague wording
- Avoid repeating details already in file table
