#!/usr/bin/env python3
"""Write the controller button icons in addons/cinematic_action_director/glyphs.

    python tools/build_glyphs.py

Plain, original SVGs: a disc or rounded key with the button's label or symbol,
labels drawn as stroked paths.
They follow each family's layout conventions (which face button carries which
letter or symbol), not any manufacturer's artwork. Replace the folder with a
licensed glyph set if the game wants the exact look.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "addons/cinematic_action_director/glyphs"
SIZE = 64
INK = "#f2f2f2"
DISC = "#2b2f3a"
EDGE = "#8b93a7"


# Strokes for the few characters the labels need, on a 10 x 14 grid. Godot's
# SVG importer does not draw <text>, so letters are paths.
STROKES = {
    "A": "M0 14 L5 0 L10 14 M2 9 L8 9",
    "B": "M0 0 L0 14 L6 14 Q10 14 10 10.5 Q10 7 6 7 L0 7 M0 0 L5 0 Q9 0 9 3.5 Q9 7 5 7",
    "X": "M0 0 L10 14 M10 0 L0 14",
    "Y": "M0 0 L5 7 L10 0 M5 7 L5 14",
    "L": "M0 0 L0 14 L9 14",
    "R": "M0 14 L0 0 L6 0 Q10 0 10 3.5 Q10 7 6 7 L0 7 M5 7 L10 14",
    "T": "M0 0 L10 0 M5 0 L5 14",
    "Z": "M0 0 L10 0 L0 14 L10 14",
    "1": "M2 3 L5 0 L5 14 M2 14 L8 14",
    "2": "M0 3 Q0 0 5 0 Q10 0 10 4 Q10 7 0 14 L10 14",
    "+": "M5 2 L5 12 M0 7 L10 7",
    "-": "M0 7 L10 7",
    "=": "M0 3 L10 3 M0 7 L10 7 M0 11 L10 11",
}


def label(text: str, colour: str, height: float) -> str:
    """Stroked characters centred on the 64 px canvas."""
    scale = height / 14.0
    advance = 14.0
    width = (len(text) - 1) * advance + 10.0
    x0 = 32 - width * scale / 2
    y0 = 32 - height / 2
    parts = []
    for i, char in enumerate(text):
        parts.append(f'<path transform="translate({x0 + i * advance * scale:.2f} {y0:.2f}) scale({scale:.3f})" '
                     f'd="{STROKES[char]}" fill="none" stroke="{colour}" stroke-width="{3.2 / scale:.2f}" '
                     f'stroke-linecap="round" stroke-linejoin="round"/>')
    return "".join(parts)


def disc(inner: str, colour: str = INK) -> str:
    return (f'<circle cx="32" cy="32" r="28" fill="{DISC}" stroke="{EDGE}" stroke-width="3"/>'
            + inner.replace("INK", colour))


def letter(text: str, colour: str = INK, size: int = 26) -> str:
    return disc(label(text, "INK", size), colour)


def key(text: str, width: int = 56) -> str:
    x = (SIZE - width) / 2
    return (f'<rect x="{x}" y="14" width="{width}" height="36" rx="9" fill="{DISC}" stroke="{EDGE}" stroke-width="3"/>'
            + label(text, INK, 18 if len(text) <= 2 else 14))


def dpad(direction: str) -> str:
    arm = {"up": (24, 6, 16, 26), "down": (24, 32, 16, 26), "left": (6, 24, 26, 16), "right": (32, 24, 26, 16)}
    shapes = [f'<rect x="24" y="6" width="16" height="52" rx="4" fill="{DISC}" stroke="{EDGE}" stroke-width="2"/>',
              f'<rect x="6" y="24" width="52" height="16" rx="4" fill="{DISC}" stroke="{EDGE}" stroke-width="2"/>']
    x, y, w, h = arm[direction]
    shapes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{INK}"/>')
    return "".join(shapes)


SHAPES = {
    "cross": '<path d="M20 20 L44 44 M44 20 L20 44" stroke="INK" stroke-width="5" stroke-linecap="round"/>',
    "circle": '<circle cx="32" cy="32" r="12" fill="none" stroke="INK" stroke-width="5"/>',
    "square": '<rect x="20" y="20" width="24" height="24" fill="none" stroke="INK" stroke-width="5"/>',
    "triangle": '<path d="M32 18 L46 42 L18 42 Z" fill="none" stroke="INK" stroke-width="5" stroke-linejoin="round"/>',
}

# Keys are CADPrompt.ICON_KEYS values: positions, the same on every family.
COMMON = {
    "lb": None, "rb": None, "lt": None, "rt": None,
    "dpad_up": dpad("up"), "dpad_down": dpad("down"), "dpad_left": dpad("left"), "dpad_right": dpad("right"),
    "ls": letter("L", size=22), "rs": letter("R", size=22),
}
FAMILIES = {
    "xbox": {
        "a": letter("A", "#7fd36b"), "b": letter("B", "#ff6b6b"), "x": letter("X", "#5aa9ff"), "y": letter("Y", "#ffd34d"),
        "lb": key("LB"), "rb": key("RB"), "lt": key("LT"), "rt": key("RT"), "start": key("="), "back": key("-"),
    },
    "playstation": {
        "a": disc(SHAPES["cross"], "#8fb8ff"), "b": disc(SHAPES["circle"], "#ff7b8a"),
        "x": disc(SHAPES["square"], "#f29ad8"), "y": disc(SHAPES["triangle"], "#6fe0c4"),
        "lb": key("L1"), "rb": key("R1"), "lt": key("L2"), "rt": key("R2"), "start": key("="), "back": key("-"),
    },
    "nintendo": {
        # Positions: the bottom button is B, the right one A.
        "a": letter("B"), "b": letter("A"), "x": letter("Y"), "y": letter("X"),
        "lb": key("L"), "rb": key("R"), "lt": key("ZL"), "rt": key("ZR"), "start": key("+"), "back": key("-"),
    },
}


def main() -> None:
    for family, buttons in FAMILIES.items():
        folder = OUT / family
        folder.mkdir(parents=True, exist_ok=True)
        for name, body in {**COMMON, **buttons}.items():
            if body is None:
                continue
            svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
                   f'viewBox="0 0 {SIZE} {SIZE}">{body}</svg>\n')
            (folder / f"{name}.svg").write_text(svg, encoding="utf-8")
    print(f"Wrote glyphs to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
