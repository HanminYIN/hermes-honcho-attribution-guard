from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import types
import unittest
import urllib.request


PROJECT_ROOT = Path(__file__).resolve().parents[1]
COMPATIBILITY = json.loads(
    (PROJECT_ROOT / "compatibility.json").read_text(encoding="utf-8")
)
BASELINE_URL = (
    "https://raw.githubusercontent.com/NousResearch/hermes-agent/"
    "v2026.8.3/plugins/memory/honcho/session.py"
)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_baseline() -> bytes:
    configured = os.environ.get("HERMES_BASELINE_FILE")
    if configured:
        data = Path(configured).read_bytes()
    else:
        with urllib.request.urlopen(BASELINE_URL, timeout=30) as response:
            data = response.read()
    expected = COMPATIBILITY["target"]["pristine_sha256"]
    if sha256_bytes(data) != expected:
        raise AssertionError("official baseline SHA256 mismatch")
    return data


def patch_baseline(baseline: bytes, root: Path) -> Path:
    target = root / COMPATIBILITY["target"]["path"]
    target.parent.mkdir(parents=True)
    target.write_bytes(baseline)
    subprocess.run(
        [
            "patch",
            "--batch",
            "--forward",
            "-p1",
            "-i",
            str(PROJECT_ROOT / COMPATIBILITY["patch"]["path"]),
        ],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    expected = COMPATIBILITY["target"]["patched_sha256"]
    if sha256_file(target) != expected:
        raise AssertionError("patched target SHA256 mismatch")
    return target


def import_patched_session(path: Path):
    for name in ("plugins", "plugins.memory", "plugins.memory.honcho"):
        module = types.ModuleType(name)
        module.__path__ = []
        sys.modules[name] = module

    client_module = types.ModuleType("plugins.memory.honcho.client")
    client_module.get_honcho_client = lambda: None
    sys.modules[client_module.__name__] = client_module

    module_name = "honcho_attribution_guard_test_session"
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise AssertionError("unable to load patched module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class AttributionBehaviorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tempdir = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tempdir.name)
        target = patch_baseline(load_baseline(), cls.root)
        cls.module = import_patched_session(target)
        cls.manager = cls.module.HonchoSessionManager.__new__(
            cls.module.HonchoSessionManager
        )
        cls.session = cls.module.HonchoSession(
            key="example-channel:example-session",
            user_peer_id="example-user",
            assistant_peer_id="example-assistant",
            honcho_session_id="example-session",
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tempdir.cleanup()

    def test_user_identity_and_pronoun_mapping(self) -> None:
        content, metadata, configuration = self.manager._format_honcho_content(
            self.session, "user", "I prefer tea; you prefer coffee."
        )
        self.assertEqual(content, "I prefer tea; you prefer coffee.")
        self.assertEqual(metadata["speaker_peer_id"], "example-user")
        self.assertEqual(metadata["addressee_peer_id"], "example-assistant")
        self.assertEqual(metadata["speaker_role"], "user")
        self.assertEqual(
            metadata["pronoun_map"],
            {
                "first_person": "example-user",
                "second_person": "example-assistant",
            },
        )
        instructions = configuration["reasoning"]["custom_instructions"]
        self.assertIn("First-person references", instructions)
        self.assertIn("Second-person references", instructions)

    def test_assistant_guess_remains_assistant_attributed(self) -> None:
        _, metadata, configuration = self.manager._format_honcho_content(
            self.session, "assistant", "You might prefer tea."
        )
        self.assertEqual(metadata["speaker_peer_id"], "example-assistant")
        self.assertEqual(metadata["addressee_peer_id"], "example-user")
        self.assertEqual(
            metadata["pronoun_map"],
            {
                "first_person": "example-assistant",
                "second_person": "example-user",
            },
        )
        instructions = configuration["reasoning"]["custom_instructions"]
        self.assertIn("unverified hypotheses", instructions)
        self.assertIn("never convert an unconfirmed assistant guess", instructions)

    def test_aliases_map_conversation_labels_without_overriding_peer_ids(self) -> None:
        manager = self.module.HonchoSessionManager.__new__(
            self.module.HonchoSessionManager
        )
        manager._identity_aliases = {
            "user": ["Example Person", "Example Alias"],
            "assistant": ["Example Assistant", "Helper Alias"],
        }
        _, metadata, configuration = manager._format_honcho_content(
            self.session,
            "assistant",
            "Example Alias may prefer tea.",
        )
        self.assertEqual(metadata["speaker_peer_id"], "example-assistant")
        self.assertEqual(
            metadata["speaker_aliases"],
            ["Example Assistant", "Helper Alias"],
        )
        self.assertEqual(metadata["addressee_peer_id"], "example-user")
        self.assertEqual(
            metadata["addressee_aliases"],
            ["Example Person", "Example Alias"],
        )
        instructions = configuration["reasoning"]["custom_instructions"]
        self.assertIn(
            "human-readable names in conversation to stable peer IDs",
            instructions,
        )
        self.assertIn("They never override speaker_peer_id", instructions)

    def test_runtime_loader_rejects_insecure_identity_profile_permissions(self) -> None:
        state = self.root / ".hermes-honcho-attribution-guard"
        state.mkdir(mode=0o700, exist_ok=True)
        profile = state / "identity.json"
        profile.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "scope": "single-user",
                    "user": {
                        "primary": "Example Person",
                        "aliases": ["Example Alias"],
                    },
                    "assistant": {
                        "primary": "Example Assistant",
                        "aliases": [],
                    },
                }
            ),
            encoding="utf-8",
        )
        profile.chmod(0o644)
        try:
            self.assertEqual(
                self.module._load_honcho_identity_aliases(),
                {"user": [], "assistant": []},
            )
        finally:
            profile.unlink()

    def test_runtime_loader_accepts_private_non_conflicting_aliases(self) -> None:
        state = self.root / ".hermes-honcho-attribution-guard"
        state.mkdir(mode=0o700, exist_ok=True)
        profile = state / "identity.json"
        profile.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "scope": "single-user",
                    "user": {
                        "primary": "Example Person",
                        "aliases": ["Example Alias"],
                    },
                    "assistant": {
                        "primary": "Example Assistant",
                        "aliases": ["Helper Alias"],
                    },
                }
            ),
            encoding="utf-8",
        )
        profile.chmod(0o600)
        try:
            self.assertEqual(
                self.module._load_honcho_identity_aliases(),
                {
                    "user": ["Example Person", "Example Alias"],
                    "assistant": ["Example Assistant", "Helper Alias"],
                },
            )
        finally:
            profile.unlink()

    def test_flush_passes_attribution_to_honcho_message(self) -> None:
        captured = []

        class FakePeer:
            def __init__(self, peer_id: str):
                self.peer_id = peer_id

            def message(self, content, *, metadata=None, configuration=None):
                value = {
                    "peer_id": self.peer_id,
                    "content": content,
                    "metadata": metadata,
                    "configuration": configuration,
                }
                captured.append(value)
                return value

        class FakeRemoteSession:
            def add_messages(self, messages):
                self.messages = messages

        manager = self.module.HonchoSessionManager.__new__(
            self.module.HonchoSessionManager
        )
        peers = {
            "example-user": FakePeer("example-user"),
            "example-assistant": FakePeer("example-assistant"),
        }
        manager._get_or_create_peer = peers.__getitem__
        manager._sessions_cache = {"example-session": FakeRemoteSession()}
        manager._cache_lock = threading.RLock()
        manager._cache = {}
        session = self.module.HonchoSession(
            key="example-channel:example-session",
            user_peer_id="example-user",
            assistant_peer_id="example-assistant",
            honcho_session_id="example-session",
            messages=[{"role": "assistant", "content": "A hypothesis."}],
        )

        self.assertTrue(manager._flush_session(session))
        self.assertEqual(captured[0]["metadata"]["speaker_role"], "assistant")
        self.assertEqual(
            captured[0]["configuration"]["reasoning"]["custom_instructions"].count(
                "assistant guess"
            ),
            1,
        )
        self.assertTrue(session.messages[0]["_synced"])

    def test_transient_and_duplicate_memory_is_filtered(self) -> None:
        source = "\n".join(
            [
                "- User prefers tea.",
                "- User is going to sleep.",
                "* user prefers tea!",
                "- 用户今晚准备睡觉了。",
                "- User has a stable dietary restriction.",
            ]
        )
        filtered = self.manager._filter_honcho_memory_text(source)
        self.assertEqual(filtered.count("prefers tea"), 1)
        self.assertNotIn("going to sleep", filtered)
        self.assertNotIn("准备睡觉", filtered)
        self.assertIn("stable dietary restriction", filtered)

    def test_duplicate_card_items_are_filtered(self) -> None:
        filtered = self.manager._filter_honcho_memory_items(
            ["User prefers tea.", "user prefers tea!", "Good night!", "Stable fact."]
        )
        self.assertEqual(filtered, ["User prefers tea.", "Stable fact."])


class InstallerSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.package = self.root / "package"
        self.hermes = self.root / "hermes"
        shutil.copytree(PROJECT_ROOT / "scripts", self.package / "scripts")
        (self.package / "patches").mkdir(parents=True)

        self.target_rel = Path("plugins/memory/honcho/session.py")
        self.pristine = b"line one\npristine line\n"
        self.patched = b"line one\npatched line\n"
        patch_data = (
            "--- a/plugins/memory/honcho/session.py\n"
            "+++ b/plugins/memory/honcho/session.py\n"
            "@@ -1,2 +1,2 @@\n"
            " line one\n"
            "-pristine line\n"
            "+patched line\n"
        ).encode()
        (self.package / "patches/test.patch").write_bytes(patch_data)

        self.compatibility = {
            "schema_version": 1,
            "package": {"name": "test-package", "version": "test-version"},
            "upstream": {
                "release_tag": "v2026.8.3",
                "python_package": {"version": "0.20.0"},
            },
            "target": {
                "path": self.target_rel.as_posix(),
                "pristine_sha256": sha256_bytes(self.pristine),
                "patched_sha256": sha256_bytes(self.patched),
            },
            "patch": {
                "path": "patches/test.patch",
                "strip": 1,
                "sha256": sha256_bytes(patch_data),
            },
        }
        (self.package / "compatibility.json").write_text(
            json.dumps(self.compatibility), encoding="utf-8"
        )
        self.write_hermes(version="0.20.0", content=self.pristine)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def write_hermes(self, *, version: str, content: bytes) -> None:
        self.hermes.mkdir(parents=True, exist_ok=True)
        (self.hermes / "pyproject.toml").write_text(
            f'[project]\nname = "hermes-agent"\nversion = "{version}"\n',
            encoding="utf-8",
        )
        target = self.hermes / self.target_rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)

    def run_script(self, name: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.package / "scripts" / name), str(self.hermes)],
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "LC_ALL": "C"},
        )

    def test_incompatible_version_is_rejected_without_backup(self) -> None:
        self.write_hermes(version="9.9.9", content=self.pristine)
        result = self.run_script("install.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.hermes / self.target_rel).read_bytes(), self.pristine)
        self.assertFalse(
            (self.hermes / ".hermes-honcho-attribution-guard").exists()
        )

    def test_incompatible_hash_is_rejected_without_backup(self) -> None:
        self.write_hermes(version="0.20.0", content=b"local modification\n")
        result = self.run_script("install.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            (self.hermes / self.target_rel).read_bytes(), b"local modification\n"
        )
        self.assertFalse(
            (self.hermes / ".hermes-honcho-attribution-guard").exists()
        )

    def test_patched_target_without_verified_backup_is_rejected(self) -> None:
        self.write_hermes(version="0.20.0", content=self.patched)
        result = self.run_script("install.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.hermes / self.target_rel).read_bytes(), self.patched)

    def test_symlinked_target_is_rejected(self) -> None:
        outside = self.root / "outside-session.py"
        outside.write_bytes(self.pristine)
        target = self.hermes / self.target_rel
        target.unlink()
        target.symlink_to(outside)

        result = self.run_script("install.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(outside.read_bytes(), self.pristine)

    def test_install_and_rollback_are_idempotent(self) -> None:
        first_install = self.run_script("install.sh")
        second_install = self.run_script("install.sh")
        self.assertEqual(first_install.returncode, 0, first_install.stderr)
        self.assertEqual(second_install.returncode, 0, second_install.stderr)
        self.assertIn("already installed", second_install.stdout)
        self.assertEqual((self.hermes / self.target_rel).read_bytes(), self.patched)

        backup = (
            self.hermes
            / ".hermes-honcho-attribution-guard/backups/v2026.8.3"
            / self.target_rel
        )
        self.assertEqual(backup.read_bytes(), self.pristine)

        first_rollback = self.run_script("rollback.sh")
        second_rollback = self.run_script("rollback.sh")
        self.assertEqual(first_rollback.returncode, 0, first_rollback.stderr)
        self.assertEqual(second_rollback.returncode, 0, second_rollback.stderr)
        self.assertIn("already rolled back", second_rollback.stdout)
        self.assertEqual((self.hermes / self.target_rel).read_bytes(), self.pristine)
        self.assertEqual(backup.read_bytes(), self.pristine)


class IdentityProfileToolTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        target = self.root / "plugins/memory/honcho/session.py"
        target.parent.mkdir(parents=True)
        target.write_text("# synthetic target\n", encoding="utf-8")
        self.tool = PROJECT_ROOT / "scripts/identity.py"

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_tool(
        self,
        command: str,
        *,
        input_text: str = "",
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(self.tool), command, str(self.root)],
            input=input_text,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_private_profile_write_show_and_clear(self) -> None:
        result = self.run_tool(
            "write",
            input_text=(
                "Example Person\n"
                "Example Alias,Example Name\n"
                "Example Assistant\n"
                "Helper Alias\n"
            ),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        profile = self.root / ".hermes-honcho-attribution-guard/identity.json"
        self.assertEqual(stat.S_IMODE(profile.stat().st_mode), 0o600)
        data = json.loads(profile.read_text(encoding="utf-8"))
        self.assertEqual(data["user"]["primary"], "Example Person")
        self.assertEqual(
            data["user"]["aliases"],
            ["Example Alias", "Example Name"],
        )

        shown = self.run_tool("show")
        self.assertEqual(shown.returncode, 0, shown.stderr)
        self.assertIn("Example Alias", shown.stdout)

        cleared = self.run_tool("clear")
        self.assertEqual(cleared.returncode, 0, cleared.stderr)
        self.assertFalse(profile.exists())

    def test_ambiguous_pronoun_alias_is_rejected(self) -> None:
        result = self.run_tool(
            "write",
            input_text="Example Person\nyou\nExample Assistant\n\n",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(
            (self.root / ".hermes-honcho-attribution-guard/identity.json").exists()
        )

    def test_cross_peer_alias_conflict_is_rejected(self) -> None:
        result = self.run_tool(
            "write",
            input_text=(
                "Example Person\nShared Alias\n"
                "Example Assistant\nShared Alias\n"
            ),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(
            (self.root / ".hermes-honcho-attribution-guard/identity.json").exists()
        )


if __name__ == "__main__":
    unittest.main()
