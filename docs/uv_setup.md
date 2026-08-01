<!-- markdownlint-disable MD046 MD024 -->
# Setting up Python with `uv`

`uv` handles Python installation, virtual environments, and dependencies in one
place.

## How it works

You can switch between versions of `virtual-ecosystem` with one command in the
terminal:

| What you want | Sync command | Run command |
| --- | --- | --- |
| Stable release from PyPI | `uv sync` | `uv run ve_run ...` |
| Latest `develop` branch build | `uv sync --group dev` | `uv run --group dev ve_run ...` |
| Pinned `develop` branch commit for testing and comparison | `uv sync --group dev-pinned` | `uv run --group dev-pinned ve_run ...` |

You only maintain *one* virtual-environment folder `.venv`.
No juggling among multiple virtual environments.

The versions are defined in `pyproject.toml` in the project root. The pinned
`dev-pinned` version can be changed at any time; it is to pin a specific version
in case we need to troubleshoot with a particular commit. You can also add
required dependencies in `pyproject.toml` for the team.

---

## Step 1: Install `uv`

### Windows

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### macOS / Linux

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Check that it works:

```sh
uv --version
```

---

## Step 2: Set up this repository

After [cloning the repository](getting_started.md#getting-the-repository), move
into the repository root and run:

```sh
uv sync
```

This command will automatically:

- Install the Python version required by this project
  (from `.python-version`, which we can all change)
- Create a local `.venv` environment if needed
- Install project dependencies

`uv` uses a local package cache. If `virtual-ecosystem` (or other dependencies)
is already in that cache *and is the exact version this project asks for*,
`uv sync` will skip installing it again.
That is why repeat syncs are typically much faster after the first run.

You do **not** need to activate the environment to start using it.

---

## Step 3: Switch versions of `virtual-ecosystem`

Use one of these commands any time you want to change version:

```sh
uv sync
uv sync --group dev
uv sync --group dev-pinned
```

Only one version is active at a time, and each command switches to that version.
Simply switching groups does not need any extra flags; `uv sync` will install
whatever version that group needs. See
[Step 4](#step-4-update-virtual-ecosystem) if you want to pull in new changes
from upstream.

---

## Step 4: Update `virtual-ecosystem`

### A) Update to the latest PyPI release

Run:

```sh
uv lock --upgrade-package virtual-ecosystem
uv sync
```

This updates `uv.lock` (the file that records exact package versions), then
installs the newest compatible PyPI release of `virtual-ecosystem`.

Note: `uv.lock` is shared across groups. So `uv lock --upgrade-package
virtual-ecosystem` can update lock entries for that package in multiple groups,
not only the one you are currently using.

### B) Update `dev` to the latest `develop` commit

Use this when you only want the `dev` group to move to the newest upstream
commit from `develop`:

```sh
uv sync --group dev --upgrade-package virtual-ecosystem
```

`--upgrade-package` asks `uv` to look for a newer allowed version/commit for
that package, instead of only reinstalling what is already pinned in `uv.lock`.

### C) Update the pinned `dev-pinned` commit

1. Edit `pyproject.toml` and change the pinned commit hash for the `dev-pinned`
   dependency.
2. Update `uv.lock` (the file that records exact package versions) and sync:

```sh
uv lock
uv sync --group dev-pinned
```

Then verify the new commit hash in `uv.lock`.

---

## Step 5: Confirm what is installed

The most reliable check is the output from `uv sync`: it shows the source
(PyPI or Git URL with commit hash).

If you want to verify afterwards, inspect `uv.lock` (the file that records
exact package versions):

```sh
grep -A 2 "name = \"virtual-ecosystem\"" uv.lock
```

`uv pip show virtual-ecosystem` is less useful here because it shows a version
tag but not the commit hash for GitHub builds, i.e., the release and dev
versions can have the same version tag.

---

## Step 6: Running `ve_run` (or any other commands or `.py` scripts)

Run commands or `.py` scripts with `uv run`. For example:

```sh
uv run ve_run ...
uv run my_script.py
```

> **Warning:** If you synced with `--group dev` or `--group dev-pinned`, pass
> the same group to `uv run` to avoid switching back to the default:
>
> ```sh
> uv run --group dev ve_run ...
> ```

If you are running many commands in one session, you can activate the virtual
environment just like the conventional way:

### Windows

```powershell
.venv\Scripts\activate
ve_run
```

### macOS / Linux

```sh
source .venv/bin/activate
ve_run
```
