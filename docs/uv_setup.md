<!-- markdownlint-disable MD046 MD024 -->
# Setting up Python with `uv`

`uv` handles Python installation, virtual environments, and dependencies in one place.

## How it works

You can switch between versions of `virtual-ecosystem` with one command in the terminal:

| What you want | Sync command | Run command |
| --- | --- | --- |
| Stable release from PyPI | `uv sync` | `uv run ve_run ...` |
| Latest `develop` branch build | `uv sync --group dev` | `uv run --group dev ve_run ...` |
| Pinned known-good `develop` branch commit | `uv sync --group dev-stable` | `uv run --group dev-stable ve_run ...` |

You only maintain *one* virtual-environment folder `.venv`.
No juggling among multiple virtual environments.

The versions are defined in `pyproject.toml` in the project root.
If you find a newer commit hash that works well as the pinned `dev-stable` version,
you are welcome to update it via a Pull Request.
You can also add required dependencies in `pyproject.toml` for the team.

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

After [cloning the repository](getting_started.md#getting-the-repository), move into the
repository root and run:

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
uv sync --group dev-stable
```

Only one version is active at a time, and each command switches to that version.
Simply switching groups does not need any extra flags; `uv sync` will install
whatever version that group needs. See [Step 4](#step-4-update-virtual-ecosystem)
if you want to pull in new changes from upstream.

---

## Step 4: Update `virtual-ecosystem`

### A) Update to the latest PyPI release

Run:

```sh
uv lock --upgrade-package virtual-ecosystem
uv sync
```

This updates `uv.lock`, a file that records the exact versions of all packages
this project uses, and then installs the newest compatible release of
`virtual-ecosystem` from PyPI.

### B) Update `dev` to the latest `develop` commit

Use this when you want a fresh (re)install with the newest upstream changes from
the `develop` branch:

```sh
uv sync --group dev --reinstall-package virtual-ecosystem
```

The `--reinstall-package` flag tells `uv` to ignore its cache and download
`virtual-ecosystem` again, even if it already has a copy.

### C) Update the pinned `dev-stable` commit

1. Edit `pyproject.toml` and change the pinned commit hash for the `dev-stable`
   dependency.
2. Update `uv.lock` (the file that records exact package versions) and sync:

```sh
uv lock
uv sync --group dev-stable
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

`uv pip show virtual-ecosystem` is less useful here because it shows a version tag but
not the commit hash for GitHub builds, i.e., the release and dev versions can have the
same version tag.

---

## Step 6: Running `ve_run` (or any other commands or `.py` scripts)

Run commands or `.py` scripts with `uv run`. For example:

```sh
uv run ve_run ...
uv run my_script.py
```

> **Warning:**
> If you synced with `--group dev` or `--group dev-stable`, pass the same group to
> `uv run` to avoid switching back to the default:
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
