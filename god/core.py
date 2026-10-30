"""Pure logic for god, the Narrator developer launcher. No tkinter here, so it is unit-testable."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

DEFAULT_PROJECT_NAME = "Narrator"
SAVE_FILE_NAME = "progress.tres"
HIDDEN_FIELDS = frozenset({"revealed_cells", "script"})
CLOSE_TIMEOUT = 5.0
POLL_MS = 3000
REVEAL_RUNNING_NOTE = "Map revealed. The game is running: restart it to see the change."


# --------------------------------------------------------------------------- paths

def repo_root() -> Path:
    """The Godot project root: the parent of the god/ folder."""
    return Path(__file__).resolve().parent.parent


def project_name(root: Path) -> str:
    """config/name from project.godot, falling back to 'Narrator'."""
    try:
        text = (root / "project.godot").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return DEFAULT_PROJECT_NAME
    m = re.search(r'^config/name\s*=\s*"((?:[^"\\]|\\.)*)"', text, re.MULTILINE)
    if not m:
        return DEFAULT_PROJECT_NAME
    try:
        name = json.loads('"%s"' % m.group(1))
    except ValueError:
        name = m.group(1)
    return name or DEFAULT_PROJECT_NAME


def save_path(root: Path, env: Optional[dict] = None) -> Path:
    """%APPDATA%/Godot/app_userdata/<project name>/progress.tres."""
    env = os.environ if env is None else env
    appdata = env.get("APPDATA")
    base = Path(appdata) if appdata else Path.home() / "AppData" / "Roaming"
    return base / "Godot" / "app_userdata" / project_name(root) / SAVE_FILE_NAME


def find_godot(env: Optional[dict] = None, which: Callable[[str], Optional[str]] = shutil.which) -> Optional[str]:
    """GODOT_BIN override, else `godot` on PATH. None when neither is available."""
    env = os.environ if env is None else env
    override = env.get("GODOT_BIN")
    if override:
        return override
    return which("godot")


# --------------------------------------------------------------------------- processes

@dataclass(frozen=True)
class Proc:
    pid: int
    name: str
    cmdline: str


def _norm(text: str) -> str:
    return text.replace("\\", "/").replace('"', "").lower().rstrip("/")


def is_editor(cmdline: str) -> bool:
    tokens = cmdline.replace('"', " ").split()
    return "--editor" in tokens or "-e" in tokens


_NOT_GAME_FLAGS = ("--headless", "--script", "-s", "--check-only", "--import", "--export", "--quit")


def is_game(proc: Proc, root: Path) -> bool:
    """True for a Godot process running this project's game (not the editor, not a headless tool)."""
    if not proc.name.lower().startswith("godot"):
        return False
    cmd = proc.cmdline
    if is_editor(cmd):
        return False
    tokens = cmd.replace('"', " ").split()
    if any(flag in tokens for flag in _NOT_GAME_FLAGS):
        return False
    return _norm(str(root)) in _norm(cmd)


_PS_QUERY = (
    "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'godot*' } | "
    "Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"
)


def query_processes() -> list[Proc]:
    """All godot* processes with their command lines (Windows: PowerShell Get-CimInstance)."""
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        out = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", _PS_QUERY],
            capture_output=True, text=True, timeout=20, creationflags=flags,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return []
    if not out:
        return []
    try:
        data = json.loads(out)
    except ValueError:
        return []
    if isinstance(data, dict):
        data = [data]
    return [Proc(int(d["ProcessId"]), str(d.get("Name") or ""), str(d.get("CommandLine") or "")) for d in data]


def terminate_pid(pid: int) -> None:
    """Graceful close request (no /F): sends WM_CLOSE to the window."""
    subprocess.run(["taskkill", "/PID", str(pid), "/T"], capture_output=True,
                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))


def kill_pid(pid: int) -> None:
    subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True,
                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))


def spawn_game(godot: str, root: Path) -> None:
    flags = getattr(subprocess, "DETACHED_PROCESS", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    subprocess.Popen([godot, "--path", str(root)], cwd=str(root), creationflags=flags,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     close_fds=True)


def run_reveal_tool(godot: str, root: Path) -> tuple[bool, str]:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        r = subprocess.run([godot, "--headless", "--path", str(root), "-s", "tools/dev_reveal_map.gd"],
                           capture_output=True, text=True, timeout=120, creationflags=flags)
    except (OSError, subprocess.SubprocessError) as e:
        return False, "Could not run Godot: %s" % e
    text = r.stdout + r.stderr
    line = next((l for l in text.splitlines() if "dev_reveal_map" in l), "")
    return r.returncode == 0, line or ("exit code %d" % r.returncode)


# --------------------------------------------------------------------------- game control

class GameController:
    """Starts, closes and restarts the game. Every side effect is injectable for tests."""

    def __init__(self, root: Path, godot: Optional[str], save: Path,
                 list_procs: Callable[[], list] = query_processes,
                 terminate: Callable[[int], None] = terminate_pid,
                 kill: Callable[[int], None] = kill_pid,
                 spawn: Callable[[str, Path], None] = spawn_game,
                 sleep: Callable[[float], None] = time.sleep,
                 clock: Callable[[], float] = time.monotonic,
                 close_timeout: float = CLOSE_TIMEOUT):
        self.root, self.godot, self.save = root, godot, save
        self._list, self._terminate, self._kill, self._spawn = list_procs, terminate, kill, spawn
        self._sleep, self._clock, self.close_timeout = sleep, clock, close_timeout
        self.warned = False

    def game_processes(self) -> list:
        return [p for p in self._list() if is_game(p, self.root)]

    def is_running(self) -> bool:
        return bool(self.game_processes())

    def save_exists(self) -> bool:
        return self.save.is_file()

    def close_game(self) -> None:
        """Ask nicely, then kill whatever is still alive after close_timeout."""
        for p in self.game_processes():
            self._terminate(p.pid)
        deadline = self._clock() + self.close_timeout
        while self.game_processes():
            if self._clock() >= deadline:
                for p in self.game_processes():
                    self._kill(p.pid)
                self._sleep(0.2)
                break
            self._sleep(0.2)
        self.warned = False

    def start(self) -> None:
        if not self.godot:
            raise RuntimeError("Godot not found: put `godot` on PATH or set GODOT_BIN")
        self._spawn(self.godot, self.root)

    def new_game(self) -> None:
        self.close_game()
        try:
            self.save.unlink()
        except FileNotFoundError:
            pass
        self.start()

    def continue_game(self) -> str:
        """'no_save', 'started', 'warned' (already running, first click) or 'restarted'."""
        if not self.save_exists():
            return "no_save"
        if not self.is_running():
            self.warned = False
            self.start()
            return "started"
        if not self.warned:
            self.warned = True
            return "warned"
        self.close_game()
        self.start()
        return "restarted"

    def sync(self, running: bool) -> None:
        """Called after each poll: the warned state only lasts while the game keeps running."""
        if not running:
            self.warned = False


@dataclass(frozen=True)
class UiState:
    continue_enabled: bool
    continue_text: str
    reveal_enabled: bool
    status: str
    hint: str


def ui_state(save_exists: bool, running: bool, warned: bool, godot_found: bool = True) -> UiState:
    """What the buttons and labels should show."""
    status = "Game: running" if running else "Game: not running"
    if not godot_found:
        status += "  (Godot not found: set GODOT_BIN)"
    cont, hint = "Continue game", ""
    if running and warned:
        cont = "Click again to close and restart"
        hint = "The game is already running. Click Continue again to close and restart it."
    return UiState(save_exists, cont, save_exists, status, hint)


# --------------------------------------------------------------------------- progress parsing

class TresError(ValueError):
    pass


def _scan_depth(text: str, depth: int, in_str: bool) -> tuple:
    i = 0
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        i += 1
    return depth, in_str


def _parse_value(raw: str):
    raw = raw.strip()
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?(\d+\.\d*|\.\d+|\d+)([eE][+-]?\d+)?", raw):
        return float(raw)
    if raw in ("true", "false"):
        return raw == "true"
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2:
        try:
            return json.loads(raw)
        except ValueError:
            return raw[1:-1]
    m = re.fullmatch(r"PackedStringArray\((.*)\)", raw, re.DOTALL)
    if m:
        body = m.group(1).strip()
        if not body:
            return []
        try:
            items = json.loads("[" + body + "]")
        except ValueError:
            raise TresError("bad PackedStringArray: %.40s" % body)
        return [str(x) for x in items]
    return raw  # Dictionary, number arrays, ExtResource(...) ...: shown as raw text


def parse_progress(text: str) -> dict:
    """Read-only parse of a progress .tres: the [resource] section's key = value pairs,
    minus HIDDEN_FIELDS. Raises TresError on malformed input."""
    text = text.lstrip("﻿")
    lines = text.splitlines()
    if not lines or not lines[0].startswith("[gd_resource"):
        raise TresError("not a Godot text resource")
    try:
        start = next(i for i, l in enumerate(lines) if l.strip() == "[resource]")
    except StopIteration:
        raise TresError("no [resource] section")
    fields: dict = {}
    key: Optional[str] = None
    buf: list = []
    depth, in_str = 0, False
    for line in lines[start + 1:]:
        if key is None:
            if not line.strip():
                continue
            if line.startswith("["):
                break
            m = re.match(r"^([A-Za-z_][\w/]*)\s*=\s*(.*)$", line)
            if not m:
                raise TresError("unreadable line: %.60s" % line)
            key, buf = m.group(1), [m.group(2)]
            depth, in_str = _scan_depth(m.group(2), 0, False)
        else:
            buf.append(line)
            depth, in_str = _scan_depth(line, depth, in_str)
        if depth < 0:
            raise TresError("unbalanced brackets in %s" % key)
        if depth == 0 and not in_str:
            if key not in HIDDEN_FIELDS:
                fields[key] = _parse_value("\n".join(buf))
            key = None
    if key is not None:
        raise TresError("unterminated value for %s" % key)
    return fields


def format_value(value) -> str:
    if isinstance(value, list):
        return "%d: %s" % (len(value), ", ".join(value)) if value else "0"
    if isinstance(value, str):
        return value if value else '""'
    text = " ".join(str(value).split())
    return text if len(text) <= 120 else text[:117] + "..."


def read_progress(path: Path) -> tuple:
    """Returns ('missing', None), ('ok', fields) or ('error', message). Never writes."""
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return "missing", None
    except (OSError, UnicodeDecodeError) as e:
        return "error", "Cannot read save: %s" % e
    try:
        return "ok", parse_progress(text)
    except TresError as e:
        return "error", "Malformed save: %s" % e


def file_signature(path: Path):
    """(mtime_ns, size) or None when absent; used to spot appear/disappear/change cheaply."""
    try:
        st = path.stat()
    except OSError:
        return None
    return st.st_mtime_ns, st.st_size
