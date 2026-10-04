import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PONYDONE = REPO_ROOT / "pony/bin/ponydone"
PONYALERT = REPO_ROOT / "pony/bin/ponyalert"
RUNTIME_DIR = REPO_ROOT / "pony/runtime"
AUDIO_HELPER = REPO_ROOT / "pony/scripts/pony-audio.sh"


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

    def test_host_request_uses_fifo_without_pid_namespace_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            fifo_path = temp_path / "audio.host.fifo"
            pid_path = temp_path / "audio.host.pid"
            output_path = temp_path / "request.txt"
            os.mkfifo(fifo_path)
            pid_path.write_text("999999999\n", encoding="utf-8")

            with output_path.open("wb") as output:
                reader = subprocess.Popen(["cat", str(fifo_path)], stdout=output)
                result = subprocess.run(
                    [
                        "bash",
                        "-c",
                        'source "$1"; pony_audio_request_host_play tool prefix /tmp/clip.wav clip stem',
                        "bash",
                        str(AUDIO_HELPER),
                    ],
                    capture_output=True,
                    text=True,
                    env={
                        **os.environ,
                        "AGENIC_PONY_AUDIO_HOST_FIFO": str(fifo_path),
                        "AGENIC_PONY_AUDIO_HOST_PID_FILE": str(pid_path),
                    },
                )
                reader.wait(timeout=2)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(fifo_path.is_fifo())
            self.assertEqual(pid_path.read_text(encoding="utf-8"), "999999999\n")
            self.assertEqual(
                output_path.read_text(encoding="utf-8"),
                "tool\tprefix\t/tmp/clip.wav\tclip\tstem\n",
            )

    def test_host_request_without_reader_preserves_launcher_state(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            fifo_path = temp_path / "audio.host.fifo"
            pid_path = temp_path / "audio.host.pid"
            os.mkfifo(fifo_path)
            pid_path.write_text("999999999\n", encoding="utf-8")

            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; pony_audio_request_host_play tool prefix /tmp/clip.wav clip stem',
                    "bash",
                    str(AUDIO_HELPER),
                ],
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PONY_AUDIO_HOST_FIFO": str(fifo_path),
                    "AGENIC_PONY_AUDIO_HOST_PID_FILE": str(pid_path),
                },
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(fifo_path.is_fifo())
            self.assertEqual(pid_path.read_text(encoding="utf-8"), "999999999\n")


if __name__ == "__main__":
    unittest.main()
