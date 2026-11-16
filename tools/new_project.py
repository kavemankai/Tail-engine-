#!/usr/bin/env python3
"""Create a new Tale Engine game from templates/starter.

    python tools/new_project.py <target_dir> "My Game Title"

Copies the engine addons (tale_engine, cinematic_action_director,
dialogue_manager) and the starter episode, and writes a project.godot that
reuses this repository's autoloads and input map.
"""

import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ("tale_engine", "cinematic_action_director", "dialogue_manager")
TEXT_SUFFIXES = {".gd", ".tres", ".tscn", ".md"}


def project_settings(title):
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    text = re.sub(r'config/name="[^"]*"', f'config/name="{title}"', text)
    text = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="res://game/main.tscn"', text)
    text = re.sub(r"; Keep the original application ID[^\n]*\n; The window[^\n]*\n", "", text)
    text = re.sub(r"\[internationalization\]\n(?:[^\[\n][^\n]*\n|\n)*", "", text)
    return text


def create(target, title):
    target = Path(target)
    if target.exists() and any(target.iterdir()):
        raise SystemExit(f"{target} exists and is not empty")
    (target / "addons").mkdir(parents=True, exist_ok=True)
    for name in ADDONS:
        shutil.copytree(ROOT / "addons" / name, target / "addons" / name,
                        ignore=shutil.ignore_patterns("*.import"))
    shutil.copytree(ROOT / "templates/starter", target, dirs_exist_ok=True)
    (target / "project.godot").write_text(project_settings(title), encoding="utf-8")
    for path in target.rglob("*"):
        if path.is_file() and path.suffix in TEXT_SUFFIXES and "addons" not in path.parts:
            path.write_text(path.read_text(encoding="utf-8").replace("{{TITLE}}", title), encoding="utf-8")
    (target / ".gitignore").write_text(
        ".godot/\n*.import\n!addons/dialogue_manager/**/*.svg.import\nbuild/\n", encoding="utf-8")
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target")
    parser.add_argument("title")
    args = parser.parse_args()
    print(f"Created {create(args.target, args.title)}")
