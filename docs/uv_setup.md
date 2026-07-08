# Setting up Python with `uv`

`uv` handles Python installation, virtual environments, and dependencies in one place.

## How it works

You can switch between versions of `virtual-ecosystem` with one command:

| What you want | Command |
|---|---|
| Stable release from PyPI | `uv sync` and `uv run ve_run ...` |
| Latest `develop` branch build | `uv sync --group dev` and `uv run --group dev ve_run ...` |
| Pinned known-good `develop` branch commit | `uv sync --group dev-stable` and `uv run --group dev-stable ve_run ...` |

That is the main workflow. No manual virtual-environment juggling needed.

The versions are defined in `pyproject.toml` in the project root.
If you find a newer commit hash that works well as the pinned `dev-stable` version,
you are welcome to update it via a Pull Request.

---

## Step 1: Install `uv`

=== "Windows"

    ```powershell
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    ```

=== "macOS / Linux"

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

- Install the Python version required by this project (from `.python-version`)
- Create a local `.venv` environment if needed
- Install project dependencies

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

### When do I need `--reinstall-package`?

Usually, you do not.
When you switch groups (`release` / `dev` / `dev-stable`), `uv sync` reinstalls
`virtual-ecosystem` automatically if needed.

Use this only when you want to upgrade `dev` to the newest upstream commit:

```sh
uv sync --group dev --reinstall-package virtual-ecosystem
```

---

## Step 4: Confirm what is installed

The most reliable check is the output from `uv sync`: it shows the source
(PyPI or Git URL with commit hash).

If you want to verify afterwards, inspect `uv.lock`:

```sh
grep -A 2 "name = \"virtual-ecosystem\"" uv.lock
```

`uv pip show virtual-ecosystem` is less useful here because it shows a version tag but
not the commit hash for GitHub builds, i.e., the release and dev versions can have the
same version tag.

---

## Step 5: Running `ve_run` (or any other commands or `.py` scripts)

Run commands or `.py` scripts with `uv run`. For example:

```sh
uv run ve_run ...
```

!!! warning "Use the same group in `uv run`"

    If you synced with `--group dev` or `--group dev-stable`, pass the same group to
    `uv run` to avoid switching back to the default:

    ```sh
    uv run --group dev ve_run ...
    ```

If you are running many commands in one session, you can activate the virtual
environment just like the conventional way:

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
