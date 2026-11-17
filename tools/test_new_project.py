import tempfile
import unittest
from pathlib import Path

import new_project


class NewProjectTest(unittest.TestCase):
    def test_generates_a_self_contained_project(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = new_project.create(Path(tmp) / "game", "My Game")
            settings = (target / "project.godot").read_text(encoding="utf-8")
            self.assertIn('config/name="My Game"', settings)
            self.assertIn('run/main_scene="res://game/main.tscn"', settings)
            self.assertNotIn("examples/last_call", settings)
            self.assertTrue((target / "addons/tale_engine/te_flow.gd").exists())
            self.assertFalse((target / "addons/humanoid_kit").exists())
            episode = (target / "game/episode_1/episode.tres").read_text(encoding="utf-8")
            self.assertIn('title = "My Game"', episode)
            self.assertNotIn("{{TITLE}}", episode)

    def test_refuses_a_non_empty_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x").write_text("x")
            with self.assertRaises(SystemExit):
                new_project.create(tmp, "Nope")


if __name__ == "__main__":
    unittest.main()
