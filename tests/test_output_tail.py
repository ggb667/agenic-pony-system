import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_TAIL = REPO_ROOT / "pony/scripts/output-tail.py"


class OutputTailTests(unittest.TestCase):
    def test_keeps_only_the_latest_thousand_lines_and_relays_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            output_path = Path(tmpdir) / "agent.output.tail.log"
            source = "".join(f"line-{index}\n" for index in range(1002))
            result = subprocess.run(
                ["python3", str(OUTPUT_TAIL), str(output_path)],
                input=source,
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(source, result.stdout)
            lines = output_path.read_text(encoding="utf-8").splitlines()
            self.assertEqual(1000, len(lines))
            self.assertEqual("line-2", lines[0])
            self.assertEqual("line-1001", lines[-1])
            self.assertEqual(0o600, output_path.stat().st_mode & 0o777)
