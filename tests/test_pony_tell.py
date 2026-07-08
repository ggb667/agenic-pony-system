import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PONY_TELL = REPO_ROOT / "pony/bin/pony-tell"


class PonyTellTests(unittest.TestCase):
    def test_pony_tell_appends_live_chat_entry(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            project_root.mkdir()
            chat_log = tmp / "chat.jsonl"
            registry_log = tmp / "registry.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "twi-uuid",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "aj-uuid",
                                "pony_name": "APPLEJACK",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 101,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["bash", str(PONY_TELL), "twi", "ping from AJ"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_LAUNCH_PERSONALITY": "APPLEJACK",
                    "AGENIC_PONY_CHAT_LOG_PATH": str(chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            self.assertTrue(result.stdout.strip())
            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["from_instance_id"], "aj-uuid")
            self.assertEqual(payload["from_pony_name"], "APPLEJACK")
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")
            self.assertEqual(payload["subject"], "ping from AJ")

    def test_pony_tell_lists_live_registry(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            project_root.mkdir()
            registry_log = tmp / "registry.jsonl"
            registry_log.write_text(
                json.dumps(
                    {
                        "uuid": "twi-uuid",
                        "pony_name": "TWILIGHT_SPARKLE",
                        "path": str(project_root),
                        "git_branch": "main",
                        "pid": 100,
                        "last_seen_at": "2099-01-01T00:00:00Z",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["bash", str(PONY_TELL), "list"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            self.assertIn("TWILIGHT_SPARKLE", result.stdout)

    def test_pony_tell_accepts_full_display_name_and_splits_subject_body(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            project_root.mkdir()
            chat_log = tmp / "chat.jsonl"
            registry_log = tmp / "registry.jsonl"
            registry_log.write_text(
                json.dumps(
                    {
                        "uuid": "celestia-uuid",
                        "pony_name": "PRINCESS_CELESTIA_SOL_INVICTUS",
                        "path": str(project_root),
                        "git_branch": "main",
                        "pid": 100,
                        "last_seen_at": "2099-01-01T00:00:00Z",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    "bash",
                    str(PONY_TELL),
                    "Twilight Sparkle",
                    "Ping from Celestia. Please confirm receipt.",
                ],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_LAUNCH_PERSONALITY": "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "AGENIC_PONY_CHAT_LOG_PATH": str(chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            self.assertTrue(result.stdout.strip())
            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["from_instance_id"], "celestia-uuid")
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")
            self.assertEqual(payload["subject"], "Ping from Celestia")
            self.assertEqual(payload["body"], ". Please confirm receipt.")


if __name__ == "__main__":
    unittest.main()
