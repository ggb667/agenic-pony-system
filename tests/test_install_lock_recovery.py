from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]


class InstallLockRecoveryTests(unittest.TestCase):
    def test_launch_refresh_recovers_ownerless_and_dead_local_locks(self) -> None:
        text = (REPO_ROOT / "pony" / "scripts" / "start-session.sh").read_text(encoding="utf-8")
        self.assertIn("recovered ownerless install-project lock", text)
        self.assertIn("recovered stale install-project lock", text)
        self.assertIn("kill -0 \"$install_lock_owner_pid\"", text)
        self.assertIn("install_lock_owner_host", text)

    def test_direct_installer_reclaims_an_ownerless_lock(self) -> None:
        text = (REPO_ROOT / "scripts" / "install-project.sh").read_text(encoding="utf-8")
        self.assertIn("An interrupted install can leave an empty lock directory behind", text)
        self.assertIn('rmdir "$install_lock_dir" 2>/dev/null || true', text)


if __name__ == "__main__":
    unittest.main()
