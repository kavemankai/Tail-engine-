import os
import re
import shutil
import subprocess
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

    def test_keeps_what_a_new_game_needs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = new_project.create(Path(tmp) / "game", "My Game")
            settings = (target / "project.godot").read_text(encoding="utf-8")
            self.assertIn("[internationalization]", settings)
            self.assertIn("res://game/episode_1/dialogue/intro.dialogue", settings)
            self.assertNotIn("templates/starter", settings)
            self.assertTrue((target / "addons/dialogue_manager/assets/icon.svg.import").exists())
            self.assertFalse(list((target / "addons/tale_engine").rglob("*.import")))
            for name in new_project.DOCS:
                self.assertTrue((target / "docs" / name).exists(), name)
            self.assertIn("docs/AUTHORING.md", (target / "README.md").read_text(encoding="utf-8"))

    def test_generated_project_imports_and_validates_in_godot(self) -> None:
        godot = os.environ.get("GODOT") or shutil.which("godot")
        if not godot:
            self.skipTest("Godot not available; set GODOT to run this check")
        with tempfile.TemporaryDirectory() as tmp:
            target = new_project.create(Path(tmp) / "game", "My Game")
            for args, marker in ((["--editor", "--import"], None),
                                 (["res://validate.tscn"], r"0 problem\(s\)"),
                                 (["--quit-after", "10"], None)):
                result = subprocess.run([godot, "--headless", "--path", str(target), *args],
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, timeout=300)
                output = result.stdout
                self.assertEqual(result.returncode, 0, output)
                self.assertIsNone(re.search(r"SCRIPT ERROR:|^ERROR:", output, re.MULTILINE), output)
                if marker:
                    self.assertRegex(output, marker)

    def test_refuses_a_non_empty_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x").write_text("x")
            with self.assertRaises(SystemExit):
                new_project.create(tmp, "Nope")


if __name__ == "__main__":
    unittest.main()
