# Managing Scenario Data and Configuration Versions

This guide describes the workflow for managing scenario data and configuration versions
within the VE Data Science repo. The guide is split up into 3 parts:

Part 1:

- Globus scenario folder structure
- how to manage scenario data files
- how to manage scenario config files
- how to add/update the "GitHub" config files on Globus

Part 2:

- how to add additional data+config versions (e.g., when new VE inputs are required)

Part 3:

- how to make a scenario data+config version backup

## Part 1: Globus scenario folder structure and managing data/config files

An example of the Globus scenario folder structure can be seen here:
`ve_data_science/data/scenarios/maliau/maliau_2`

Here, `maliau_2` is the name of the scenario, and contains the following folders:

- `data`
- `config`

The `data` folder contains the input data needed to run the scenario. The data files in
the `data` folder are actively maintained but NOT through GitHub. Instead, they are
kept up to date by uploading (and updating when needed) the required input data files
through the Globus sync system.

**Note that this section of the guide will need to be updated if we add the main data
files to a `maliau_2/data/main` folder (see Part 2).**

The `config` folder contains the configuration files that can be used with the scenario
data. You can choose to either use the individual model configuration files, or the
compiled version (named `config.toml`). All config files in the `config`
folder are actively maintained through GitHub and are kept up to date with the latest
`main` version of the VE code.

The `maliau_2` folder also contains the `change_log.txt` file. This file is used to
document any changes made to the config and data folders, and is maintained through
GitHub. This means that when you have made changes locally, you need to document these
changes in the `change_log.txt` file and push the changes to GitHub to merge them into
the VE Data Science repo's main branch through a pull request.

### How to add/update the "GitHub" config files on Globus

The Globus folder structure matches the VE Data Science repo data folder structure.
However, changes to the `config` files and `change_log.txt` file on GitHub do not
automatically show up in Globus. This is because files on Globus are stored on the
Research Data Storage (RDS) on the High Performance Computer (HPC). This setup isn't
that different from e.g. your local hard drive on your local pc. Having said that,
there are 2 ways to add/update "GitHub" files on Globus, with the second option being
the preferred and safer choice.

Assuming the changes have already been merged into the `main` branch of the VE Data
Science repo, the first option is to use `git pull` on your local pc to get the
latest version of the respective file (e.g., an updated config file), and to then
upload this file to Globus through the sync system. For new files that are not present
in Globus yet this should be fine in general. For files already present in Globus,
this approach means that your upload would overwrite/replace the existing file with
the new file. The main reason why this approach is not preferred is because two people
could in theory try to upload two different versions of the same file, and only one
will be preserved, being the latest upload. Because of this, it is hard to do version
control and there is no way to detect/solve conflicts.

The second, preferred, approach, is to update the GitHub files on Globus by accessing
the HPC, then use `git pull` to update the `main` branch. Since these changes are
pulled from GitHub directly, there is no possibility of a conflict and the respective
file will always be the latest GitHub version, which is what we want in this case.
To access the HPC, please follow the instructions below. Additional details can also be
found here: <https://imperialcollegelondon.github.io/ve_data_science/hpc_setup/>.

Please note that this guide only focuses on how to manage the `config` files and
`change_log.txt` file, and does not focus on using the HPC to run specific analyses
or using different branches (for additional things to consider, see the link above).

```bash
ssh username@login.cx3.hpc.imperial.ac.uk
cd /rds/general/project/virtual_rainforest/live/ve_data_science/
git checkout main
git pull origin
```

Once you have pulled the changes from GitHub to the `main` branch on the HPC, Globus
will contain the changes. In other words, the files you see on Globus are the files
on the current branch on the HPC. For this reason, it is preferred to keep the HPC on
the `main` branch as much as possible. It is good practice to keep the `main` branch
on the HPC up to date as much as possible, because then the "GitHub" files on Globus
and the actual files on GitHub will remain in sync. Therefore, whenever you merge
changes into the `main` branch on the VE Data Science repo, it is preferred to also
update the HPC `main` branch.

This, combined with keeping the HPC on the `main` branch,, means that anyone with access
to the Globus files can download scenario config and data files that are up to date with
the latest `main` version of the VE code.

## Part 2: How to add additional data+config versions

The second part of this guide focuses on how to add additional data+config versions
to Globus. An example of when this is needed is when a particular PR in the VE repo has
changed the VE code, causing a change in the required inputs. In such case, using the
data and config files in `maliau_2/data/main` with the VE PR version would cause the
simulation to fail during configuration. More specific examples of such changes include
a variable name being changed, or a new variable being added, etc.

Before such VE repo PR can be merged into `main`, the VE PR version needs to be tested
with new input data. Once this new input data has been prepared, and has been verified
to work with the VE PR version, this data needs to be added to Globus. Additionally,
since in many such cases testing the new data will require changes to the config files,
these new config files must also be made available through Globus.

Adding these new data and config files to Globus follows the instructions in Part 1,
with the only difference being a new folder structure, which will closely mimic how
GitHub branching works:

1. Do nothing to current main Globus files (akin to main branch).
2. Stage new Globus files to a new folder (akin to a PR branch).
3. Replace main Globus files with the new files when the VE PR is merged.
4. Delete the "branch" folder (currently undecided when this should happen).

More specifically, let's say VE PR 1889 has made some changes to the VE code and this
VE version now needs slightly different input data and config files. The workflow would
be as follows:

- `maliau_2/data/main` is the "main branch".
- Create a new folder (e.g. `maliau_2/data/pr1889`), which represents the "PR branch"
  with matching PR number from the VE repo.
- Copy the main data files in `maliau_2/data/main` to `maliau_2/data/pr1889`
- Generate the new input data files, based on the requirements by the VE PR.
- Test the VE PR version with the new input data (for notes on testing a specific VE PR
  version, see below).
- If the VE PR version fails the test run, resolve the VE code and/or update the files
  locally again, then repeat the test.
- After the test is succesfull, replace the files in Globus in `maliau_2/data/pr1889`,
  only replace the files that need changing (i.e., those that required changes).
- Add a new copy of the config files in Globus to `maliau_2/data/pr1889` so that the
  config files are available in case someone else wants to do more testing. It shouldn't
  matter if these config files are individual module-specific files or a compiled version.
- Please add the specific VE repo commit used for testing right above the
  `# Core settings` section, for example:

  ```toml
  # Commit used for testing: 72f8724629ee8fbbddadac460a2c2abd6c483f68

  # Core settings
  [core]
  ```

- Then add these new config files to GitHub by pushing the changes from your local pc
  and merging them into `main` through a pull request.
- Then access the HPC, use `git pull` to pull the changes from GitHub and update the
  `main` branch on the HPC, causing the Globus files to be updated (see Part 1).

At this point, the new data and config files have been succesfully added to Globus.
However, once the VE repo PR has been merged, the now "outdated" main files in
`maliau_2/data/main` need to be replaced with the ones from `maliau_2/data/pr1889`.
Note that this will usually only involve changing one file. Please leave the files
that you didn't change alone, and record the change in the `change_log.txt` file.
You will also need to update the config settings once the VE PR has been merged into
`main`, so update the config file, change the `change_log.txt` file, and push these
changes to GitHub. Then access the HPC, use `git pull` to pull the changes from
GitHub and update the `main` branch on the HPC, causing the Globus files to be
updated (see Part 1).

It is worth pointing out that once the "outdated" main files in `maliau_2/data/main`
have been replaced with an updated version, the "outdated" files are considered gone.
It may be that they are kept within the repo if they were part of a specific PR folder,
but maintaining each of these "outdated" versions is not a priority. The reason for
this is that we think that nobody will be interested in running an outdated `main`
version of VE (that is not an official release). Having said that, we will focus on
keeping data+config versions for each new release, which we will discuss in Part 3 of
the guide.

### Notes on testing a specific VE PR version

After the new input data has been generated (i.e., usually on your local pc), carry out
a VE test run with the pinned VE PR version. A test run of a few timesteps should be
sufficient to check whether the new VE PR version gets past configuration.

Note that the purpose of testing here is just to verify if we can get past the
configuration and initialisation stages. It can be possible that the simulation still
crashes at later timesteps, but avoiding that type of errors is not within the scope of
what we're testing for here.

To pin and run a VE PR, add a dedicated dependency group in `pyproject.toml`, pinned to
the VE PR commit. For example, for PR 1889 the group is named `dev-pr1889` and points
to commit `72f8724629ee8fbbddadac460a2c2abd6c483f68`:

```toml
dev-pr1889 = [
    "virtual-ecosystem @ git+https://github.com/ImperialCollegeLondon/virtual_ecosystem.git@72f8724629ee8fbbddadac460a2c2abd6c483f68"
]
```

Note that it is generally a good idea to use a commit that already has main merged into
the PR branch, and that represents a state of the PR branch that is ready for testing.
It may be that additional commits are added to this PR branch, in which case we could
decide to update the specific commit. At the moment this is not required. Also note
that we could update the commit to the final commit of the PR right before it is merged
into main. This would be useful to maintain a consistent approach for re-use later on.
This is also not required at the moment.

Also note that it is possible to add an entire branch instead of a specific commit.
The benefit is that this makes it easier to update `uv` but the downside is that
changes to the branch may be "hidden". The branch aproach also stops working once
the VE PR is merged, as the branch is automatically deleted. Hence manual selection
of which specific commit to use is preferred over the branch approach.

Because `dev`, `dev-pinned`, and `dev-pr1889` provide different Git revisions of the
same package, declare the groups mutually exclusive in `[tool.uv].conflicts`. Keep the
existing `dev`/`dev-pinned` pair and add the two PR group pairs:

```toml
conflicts = [
  [{ group = "dev" }, { group = "dev-pinned" }],
  [{ group = "dev" }, { group = "dev-pr1889" }],
  [{ group = "dev-pinned" }, { group = "dev-pr1889" }],
]
```

From the repository root, sync the group. This resolves dependencies, updates
`uv.lock` if needed, and installs the selected group:

```powershell
uv sync --group dev-pr1889
```

When running VE, select the group explicitly because dependency groups are not selected
by default:

```powershell
uv run --group dev-pr1889 ve_run <scenario config files> --out <output directory>
```

## Part 3: How to make a scenario data+config version backup

The third part of this guide focuses on how to create a backup of the main data and
config files prior to whenever a new VE version is released.

The idea is that this backup provides a set of data and config files that can be used
at any point in time, separately from more recent `main` VE versions. This backup would
consist of a copy of the main data files (e.g., those in `maliau_2/data/main`), as well
as a copy of the main config files in `maliau_2/config`.

Hence, whenever a new VE version is about to be released, the main data files in
`maliau_2/data/main` should be double checked to make sure that they work with the
current latest `main` VE version. Once this has been verified, those files should be
copied to a new folder (e.g., `maliau_2/data/v0.2.3`, being the archive folder for VE
version 0.2.3), along with a copy of the `maliau_2/config` files. The new VE version
(i.e., in this example 0.2.3) can then be released, and the backup data and config
files can then be used for this VE version. Similar to Part 2, the new config files and
changes to the changelog should then be pushed to GitHub, and Globus should be updated
by accessing the HPC and using `git pull`. Following this sequence should avoid any
mismatches between a new VE release and the corresponding data and config files backup.

Note that there are plans to use Zenodo for dataset releases, which supports versioning.
At the moment this is not part of the workflow.
