#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path


def configure_import_path(script_path: Path) -> None:
    project_vendor = script_path.resolve().parents[1] / "vendor"
    if str(project_vendor) not in sys.path:
        sys.path.insert(0, str(project_vendor))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--personality", required=True)
    parser.add_argument("--workfile", required=True)
    parser.add_argument("--rootdir", required=True)
    parser.add_argument("--promptfile", required=True)
    parser.add_argument("--session-name", required=True)
    parser.add_argument("--socket-path", required=True)
    parser.add_argument("--draft-path", required=True)
    parser.add_argument("--notice-path", required=True)
    parser.add_argument("--history-path", required=True)
    parser.add_argument("--queue-script", required=True)
    parser.add_argument("--codex-wrapper", required=True)
    parser.add_argument("--monitor-script", required=True)
    parser.add_argument("--idle-sentinel", default="")
    parser.add_argument("--partial-idle-sentinel", default="Ω")
    return parser.parse_args()


def prompt_label_for(personality: str) -> str:
    labels = {
        "PRINCESS_CELESTIA_SOL_INVICTUS": "Tia ☀︎",
        "TWILIGHT_SPARKLE": "Twilight ✶",
        "APPLEJACK": "Applejack 🍎",
        "PINKIE_PIE": "Pinkie 🎈",
        "RARITY": "Rarity 💎",
        "FLUTTERSHY": "Fluttershy 🦋",
        "RAINBOW_DASH": "Rainbow Dash ⚡",
        "SPIKE": "Spike 🐲",
    }
    return labels.get(personality, personality)

def prompt_fragments_for(personality: str) -> list[tuple[str, str]]:
    return [("class:prompt", f"{prompt_label_for(personality)} > ")]


def dirty_fix_first_prompt(project_root: str, initial_prompt: str) -> str:
    cleanup_prompt = (
        f"Coordinator preflight detected a dirty worktree in {project_root}. "
        "First, inspect and reconcile or put away the pending local changes in that repo. "
        "Do not ignore them or defer that cleanup. After the worktree is in a deliberate state, "
        "continue with normal coordination behavior for the active pony."
    )
    if initial_prompt:
        return f"{cleanup_prompt}\n\n{initial_prompt}"
    return cleanup_prompt


def waiting_for_task_notice(personality: str, workfile_path: str) -> str:
    scope_text = ""
    workfile = Path(workfile_path)
    if workfile.exists():
        for line in workfile.read_text().splitlines():
            if line.startswith("Scope:"):
                scope_text = line.split(":", 1)[1].strip()
                break
    if scope_text and scope_text != "unassigned":
        return (
            f"Preflight: no concrete task is assigned yet for {personality}. "
            f"Scope is {scope_text}. Remain live at the Codex prompt and wait for Twilight "
            "or the user to hand you the next specific task."
        )
    return (
        f"Preflight: no concrete task is assigned yet for {personality}. "
        "Remain live at the Codex prompt and wait for Twilight or the user to hand you the next specific task."
    )

def escalate_twi_notice(personality: str, initial_prompt: str) -> str:
    notice = (
        f"Preflight detected a coordinator-routing issue for {personality}. "
        "Launch Codex anyway, inspect the local pony state, summarize the mismatch or blocker plainly, "
        "and hand the routing question to Twilight or the user instead of stopping at the launcher."
    )
    if initial_prompt:
        return f"{notice}\n\n{initial_prompt}"
    return notice


def ready_no_llm_notice(personality: str, initial_prompt: str) -> str:
    notice = (
        f"Preflight says there is no immediate active coding slice for {personality}. "
        "Launch Codex anyway, verify the local state, and remain available for direct follow-up input "
        "rather than stopping at the launcher."
    )
    if initial_prompt:
        return f"{notice}\n\n{initial_prompt}"
    return notice


def coordinator_profile_for(personality: str) -> str | None:
    if personality == "TWILIGHT_SPARKLE":
        return "twi_coordinator"
    if personality == "PRINCESS_CELESTIA_SOL_INVICTUS":
        return "celestia_coordinator"
    return None


def default_profile_for(personality: str) -> str:
    coordinator_profile = coordinator_profile_for(personality)
    if coordinator_profile is not None:
        return coordinator_profile
    return "worker_mini"


class PonySessionHost:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.rootdir = Path(args.rootdir)
        self.promptfile = Path(args.promptfile)
        self.draft_path = Path(args.draft_path)
        self.notice_path = Path(args.notice_path)
        self.history_path = Path(args.history_path)
        self.session_name = args.session_name
        self.socket_path = Path(args.socket_path)
        self.queue_script = args.queue_script
        self.codex_wrapper = args.codex_wrapper
        self.monitor_script = args.monitor_script
        self.initial_prompt = self.promptfile.read_text() if self.promptfile.exists() else ""
        self.personality = args.personality
        self.bootstrap_profile, self.bootstrap_prompt = self._resolve_preflight()

    def tmux(self, *subcmd: str, capture: bool = False, check: bool = True) -> subprocess.CompletedProcess[str]:
        cmd = ["tmux", "-S", str(self.socket_path), *subcmd]
        return subprocess.run(
            cmd,
            text=True,
            capture_output=capture,
            check=check,
        )

    def _resolve_preflight(self) -> tuple[str, str]:
        preflight = subprocess.run(
            [self.args.queue_script.replace("queue-runtime.sh", "worker-preflight.sh"), self.personality, self.args.workfile, self.args.rootdir],
            text=True,
            capture_output=True,
            check=False,
            cwd=self.rootdir,
        )
        result = preflight.stdout.strip() or "ESCALATE_TWI"
        profile = default_profile_for(self.personality)
        if result == "READY_NO_LLM":
            return profile, ready_no_llm_notice(self.personality, self.initial_prompt)
        if result == "READY_KEEP_LIVE":
            return profile, waiting_for_task_notice(self.personality, self.args.workfile)
        if result == "BLOCKED_DIRTY_FIX_FIRST":
            return profile, dirty_fix_first_prompt(self.args.rootdir, self.initial_prompt)
        if result == "ESCALATE_MINI":
            return profile, self.initial_prompt
        if result == "ESCALATE_TWI":
            return profile, escalate_twi_notice(self.personality, self.initial_prompt)
        return profile, f"Preflight error: unexpected result '{result}'.\n\n{self.initial_prompt}".strip()

    def session_exists(self) -> bool:
        return self.tmux("has-session", "-t", self.session_name, check=False).returncode == 0

    def current_pane_id(self) -> str:
        result = self.tmux("display-message", "-p", "-t", self.session_name, "#{pane_id}", capture=True)
        return result.stdout.strip()

    def create_session(self, bootstrap_prompt: str, profile: str | None) -> None:
        env_pairs = {
            "PERSONALITY": self.personality,
            "WORKING_ON": self.args.workfile,
        }
        wrapper_parts = [shlex.quote(self.codex_wrapper)]
        if profile:
            wrapper_parts.extend(["-p", shlex.quote(profile)])
        if bootstrap_prompt:
            wrapper_parts.append(shlex.quote(bootstrap_prompt))
        shell_cmd = (
            f"cd {shlex.quote(str(self.rootdir))} && "
            f"exec env {' '.join(f'{key}={shlex.quote(value)}' for key, value in env_pairs.items())} "
            f"{' '.join(wrapper_parts)}"
        )
        self.tmux("new-session", "-d", "-s", self.session_name, shell_cmd)

    def attach(self) -> None:
        self.tmux("attach-session", "-t", self.session_name, check=False)

    def send_prompt(self, text: str) -> None:
        pane_id = self.current_pane_id()
        self.tmux("send-keys", "-t", pane_id, "-l", text)
        self.tmux("send-keys", "-t", pane_id, "Enter")

    def read_notice(self) -> str:
        if self.notice_path.exists():
            return self.notice_path.read_text().strip()
        return ""

    def prompt_loop(self) -> int:
        from prompt_toolkit import PromptSession
        from prompt_toolkit.history import FileHistory
        from prompt_toolkit.styles import Style

        self.draft_path.parent.mkdir(parents=True, exist_ok=True)
        self.history_path.parent.mkdir(parents=True, exist_ok=True)

        style = Style.from_dict({"prompt": "bold", "toolbar": "reverse"})
        session = PromptSession(history=FileHistory(str(self.history_path)))
        if not self.session_exists():
            self.create_session(self.bootstrap_prompt, self.bootstrap_profile)
        self.attach()

        while True:
            default_text = self.draft_path.read_text() if self.draft_path.exists() else ""
            notice_text = self.read_notice()
            toolbar = notice_text or "Enter submits to the parked pony session. Ctrl-C exits the host."
            try:
                text = session.prompt(
                    prompt_fragments_for(self.personality),
                    default=default_text,
                    style=style,
                    bottom_toolbar=toolbar,
                    multiline=True,
                )
            except KeyboardInterrupt:
                return 130
            except EOFError:
                return 130

            self.draft_path.write_text(text)
            if not text.strip():
                continue

            if not self.session_exists():
                self.create_session(self.bootstrap_prompt, self.bootstrap_profile)
            self.send_prompt(text)
            self.attach()


def main() -> int:
    script_path = Path(__file__)
    configure_import_path(script_path)
    args = parse_args()
    host = PonySessionHost(args)
    return host.prompt_loop()


if __name__ == "__main__":
    raise SystemExit(main())
