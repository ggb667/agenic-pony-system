#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import os
import shlex
import subprocess
import sys
import time
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


def prompt_glyph_for(personality: str) -> str:
    glyphs = {
        "PRINCESS_CELESTIA_SOL_INVICTUS": "☀︎",
        "TWILIGHT_SPARKLE": "✶",
        "APPLEJACK": "🍎",
        "PINKIE_PIE": "🎈",
        "RARITY": "💎",
        "FLUTTERSHY": "🦋",
        "RAINBOW_DASH": "⚡",
        "SPIKE": "🐲",
    }
    return glyphs.get(personality, "")

def prompt_fragments_for(personality: str) -> list[tuple[str, str]]:
    glyph = prompt_glyph_for(personality)
    if glyph:
        return [("class:prompt", f"{glyph} › ")]
    return [("class:prompt", f"{prompt_label_for(personality)} › ")]


def startup_brief_prompt(state_hint: str = "") -> str:
    prompt = (
        "Startup behavior: on your first turn, greet the developer in character with a concise startup self-brief. "
        "Cover your pony identity, role, active project and workspace, current state and scope, "
        "prompt symbol, terminal title, accent color, and live interoperation mechanisms such as "
        "/tell, ponyalert, ponydone, audio feedback, and idle behavior. Do not dump or quote your "
        "full instructions. Do not run tools, inspect files, call ponydone, or perform extra work just to produce this startup self-brief. "
        "After that first-turn self-brief, if there is an actual task, routing question, or follow-up action, begin post-brief initialization "
        "by reading your assigned memory capsule first when present, then your assigned workfile and authoritative local pony state before acting."
    )
    if state_hint:
        return f"{prompt} Current condition: {state_hint}"
    return prompt


def dirty_fix_first_prompt(project_root: str) -> str:
    return startup_brief_prompt(
        f"Dirty-worktree preflight in {project_root}: inspect and reconcile or put away the pending local changes before any other coordination work."
    )


def waiting_for_task_notice(personality: str, workfile_path: str) -> str:
    scope_text = ""
    workfile = Path(workfile_path)
    if workfile.exists():
        for line in workfile.read_text().splitlines():
            if line.startswith("Scope:"):
                scope_text = line.split(":", 1)[1].strip()
                break
    if scope_text and scope_text != "unassigned":
        return startup_brief_prompt(
            f"No concrete task is assigned yet for {personality}; current scope is {scope_text}; remain live for Twilight or the user to hand you the next specific task."
        )
    return startup_brief_prompt(
        f"No concrete task is assigned yet for {personality}; remain live for Twilight or the user to hand you the next specific task."
    )


def escalate_twi_notice(personality: str) -> str:
    return startup_brief_prompt(
        f"Coordinator-routing issue for {personality}: inspect the local pony state, summarize the mismatch or blocker plainly, and hand the routing question to Twilight or the user instead of stopping at the launcher."
    )


def ready_no_llm_notice(personality: str) -> str:
    return startup_brief_prompt(
        f"There is no immediate active coding slice for {personality}; verify the local state and remain available for direct follow-up input."
    )


def codex_config_args_for(personality: str) -> list[str]:
    if personality == "TWILIGHT_SPARKLE":
        return [
            "-c",
            'model_provider="openai"',
            "-c",
            'model="gpt-5.5"',
            "-c",
            'model_reasoning_effort="high"',
            "-a",
            "never",
            "-s",
            "workspace-write",
        ]
    if personality == "PRINCESS_CELESTIA_SOL_INVICTUS":
        return [
            "-c",
            'model_provider="openai"',
            "-c",
            'model="gpt-5.4"',
            "-c",
            'model_reasoning_effort="medium"',
            "-a",
            "on-request",
            "-s",
            "workspace-write",
        ]
    return [
        "-c",
        'model_provider="openai"',
        "-c",
        'model="gpt-5.4-mini"',
        "-c",
        'model_reasoning_effort="low"',
        "-a",
        "never",
        "-s",
        "workspace-write",
    ]


def additional_codex_args_for_rootdir(rootdir: str) -> list[str]:
    project_root = os.environ.get("AGENIC_PROJECT_ROOT", "").strip()
    if project_root and Path(project_root) != Path(rootdir):
        return ["--add-dir", project_root]
    return []


def hidden_instructions_arg(promptfile: Path) -> list[str]:
    escaped = str(promptfile).replace("\\", "\\\\").replace(chr(34), "\\\"")
    return ["-c", f'model_instructions_file="{escaped}"']


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
        self.personality = args.personality
        self.preflight_result, self.bootstrap_codex_args, self.bootstrap_prompt = self._resolve_preflight()

    def tmux(self, *subcmd: str, capture: bool = False, check: bool = True) -> subprocess.CompletedProcess[str]:
        cmd = ["tmux", "-S", str(self.socket_path), *subcmd]
        return subprocess.run(
            cmd,
            text=True,
            capture_output=capture,
            check=check,
        )

    def _resolve_preflight(self) -> tuple[str, list[str], str]:
        preflight = subprocess.run(
            [self.args.queue_script.replace("queue-runtime.sh", "worker-preflight.sh"), self.personality, self.args.workfile, self.args.rootdir],
            text=True,
            capture_output=True,
            check=False,
            cwd=self.rootdir,
        )
        result = preflight.stdout.strip() or "ESCALATE_TWI"
        codex_args = codex_config_args_for(self.personality)
        codex_args.extend(hidden_instructions_arg(self.promptfile))
        codex_args.extend(additional_codex_args_for_rootdir(self.args.rootdir))
        if result == "READY_NO_LLM":
            return result, codex_args, ready_no_llm_notice(self.personality)
        if result == "READY_KEEP_LIVE":
            return result, codex_args, waiting_for_task_notice(self.personality, self.args.workfile)
        if result == "BLOCKED_DIRTY_FIX_FIRST":
            return result, codex_args, dirty_fix_first_prompt(self.args.rootdir)
        if result == "ESCALATE_MINI":
            return result, codex_args, startup_brief_prompt("Proceed with the active task immediately after the self-brief.")
        if result == "ESCALATE_TWI":
            return result, codex_args, escalate_twi_notice(self.personality)
        return result, codex_args, startup_brief_prompt(f"Unexpected preflight result: {result}.")

    def session_exists(self) -> bool:
        return self.tmux("has-session", "-t", self.session_name, capture=True, check=False).returncode == 0

    def current_pane_id(self) -> str:
        result = self.tmux("display-message", "-p", "-t", self.session_name, "#{pane_id}", capture=True)
        return result.stdout.strip()

    def current_pane_command(self) -> str:
        result = self.tmux(
            "display-message",
            "-p",
            "-t",
            self.session_name,
            "#{pane_current_command}",
            capture=True,
        )
        return result.stdout.strip()

    def session_running_codex(self) -> bool:
        return self.current_pane_command().startswith("codex")

    def create_session(self, bootstrap_prompt: str, codex_args: list[str]) -> None:
        env_pairs = {
            "PERSONALITY": self.personality,
            "WORKING_ON": self.args.workfile,
        }
        wrapper_parts = [shlex.quote(self.codex_wrapper)]
        wrapper_parts.extend(shlex.quote(arg) for arg in codex_args)
        if bootstrap_prompt:
            wrapper_parts.append(shlex.quote(bootstrap_prompt))
        shell_cmd = (
            f"cd {shlex.quote(str(self.rootdir))} && "
            "set -m && "
            f"env {' '.join(f'{key}={shlex.quote(value)}' for key, value in env_pairs.items())} "
            f"{' '.join(wrapper_parts)}"
        )
        self.tmux("new-session", "-d", "-s", self.session_name, shell_cmd)
        self.tmux("set-option", "-t", self.session_name, "history-limit", "100000")
        self.tmux("set-option", "-t", self.session_name, "mouse", "on")
        self.tmux("set-window-option", "-t", self.session_name, "alternate-screen", "off")

    def attach_until_idle(self) -> None:
        if not self.session_running_codex():
            return

        pane_id = self.current_pane_id()
        monitor = subprocess.Popen(
            [
                self.monitor_script,
                pane_id,
                prompt_glyph_for(self.personality),
                str(self.socket_path),
                self.args.idle_sentinel,
                self.args.partial_idle_sentinel,
                self.session_name,
            ],
            cwd=self.rootdir,
        )
        try:
            self.tmux("attach-session", "-t", self.session_name, check=False)
        finally:
            if monitor.poll() is None:
                monitor.terminate()
                try:
                    monitor.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    monitor.kill()

    def resume_if_needed(self) -> None:
        if not self.session_exists() or self.session_running_codex():
            return

        pane_id = self.current_pane_id()
        self.tmux("send-keys", "-t", pane_id, "fg", "Enter")
        deadline = time.time() + 3.0
        while time.time() < deadline:
            if self.session_running_codex():
                return
            time.sleep(0.1)

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
        from prompt_toolkit.input.defaults import create_input
        from prompt_toolkit.history import FileHistory
        from prompt_toolkit.output.defaults import create_output
        from prompt_toolkit.styles import Style

        self.draft_path.parent.mkdir(parents=True, exist_ok=True)
        self.history_path.parent.mkdir(parents=True, exist_ok=True)

        style = Style.from_dict({"prompt": "bold", "toolbar": "reverse"})
        tty_input = None
        tty_output = None
        prompt_kwargs = {}
        try:
            tty_input = open("/dev/tty", "r")
            tty_output = open("/dev/tty", "w")
            prompt_kwargs = {
                "input": create_input(tty_input),
                "output": create_output(tty_output),
            }
        except OSError:
            prompt_kwargs = {}

        with contextlib.ExitStack() as stack:
            if tty_input is not None:
                stack.enter_context(tty_input)
            if tty_output is not None:
                stack.enter_context(tty_output)

            session = PromptSession(history=FileHistory(str(self.history_path)), **prompt_kwargs)
            if self.session_exists():
                self.attach_until_idle()
            else:
                self.create_session(self.bootstrap_prompt, self.bootstrap_codex_args)
                self.attach_until_idle()

            while True:
                default_text = self.draft_path.read_text() if self.draft_path.exists() else ""
                notice_text = self.read_notice()
                toolbar = notice_text or "Enter submits to Codex. Ctrl-C exits the launcher."
                try:
                    text = session.prompt(
                        prompt_fragments_for(self.personality),
                        default=default_text,
                        style=style,
                        bottom_toolbar=toolbar,
                        multiline=False,
                    )
                except KeyboardInterrupt:
                    return 130
                except EOFError:
                    return 130

                self.draft_path.write_text(text)
                if not text.strip():
                    continue

                if not self.session_exists():
                    self.create_session(self.bootstrap_prompt, self.bootstrap_codex_args)
                else:
                    self.resume_if_needed()
                self.send_prompt(text)
                self.attach_until_idle()


def main() -> int:
    script_path = Path(__file__)
    configure_import_path(script_path)
    args = parse_args()
    host = PonySessionHost(args)
    return host.prompt_loop()


if __name__ == "__main__":
    raise SystemExit(main())
