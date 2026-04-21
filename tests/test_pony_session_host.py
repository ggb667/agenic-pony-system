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

    def test_celestia_uses_celestia_profile_for_dirty_fix_first(self) -> None:
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

            self.assertEqual(host.bootstrap_profile, "celestia_coordinator")
            self.assertIn("dirty worktree", host.bootstrap_prompt)
            self.assertEqual(host.startup_action, "launch")

    def test_celestia_uses_celestia_profile_for_escalate_twi(self) -> None:
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

            self.assertEqual(host.bootstrap_profile, "celestia_coordinator")
            self.assertEqual(host.bootstrap_prompt, "governance follow-up\n")
            self.assertEqual(host.startup_action, "launch")
