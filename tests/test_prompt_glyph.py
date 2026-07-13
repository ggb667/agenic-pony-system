import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PromptGlyphTests(unittest.TestCase):
    def test_vendored_prompt_toolkit_imports_without_installed_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            result = subprocess.run(
                [
                    "python3",
                    "-c",
                    (
                        "import sys; "
                        f"sys.path.insert(0, {str(project_root / 'pony/vendor')!r}); "
                        "import prompt_toolkit; "
                        "print(prompt_toolkit.__version__)"
                    ),
                ],
                check=True,
                capture_output=True,
                text=True,
                cwd=project_root,
            )

            self.assertEqual(result.stdout.strip(), "0.0.0")

    def test_celestia_glyph_helper_keeps_trailing_space(self) -> None:
        result = subprocess.run(
            [
                "bash",
                "-lc",
                (
                    f"source {REPO_ROOT / 'pony/bin/codex-prompt-style.sh'} && "
                    "codex_prompt_glyph_for_personality PRINCESS_CELESTIA_SOL_INVICTUS"
                ),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.stdout, "☀︎\n")

    def test_installed_codex_pony_passes_spaced_celestia_glyph(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()
            warp_dir = Path(tmpdir) / "warp-configs"
            warp_dir.mkdir()

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            captured_args_path = project_root / "captured-args.json"
            stub_codex = project_root / "stub-codex.py"
            stub_codex.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env python3
                    import json
                    import sys
                    from pathlib import Path

                    Path({str(captured_args_path)!r}).write_text(json.dumps(sys.argv[1:]))
                    """
                ),
                encoding="utf-8",
            )
            stub_codex.chmod(0o755)

            subprocess.run(
                ["bash", str(project_root / "pony/bin/codex-pony"), "launch smoke"],
                check=True,
                cwd=project_root,
                env={
                    **os.environ,
                    "PATH": "/usr/bin:/bin",
                    "CODEX_PONY_BIN": str(stub_codex),
                    "PERSONALITY": "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "USER": os.environ.get("USER", "test-user"),
                    "WARP_LAUNCH_CONFIG_DIR": str(warp_dir),
                },
            )

            captured_args = json.loads(captured_args_path.read_text(encoding="utf-8"))
            self.assertIn('tui.prompt_glyph="☀︎"', captured_args)
            self.assertIn("tui.terminal_title=[]", captured_args)

    def test_installed_wrappers_are_shell_valid(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            subprocess.run(
                ["bash", "-n", str(project_root / "pony/bin/codex-pony")],
                check=True,
                cwd=project_root,
            )
            codex_wrapper = (REPO_ROOT / "pony/bin/codex-pony").read_text(encoding="utf-8")
            self.assertIn('rebind stdio to /dev/tty before exec', codex_wrapper)
            self.assertIn('stdin_tty=$( [[ -t 0 ]] && printf yes || printf no ) stdout_tty=$( [[ -t 1 ]] && printf yes || printf no )', codex_wrapper)
            subprocess.run(
                ["bash", "-n", str(project_root / "pony/scripts/start-session.sh")],
                check=True,
                cwd=project_root,
            )
            subprocess.run(
                ["bash", "-n", str(project_root / "pony/scripts/watch-twi.sh")],
                check=True,
                cwd=project_root,
            )
            watch_script = (project_root / "pony/scripts/watch-twi.sh").read_text(encoding="utf-8")
            self.assertIn('"$lower" == "none recorded"', watch_script)
            self.assertIn('"$decision_needed" == "none recorded"', watch_script)
            subprocess.run(
                ["python3", "-m", "py_compile", str(project_root / "pony/scripts/pony-session-host.py")],
                check=True,
                cwd=project_root,
            )
            launch_script = (project_root / "pony/scripts/launch-in-pony-shell.sh").read_text(encoding="utf-8")
            entry_script = (project_root / "pony/scripts/enter-twi-session.sh").read_text(encoding="utf-8")
            direct_script = (project_root / "pony/scripts/enter-worker-and-codex.sh").read_text(encoding="utf-8")
            self.assertIn('source_root="${AGENIC_PONY_SOURCE_ROOT}"', launch_script)
            self.assertIn(
                '"${source_root}/pony/scripts/start-session.sh" "${AGENIC_LAUNCH_PERSONALITY}" "${AGENIC_PROJECT_ROOT}"',
                launch_script,
            )
            self.assertNotIn(
                '"${source_root}/pony/scripts/start-session.sh" "${AGENIC_LAUNCH_PERSONALITY}" "${AGENIC_PROJECT_ROOT}" </dev/tty >/dev/tty 2>&1',
                launch_script,
            )
            team_member_script = (project_root / "pony/scripts/launch-team-member.sh").read_text(encoding="utf-8")
            self.assertIn('Usage: $(basename "$0") [--direct] PERSONALITY', team_member_script)
            self.assertNotIn('--parked', team_member_script)
            self.assertNotIn('AGENIC_PONY_TEAM_MEMBER_HOST_MODE', team_member_script)
            self.assertIn('FLUTTERSHY) pony_func="fluttershy" ;;', launch_script)
            self.assertIn('RAINBOW_DASH) pony_func="rainbow" ;;', launch_script)
            self.assertNotIn("CODEX_PONY_PROFILE", launch_script)
            self.assertIn('entry_launcher="$(pony_script_path enter-worker-and-codex.sh)"', entry_script)
            self.assertIn('exec "$entry_launcher"   TWILIGHT_SPARKLE', entry_script)
            self.assertIn('multiline=False', (project_root / "pony/scripts/pony-line-editor.py").read_text(encoding="utf-8"))
            self.assertIn('Do not run tools, inspect files, call ponydone, or perform extra work just to produce this startup self-brief.', direct_script)
            host_script = (project_root / "pony/scripts/pony-session-host.py").read_text(encoding="utf-8")
            self.assertIn('open("/dev/tty", "r")', host_script)
            self.assertIn('multiline=False', host_script)
            self.assertIn('Enter submits to Codex. Ctrl-C exits the launcher.', host_script)
            source_start_session = (REPO_ROOT / "pony/scripts/start-session.sh").read_text(encoding="utf-8")
            self.assertIn('exec enter-worker-and-codex:', source_start_session)
            self.assertIn('enter-worker-and-codex.sh', source_start_session)
            self.assertIn('PRINCESS_CELESTIA_SOL_INVICTUS) pony_label="Celestia" ;;', launch_script)
            self.assertIn('TWILIGHT_SPARKLE) pony_label="Twilight" ;;', launch_script)
            self.assertIn('APPLEJACK) pony_label="Applejack" ;;', launch_script)
            self.assertIn('PINKIE_PIE) pony_label="Pinkie" ;;', launch_script)
            self.assertIn('FLUTTERSHY) pony_label="Fluttershy" ;;', launch_script)
            self.assertIn('RARITY) pony_label="Rarity" ;;', launch_script)
            self.assertIn('RAINBOW_DASH) pony_label="Rainbow Dash" ;;', launch_script)
            self.assertIn('SPIKE) pony_label="Spike" ;;', launch_script)
            self.assertIn('NR > 1 && $3 == personality { print $9; exit }', launch_script)
            self.assertIn('"$pony_scope" != "Idle"', launch_script)
            self.assertIn('"$pony_scope" != "idle"', launch_script)
            self.assertIn('"$pony_scope" != "unassigned"', launch_script)

    def test_manual_celestia_profile_requires_canonical_profile_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()
            warp_dir = Path(tmpdir) / "warp-configs"
            warp_dir.mkdir()
            codex_home = Path(tmpdir) / "codex-home"
            codex_home.mkdir()

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            captured_args_path = project_root / "captured-args.json"
            stub_codex = project_root / "stub-codex.py"
            stub_codex.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env python3
                    import json
                    import sys
                    from pathlib import Path

                    Path({str(captured_args_path)!r}).write_text(json.dumps(sys.argv[1:]))
                    """
                ),
                encoding="utf-8",
            )
            stub_codex.chmod(0o755)

            subprocess.run(
                ["bash", str(project_root / "pony/bin/codex-pony"), "launch", "smoke"],
                check=True,
                cwd=project_root,
                env={
                    **os.environ,
                    "PATH": "/usr/bin:/bin",
                    "CODEX_HOME": str(codex_home),
                    "CODEX_PONY_BIN": str(stub_codex),
                    "CODEX_PONY_PROFILE": "celestia",
                    "PERSONALITY": "PRINCESS_CELESTIA_SOL_INVICTUS",
                    "USER": os.environ.get("USER", "test-user"),
                    "WARP_LAUNCH_CONFIG_DIR": str(warp_dir),
                },
            )

            captured_args = json.loads(captured_args_path.read_text(encoding="utf-8"))
            self.assertIn("-p", captured_args)
            self.assertIn("celestia", captured_args)
            self.assertEqual(sorted(path.name for path in codex_home.glob("*.config.toml")), [])

    def test_git_project_bootstrap_provisions_worker_worktrees_and_worker_assignment_uses_them(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()
            (project_root / "README.md").write_text("sample\n", encoding="utf-8")

            subprocess.run(["git", "init", "-b", "main"], check=True, cwd=project_root)
            subprocess.run(["git", "config", "user.name", "Test User"], check=True, cwd=project_root)
            subprocess.run(["git", "config", "user.email", "test@example.com"], check=True, cwd=project_root)
            subprocess.run(["git", "add", "README.md"], check=True, cwd=project_root)
            subprocess.run(["git", "commit", "-m", "init"], check=True, cwd=project_root)

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            registry_text = (project_root / "pony/team.coordination/assignment.registry.tsv").read_text(encoding="utf-8")
            self.assertIn(f"pony/aj/main\t{project_root / 'pony/worktrees/aj'}", registry_text)
            self.assertIn(f"main\t{project_root}", registry_text)
            self.assertTrue((project_root / "pony/worktrees/aj/.git").exists())
            self.assertIn(
                f'project_root="{project_root}"',
                (project_root / "pony/worktrees/aj/pony/scripts/start-session.sh").read_text(encoding="utf-8"),
            )
            self.assertIn(
                f'source "{project_root}/pony/scripts/pony.zsh.support.zsh"',
                (project_root / "pony/worktrees/aj/pony/scripts/pony.zsh.support.zsh").read_text(encoding="utf-8"),
            )
            self.assertEqual(
                (
                    project_root / "pony/worktrees/aj/pony/bin/ponydone"
                ).read_text(encoding="utf-8"),
                (
                    "#!/usr/bin/env bash\n"
                    "set -euo pipefail\n"
                    f'exec "{project_root}/pony/bin/ponydone" "$@"'
                ),
            )
            self.assertEqual(
                (
                    project_root / "pony/worktrees/aj/pony/bin/ponyalert"
                ).read_text(encoding="utf-8"),
                (
                    "#!/usr/bin/env bash\n"
                    "set -euo pipefail\n"
                    f'exec "{project_root}/pony/bin/ponyalert" "$@"'
                ),
            )

            result = subprocess.run(
                [
                    "bash",
                    "-lc",
                    (
                        f"source {project_root / 'pony/scripts/pony-paths.sh'} && "
                        f"load_project_paths {project_root} && "
                        "resolve_worker_assignment_by_personality APPLEJACK"
                    ),
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            workfile, worktree = result.stdout.strip().split("\t")
            self.assertEqual(workfile, str(project_root / "pony/work/aj.md"))
            self.assertEqual(worktree, str(project_root / "pony/worktrees/aj"))
            pending_approvals = (project_root / "pony/team.coordination/twi.pending-approvals.md").read_text(encoding="utf-8")
            review_queue = (project_root / "pony/team.coordination/twi.review-queue.md").read_text(encoding="utf-8")
            event_history = (project_root / "pony/team.coordination/twi.event.stream.history.md").read_text(encoding="utf-8")
            self.assertIn("No pending user approvals.", pending_approvals)
            self.assertIn("Generated helper output only.", review_queue)
            self.assertIn("durable_coordination_history: none", event_history)

    def test_git_project_bootstrap_keeps_generated_pony_tree_out_of_status_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()
            (project_root / "README.md").write_text("sample\n", encoding="utf-8")

            subprocess.run(["git", "init", "-b", "main"], check=True, cwd=project_root)
            subprocess.run(["git", "config", "user.name", "Test User"], check=True, cwd=project_root)
            subprocess.run(["git", "config", "user.email", "test@example.com"], check=True, cwd=project_root)
            subprocess.run(["git", "add", "README.md"], check=True, cwd=project_root)
            subprocess.run(["git", "commit", "-m", "init"], check=True, cwd=project_root)

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            status_result = subprocess.run(
                ["git", "status", "--short"],
                check=True,
                capture_output=True,
                text=True,
                cwd=project_root,
            )
            exclude_text = (project_root / ".git" / "info" / "exclude").read_text(encoding="utf-8")

            self.assertEqual(status_result.stdout, "")
            self.assertIn("/pony/", exclude_text)


    def test_bootstrapped_start_session_writes_startup_identity_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir) / "project"
            project_root.mkdir()

            subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/bootstrap-project.sh"), str(project_root)],
                check=True,
                cwd=REPO_ROOT,
            )

            (project_root / "pony/work/governor-celestia.md").write_text(
                "Status: active\nScope: source governance\n",
                encoding="utf-8",
            )
            (project_root / "pony/team.coordination/celestia.status.md").write_text(
                "STATUS: ACTIVE\n",
                encoding="utf-8",
            )
            (project_root / "pony/scripts/enter-worker-from-prompt-file.sh").write_text(
                "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
                encoding="utf-8",
            )
            (project_root / "pony/scripts/enter-worker-from-prompt-file.sh").chmod(0o755)
            (project_root / "pony/scripts/enter-worker-and-codex.sh").write_text(
                "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
                encoding="utf-8",
            )
            (project_root / "pony/scripts/enter-worker-and-codex.sh").chmod(0o755)
            (project_root / "pony/scripts/enter-twi-session.sh").write_text(
                "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
                encoding="utf-8",
            )
            (project_root / "pony/scripts/enter-twi-session.sh").chmod(0o755)

            subprocess.run(
                [
                    "bash",
                    str(project_root / "pony/scripts/start-session.sh"),
                    "PRINCESS_CELESTIA_SOL_INVICTUS",
                    str(project_root),
                ],
                check=True,
                cwd=project_root,
                env={
                    **os.environ,
                    "AGENIC_PONY_DISABLE_REUSABLE_PROMPT": "1",
                },
            )

            prompt_text = (project_root / "pony/runtime/celestia.launch.prompt.txt").read_text(encoding="utf-8")
            self.assertIn("Startup identity contract:", prompt_text)
            self.assertIn("- Identity: Princess Celestia Sol Invictus (☀︎)", prompt_text)
            self.assertIn("- Runtime role: source-repo governance pony.", prompt_text)
            self.assertIn(f"- Active project: {project_root} on branch no-git-branch.", prompt_text)
            self.assertIn(f"- Active workspace: {project_root}.", prompt_text)
            self.assertIn("- Runtime state: ACTIVE; scope source governance; assigned workfile", prompt_text)
            self.assertIn("- Prompt and title: prompt label Princess Celestia Sol Invictus ☀︎ ›; terminal title Celestia · project.", prompt_text)
            self.assertIn(f"- Interoperation: direct live messaging via {project_root / 'pony/bin/pony-tell'}", prompt_text)
            self.assertIn(f"- Feedback and handoff: approval alert via {project_root / 'pony/bin/ponyalert'} PRINCESS_CELESTIA_SOL_INVICTUS", prompt_text)
            self.assertIn("- Startup rule: begin from this pony identity and live runtime context before summarizing any broader developer instructions.", prompt_text)

    def test_start_session_contains_runtime_contract_validation(self) -> None:
        script_text = (REPO_ROOT / "pony/scripts/start-session.sh").read_text(encoding="utf-8")
        self.assertIn("validate_runtime_prompt_contract", script_text)
        self.assertIn('"Startup identity contract:"', script_text)
        self.assertIn('"- Prompt and title:"', script_text)
        self.assertIn('"Direct-message rule:"', script_text)
        self.assertIn('"Alert rule:"', script_text)
        self.assertIn('"Done rule:"', script_text)
        self.assertIn('"Idle-sentinel rule:"', script_text)


if __name__ == "__main__":
    unittest.main()
