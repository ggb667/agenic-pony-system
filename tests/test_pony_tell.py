import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PONY_TELL = REPO_ROOT / "pony/bin/pony-tell"
AGENT_CONFIG = REPO_ROOT / "pony/scripts/agent-config.py"


class PonyTellTests(unittest.TestCase):
    def test_agent_config_emits_paths_and_qualified_aliases(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            other_root = tmp / "other"
            runtime_dir = project_root / "pony" / "runtime"
            runtime_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            (other_root / "pony").mkdir(parents=True)
            (other_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: OPS\nproject_root: " + str(other_root) + "\n",
                encoding="utf-8",
            )
            registry_log = runtime_dir / "agent.registry.jsonl"
            message_log = runtime_dir / "agent.messages.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "twi-evh",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "twi-ops",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(other_root),
                                "git_branch": "ops-branch",
                                "pid": 101,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            config_path = runtime_dir / "twi.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "TWILIGHT_SPARKLE",
                    "--project-root",
                    str(project_root),
                    "--output",
                    str(config_path),
                    "--registry-path",
                    str(registry_log),
                    "--message-log-path",
                    str(message_log),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=os.environ,
            )

            payload = json.loads(config_path.read_text(encoding="utf-8"))
            self.assertEqual(payload["registryPath"], str(registry_log))
            self.assertEqual(payload["messageLogPath"], str(message_log))
            self.assertIn("evh:twilight sparkle", [alias.casefold() for alias in payload["aliases"]])

            ops_twilight = next(
                agent for agent in payload["agents"] if agent["routeId"] == "OPS:TWILIGHT_SPARKLE"
            )
            self.assertIn("ops:twilight sparkle", [alias.casefold() for alias in ops_twilight["aliases"]])
            self.assertEqual(ops_twilight["projectRoot"], str(other_root))

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
            self.assertEqual(payload["project_root"], str(project_root))
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
            self.assertEqual(payload["project_root"], str(project_root))
            self.assertEqual(payload["from_instance_id"], "celestia-uuid")
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")
            self.assertEqual(payload["subject"], "Ping from Celestia")
            self.assertEqual(payload["body"], ". Please confirm receipt.")

    def test_pony_tell_defaults_to_project_local_runtime_logs(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            runtime_dir = project_root / "pony" / "runtime"
            runtime_dir.mkdir(parents=True)
            registry_log = runtime_dir / "pony.registry.jsonl"
            chat_log = runtime_dir / "pony.chat.jsonl"
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

            subprocess.run(
                ["bash", str(PONY_TELL), "twi", "team-local ping"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_LAUNCH_PERSONALITY": "APPLEJACK",
                    "AGENIC_PONY_CHAT_LOG_PATH": "",
                    "AGENIC_PONY_REGISTRY_LOG_PATH": "",
                },
            )

            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["project_root"], str(project_root))
            self.assertEqual(payload["from_instance_id"], "aj-uuid")
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")

    def test_pony_tell_resolves_full_display_name_from_generated_agent_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            runtime_dir = project_root / "pony" / "runtime"
            coordination_dir = project_root / "pony" / "team.coordination"
            runtime_dir.mkdir(parents=True)
            coordination_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            chat_log = runtime_dir / "agent.messages.jsonl"
            registry_log = runtime_dir / "agent.registry.jsonl"
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
            config_path = runtime_dir / "twi.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "TWILIGHT_SPARKLE",
                    "--project-root",
                    str(project_root),
                    "--output",
                    str(config_path),
                    "--registry-path",
                    str(registry_log),
                    "--message-log-path",
                    str(chat_log),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=os.environ,
            )

            subprocess.run(
                ["bash", str(PONY_TELL), "Princess Celestia Sol Invictus", "policy ping"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_LAUNCH_PERSONALITY": "TWILIGHT_SPARKLE",
                    "CODEX_AGENT_CONFIG": str(config_path),
                    "AGENIC_PONY_CHAT_LOG_PATH": str(chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["to"], "PRINCESS_CELESTIA_SOL_INVICTUS")
            self.assertEqual(payload["to_route_id"], "PRINCESS_CELESTIA_SOL_INVICTUS")

    def test_pony_tell_prefers_local_agent_for_unqualified_cross_repo_alias(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            other_root = tmp / "other"
            runtime_dir = project_root / "pony" / "runtime"
            runtime_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            (other_root / "pony").mkdir(parents=True)
            (other_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: OPS\nproject_root: " + str(other_root) + "\n",
                encoding="utf-8",
            )
            chat_log = runtime_dir / "agent.messages.jsonl"
            registry_log = runtime_dir / "agent.registry.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "twi-evh",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "twi-ops",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(other_root),
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
            config_path = runtime_dir / "twi.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "TWILIGHT_SPARKLE",
                    "--project-root",
                    str(project_root),
                    "--output",
                    str(config_path),
                    "--registry-path",
                    str(registry_log),
                    "--message-log-path",
                    str(chat_log),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=os.environ,
            )

            result = subprocess.run(
                ["bash", str(PONY_TELL), "Twilight Sparkle", "ambiguous ping"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_LAUNCH_PERSONALITY": "TWILIGHT_SPARKLE",
                    "CODEX_AGENT_CONFIG": str(config_path),
                    "AGENIC_PONY_CHAT_LOG_PATH": str(chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")
            self.assertEqual(payload["to_route_id"], "EVH:TWILIGHT_SPARKLE")


if __name__ == "__main__":
    unittest.main()
