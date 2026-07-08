import argparse
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "pony/scripts/pony-session-host.py"
SPEC = importlib.util.spec_from_file_location("pony_session_host", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
pony_session_host = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pony_session_host)


class PonySessionHostPreflightTests(unittest.TestCase):
    def make_args(self, rootdir: Path, promptfile: Path) -> argparse.Namespace:
        return argparse.Namespace(
            personality="PRINCESS_CELESTIA_SOL_INVICTUS",
            workfile=str(rootdir / "pony/work/governor-celestia.md"),
            rootdir=str(rootdir),
            promptfile=str(promptfile),
            session_name="celestia-test",
            socket_path=str(rootdir / "tmux.sock"),
            draft_path=str(rootdir / "draft.txt"),
            notice_path=str(rootdir / "notice.txt"),
            history_path=str(rootdir / "history.txt"),
            queue_script=str(rootdir / "pony/scripts/queue-runtime.sh"),
            codex_wrapper=str(rootdir / "pony/bin/codex-pony"),
            monitor_script=str(rootdir / "pony/scripts/monitor.py"),
            idle_sentinel="",
            partial_idle_sentinel="Ω",
        )

    def test_celestia_uses_explicit_codex_args_for_dirty_fix_first(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rootdir = Path(tmpdir)
            promptfile = rootdir / "prompt.txt"
            promptfile.write_text("governance follow-up\n", encoding="utf-8")
            args = self.make_args(rootdir, promptfile)

            with patch.object(
                pony_session_host.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="BLOCKED_DIRTY_FIX_FIRST\n", stderr=""),
            ):
                host = pony_session_host.PonySessionHost(args)

            self.assertIn('model="gpt-5.4"', host.bootstrap_codex_args)
            self.assertIn("on-request", host.bootstrap_codex_args)
            self.assertIn("dirty worktree", host.bootstrap_prompt)

    def test_celestia_uses_explicit_codex_args_for_escalate_twi(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rootdir = Path(tmpdir)
            promptfile = rootdir / "prompt.txt"
            promptfile.write_text("governance follow-up\n", encoding="utf-8")
            args = self.make_args(rootdir, promptfile)

            with patch.object(
                pony_session_host.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="ESCALATE_TWI\n", stderr=""),
            ):
                host = pony_session_host.PonySessionHost(args)

            self.assertIn('model="gpt-5.4"', host.bootstrap_codex_args)
            self.assertIn("on-request", host.bootstrap_codex_args)
            self.assertIn("Launch Codex anyway", host.bootstrap_prompt)
            self.assertIn("governance follow-up", host.bootstrap_prompt)

    def test_worker_escalate_twi_still_launches_codex(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rootdir = Path(tmpdir)
            promptfile = rootdir / "prompt.txt"
            promptfile.write_text("worker follow-up\n", encoding="utf-8")
            args = self.make_args(rootdir, promptfile)
            args.personality = "FLUTTERSHY"
            args.workfile = str(rootdir / "pony/work/fs.md")

            with patch.object(
                pony_session_host.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="ESCALATE_TWI\n", stderr=""),
            ):
                host = pony_session_host.PonySessionHost(args)

            self.assertIn('model="gpt-5.4-mini"', host.bootstrap_codex_args)
            self.assertIn("never", host.bootstrap_codex_args)
            self.assertIn("Launch Codex anyway", host.bootstrap_prompt)
            self.assertIn("worker follow-up", host.bootstrap_prompt)

    def test_worker_ready_no_llm_still_launches_codex(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rootdir = Path(tmpdir)
            promptfile = rootdir / "prompt.txt"
            promptfile.write_text("worker follow-up\n", encoding="utf-8")
            args = self.make_args(rootdir, promptfile)
            args.personality = "FLUTTERSHY"
            args.workfile = str(rootdir / "pony/work/fs.md")

            with patch.object(
                pony_session_host.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="READY_NO_LLM\n", stderr=""),
            ):
                host = pony_session_host.PonySessionHost(args)

            self.assertIn('model="gpt-5.4-mini"', host.bootstrap_codex_args)
            self.assertIn("never", host.bootstrap_codex_args)
            self.assertIn("Launch Codex anyway", host.bootstrap_prompt)

    def test_worker_worktree_gets_project_root_writable_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            worker_root = project_root / "pony/worktrees/aj"
            worker_root.mkdir(parents=True)
            promptfile = worker_root / "prompt.txt"
            promptfile.write_text("worker follow-up\n", encoding="utf-8")
            args = self.make_args(worker_root, promptfile)
            args.personality = "APPLEJACK"
            args.workfile = str(project_root / "pony/work/aj.md")

            with patch.dict("os.environ", {"AGENIC_PROJECT_ROOT": str(project_root)}, clear=False):
                with patch.object(
                    pony_session_host.subprocess,
                    "run",
                    return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="READY_NO_LLM\n", stderr=""),
                ):
                    host = pony_session_host.PonySessionHost(args)

            self.assertIn("--add-dir", host.bootstrap_codex_args)
            self.assertIn(str(project_root), host.bootstrap_codex_args)

    def test_ready_keep_live_defers_initial_codex_start(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rootdir = Path(tmpdir)
            promptfile = rootdir / "prompt.txt"
            promptfile.write_text("worker follow-up\n", encoding="utf-8")
            args = self.make_args(rootdir, promptfile)
            args.personality = "TWILIGHT_SPARKLE"
            args.workfile = str(rootdir / "pony/work/coordinator-twi.md")

            with patch.object(
                pony_session_host.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="READY_KEEP_LIVE\n", stderr=""),
            ):
                host = pony_session_host.PonySessionHost(args)

            self.assertEqual(host.preflight_result, "READY_KEEP_LIVE")
            self.assertTrue(host.should_defer_initial_codex_start())
            self.assertIn("no concrete task is assigned yet", host.bootstrap_prompt)
