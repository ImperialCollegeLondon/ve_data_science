"""A module providing the main command line interface for the maintenance tool."""

import argparse
import sys
import textwrap
from pathlib import Path

from maintenance_tool.data_directories import (
    check_all_data_directories,
    check_data_directory,
)
from maintenance_tool.globus import globus_sync
from maintenance_tool.script_directories import check_script_directory


def maintenance_tool_cli(args_list: list[str] | None = None) -> int:
    """A maintenance tool for use with ve_data_science.

    Args:
        args_list: This is a developer and testing facing argument that is used to
            simulate command line arguments, allowing this function to be called
            directly. For example, ``ve_run --install-example /usr/abc`` can be
            replicated by calling ``ve_run_cli(['--install-example', '/usr/abc/'])``.

    Returns:
        An integer indicating success (0) or failure (1)
    """  # noqa : 401

    # If no arguments list is provided
    if args_list is None:
        args_list = sys.argv[1:]

    # Check function docstring exists to safeguard against -OO mode, and strip off the
    # description of the function args_list, which should not be included in the command
    # line docs
    if maintenance_tool_cli.__doc__ is not None:
        desc = textwrap.dedent(
            "\n".join(maintenance_tool_cli.__doc__.splitlines()[:-10])
        )
    else:
        desc = "Python in -OO mode: no docs"

    fmt = argparse.RawDescriptionHelpFormatter
    parser = argparse.ArgumentParser(description=desc, formatter_class=fmt)

    subparsers = parser.add_subparsers(dest="subcommand", metavar="")

    check_script_directory_subparser = subparsers.add_parser(
        "check_script_directory",
        description="Check a script directory",
        help="Check a script directory",
    )

    check_script_directory_subparser.add_argument(
        "directory",
        type=Path,
        help="Path to the directory to check",
    )

    check_script_directory_subparser.add_argument(
        "repository_root",
        type=Path,
        nargs="?",
        help="Optional path to repository root.",
    )

    check_data_directory_subparser = subparsers.add_parser(
        "check_data_directory",
        description="Check a data directory",
        help="Check a data directory",
    )

    check_data_directory_subparser.add_argument(
        "directory",
        type=Path,
        help="Path to the directory to check",
    )

    check_data_directory_subparser.add_argument(
        "repository_root",
        type=Path,
        nargs="?",
        help="Optional path to repository root.",
    )

    check_all_data_directories_subparser = subparsers.add_parser(
        "check_all_data_directories",
        description="Check all data directories",
        help="Check all data directories",
    )

    check_all_data_directories_subparser.add_argument(
        "data_root",
        type=Path,
        default=Path("data"),
        nargs="?",
        help="Path to the root data directory",
    )

    check_all_data_directories_subparser.add_argument(
        "repository_root",
        type=Path,
        nargs="?",
        help="Optional path to repository root.",
    )

    globus_sync_subparser = subparsers.add_parser(
        "globus_sync",
        description="Synchronise data with GLOBUS",
        help="Synchronise data with GLOBUS",
    )

    globus_sync_subparser.add_argument(
        "config_path",
        type=Path,
        default=Path("./globus_config.yaml"),
        help="Path to the GLOBUS config directory",
    )

    args = parser.parse_args(args=args_list)

    match args.subcommand:
        case "check_script_directory":
            root = Path.cwd() if args.repository_root is None else args.repository_root
            check_script_directory(directory=args.directory, repository_root=root)

        case "check_data_directory":
            root = Path.cwd() if args.repository_root is None else args.repository_root
            check_data_directory(directory=args.directory, repository_root=root)
        case "check_all_data_directories":
            root = Path.cwd() if args.repository_root is None else args.repository_root
            check_all_data_directories(data_root=args.data_root, repository_root=root)
        case "globus_sync":
            globus_sync(args.config_path)

    return 1


if __name__ == "__main__":
    maintenance_tool_cli()
