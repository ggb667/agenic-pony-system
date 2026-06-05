import os
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PONYDONE = REPO_ROOT / "pony/bin/ponydone"
PONYALERT = REPO_ROOT / "pony/bin/ponyalert"
RUNTIME_DIR = REPO_ROOT / "pony/runtime"


class PonyAudioBinTests(unittest.TestCase):
    def clean_env(self) -> dict[str, str]:
        env = dict(os.environ)
        env["PONYDEBUG"] = "1"
        env["AGENIC_PONY_AUDIO_HOST_FIFO"] = "/tmp/wrong-audio.host.fifo"
        env["AGENIC_PONY_AUDIO_HOST_PID_FILE"] = "/tmp/wrong-audio.host.pid"
        return env

    def test_ponydone_rejects_extra_args(self) -> None:
        result = subprocess.run(
            ["bash", str(PONYDONE), "dash", "PINKIE_PIE"],
            capture_output=True,
            text=True,
            env=self.clean_env(),
        )

        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage: ponydone [PERSONALITY]", result.stderr)

    def test_ponyalert_rejects_extra_args(self) -> None:
        result = subprocess.run(
            ["bash", str(PONYALERT), "dash", "PINKIE_PIE"],
            capture_output=True,
            text=True,
            env=self.clean_env(),
        )

        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage: ponyalert [PERSONALITY]", result.stderr)

    def test_ponydone_overrides_stale_audio_host_env(self) -> None:
        result = subprocess.run(
            ["bash", str(PONYDONE), "PINKIE_PIE"],
            capture_output=True,
            text=True,
            env=self.clean_env(),
        )

        self.assertEqual(result.returncode, 0)
        self.assertIn(str(RUNTIME_DIR / "audio.host.fifo"), result.stderr)
        self.assertNotIn("/tmp/wrong-audio.host.fifo", result.stderr)


if __name__ == "__main__":
    unittest.main()
