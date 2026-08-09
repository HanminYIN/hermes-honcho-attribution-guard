#!/usr/bin/env python3
"""Manage the private, local identity-alias profile used by the patch."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys


STATE_DIRECTORY = ".hermes-honcho-attribution-guard"
PROFILE_FILENAME = "identity.json"
TARGET_RELATIVE = Path("plugins/memory/honcho/session.py")
MAX_ALIASES = 10
MAX_LABEL_LENGTH = 64
ALLOWED_PUNCTUATION = frozenset(" _-.·'")
AMBIGUOUS_LABELS = frozenset(
    {
        "i",
        "me",
        "my",
        "we",
        "you",
        "your",
        "they",
        "我",
        "我的",
        "我们",
        "你",
        "你的",
        "你们",
        "他",
        "她",
        "它",
    }
)


class ProfileError(ValueError):
    """Raised when an identity profile would be unsafe or ambiguous."""


def normalize_label(value: object) -> str:
    if not isinstance(value, str):
        raise ProfileError("identity labels must be strings")
    normalized = " ".join(value.split())
    if not normalized:
        raise ProfileError("identity labels cannot be empty")
    if len(normalized) > MAX_LABEL_LENGTH:
        raise ProfileError(f"identity labels must be at most {MAX_LABEL_LENGTH} characters")
    if normalized.casefold() in AMBIGUOUS_LABELS:
        raise ProfileError(f"ambiguous pronouns cannot be aliases: {normalized!r}")
    if any(
        not char.isalnum() and char not in ALLOWED_PUNCTUATION
        for char in normalized
    ):
        raise ProfileError(
            "identity labels may contain letters, numbers, spaces, hyphens, "
            "underscores, periods, apostrophes, and middle dots only"
        )
    return normalized


def parse_aliases(value: str) -> list[str]:
    parts = value.replace("，", ",").split(",") if value.strip() else []
    aliases: list[str] = []
    seen: set[str] = set()
    for part in parts:
        label = normalize_label(part)
        key = label.casefold()
        if key not in seen:
            seen.add(key)
            aliases.append(label)
    if len(aliases) > MAX_ALIASES:
        raise ProfileError(f"no more than {MAX_ALIASES} aliases are allowed per peer")
    return aliases


def normalize_entry(primary: str, aliases: list[str], *, required: bool) -> dict[str, object]:
    primary = primary.strip()
    if not primary and not required:
        if aliases:
            raise ProfileError("an assistant primary name is required when assistant aliases exist")
        return {"primary": "", "aliases": []}
    normalized_primary = normalize_label(primary)
    primary_key = normalized_primary.casefold()
    normalized_aliases = [
        alias for alias in aliases if alias.casefold() != primary_key
    ]
    return {"primary": normalized_primary, "aliases": normalized_aliases}


def build_profile(
    user_primary: str,
    user_aliases: str,
    assistant_primary: str,
    assistant_aliases: str,
) -> dict[str, object]:
    user = normalize_entry(user_primary, parse_aliases(user_aliases), required=True)
    assistant = normalize_entry(
        assistant_primary,
        parse_aliases(assistant_aliases),
        required=False,
    )
    user_labels = {str(user["primary"]).casefold()}
    user_labels.update(str(value).casefold() for value in user["aliases"])
    assistant_labels = set()
    if assistant["primary"]:
        assistant_labels.add(str(assistant["primary"]).casefold())
    assistant_labels.update(
        str(value).casefold() for value in assistant["aliases"]
    )
    conflicts = sorted(user_labels & assistant_labels)
    if conflicts:
        raise ProfileError(
            "the same label cannot belong to both peers: " + ", ".join(conflicts)
        )
    return {
        "schema_version": 1,
        "scope": "single-user",
        "user": user,
        "assistant": assistant,
    }


def resolve_paths(root_value: str) -> tuple[Path, Path, Path]:
    root = Path(root_value).expanduser().resolve(strict=True)
    target = root / TARGET_RELATIVE
    if not target.is_file() or target.is_symlink():
        raise ProfileError(f"Hermes target is missing or unsafe: {target}")
    state_directory = root / STATE_DIRECTORY
    profile_path = state_directory / PROFILE_FILENAME
    if state_directory.is_symlink() or profile_path.is_symlink():
        raise ProfileError("identity profile path contains a symbolic link")
    return root, state_directory, profile_path


def validate_loaded_profile(value: object) -> dict[str, object]:
    if (
        not isinstance(value, dict)
        or value.get("schema_version") != 1
        or value.get("scope") != "single-user"
    ):
        raise ProfileError("unsupported identity profile schema")
    user = value.get("user")
    assistant = value.get("assistant")
    if not isinstance(user, dict) or not isinstance(assistant, dict):
        raise ProfileError("identity profile entries must be objects")
    user_aliases = user.get("aliases", [])
    assistant_aliases = assistant.get("aliases", [])
    user_primary = user.get("primary", "")
    assistant_primary = assistant.get("primary", "")
    if not isinstance(user_primary, str) or not isinstance(assistant_primary, str):
        raise ProfileError("identity primary names must be strings")
    if not isinstance(user_aliases, list) or not all(
        isinstance(item, str) for item in user_aliases
    ):
        raise ProfileError("user aliases must be a list of strings")
    if not isinstance(assistant_aliases, list) or not all(
        isinstance(item, str) for item in assistant_aliases
    ):
        raise ProfileError("assistant aliases must be a list of strings")
    return build_profile(
        user_primary,
        ",".join(user_aliases),
        assistant_primary,
        ",".join(assistant_aliases),
    )


def load_profile(profile_path: Path) -> dict[str, object]:
    if not profile_path.exists():
        raise FileNotFoundError(profile_path)
    if not profile_path.is_file() or profile_path.is_symlink():
        raise ProfileError("identity profile is not a safe regular file")
    if profile_path.stat().st_mode & 0o077:
        raise ProfileError("identity profile permissions must be 0600")
    with profile_path.open(encoding="utf-8") as handle:
        return validate_loaded_profile(json.load(handle))


def write_profile(state_directory: Path, profile_path: Path, profile: dict[str, object]) -> None:
    if state_directory.exists() and not state_directory.is_dir():
        raise ProfileError("identity state path is not a directory")
    state_directory.mkdir(mode=0o700, exist_ok=True)
    os.chmod(state_directory, 0o700)
    temporary = state_directory / f".{PROFILE_FILENAME}.tmp.{os.getpid()}"
    if temporary.exists() or temporary.is_symlink():
        raise ProfileError("temporary identity profile path already exists")

    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(profile, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, profile_path)
        os.chmod(profile_path, 0o600)
    finally:
        if temporary.exists():
            temporary.unlink()


def command_write(root_value: str) -> int:
    lines = sys.stdin.read().splitlines()
    if len(lines) != 4:
        raise ProfileError("write expects four input lines")
    _, state_directory, profile_path = resolve_paths(root_value)
    profile = build_profile(*lines)
    write_profile(state_directory, profile_path, profile)
    print(f"identity profile saved: {profile_path}")
    return 0


def command_show(root_value: str) -> int:
    _, _, profile_path = resolve_paths(root_value)
    try:
        profile = load_profile(profile_path)
    except FileNotFoundError:
        print("identity profile: not configured")
        return 0
    print(json.dumps(profile, ensure_ascii=False, indent=2, sort_keys=True))
    print(f"identity profile path: {profile_path}")
    return 0


def command_exists(root_value: str) -> int:
    _, _, profile_path = resolve_paths(root_value)
    if not profile_path.exists():
        return 1
    load_profile(profile_path)
    return 0


def command_clear(root_value: str) -> int:
    _, _, profile_path = resolve_paths(root_value)
    if not profile_path.exists():
        print("identity profile already absent")
        return 0
    load_profile(profile_path)
    profile_path.unlink()
    print("identity profile cleared; it cannot be recovered without a separate copy")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("write", "show", "exists", "clear"))
    parser.add_argument("hermes_root")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    commands = {
        "write": command_write,
        "show": command_show,
        "exists": command_exists,
        "clear": command_clear,
    }
    try:
        return commands[args.command](args.hermes_root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
