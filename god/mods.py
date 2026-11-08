"""New-game mods (task-078): what the "Start new game with mods" dialog offers and how it becomes the arguments of
tools/dev_new_game.gd. Pure logic, no tkinter. Add a mod here (and its argument in the tool)."""
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

SETTING_MODS = "new_game_mods"
TOOL = "tools/dev_new_game.gd"
TOOL_TIMEOUT = 120


@dataclass(frozen=True)
class Field:
    arg: str        # tool argument name (--arg=value)
    label: str
    default: int
    minimum: int
    maximum: int


@dataclass(frozen=True)
class Mod:
    key: str
    title: str
    help: str
    fields: tuple


MODS = (
    Mod("language_expert", "All languages expert", "Every language unlocked at this understanding.",
        (Field("language", "start %", 80, 0, 100),)),
    Mod("resources", "Resources", "Start with this much consumed dirt and collected diamonds.",
        (Field("dirt", "dirt", 10000, 0, 10_000_000), Field("diamonds", "diamonds", 10000, 0, 10_000_000))),
)


def defaults() -> dict:
    """{mod key: {"on": bool, field arg: value}} with every mod on at its default values."""
    return {m.key: dict({"on": True}, **{f.arg: f.default for f in m.fields}) for m in MODS}


def merged(saved) -> dict:
    """The remembered choices over the defaults; unknown keys and bad values are dropped."""
    out = defaults()
    if not isinstance(saved, dict):
        return out
    for m in MODS:
        s = saved.get(m.key)
        if not isinstance(s, dict):
            continue
        if isinstance(s.get("on"), bool):
            out[m.key]["on"] = s["on"]
        for f in m.fields:
            try:
                out[m.key][f.arg] = clamp(f, int(s.get(f.arg, f.default)))
            except (TypeError, ValueError):
                pass
    return out


def clamp(field: Field, value: int) -> int:
    return max(field.minimum, min(field.maximum, value))


def tool_args(choices: dict) -> list:
    """['--language=80', '--dirt=10000', ...] for the mods that are on."""
    args = []
    for m in MODS:
        c = choices.get(m.key, {})
        if not c.get("on"):
            continue
        for f in m.fields:
            args.append("--%s=%d" % (f.arg, clamp(f, int(c.get(f.arg, f.default)))))
    return args


def summary(choices: dict) -> str:
    parts = []
    for m in MODS:
        c = choices.get(m.key, {})
        if c.get("on"):
            parts.append("%s (%s)" % (m.title, ", ".join("%s %s" % (f.label, c.get(f.arg)) for f in m.fields)))
    return "; ".join(parts) if parts else "no mods"


def run_tool(godot: str, root: Path, args: list, save: Optional[Path] = None) -> tuple:
    """Writes the modded new save with the headless tool. (ok, last tool line)."""
    cmd = [godot, "--headless", "--path", str(root), "-s", TOOL, "--", *args]
    if save is not None:
        cmd.append("--save=%s" % save)
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=TOOL_TIMEOUT, creationflags=flags)
    except (OSError, subprocess.SubprocessError) as e:
        return False, "Could not run Godot: %s" % e
    text = r.stdout + r.stderr
    line = next((l for l in text.splitlines() if "dev_new_game" in l), "")
    return r.returncode == 0, line or ("exit code %d" % r.returncode)
