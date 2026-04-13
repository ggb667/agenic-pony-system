import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RESOLVER = REPO_ROOT / "pony/scripts/resolve-system-root.sh"


def make_fake_source(root: Path) -> None:
    scripts_dir = root / "scripts"
    scripts_dir.mkdir(parents=True)
    install_script = scripts_dir / "install-project.sh"
    install_script.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
    install_script.chmod(install_script.stat().st_mode | stat.S_IXUSR)


class SourceResolutionTests(unittest.TestCase):
    def clean_env(self) -> dict[str, str]:
        env = dict(os.environ)
        env.pop("AGENIC_PONY_SOURCE_ROOT", None)
        env.pop("AGENIC_PONY_SOURCE_CACHE_ROOT", None)
        env.pop("AGENIC_PONY_SOURCE_CACHE_DIR", None)
        return env

    def write_project_config(self, project_root: Path, configured_root: str) -> Path:
        pony_dir = project_root / "pony"
        pony_scripts = pony_dir / "scripts"
        pony_scripts.mkdir(parents=True)
        installed_resolver = pony_scripts / "resolve-system-root.sh"
        installed_resolver.write_text(RESOLVER.read_text(encoding="utf-8"), encoding="utf-8")
        installed_resolver.chmod(installed_resolver.stat().st_mode | stat.S_IXUSR)
        config_path = pony_dir / "pony.system.config.yaml"
        config_path.write_text(
            "\n".join(
                [
                    "project_name: sample",
                    f"project_root: {project_root}",
                    "branch: main",
                    "launcher_prefix: Sample Pony",
                    f"agenic_system_root: {configured_root}",
                    "agenic_system_repo: https://github.com/ggb667/agenic-pony-system.git",
                    "agenic_system_ref: main",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        return config_path

    def run_resolver(self, project_root: Path, env: dict[str, str]) -> str:
        result = subprocess.run(
            ["bash", str(project_root / "pony/scripts/resolve-system-root.sh"), str(project_root)],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return result.stdout.strip()

    def test_env_source_root_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            fake_source = tmp / "env-source"
            make_fake_source(fake_source)
            self.write_project_config(project_root, "/missing/source")

            resolved = self.run_resolver(
                project_root,
                {**self.clean_env(), "AGENIC_PONY_SOURCE_ROOT": str(fake_source)},
            )

            self.assertEqual(resolved, str(fake_source))

    def test_configured_root_used_when_valid(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            fake_source = tmp / "configured-source"
            make_fake_source(fake_source)
            self.write_project_config(project_root, str(fake_source))

            resolved = self.run_resolver(project_root, self.clean_env())

            self.assertEqual(resolved, str(fake_source))

    def test_cache_root_used_when_configured_root_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            project_root = tmp / "project"
            cache_source = tmp / "cache-source"
            make_fake_source(cache_source)
            self.write_project_config(project_root, "/missing/source")

            resolved = self.run_resolver(
                project_root,
                {**self.clean_env(), "AGENIC_PONY_SOURCE_CACHE_ROOT": str(cache_source)},
            )

            self.assertEqual(resolved, str(cache_source))


if __name__ == "__main__":
    unittest.main()
