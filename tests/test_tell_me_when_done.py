import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HELPER = REPO_ROOT / "pony" / "bin" / "tellMeWhenDone"


class TellMeWhenDoneTests(unittest.TestCase):
    def make_bin(self, root: Path) -> tuple[Path, Path]:
        bin_dir = root / "pony" / "bin"
        bin_dir.mkdir(parents=True)
        helper = bin_dir / "tellMeWhenDone"
        shutil.copy2(HELPER, helper)
        helper.chmod(0o755)

        capture = root / "tell.args"
        pony_tell = bin_dir / "pony-tell"
        pony_tell.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\0' \"$@\" >\"$TELL_CAPTURE\"\n"
            "printf tell-out\n"
            "printf tell-err >&2\n"
            "exit \"${TELL_RC:-0}\"\n",
            encoding="utf-8",
        )
        pony_tell.chmod(0o755)
        return helper, capture

    def run_helper(
        self, helper: Path, capture: Path, *args: str, tell_rc: int = 0
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(helper), *args],
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "TELL_CAPTURE": str(capture),
                "TELL_RC": str(tell_rc),
            },
        )

    def read_tell_args(self, capture: Path) -> list[str]:
        return capture.read_bytes().rstrip(b"\0").decode().split("\0")

    def test_preserves_output_and_success_while_sending_structured_notice(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            helper, capture = self.make_bin(Path(tmpdir))
            result = self.run_helper(
                helper,
                capture,
                "--to",
                "Twilight Sparkle",
                "--",
                "bash",
                "-c",
                "printf command-out; printf command-err >&2",
            )

            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "command-out")
            self.assertEqual(result.stderr, "command-err")
            target, message = self.read_tell_args(capture)
            self.assertEqual(target, "Twilight Sparkle")
            self.assertTrue(message.startswith("Subject: done\nBody: "))
            self.assertIn("bash -c", message)
            self.assertTrue(message.endswith("(exit=0)"))

    def test_notification_failure_never_masks_command_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            helper, capture = self.make_bin(Path(tmpdir))
            result = self.run_helper(
                helper,
                capture,
                "bash",
                "-c",
                "printf failed-out; printf failed-err >&2; exit 7",
                tell_rc=23,
            )

            self.assertEqual(result.returncode, 7)
            self.assertEqual(result.stdout, "failed-out")
            self.assertEqual(result.stderr, "failed-err")
            target, message = self.read_tell_args(capture)
            self.assertEqual(target, "all")
            self.assertTrue(message.startswith("Subject: done\nBody: "))
            self.assertTrue(message.endswith("(exit=7)"))

    def test_missing_command_is_usage_error_without_notification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            helper, capture = self.make_bin(Path(tmpdir))
            result = self.run_helper(helper, capture)

            self.assertEqual(result.returncode, 64)
            self.assertIn("Usage:", result.stderr)
            self.assertFalse(capture.exists())


if __name__ == "__main__":
    unittest.main()
