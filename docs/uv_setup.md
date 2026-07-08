# Setting up Python with `uv`

This guide covers how to install `uv`, set up the project's Python environment, and
switch between versions of the Virtual Ecosystem (`virtual-ecosystem`) package.

## Why `uv`?

This project previously used [Poetry](https://python-poetry.org/) for dependency management, which
required setting up three separate virtual environments by hand — one for each version of
`virtual-ecosystem` — and manually activating the right one before running any scripts. That
workflow placed a real burden on new contributors unfamiliar with Python tooling.

[`uv`](https://docs.astral.sh/uv/) removes most of that friction. It is a fast, all-in-one Python
package and environment manager that handles Python version installation, virtual environment
creation, and dependency resolution automatically. Switching between the three versions of
`virtual-ecosystem` is now a single command, and you never need to create or activate a virtual
environment by hand. `uv` is also significantly faster than Poetry at resolving and installing
packages.

If you have used Poetry before, the main difference in day-to-day use is that you replace
`poetry run` with `uv run`, and `poetry install` with `uv sync`. The concepts are similar, but the
setup overhead — especially for a project that tracks multiple versions of one package — is much
lower.

---

## Install `uv`

=== "Windows"

    ```powershell
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    ```

=== "macOS / Linux"

    ```sh
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```

Verify the installation:

```sh
uv --version
```

---

## Install project dependencies

After [cloning the repository](getting_started.md#getting-the-repository), navigate to
the project root and run:

```sh
uv sync
```

This will:

- Download and install the correct Python version automatically (as specified in
  `.python-version`)
- Create a `.venv` virtual environment in the project root if one does not already exist
- Install all project dependencies, including the `virtual-ecosystem` PyPI release

`uv sync` creates and populates the virtual environment, but does **not** activate it in
your current shell. You can use `uv run` to run commands inside it without activating, or
activate it manually — see [Running scripts](#running-scripts) below.

---

## Verify the installation

Check that `virtual-ecosystem` is installed:

```sh
uv pip show virtual-ecosystem
```

This shows the installed version tag, but **the version tag alone is not a reliable
indicator** — the PyPI release and GitHub builds all share the same version string
(e.g. `0.2.0`). `uv pip show` does not expose the commit hash.

The two more reliable ways to confirm what is installed are:

1. **Read the `uv sync` output** (the easiest option). When `uv sync` runs, it prints
   exactly what was installed, including the full commit hash for VCS sources:

    ```
    - virtual-ecosystem==0.2.0
    + virtual-ecosystem==0.2.0 (from git+https://github.com/.../virtual_ecosystem.git@3c6e752e...)
    ```

2. **Search `uv.lock`** for the resolved source. The lock file records all three versions
   with their full commit hashes. Run this from the project root:

    ```sh
    grep -A 2 "name = \"virtual-ecosystem\"" uv.lock
    ```

    The `source` field for each entry will show `registry = "https://pypi.org/simple"` for
    the PyPI release, or a `git = "..."` URL with the full commit hash for GitHub builds.

To see all installed packages:

```sh
uv pip freeze
```

---

## Switch between versions of Virtual Ecosystem

The project provides three versions of `virtual-ecosystem` to install. Use the
appropriate command depending on which version you need to test:

| Version | Description | Command |
|---|---|---|
| **release** | Latest stable release from PyPI (default) | `uv sync` |
| **dev** | Latest commit on the `main` GitHub branch | `uv sync --group dev` |
| **dev-stable** | A specific pinned commit know to "run well" | `uv sync --group dev-stable` |

Only one version is active at a time. Running any of the above commands will switch
your environment to that version.

### Force reinstall

When switching between the three groups, `uv sync` will automatically reinstall
`virtual-ecosystem` if the source URL changes (e.g. moving from PyPI to GitHub, or
between the two GitHub groups). You do not need to force reinstall in those cases.

Force reinstall is only necessary when re-running the **same group** and the remote
source has changed but the version tag has not — most commonly when the `dev` group
tracks the `main` branch and new commits have been pushed without a version bump:

```sh
uv sync --group dev --reinstall-package virtual-ecosystem
```

This is not needed for `dev-stable` (pinned to a fixed commit) or `release` (PyPI only
updates on new published versions).

---

## Verify a version switch

The most direct confirmation is the **`uv sync` output itself** — it prints the full
commit hash inline whenever a VCS package is installed or reinstalled. If you need to
check after the fact, search `uv.lock`:

```sh
grep -A 2 "name = \"virtual-ecosystem\"" uv.lock
```

Do not rely on `uv pip show`: it reports the version tag (`0.2.0`) but omits the commit
hash, making it impossible to distinguish between builds that share a tag.

---

## Running scripts

You can run commands without manually activating the virtual environment by prefixing with
`uv run`. For example, to run the Virtual Ecosystem CLI:

```sh
uv run ve_run
```

Or, in a more convention way, activate the environment once for the current terminal session and call commands directly:

=== "Windows"

    ```powershell
    .venv\Scripts\activate
    ve_run
    ```

=== "macOS / Linux"

    ```sh
    source .venv/bin/activate
    ve_run
    ```
