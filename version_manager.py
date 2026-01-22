#!/usr/bin/env python3
import datetime
import sys
import re
import os

VERSION_FILE = "VERSION"

def read_current_version():
    if not os.path.exists(VERSION_FILE):
        return "0.0.0"
    with open(VERSION_FILE, "r") as f:
        return f.read().strip()

def write_version(version):
    with open(VERSION_FILE, "w") as f:
        f.write(version)
    print(f"Version updated to: {version}")

def get_date_parts():
    now = datetime.datetime.now(datetime.timezone.utc)
    return now.year, now.month, now.strftime("%Y%m%d.%H%M")

def parse_version(version_str):
    # Regex to capture YYYY.MM.PATCH and optional suffix
    # e.g., 2026.01.5, 2026.01.5-beta, 2026.01.5-nightly.20260121.1200
    match = re.match(r"^(\d{4})\.(\d{1,2})\.(\d+)(?:-(.+))?$", version_str)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2)), int(match.group(3)), match.group(4)

def bump_version(release_type):
    current_version = read_current_version()
    parsed = parse_version(current_version)
    
    current_year, current_month, current_patch = 0, 0, 0
    
    if parsed:
        current_year, current_month, current_patch, _ = parsed
    
    now_year, now_month, timestamp = get_date_parts()
    
    # Calculate new base version
    new_year = now_year
    new_month = now_month
    new_patch = current_patch
    
    # Reset patch if month or year changed
    if new_year != current_year or new_month != current_month:
        new_patch = 1
    else:
        # Only increment patch if we are not just switching suffix on the same base
        # But per requirements: "Reset patch to 1 when month or year changes."
        # Use simpler logic: if it's a new release cycle for the same month, we might want to increment.
        # However, usually for "next" version we increment. 
        # For this script, let's assume if we run it, we want a NEW version.
        if release_type != 'current':
             new_patch += 1

    base_version = f"{new_year}.{new_month}.{new_patch}"
    
    if release_type == "stable":
        new_version = base_version
    elif release_type == "beta":
        new_version = f"{base_version}-beta"
    elif release_type == "nightly":
        new_version = f"{base_version}-nightly.{timestamp}"
    elif release_type == "dev":
        new_version = f"{base_version}-dev"
    elif release_type == "current":
        # Just return the current version re-formatted or verified? 
        # Actually usually used to just output current.
        print(current_version)
        return
    else:
        print(f"Unknown release type: {release_type}")
        sys.exit(1)
        
    write_version(new_version)
    # Output for GitHub Actions
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"version={new_version}\n")
    else:
        print(f"::set-output name=version::{new_version}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: version_manager.py <release_type>")
        print("Types: stable, beta, nightly, dev")
        sys.exit(1)
    
    bump_version(sys.argv[1])
