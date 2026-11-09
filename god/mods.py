"""New-game mods (task-078): what the "Start new game with mods" dialog offers and how it becomes arguments.
A "save" mod is an argument of tools/dev_new_game.gd (it shapes the fresh save); a "game" mod (task-098) is a user
argument of the started game only (scripts/core/run_mods.gd), so it lasts for that run and never touches the DB or the
save. Pure logic, no tkinter. Add a mod here (and its argument in the tool or in RunMods)."""
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

SETTING_MODS = "new_game_mods"
TOOL = "tools/dev_new_game.gd"
TOOL_TIMEOUT = 120


SAVE = "save"   # argument of tools/dev_new_game.gd
GAME = "game"   # user argument of the started game (run only)


@dataclass(frozen=True)
class Field:
    arg: str        # argument name (--arg=value)
    label: str
    default: int
    minimum: int
    maximum: int
    toggle: bool = False    # shown as a checkbox; the value is 0 or 1


@dataclass(frozen=True)
class Mod:
    key: str
    title: str
    help: str
    fields: tuple
    target: str = SAVE
    flag: str = ""          # argument sent as --flag=1 while the mod is on (mods without fields)
    default_on: bool = True


MODS = (
    Mod("language_expert", "All languages expert", "Every language unlocked at this understanding.",
        (Field("language", "start %", 80, 0, 100),)),
    Mod("resources", "Resources", "Start with this much consumed dirt and collected diamonds.",
        (Field("dirt", "dirt", 10000, 0, 10_000_000), Field("diamonds", "diamonds", 10000, 0, 10_000_000))),
    Mod("all_forms", "All forms", "One, many and brain forms unlocked, with the menu that switches them.",
        (), flag="all_forms"),
    Mod("fog", "Fog (this run only)", "Checked: normal fog and darkness on every map. Unchecked: no fog, full light, "
        "whole map revealed.", (Field("fog", "fog on", 0, 0, 1, toggle=True),), target=GAME, default_on=False),
    Mod("sight", "Sight area (this run only)", "Reveal radius and player light of every form, in percent.",
        (Field("sight", "percent", 200, 10, 1000),), target=GAME, default_on=False),
)


def defaults() -> dict:
    """{mod key: {"on": bool, field arg: value}} with every mod at its default switch and values."""
    return {m.key: dict({"on": m.default_on}, **{f.arg: f.default for f in m.fields}) for m in MODS}


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


def _args(choices: dict, target: str) -> list:
    args = []
    for m in MODS:
        c = choices.get(m.key, {})
        if m.target != target or not c.get("on"):
            continue
        if m.flag:
            args.append("--%s=1" % m.flag)
        for f in m.fields:
            args.append("--%s=%d" % (f.arg, clamp(f, int(c.get(f.arg, f.default)))))
    return args


def tool_args(choices: dict) -> list:
    """['--language=80', '--dirt=10000', ...] for the save mods that are on (tools/dev_new_game.gd)."""
    return _args(choices, SAVE)


def game_args(choices: dict) -> list:
    """['--fog=0', '--sight=200'] for the run-only mods that are on (user arguments of the started game)."""
    return _args(choices, GAME)


def summary(choices: dict) -> str:
    parts = []
    for m in MODS:
        c = choices.get(m.key, {})
        if c.get("on"):
            values = ", ".join("%s %s" % (f.label, c.get(f.arg)) for f in m.fields)
            parts.append("%s (%s)" % (m.title, values) if values else m.title)
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
