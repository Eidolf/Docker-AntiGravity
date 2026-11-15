#!/usr/bin/env python3
"""Calculate Docker-AntiGravity release versions from stable Git tags."""

from __future__ import annotations

import argparse
import datetime
import os
import re
import subprocess
import sys
from pathlib import Path

VERSION_FILE = Path(__file__).resolve().with_name("VERSION")
STABLE_TAG_PATTERN = re.compile(r"^v?(\d{4})\.(\d{1,2})\.(\d+)$")


def parse_stable_tag(tag: str) -> tuple[int, int, int] | None:
    """Parse a stable CalVer tag, accepting unprefixed historical tags."""
    match = STABLE_TAG_PATTERN.fullmatch(tag)
    if match is None:
        return None

    year, month, patch = (int(part) for part in match.groups())
    if not 1 <= month <= 12 or patch < 1:
        return None
    return year, month, patch


def stable_patch_for_month(tags: list[str], year: int, month: int) -> int:
    """Return the next patch based only on stable tags in the given month."""
    stable_versions = [
        version
        for tag in tags
        if (version := parse_stable_tag(tag)) is not None
    ]
    latest_stable = max(stable_versions, default=None)
    if latest_stable is not None and latest_stable[:2] > (year, month):
        raise ValueError(
            "Latest stable tag "
            f"{latest_stable[0]}.{latest_stable[1]}.{latest_stable[2]} "
            "is from a future UTC month"
        )

    patches = [
        patch
        for tag_year, tag_month, patch in stable_versions
        if (tag_year, tag_month) == (year, month)
    ]
    return max(patches, default=0) + 1


def get_stable_tags() -> list[str]:
    """Read all local Git tags; callers must fetch full history first."""
    result = subprocess.run(
        ["git", "tag", "--list"],
        check=True,
        capture_output=True,
        text=True,
        cwd=Path(__file__).resolve().parent,
    )
    return result.stdout.splitlines()


def calculate_version(
    release_type: str,
    stable_tags: list[str],
    now: datetime.datetime,
    run_id: str | None = None,
    run_attempt: str | None = None,
) -> str:
    """Calculate a Stable candidate or unique Nightly from stable tag history."""
    if release_type not in {"stable", "nightly"}:
        raise ValueError(f"Unknown release type: {release_type}")
    if now.tzinfo is None:
        raise ValueError("The release timestamp must be timezone-aware")

    utc_now = now.astimezone(datetime.UTC)
    patch = stable_patch_for_month(stable_tags, utc_now.year, utc_now.month)
    base = f"{utc_now.year}.{utc_now.month}.{patch}"

    if release_type == "stable":
        return base

    if run_id is None:
        run_id = f"local{utc_now.strftime('%Y%m%d%H%M%S%f')}"
    if not re.fullmatch(r"[A-Za-z0-9-]+", run_id):
        raise ValueError("Run ID must contain only letters, numbers, and hyphens")
    attempt = run_attempt or "1"
    if not re.fullmatch(r"\d+", attempt):
        raise ValueError("Run attempt must be a positive integer")
    timestamp = utc_now.strftime("%Y%m%d.%H%M")
    return f"{base}-nightly.{timestamp}.{run_id}.{attempt}"


def write_version(version: str) -> None:
    VERSION_FILE.write_text(f"{version}\n", encoding="utf-8")


def generate_version(
    release_type: str,
    stable_tags: list[str],
    now: datetime.datetime,
    run_id: str | None = None,
    run_attempt: str | None = None,
) -> str:
    """Generate a release version, recording only Stable in VERSION."""
    version = calculate_version(
        release_type, stable_tags, now, run_id, run_attempt
    )
    if release_type == "stable":
        write_version(version)
    return version


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release_type", choices=("nightly", "stable"))
    args = parser.parse_args()

    try:
        version = generate_version(
            args.release_type,
            get_stable_tags(),
            datetime.datetime.now(datetime.UTC),
            os.environ.get("GITHUB_RUN_ID"),
            os.environ.get("GITHUB_RUN_ATTEMPT"),
        )
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as output:
            output.write(f"version={version}\n")
    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
