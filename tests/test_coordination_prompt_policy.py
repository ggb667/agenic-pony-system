from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PROMPTS_DIR = REPO_ROOT / "pony" / "launch.prompts"


class CoordinationPromptPolicyTests(unittest.TestCase):
    def test_worker_prompts_route_durable_state_through_twilight(self) -> None:
        worker_prompts = ["aj", "fs", "pinkie", "rarity", "rd", "spike"]
        stale_phrases = [
            "Persist your current task, concrete next step, and any blockers in the local `pony/work/*.md` and `pony/team.coordination/*.status.md` files before you idle or hand work back.",
            "Treat `pony/work/*.md` as the canonical home for your worker-local state; use mailbox and status files to summarize deltas or route requests rather than duplicating the full record there.",
            "When the project root is writable, write the project-root `pony/work/*.md` and `pony/team.coordination/*.status.md` files first; worker worktree mirrors are fallback copies only.",
        ]

        for prompt_name in worker_prompts:
            text = (PROMPTS_DIR / f"{prompt_name}.txt").read_text(encoding="utf-8")
            self.assertIn("telling Twilight in the same run", text)
            self.assertIn("workspace artifacts", text)
            self.assertIn("shared coordination mechanism", text)
            self.assertIn("if another pony must act, send that pony a direct `/tell`", text)
            self.assertIn("if shared durable state must change, tell Twilight the exact update to record", text)
            self.assertIn("if both are true, do both in the same run", text)
            for phrase in stale_phrases:
                self.assertNotIn(phrase, text)

    def test_twilight_prompt_uses_shared_coordination_mechanism(self) -> None:
        text = (PROMPTS_DIR / "twi.txt").read_text(encoding="utf-8")
        self.assertIn("shared Twilight-managed coordination mechanism", text)
        self.assertIn("are not the shared authority", text)
        self.assertIn("shared authoritative state", text)
        self.assertNotIn(
            "treat `pony/work/*.md` as the canonical home for worker-local task state",
            text,
        )


if __name__ == "__main__":
    unittest.main()
