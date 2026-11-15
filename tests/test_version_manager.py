import datetime
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from version_manager import calculate_version, generate_version, parse_stable_tag

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CREATE_TAG_SCRIPT = PROJECT_ROOT / "scripts" / "create-release-tag.sh"


def run_git(repository: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repository,
        check=True,
        capture_output=True,
        text=True,
    )


class VersionManagerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime.datetime(2026, 11, 15, 22, 49, tzinfo=datetime.UTC)

    def test_new_month_starts_at_patch_one(self) -> None:
        version = calculate_version(
            "stable",
            ["v2026.10.8", "2026.9.4", "2025.11.12"],
            self.now,
        )

        self.assertEqual(version, "2026.11.1")

    def test_nightlies_and_first_stable_share_candidate(self) -> None:
        tags = ["2026.11.2", "v2026.10.8"]
        first_nightly = calculate_version(
            "nightly", tags, self.now, run_id="731", run_attempt="1"
        )
        second_nightly = calculate_version(
            "nightly", tags, self.now, run_id="732", run_attempt="1"
        )
        stable = calculate_version("stable", tags, self.now)

        self.assertTrue(first_nightly.startswith("2026.11.3-nightly."))
        self.assertTrue(second_nightly.startswith("2026.11.3-nightly."))
        self.assertEqual(
            first_nightly,
            "2026.11.3-nightly.20261115.2249.731.1",
        )
        self.assertNotEqual(first_nightly, second_nightly)
        self.assertEqual(stable, "2026.11.3")

    def test_stable_tag_advances_next_stable_patch(self) -> None:
        version = calculate_version(
            "stable",
            ["2026.11.2", "v2026.11.3", "v2026.11.3-nightly.20261115.224900.731.1"],
            self.now,
        )

        self.assertEqual(version, "2026.11.4")

    def test_legacy_stable_tags_are_recognized_but_prereleases_are_ignored(self) -> None:
        self.assertEqual(parse_stable_tag("2026.11.3"), (2026, 11, 3))
        self.assertEqual(parse_stable_tag("v2026.11.4"), (2026, 11, 4))
        self.assertIsNone(parse_stable_tag("v2026.11.9-nightly.20261115.2249.731.1"))
        self.assertIsNone(parse_stable_tag("v2026.13.1"))

    def test_only_stable_and_nightly_are_supported(self) -> None:
        with self.assertRaises(ValueError):
            calculate_version("beta", [], self.now)

    def test_future_stable_tag_is_rejected(self) -> None:
        for release_type in ("stable", "nightly"):
            with self.subTest(release_type=release_type), self.assertRaisesRegex(
                ValueError, "future UTC month"
            ):
                calculate_version(
                    release_type,
                    ["v2026.12.1"],
                    self.now,
                    run_id="731",
                )

    def test_only_stable_updates_version_metadata(self) -> None:
        with patch("version_manager.write_version") as write_version:
            nightly = generate_version(
                "nightly", ["2026.11.2"], self.now, "731", "1"
            )
            write_version.assert_not_called()

            stable = generate_version("stable", ["2026.11.2"], self.now)
            write_version.assert_called_once_with("2026.11.3")

        self.assertTrue(nightly.startswith("2026.11.3-nightly."))
        self.assertEqual(stable, "2026.11.3")

    def test_release_tag_creation_is_idempotent_and_rejects_retargeting(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix=".release-tag-test-", dir=PROJECT_ROOT
        ) as directory:
            root = Path(directory)
            remote = root / "remote.git"
            repository = root / "working"
            repository.mkdir()
            run_git(root, "init", "--bare", "--quiet", str(remote))
            run_git(repository, "init", "--quiet")
            run_git(repository, "config", "user.name", "Release Test")
            run_git(repository, "config", "user.email", "release-test@example.com")
            (repository / "release.txt").write_text("first\n", encoding="utf-8")
            run_git(repository, "add", "release.txt")
            run_git(repository, "commit", "--quiet", "-m", "first")
            release_sha = run_git(repository, "rev-parse", "HEAD").stdout.strip()
            run_git(repository, "remote", "add", "origin", str(remote))
            run_git(repository, "push", "--quiet", "origin", "HEAD:main")

            command = [
                "bash",
                str(CREATE_TAG_SCRIPT),
                "v2026.11.3",
                release_sha,
            ]
            for _ in range(2):
                result = subprocess.run(
                    command,
                    check=False,
                    cwd=repository,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            (repository / "release.txt").write_text("second\n", encoding="utf-8")
            run_git(repository, "add", "release.txt")
            run_git(repository, "commit", "--quiet", "-m", "second")
            different_sha = run_git(repository, "rev-parse", "HEAD").stdout.strip()
            result = subprocess.run(
                [
                    "bash",
                    str(CREATE_TAG_SCRIPT),
                    "v2026.11.3",
                    different_sha,
                ],
                check=False,
                cwd=repository,
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("already points to", result.stderr)
            tag_sha = run_git(repository, "rev-parse", "v2026.11.3^{commit}").stdout.strip()
            remote_tag_sha = run_git(
                repository, "ls-remote", "origin", "refs/tags/v2026.11.3"
            ).stdout.split()[0]
            self.assertEqual(tag_sha, release_sha)
            self.assertEqual(remote_tag_sha, release_sha)


if __name__ == "__main__":
    unittest.main()
