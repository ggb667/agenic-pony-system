import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PromptGlyphTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
