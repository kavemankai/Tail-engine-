#!/usr/bin/env python3
"""Create a new Tale Engine game from templates/starter.

    python tools/new_project.py <target_dir> "My Game Title"

Copies the engine addons (tale_engine, cinematic_action_director,
dialogue_manager), the starter episode and the authoring guides, and writes a
project.godot that reuses this repository's autoloads and input map.
"""

import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ("tale_engine", "cinematic_action_director", "dialogue_manager")
TEXT_SUFFIXES = {".gd", ".tres", ".tscn", ".md"}
DOCS = ("AUTHORING.md", "INTEGRATION.md", "ASSET_SWAP.md")
POT_FILES = 'PackedStringArray("res://game/episode_1/dialogue/intro.dialogue")'


def skip_imports(directory: str, names: list[str]) -> list[str]:
    """Drop generated *.import files, except Dialogue Manager's SVG metadata.

    Those are committed upstream; without them Godot assigns new UIDs and the
    plugin's scenes log missing-dependency errors on first import.
    """
    keep_svg = "dialogue_manager" in Path(directory).parts
    return [name for name in names
            if name.endswith(".import") and not (keep_svg and name.endswith(".svg.import"))]


def project_settings(title):
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    text = re.sub(r'config/name="[^"]*"', f'config/name="{title}"', text)
    text = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="res://game/main.tscn"', text)
    text = re.sub(r"; Keep the original application ID[^\n]*\n; The window[^\n]*\n", "", text)
    # Keep translation-template generation, pointed at the new game's dialogue.
    text = re.sub(r"locale/translations_pot_files=[^\n]*",
                  lambda _match: f"locale/translations_pot_files={POT_FILES}", text)
    return text


def create(target, title):
    target = Path(target)
    if target.exists() and any(target.iterdir()):
        raise SystemExit(f"{target} exists and is not empty")
    (target / "addons").mkdir(parents=True, exist_ok=True)
    for name in ADDONS:
        shutil.copytree(ROOT / "addons" / name, target / "addons" / name,
                        ignore=skip_imports)
    shutil.copytree(ROOT / "templates/starter", target, dirs_exist_ok=True)
    (target / "docs").mkdir(exist_ok=True)
    for name in DOCS:
        shutil.copy2(ROOT / "docs" / name, target / "docs" / name)
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
