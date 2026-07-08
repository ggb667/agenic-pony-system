from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = REPO_ROOT / "scripts" / "validate-installed-runtime.sh"
FINGERPRINT = REPO_ROOT / "pony" / "scripts" / "runtime-fingerprint.sh"


class ValidateInstalledRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.project_root = Path(self.tempdir.name) / "sample-project"
        (self.project_root / "pony" / "runtime").mkdir(parents=True)
        (self.project_root / "pony" / "launch.prompts").mkdir(parents=True)
        (self.project_root / "pony" / "scripts").mkdir(parents=True)
        (self.project_root / "pony" / "bin").mkdir(parents=True)

        self.source_fingerprint = subprocess.run(
            [str(FINGERPRINT)],
            check=True,
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        ).stdout.strip()

        (self.project_root / "pony" / "runtime" / "install-project.state").write_text(
            "complete\n", encoding="utf-8"
        )
        (self.project_root / "pony" / "runtime" / "install-project.metadata").write_text(
            "\n".join(
                [
                    "last_completed_at: 2026-07-08T00:00:00Z",
                    f"source_runtime_fingerprint: {self.source_fingerprint}",
                    f"project_root: {self.project_root}",
                    "project_branch: main",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        (self.project_root / "pony" / "runtime" / "source-runtime.fingerprint").write_text(
            f"{self.source_fingerprint}\n", encoding="utf-8"
        )

        shutil.copy2(REPO_ROOT / "pony" / "launch.prompts" / "twi.txt", self.project_root / "pony" / "launch.prompts" / "twi.txt")
        shutil.copy2(
            REPO_ROOT / "pony" / "scripts" / "launch-in-pony-shell.sh",
            self.project_root / "pony" / "scripts" / "launch-in-pony-shell.sh",
        )

        (self.project_root / "pony" / "scripts" / "resolve-system-root.sh").write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' '/tmp/source-root'\n",
            encoding="utf-8",
        )
        (self.project_root / "pony" / "bin" / "codex-pony").write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\nsource_root=\"$(\"/tmp/sample/resolve-system-root.sh\" \"/tmp/sample\")\"\nexec \"$source_root/pony/bin/codex-pony\" \"$@\"\n",
            encoding="utf-8",
        )
        pony_tell = self.project_root / "pony" / "bin" / "pony-tell"
        pony_tell.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        pony_tell.chmod(0o755)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_validator_passes_for_current_expected_runtime_surface(self) -> None:
        result = subprocess.run(
            [str(VALIDATOR), str(self.project_root)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Installed runtime validation passed", result.stdout)
        self.assertIn("source and installed pony-tell are executable", result.stdout)

    def test_validator_reports_stale_prompt_and_fingerprint(self) -> None:
        (self.project_root / "pony" / "runtime" / "source-runtime.fingerprint").write_text(
            "stale-fingerprint\n", encoding="utf-8"
        )
        (self.project_root / "pony" / "launch.prompts" / "twi.txt").write_text(
            "Read:\n8. `README.md`\n9. `docs/runtime-loop.md`\n10. `docs/project-installation.md`\n",
            encoding="utf-8",
        )

        result = subprocess.run(
            [str(VALIDATOR), str(self.project_root)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Installed runtime validation FAILED", result.stdout)
        self.assertIn("installed runtime fingerprint is stale", result.stdout)
        self.assertIn("installed Twilight prompt still contains stale text", result.stdout)


if __name__ == "__main__":
    unittest.main()
