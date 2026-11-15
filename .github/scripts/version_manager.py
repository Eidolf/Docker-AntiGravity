#!/usr/bin/env python3
"""Compatibility CLI delegating version calculation to the root manager."""

from __future__ import annotations

import argparse
import datetime
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from version_manager import (
    VERSION_FILE,
    calculate_version,
    get_stable_tags,
    write_version,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--action",
        required=True,
        choices=("get-current", "calculate", "write"),
    )
    parser.add_argument("--type", choices=("stable", "nightly"))
    parser.add_argument("--version")
    args = parser.parse_args()

    try:
        if args.action == "get-current":
            print(VERSION_FILE.read_text(encoding="utf-8").strip())
        elif args.action == "calculate":
            if args.type is None:
                parser.error("--type is required for calculate")
            print(
                calculate_version(
                    args.type,
                    get_stable_tags(),
                    datetime.datetime.now(datetime.UTC),
                    os.environ.get("GITHUB_RUN_ID"),
                    os.environ.get("GITHUB_RUN_ATTEMPT"),
                )
            )
        else:
            if args.version is None:
                parser.error("--version is required for write")
            write_version(args.version)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
