"""Colour palette cells (task-077): DB text like "#5a5a7a,#ffbd70,#ff8c5a". Pure logic, no tkinter."""
from __future__ import annotations

import re
from typing import Optional

_HEX = re.compile(r"^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})$")
# Colours the game uses at most per palette column (the rest are ignored): GlyphAnimConfig.max_palette and
# AvatarFxConfig.crystal_max_colors (shader arrays of 6).
LIMITS = {
    ("glyph_anim", "palette"): 6,
    ("avatar_fx", "crystal_palette"): 6,
}
PALETTE_WORD = "palette"


def is_color(text: str) -> bool:
    return bool(_HEX.match(text.strip()))


def normalize(color: str) -> str:
    """'#ABC' / '#AABBCC' -> '#aabbcc'. Raises ValueError for anything else."""
    c = color.strip()
    if not is_color(c):
        raise ValueError("not a #rrggbb colour: %r" % color)
    if len(c) == 4:
        c = "#" + "".join(ch * 2 for ch in c[1:])
    return c.lower()


def parse(text: str) -> list:
    """The colours of a palette cell, in order. Raises ValueError when a part is not a colour."""
    parts = [p.strip() for p in str(text).split(",")]
    return [normalize(p) for p in parts if p]


def format_palette(colors: list) -> str:
    return ",".join(normalize(c) for c in colors)


def is_palette_cell(column: str, type_name: str, value: str) -> bool:
    """Opens the palette editor: a String column named *palette*, or one whose value is a list of colours
    (single colours like avatar_fx.trail_color included)."""
    if type_name != "String":
        return False
    if PALETTE_WORD in column.lower():
        return True
    try:
        return bool(value.strip()) and len(parse(value)) > 0
    except ValueError:
        return False


def limit(table: str, column: str) -> Optional[int]:
    return LIMITS.get((table, column))


def text_color(background: str) -> str:
    """Black or white, whichever reads better on the background colour."""
    c = normalize(background)
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return "#000000" if (0.299 * r + 0.587 * g + 0.114 * b) > 140 else "#ffffff"
