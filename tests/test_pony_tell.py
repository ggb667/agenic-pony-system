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
    def test_agent_config_ignores_non_object_registry_and_chat_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            runtime_dir = project_root / "pony" / "runtime"
            runtime_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            registry_log = runtime_dir / "agent.registry.jsonl"
            message_log = runtime_dir / "pony.chat.jsonl"
            registry_log.write_text(
                "1\n"
                + json.dumps(
                    {
                        "uuid": "twi-evh",
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
            message_log.write_text("2\n", encoding="utf-8")
            config_path = runtime_dir / "spike.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "SPIKE",
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
            self.assertEqual(payload["agentId"], "SPIKE")
            self.assertTrue(any(agent["routeId"] == "EVH:TWILIGHT_SPARKLE" for agent in payload["agents"]))

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
            self.assertEqual(payload["projectRoot"], str(project_root))

            ops_twilight = next(
                agent for agent in payload["agents"] if agent["routeId"] == "OPS:TWILIGHT_SPARKLE"
            )
            self.assertIn("ops:twilight sparkle", [alias.casefold() for alias in ops_twilight["aliases"]])
            self.assertEqual(ops_twilight["projectRoot"], str(other_root))
            self.assertEqual(
                ops_twilight["registryPath"],
                str(other_root / "pony" / "runtime" / "pony.registry.jsonl"),
            )
            self.assertEqual(
                ops_twilight["messageLogPath"],
                str(other_root / "pony" / "runtime" / "pony.chat.jsonl"),
            )
            self.assertGreater(len(payload["agents"]), 8)

    def test_agent_config_prefers_live_celestia_singleton_lane(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            source_root = tmp / "agenic-pony-system"
            runtime_dir = project_root / "pony" / "runtime"
            runtime_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: CODEX\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            (source_root / "pony").mkdir(parents=True)
            (source_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: agenic-pony-system\nproject_root: " + str(source_root) + "\n",
                encoding="utf-8",
            )
            registry_log = runtime_dir / "agent.registry.jsonl"
            message_log = runtime_dir / "agent.messages.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "twi-codex",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "celestia-agenic",
                                "pony_name": "PRINCESS_CELESTIA_SOL_INVICTUS",
                                "path": str(source_root),
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
                    str(message_log),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=os.environ,
            )

            payload = json.loads(config_path.read_text(encoding="utf-8"))
            celestia = next(
                agent
                for agent in payload["agents"]
                if agent["routeId"] == "PRINCESS_CELESTIA_SOL_INVICTUS"
            )
            self.assertEqual(celestia["projectRoot"], str(source_root))
            self.assertEqual(
                celestia["registryPath"],
                str(source_root / "pony" / "runtime" / "pony.registry.jsonl"),
            )
            self.assertEqual(
                celestia["messageLogPath"],
                str(source_root / "pony" / "runtime" / "pony.chat.jsonl"),
            )

    def test_source_celestia_session_uses_live_twilight_not_fake_local_twilight(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            source_root = tmp / "agenic-pony-system"
            codex_root = tmp / "codex"
            source_runtime = source_root / "pony" / "runtime"
            source_runtime.mkdir(parents=True)
            (source_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: agenic-pony-system\nproject_root: " + str(source_root) + "\n",
                encoding="utf-8",
            )
            (codex_root / "pony").mkdir(parents=True)
            (codex_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: codex\nproject_root: " + str(codex_root) + "\n",
                encoding="utf-8",
            )
            registry_log = source_runtime / "agent.registry.jsonl"
            message_log = source_runtime / "agent.messages.jsonl"
            registry_log.write_text(
                json.dumps(
                    {
                        "uuid": "twi-codex",
                        "pony_name": "TWILIGHT_SPARKLE",
                        "path": str(codex_root),
                        "git_branch": "main",
                        "pid": 100,
                        "last_seen_at": "2099-01-01T00:00:00Z",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            config_path = source_runtime / "celestia.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "--project-root",
                    str(source_root),
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
            twilight = next(
                agent for agent in payload["agents"] if agent["routeId"] == "CODEX:TWILIGHT_SPARKLE"
            )
            self.assertEqual(twilight["projectRoot"], str(codex_root))
            self.assertEqual(
                twilight["messageLogPath"],
                str(codex_root / "pony" / "runtime" / "pony.chat.jsonl"),
            )
            self.assertNotIn(
                "AGENIC-PONY-SYSTEM:TWILIGHT_SPARKLE",
                [agent["routeId"] for agent in payload["agents"]],
            )

    def test_source_celestia_session_can_discover_cross_project_twilight_from_chat_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            source_root = tmp / "agenic-pony-system"
            codex_root = tmp / "codex"
            source_runtime = source_root / "pony" / "runtime"
            source_runtime.mkdir(parents=True)
            (source_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: agenic-pony-system\nproject_root: " + str(source_root) + "\n",
                encoding="utf-8",
            )
            (codex_root / "pony").mkdir(parents=True)
            (codex_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: codex\nproject_root: " + str(codex_root) + "\n",
                encoding="utf-8",
            )
            registry_log = source_runtime / "agent.registry.jsonl"
            message_log = source_runtime / "pony.chat.jsonl"
            message_log.write_text(
                json.dumps(
                    {
                        "id": "msg-1",
                        "project_root": str(codex_root),
                        "project_label": "codex",
                        "from_instance_id": "twi-codex",
                        "from_agent_id": "TWILIGHT_SPARKLE",
                        "from_route_id": "CODEX:TWILIGHT_SPARKLE",
                        "from_label": "Twilight Sparkle",
                        "from_pony_name": "TWILIGHT_SPARKLE",
                        "from_symbol": "✶",
                        "to_agent_id": "PRINCESS_CELESTIA_SOL_INVICTUS",
                        "to_route_id": "PRINCESS_CELESTIA_SOL_INVICTUS",
                        "to_label": "Princess Celestia Sol Invictus",
                        "to": "PRINCESS_CELESTIA_SOL_INVICTUS",
                        "subject": "ping",
                        "body": "",
                        "created_at": "2099-01-01T00:00:00Z",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            config_path = source_runtime / "celestia.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "--project-root",
                    str(source_root),
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
            twilight = next(
                agent for agent in payload["agents"] if agent["routeId"] == "CODEX:TWILIGHT_SPARKLE"
            )
            self.assertEqual(twilight["projectRoot"], str(codex_root))
            self.assertEqual(
                twilight["messageLogPath"],
                str(codex_root / "pony" / "runtime" / "pony.chat.jsonl"),
            )

    def test_pony_tell_uses_source_agent_config_when_project_copy_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            runtime_dir = project_root / "pony" / "runtime"
            scripts_dir = project_root / "pony" / "scripts"
            runtime_dir.mkdir(parents=True)
            scripts_dir.mkdir(parents=True)
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            chat_log = runtime_dir / "pony.chat.jsonl"
            registry_log = runtime_dir / "pony.registry.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "aj-uuid",
                                "pony_name": "APPLEJACK",
                                "path": str(project_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "twi-uuid",
                                "pony_name": "TWILIGHT_SPARKLE",
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
                ["bash", str(PONY_TELL), "EVH:Twilight Sparkle", "cross-project-ready ping"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(project_root),
                    "AGENIC_PONY_SOURCE_ROOT": str(REPO_ROOT),
                    "AGENIC_LAUNCH_PERSONALITY": "APPLEJACK",
                    "AGENIC_PONY_CHAT_LOG_PATH": str(chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                    "AGENIC_AGENT_CONFIG_PATH": "",
                    "CODEX_AGENT_CONFIG": "",
                },
            )

            config_path = runtime_dir / "aj.agent-session.json"
            self.assertTrue(config_path.exists())
            config_payload = json.loads(config_path.read_text(encoding="utf-8"))
            twilight = next(agent for agent in config_payload["agents"] if agent["routeId"] == "EVH:TWILIGHT_SPARKLE")
            self.assertIn("evh:twilight sparkle", [alias.casefold() for alias in twilight["aliases"]])
            payload = json.loads(chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["to_route_id"], "EVH:TWILIGHT_SPARKLE")

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
                "project_name: EVH\nproject_root: "
                + str(project_root)
                + "\nagenic_system_root: "
                + str(project_root)
                + "\n",
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

    def test_pony_tell_routes_celestia_to_recipient_message_log_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            sender_root = tmp / "codex"
            source_root = tmp / "agenic-pony-system"
            sender_runtime = sender_root / "pony" / "runtime"
            source_runtime = source_root / "pony" / "runtime"
            sender_runtime.mkdir(parents=True)
            source_runtime.mkdir(parents=True)
            (sender_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: codex\nproject_root: " + str(sender_root) + "\n",
                encoding="utf-8",
            )
            (source_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: agenic-pony-system\nproject_root: " + str(source_root) + "\n",
                encoding="utf-8",
            )
            sender_chat_log = sender_runtime / "pony.chat.jsonl"
            source_chat_log = source_runtime / "pony.chat.jsonl"
            registry_log = sender_runtime / "pony.registry.jsonl"
            registry_log.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "uuid": "twi-codex",
                                "pony_name": "TWILIGHT_SPARKLE",
                                "path": str(sender_root),
                                "git_branch": "main",
                                "pid": 100,
                                "last_seen_at": "2099-01-01T00:00:00Z",
                            }
                        ),
                        json.dumps(
                            {
                                "uuid": "celestia-agenic",
                                "pony_name": "PRINCESS_CELESTIA_SOL_INVICTUS",
                                "path": str(source_root),
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
            config_path = sender_runtime / "twi.agent-session.json"

            subprocess.run(
                [
                    "python3",
                    str(AGENT_CONFIG),
                    "write-session",
                    "--agent",
                    "TWILIGHT_SPARKLE",
                    "--project-root",
                    str(sender_root),
                    "--output",
                    str(config_path),
                    "--registry-path",
                    str(registry_log),
                    "--message-log-path",
                    str(sender_chat_log),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=os.environ,
            )

            subprocess.run(
                ["bash", str(PONY_TELL), "Celestia", "routing receipt test"],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(sender_root),
                    "AGENIC_LAUNCH_PERSONALITY": "TWILIGHT_SPARKLE",
                    "CODEX_AGENT_CONFIG": str(config_path),
                    "AGENIC_PONY_CHAT_LOG_PATH": str(sender_chat_log),
                    "AGENIC_PONY_REGISTRY_LOG_PATH": str(registry_log),
                },
            )

            self.assertFalse(sender_chat_log.exists())
            payload = json.loads(source_chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["project_root"], str(sender_root))
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
                cwd=project_root,
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

    def test_pony_tell_uses_current_project_root_instead_of_stale_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            source_root = tmp / "source"
            project_root = tmp / "project"
            source_runtime = source_root / "pony" / "runtime"
            project_runtime = project_root / "pony" / "runtime"
            source_runtime.mkdir(parents=True)
            project_runtime.mkdir(parents=True)
            (source_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: SOURCE\nproject_root: " + str(source_root) + "\n",
                encoding="utf-8",
            )
            (project_root / "pony" / "pony.system.config.yaml").write_text(
                "project_name: EVH\nproject_root: " + str(project_root) + "\n",
                encoding="utf-8",
            )
            project_chat_log = project_runtime / "pony.chat.jsonl"
            project_registry_log = project_runtime / "pony.registry.jsonl"
            project_registry_log.write_text(
                json.dumps(
                    {
                        "uuid": "twi-evh",
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
            stale_config_path = source_runtime / "celestia.agent-session.json"
            stale_config_path.write_text(
                json.dumps(
                    {
                        "agentId": "PRINCESS_CELESTIA_SOL_INVICTUS",
                        "projectRoot": str(source_root),
                        "agents": [
                            {
                                "agentId": "PRINCESS_CELESTIA_SOL_INVICTUS",
                                "routeId": "PRINCESS_CELESTIA_SOL_INVICTUS",
                                "label": "Princess Celestia Sol Invictus",
                                "aliases": [
                                    "PRINCESS_CELESTIA_SOL_INVICTUS",
                                    "Celestia",
                                ],
                                "projectRoot": str(source_root),
                                "projectLabel": "SOURCE",
                                "branchLabel": "main",
                                "registryPath": str(source_runtime / "pony.registry.jsonl"),
                                "messageLogPath": str(source_runtime / "pony.chat.jsonl"),
                                "globalSingleton": True,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            subprocess.run(
                ["bash", str(PONY_TELL), "EVH:Twilight Sparkle", "root precedence probe"],
                check=True,
                capture_output=True,
                text=True,
                cwd=project_root,
                env={
                    **os.environ,
                    "AGENIC_PROJECT_ROOT": str(source_root),
                    "AGENIC_LAUNCH_PERSONALITY": "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "CODEX_AGENT_CONFIG": str(stale_config_path),
                },
            )

            payload = json.loads(project_chat_log.read_text(encoding="utf-8").strip())
            self.assertEqual(payload["project_root"], str(project_root))
            self.assertEqual(payload["to"], "TWILIGHT_SPARKLE")
            self.assertEqual(payload["to_route_id"], "EVH:TWILIGHT_SPARKLE")


if __name__ == "__main__":
    unittest.main()
