# Coordinating VE Input Data Compatibility Changes

This guide describes a coordinated workflow for Virtual Ecosystem (VE) changes that
require incompatible input-data schemas. It uses the Maliau 2 plant cohort update for
VE PR1889 as a worked example. The backup and Globus sequencing recommendations
below should be agreed by the VE and Data Science teams before each breaking change.

## Principles

- Coordinate one breaking VE input change at a time where possible. Notify the affected
  module and Data Science teams before changing shared input files.
- Before replacing active data, create an untouched, timestamped backup in Globus.
  Back up only the files expected to change when practical; copying the full data
  folder is also an option but requires more storage.
- Generate new files in the active data location from the maintained scripts. Do not
  edit the Globus backup or use it as a generation target. Treat it as read-only.
- Keep any local testing backup separate from the Globus backup. The local backup may
  contain a different set of files and should not be treated as a copy of the Globus
  backup.
- Treat the backup as a snapshot, not a maintained second dataset. Record the VE version
  or commit known to accept its schema (currently not implemented).
- Do not sync new, incompatible files to Globus until the VE revision that supports them
  has been merged and the team has agreed that the new files are ready.

## Before Changing Data

1. Notify the affected teams and identify the VE PR, target commit, changed schema, and
   affected data files.
2. Create the Globus backup before deleting or replacing any active files. For this
  example, use `backup_pre_PR1889` and confirm Globus records the backup's creation
  date and time.
3. Verify that the Globus backup contains the intended files. A separate local backup,
  such as `backup_pre_PR1889_local`, may contain additional or different testing files.
4. Keep backup folders out of input-generation scripts and model input paths. Do not
  maintain backup contents after creation.

## Regenerate and Validate Inputs

1. After confirming the backup, remove only the active files expected to
   change, then regenerate them using the maintained input-data scripts.
2. After the new input data has been generated locally, run a VE validation
  with the pinned PR VE version. A test run of a few timesteps should be
  sufficient to check whether the new PR VE version gets past configuration.

## Pin and Run a VE PR

Add a dedicated dependency group in `pyproject.toml`, pinned to the PR VE commit.
For PR1889 the group is named `dev-PR1889` and points to commit
`72f8724629ee8fbbddadac460a2c2abd6c483f68`:

```toml
dev-PR1889 = [
    "virtual-ecosystem @ git+https://github.com/ImperialCollegeLondon/virtual_ecosystem.git@72f8724629ee8fbbddadac460a2c2abd6c483f68"
]
```

Because `dev`, `dev-pinned`, and `dev-PR1889` provide different Git revisions of the
same package, declare the groups mutually exclusive in `[tool.uv].conflicts`. Keep the
existing `dev`/`dev-pinned` pair and add the two PR group pairs:

```toml
conflicts = [
  [{ group = "dev" }, { group = "dev-pinned" }],
  [{ group = "dev" }, { group = "dev-PR1889" }],
  [{ group = "dev-pinned" }, { group = "dev-PR1889" }],
]
```

From the repository root, sync the group. This resolves dependencies, updates
`uv.lock` if needed, and installs the selected group:

```powershell
uv sync --group dev-PR1889
```

When running VE, select the group explicitly because dependency groups are not selected
by default in this repository:

```powershell
uv run --group dev-PR1889 ve_run <scenario config files> --out <output directory>
```

## Globus and PR Sequencing

Recommended sequence, subject to team agreement:

1. Open the Data Science PR. Obtain review from at least VE PR author.
2. Test the new files with the pinned VE PR revision. Keep the old snapshot unchanged.
3. Merge the VE PR before syncing the new files to Globus.
4. Once the VE change is merged, sync the active files to
   Globus and record the file changes in the Maliau 2 change log. Complete the Data
   Science PR and merge it in coordination with the transfer so users are not directed
   to an incompatible code/data combination.
5. Agree a retention period with the teams before deleting a backup. Two to four weeks
   is a possible starting point.

If the PR VE version fails to run, resolve the VE code first, then repeat the test run.
This may require updating the files locally again. Add the new files to Globus only after
the VE PR runs successfully.
