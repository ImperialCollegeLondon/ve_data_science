# Managing Scenario Data and Configuration Versions

This document describes the workflow for managing scenario data and configuration versions
within the VE Data Science repo. The document is split up into 3 parts:

Part 0:

- overview of file structures on the RDS and HPC

Part 1:

- Globus scenario folder structure
- how to manage scenario data files
- how to manage scenario config files
- how to add/update the "GitHub" changelog file on Globus

Part 2:

- how to add additional data+config versions (e.g., when new VE inputs are required)

Part 3:

- how to make a scenario data+config version backup

## Part 0: Overview of file structures on the RDS and HPC

It is important to have a good understanding of the way in which data files and code
are structured on the Research Data Store (RDS) in order to maintain our core data files
and run VE simulations on HPC. In particular, you need to understand the differences
between the **project** directory and your **home** directory.

### The project directory

The path `/rds/general/project/virtual_rainforest/live/ve_data_science/` is the path to
our central data and code store on the RDS. The shared VE files through the GLOBUS
system are **these exact files**: GLOBUS simply provides authentication and file
download/upload tools around the files.
As well as containing all of the data files that are managed outside of Git, the
project root directory is also a Git clone of the `ve_data_science` repository. This
means that the code files in the directory and that are visible through GLOBUS will be
the most recent `git pull` on the checked out branch. In order to ensure that a single
consistent set of files is provided through GLOBUS, it is important that the repository
clone at `/rds/general/project/virtual_rainforest/live/ve_data_science/`:

1. is always left on the `main` branch, and
2. is regularly updated to the most recent changes (mainly relevant for the changelog
  file, see later).

### Your home directory

If you are working with running the [VE on the HPC](./hpc_setup.md) then you will set up
a **completely separate clone** of the `ve_data_science` repository in your home
directory at:

`/rds/general/user/your_user_name/home`

Any scripts and configuration you run will need to point to the data files in the
project directory. In general you are likely to be using an official VE release or the
most recent code in `main`, but - within this clone on your own home directory - you
can also switch branches to run alternative code.

## Part 1: Globus scenario folder structure and managing data/config files

An example of the Globus scenario folder structure can be seen here:
`ve_data_science/data/scenarios/maliau/maliau_2`

Here, `maliau_2` is the name of the scenario, and contains the following folders:

- `data`
- `config`

The `data` folder contains the input data needed to run the scenario.
Within this `data` folder:

- `data/main` contains the data that works with the latest `main` branch of the VE code
- `data/release_0_2_3` contains the data that works with the latest VE release
- `data/pr1958` contains the data that works with VE PR 1958

The data files in the `data` folder are actively maintained and kept up to date by
uploading (and updating when needed) the required input data files through the Globus
sync system.

The `config` folder contains the configuration files that can be used with the scenario
data. We provide model-specific config files as this gives the greatest flexibility,
but nothing is stopping you from merging these together into one compiled file for
personal use on your local machine.

Within this `config` folder:

- `config/main` contains the config files that work with the latest `main` branch
  of the VE code
- `config/release_0_2_3` contains the config files that work with the latest VE release
- `config/pr1958` contains the config files that work with VE PR 1958

The config files in the `config` folder are also maintained through the Globus sync
system.

Thus, anyone with access to the Globus files can download scenario config and data
files that are up to date with the latest `main` version of the VE code.

The `maliau_2` folder also contains the `change_log.txt` file. This file is used to
document any changes made to the (untracked) config and data folders for this scenario,
and is maintained through GitHub. This means that when you have made changes locally,
you need to document these changes in the `change_log.txt` file and push the changes to
GitHub to merge them into the VE Data Science repo's main branch through a PR.

It is important to add sufficient details in the changelog description about the
changes made to either the data and/or config files because these files are not tracked
on GitHub. Note that there currently is not a way to prevent conflicts when updating
the data and/or config files on Globus. However, because people generally only focus
on model-specific data files, and because we have opted for individual model-specific
config files, the odds of conflicts occurring are expected to be low (but not zero).

Please note that the safest way to access to latest version of the `change_log.txt`
file is to go to the VE Data Science repo and access it there.

### How to add/update the "GitHub" changelog file on Globus

As mentioned in Part 0 of this document, the Globus folder structure matches the VE
Data Science repo data folder structure. However, changes to the `change_log.txt` file
on GitHub do not automatically show up in Globus.

You can add/update the `change_log.txt` file on Globus by accessing the HPC, then use
`git pull` to update the `main` branch. Since these changes are pulled from GitHub
directly, there is no possibility of a conflict and the respective file will always be
the latest GitHub version of the `change_log.txt` file. Please always use the method
above to add/update the `change_log.txt` file on Globus, and not the Globus sync system
as the latter would simply overwrite the existing file without guarantee that it is
actually the latest GitHub version.

To access the HPC, please follow the instructions below.

```bash
ssh username@login.cx3.hpc.imperial.ac.uk
cd /rds/general/project/virtual_rainforest/live/ve_data_science/
git checkout main
git pull origin
```

Please note that this current document only focuses on how to add/update the
`change_log.txt` file, and does not focus on using the HPC to run specific analyses
or using different branches. For more details on HPC use, see the link below:
<https://imperialcollegelondon.github.io/ve_data_science/hpc_setup/>.

Please note that it is not recommended to assume that the Globus `change_log.txt` file
is always up to date, as it is possible that the Globus version has not been updated to
the latest GitHub version yet. Hence, as mentioned earlier, we recommend to access the
`change_log.txt` file through the VE Data Science repo.

## Part 2: How to add additional data+config versions

The second part of this document focuses on how to add additional data+config versions
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

More specifically, let's say VE PR 1958 has made some changes to the VE code and this
VE version now needs slightly different input data and config files. The workflow would
be as follows:

- `maliau_2/data/main` is the "main branch".
- Create a new folder (e.g. `maliau_2/data/pr1958`), which represents the "PR branch"
  with matching PR number from the VE repo.
- Copy the existing data files from `maliau_2/data/main` to `maliau_2/data/pr1958`.
- Delete the outdated file that needs to be replaced in `maliau_2/data/pr1958`.
- Generate the new input data file in `maliau_2/data/pr1958`.
- Test the VE PR version with the new input data. If the VE PR version fails the test,
  resolve the VE code and/or update the files, then repeat the test.
- After the test is succesfull, sync the files to Globus in `maliau_2/data/pr1958`
- Also sync the new (model-specific) config files to Globus in a new
  `maliau_2/config/pr1958` folder.
- Document the addition of the new folders and files in the `change_log.txt` file and
  add these changes to the VE Data Science repo through a PR. Please add sufficient
  details to the changelog description.

At this point, the new data and config files have been succesfully added to Globus.
However, once the VE repo PR has been merged, the now "outdated" main files in
`maliau_2/data/main` need to be replaced with the ones from `maliau_2/data/pr1958`.
Note that this will usually only involve changing one file. Please leave the files
that you didn't change alone, and record the change in the `change_log.txt` file.
You will also need to update the config settings once the VE PR has been merged into
`main`, so replace the respective model-specific config file in
`maliau_2/config/main` with the new one in `maliau_2/config/pr1958`.

Important: The config paths in `maliau_2/config/main` should point to the data files in
`maliau_2/data/main` (no longer to `maliau_2/data/pr1958`). Hence, update the config
paths in `maliau_2/config/main` accordingly once the data and config files have been moved.

It is worth pointing out that once the "outdated" main files in `maliau_2/data/main`
have been replaced with an updated version, the "outdated" files are considered gone.
It may be that they are kept within the repo if they were part of a specific PR folder,
but maintaining each of these "outdated" versions is not a priority. The reason for
this is that we think that nobody will be interested in running an outdated `main`
version of VE (that is not an official release). Having said that, we will focus on
keeping data+config versions for each new release, which we will discuss in Part 3 of
this document.

### Notes on testing a specific VE PR version

After the new input data has been generated (usually on your local pc), carry out
a VE test run with the pinned VE PR version. A test run of a few timesteps should be
sufficient to check whether the new VE PR version gets past configuration.

Note that the purpose of testing here is just to verify if we can get past the
configuration and initialisation stages. It can be possible that the simulation still
crashes at later timesteps, but avoiding that type of error is not within the scope of
what we're testing for here.

To pin and run a VE PR, change the dedicated `dev-pinned` dependency group in
`pyproject.toml`, pinned to the VE PR commit. Note that it is generally a good idea to
use a commit that already has main merged into the PR branch, and that represents a
state of the PR branch that is ready for testing.

Then, from the repository root, sync the group. This resolves dependencies, updates
`uv.lock` if needed, and updates the `dev-pinned` group:

```powershell
uv sync --group dev-pinned
```

When running VE, select the group explicitly because dependency groups are not selected
by default:

```powershell
uv run --group dev-pinned ve_run <scenario config files> --out <output directory>
```

Note that we intentionally do not require logging the specific commit used for testing.
The commit will be stored under the `dev-pinned` group, but this may be overwritten in
the future when another VE PR requires testing with new data. We assume the VE PR
number is sufficient to track down the specific commit in case additional testing is
required in the future (which is unlikely once the VE PR is merged).

## Part 3: How to make a scenario data+config version backup

The third part of this document focuses on how to create a backup of the main data and
config files prior to a new VE version being released.

The idea is that this backup provides a set of data and config files that can be used
at any point in time, separately from more recent `main` VE versions. This backup would
consist of a copy of the main data files (i.e., those in `maliau_2/data/main`), as well
as a copy of the main config files in `maliau_2/config/main`.

Hence, whenever a new VE version is about to be released, the main data files in
`maliau_2/data/main` should be double checked to make sure that they work with the
current latest `main` VE version. Once this has been verified, those files should be
copied to a new folder (e.g., `maliau_2/data/release_0_2_3`, being the archive folder
for VE version 0.2.3). Also place a copy of the config files from `maliau_2/config/main`
in `maliau_2/config/release_0_2_3`. The new VE version (in this example 0.2.3) can then
be released, and the backup data and config files can then be used for this VE version.
Similar to Part 2, record the changes in the changelog and push them to GitHub
through a VE Data Science repo PR. Following this sequence should avoid any mismatches
between a new VE release and the corresponding data and config files backup.

Note that there are plans to use Zenodo for dataset releases, which supports versioning.
At the moment this is not part of the workflow.
