#!/usr/bin/env python3
import json
import os
import stat
import sys
import tempfile
from pathlib import Path


SETTING = "security.workspace.trust.enabled"


def _blank_comments(text):
    chars = list(text)
    index = 0
    in_string = False

    while index < len(chars):
        if in_string:
            if chars[index] == "\\":
                index += 2
                continue
            if chars[index] == '"':
                in_string = False
            index += 1
            continue

        if chars[index] == '"':
            in_string = True
            index += 1
            continue

        if text.startswith("//", index):
            end = index + 2
            while end < len(chars) and chars[end] not in "\r\n":
                end += 1
            for position in range(index, end):
                chars[position] = " "
            index = end
            continue

        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated block comment")
            for position in range(index, end + 2):
                if chars[position] not in "\r\n":
                    chars[position] = " "
            index = end + 2
            continue

        index += 1

    return "".join(chars)


def _remove_trailing_commas(text):
    chars = list(text)
    index = 0

    while index < len(chars):
        if chars[index] == '"':
            index += 1
            while index < len(chars):
                if chars[index] == "\\":
                    index += 2
                elif chars[index] == '"':
                    index += 1
                    break
                else:
                    index += 1
            continue

        if chars[index] == ",":
            next_index = index + 1
            while next_index < len(chars) and chars[next_index].isspace():
                next_index += 1
            if next_index < len(chars) and chars[next_index] in "}]":
                chars[index] = " "
        index += 1

    return "".join(chars)


def _find_root_false_values(text, key):
    decoder = json.JSONDecoder()
    depth = 0
    index = 0
    spans = []

    while index < len(text):
        if text[index] == '"':
            value, end = decoder.raw_decode(text, index)
            if depth == 1 and isinstance(value, str):
                cursor = end
                while cursor < len(text) and text[cursor].isspace():
                    cursor += 1
                if cursor < len(text) and text[cursor] == ":" and value == key:
                    cursor += 1
                    while cursor < len(text) and text[cursor].isspace():
                        cursor += 1
                    if text.startswith("false", cursor):
                        spans.append((cursor, cursor + len("false")))
            index = end
            continue

        if text[index] in "{[":
            depth += 1
        elif text[index] in "}]":
            depth -= 1
        index += 1

    return spans


def enable_workspace_trust(path):
    original = path.read_text(encoding="utf-8")
    bom = "\ufeff" if original.startswith("\ufeff") else ""
    content = original[len(bom) :]
    sanitized = _remove_trailing_commas(_blank_comments(content))
    settings = json.loads(sanitized)
    if not isinstance(settings, dict):
        raise ValueError("VS Code settings must contain a JSON object")
    if settings.get(SETTING) is not False:
        return

    spans = _find_root_false_values(sanitized, SETTING)
    if not spans:
        raise ValueError(f"Could not locate {SETTING} in VS Code settings")
    updated = content
    for start, end in reversed(spans):
        updated = updated[:start] + "true" + updated[end:]
    updated = bom + updated

    original_mode = stat.S_IMODE(path.stat().st_mode)
    descriptor, temporary_path = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as temporary_file:
            temporary_file.write(updated)
        os.chmod(temporary_path, original_mode)
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} SETTINGS_JSONC", file=sys.stderr)
        return 2
    try:
        enable_workspace_trust(Path(sys.argv[1]))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
