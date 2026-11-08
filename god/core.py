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

# Throwaway rendering prototypes (task-027/028); running one is not "the game".
SPIKE_DIR = "scenes/spikes/"
SPIKES = {
    "Spike A: glyph world": "res://scenes/spikes/glyph_world/glyph_world.tscn",
    "Spike B: glyph morph": "res://scenes/spikes/glyph_morph/glyph_morph.tscn",
}
# Potato-first rule (CLAUDE.md): every CLI run is capped at 30 FPS.
MAX_FPS_ARGS = ["--max-fps", "30"]


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
    if SPIKE_DIR in _norm(cmd):
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


def spike_args(godot: str, root: Path, scene: str) -> list[str]:
    return [godot, "--path", str(root), *MAX_FPS_ARGS, scene]


def _spawn_detached(args: list[str], root: Path) -> None:
    flags = getattr(subprocess, "DETACHED_PROCESS", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    subprocess.Popen(args, cwd=str(root), creationflags=flags,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     close_fds=True)


def spawn_game(godot: str, root: Path) -> None:
    _spawn_detached([godot, "--path", str(root), *MAX_FPS_ARGS], root)


def spawn_spike(godot: str, root: Path, scene: str) -> None:
    _spawn_detached(spike_args(godot, root, scene), root)


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


# --------------------------------------------------------------------------- SpacetimeDB (TASK-047)

DB_URL = "http://127.0.0.1:3000"
DB_NAME = "database-narrator"
DB_SERVER = "local"
DB_DIR = "database"
DB_TABLES = (
    "event_def", "language_def", "narration", "player_stats", "player_death",
    "player_language", "missing_narration", "glyph_anim", "movement_profile", "config_version",
)
# Player movement profiles (DB table movement_profile): "default" is the fallback, the others are entity forms.
MOVEMENT_PROFILES = ("default", "single", "grown")
MOVEMENT_FIELDS = ("max_speed", "acceleration", "deceleration")
DB_HTTP_TIMEOUT = 5.0
DB_PING_TIMEOUT = 1.0
DB_PUBLISH_TIMEOUT = 600
FLOAT_DECIMALS = 3
TIMESTAMP_FIELD = "__timestamp_micros_since_unix_epoch__"
DURATION_FIELD = "__time_duration_micros__"
DB_PROCESS_PREFIX = "spacetime"
DB_LOG_NAME = "narrator_spacetimedb.log"
DB_START_WAIT_TRIES = 30
DB_START_WAIT_STEP = 0.5
COLUMN_CHAR_PX = 7
COLUMN_PAD_PX = 16
COLUMN_MIN_PX = 50
COLUMN_MAX_PX = 360


class DbError(RuntimeError):
    pass


@dataclass(frozen=True)
class SqlTable:
    columns: list
    types: list
    rows: list


def _type_name(algebraic_type) -> str:
    """'String', 'F32', 'U64', 'Bool', 'Timestamp', 'TimeDuration', 'Product', 'Sum', ..."""
    if not isinstance(algebraic_type, dict) or len(algebraic_type) != 1:
        return "?"
    (kind, body), = algebraic_type.items()
    if kind == "Product" and isinstance(body, dict):
        names = [(e.get("name") or {}).get("some") for e in body.get("elements", [])]
        if names == [TIMESTAMP_FIELD]:
            return "Timestamp"
        if names == [DURATION_FIELD]:
            return "TimeDuration"
    return kind


def parse_sql_response(text: str) -> list:
    """Parse the JSON body of POST /v1/database/<db>/sql into SqlTables (one per statement).

    Body shape: [{"schema": {"elements": [{"name": {"some": col}, "algebraic_type": {"F32": []}}, ...]},
                  "rows": [[v1, v2, ...], ...], ...}]
    Raises DbError on anything else."""
    try:
        data = json.loads(text)
    except ValueError as e:
        raise DbError("SQL response is not JSON: %s" % e)
    if not isinstance(data, list):
        raise DbError("SQL response is not a list")
    tables = []
    for stmt in data:
        try:
            elements = stmt["schema"]["elements"]
            rows = stmt["rows"]
        except (KeyError, TypeError):
            raise DbError("SQL response statement has no schema/rows")
        columns, types = [], []
        for i, el in enumerate(elements):
            name = (el.get("name") or {}).get("some")
            columns.append(name if name else "col%d" % i)
            types.append(_type_name(el.get("algebraic_type")))
        tables.append(SqlTable(columns, types, [list(r) for r in rows]))
    return tables


def format_float(value: float) -> str:
    text = "%.*f" % (FLOAT_DECIMALS, value)
    text = text.rstrip("0")
    return text + "0" if text.endswith(".") else text


def format_timestamp(micros: int, tz=None) -> str:
    """Microseconds since the Unix epoch -> 'YYYY-MM-DD HH:MM:SS' (local time unless tz is given)."""
    from datetime import datetime, timezone
    dt = datetime.fromtimestamp(micros / 1_000_000, tz=timezone.utc)
    dt = dt.astimezone(tz) if tz is not None else dt.astimezone()
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def format_cell(value, type_name: str, tz=None) -> str:
    """One SQL value as display text. Timestamps arrive as [micros]."""
    if type_name in ("Timestamp", "TimeDuration") and isinstance(value, list) and len(value) == 1 \
            and isinstance(value[0], int):
        if type_name == "Timestamp":
            return format_timestamp(value[0], tz)
        return format_float(value[0] / 1_000_000) + " s"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return format_float(value)
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    return json.dumps(value, ensure_ascii=False)


def format_table(table: SqlTable, tz=None) -> list:
    """Rows of display strings, aligned with table.columns."""
    return [[format_cell(v, table.types[i] if i < len(table.types) else "?", tz) for i, v in enumerate(row)]
            for row in table.rows]


def column_width(header: str, cells: list) -> int:
    """Pixel width for a Treeview column: fits the longest text, clamped."""
    longest = max([len(header)] + [len(c) for c in cells])
    return min(max(longest * COLUMN_CHAR_PX + COLUMN_PAD_PX, COLUMN_MIN_PX), COLUMN_MAX_PX)


def is_valid_table(name: str) -> bool:
    return name in DB_TABLES


def _default_urlopen(request, timeout):
    import urllib.request
    return urllib.request.urlopen(request, timeout=timeout)


class DbClient:
    """Plain HTTP client for the local SpacetimeDB server. The token from /v1/identity is cached;
    on a 401 it is dropped and fetched again once."""

    def __init__(self, base_url: str = DB_URL, database: str = DB_NAME,
                 urlopen: Callable = _default_urlopen, timeout: float = DB_HTTP_TIMEOUT):
        self.base_url, self.database = base_url.rstrip("/"), database
        self._urlopen, self.timeout = urlopen, timeout
        self.token: Optional[str] = None

    def _request(self, method: str, path: str, body: Optional[bytes] = None,
                 headers: Optional[dict] = None, timeout: Optional[float] = None) -> tuple:
        """(status, text). HTTP error statuses are returned, not raised; connection failures raise DbError."""
        import urllib.error
        import urllib.request
        req = urllib.request.Request(self.base_url + path, data=body, method=method, headers=headers or {})
        try:
            with self._urlopen(req, timeout if timeout is not None else self.timeout) as resp:
                return resp.status, resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            try:
                return e.code, e.read().decode("utf-8", errors="replace")
            finally:
                e.close()
        except (urllib.error.URLError, OSError) as e:
            raise DbError("DB not reachable at %s: %s" % (self.base_url, getattr(e, "reason", e)))

    def ping(self) -> bool:
        try:
            status, _ = self._request("GET", "/v1/ping", timeout=DB_PING_TIMEOUT)
        except DbError:
            return False
        return status == 200

    def get_token(self) -> str:
        if self.token:
            return self.token
        status, text = self._request("POST", "/v1/identity")
        if status != 200:
            raise DbError("identity request failed (%d): %s" % (status, text.strip()))
        try:
            self.token = json.loads(text)["token"]
        except (ValueError, KeyError, TypeError):
            raise DbError("identity response has no token")
        return self.token

    def _authed(self, path: str, body: bytes, content_type: str) -> str:
        for attempt in range(2):
            headers = {"Authorization": "Bearer " + self.get_token(), "Content-Type": content_type}
            status, text = self._request("POST", path, body, headers)
            if status == 401 and attempt == 0:
                self.token = None
                continue
            if status != 200:
                raise DbError("HTTP %d: %s" % (status, text.strip()))
            return text
        raise DbError("unauthorized")

    def sql(self, query: str) -> list:
        text = self._authed("/v1/database/%s/sql" % self.database, query.encode("utf-8"), "text/plain")
        return parse_sql_response(text)

    def read_table(self, table: str) -> SqlTable:
        if not is_valid_table(table):
            raise DbError("unknown table: %s" % table)
        result = self.sql("SELECT * FROM %s" % table)
        if not result:
            raise DbError("empty SQL response for %s" % table)
        return result[0]

    def call(self, reducer: str, args: Optional[list] = None) -> None:
        self._authed("/v1/database/%s/call/%s" % (self.database, reducer),
                     json.dumps(args or []).encode("utf-8"), "application/json")


def find_spacetime(env: Optional[dict] = None, which: Callable[[str], Optional[str]] = shutil.which) -> Optional[str]:
    """SPACETIME_BIN override, else `spacetime` on PATH."""
    env = os.environ if env is None else env
    return env.get("SPACETIME_BIN") or which("spacetime")


def publish_args(spacetime: str) -> list:
    return [spacetime, "publish", DB_NAME, "--server", DB_SERVER, "--yes"]


def select_db_processes(procs: list) -> list:
    """The SpacetimeDB processes: names starting with 'spacetime' (spacetime, spacetimedb-cli,
    spacetimedb-standalone)."""
    return [p for p in procs if p.name.lower().startswith(DB_PROCESS_PREFIX)]


_PS_DB_QUERY = (
    "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'spacetime*' } | "
    "Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"
)


def query_db_processes() -> list:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        out = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", _PS_DB_QUERY],
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
    return select_db_processes(
        [Proc(int(d["ProcessId"]), str(d.get("Name") or ""), str(d.get("CommandLine") or "")) for d in data])


def db_log_path() -> Path:
    import tempfile
    return Path(tempfile.gettempdir()) / DB_LOG_NAME


def spawn_db(spacetime: str, root: Path) -> int:
    """`spacetime start` detached; output goes to %TEMP%/narrator_spacetimedb.log. Returns the PID."""
    flags = (getattr(subprocess, "DETACHED_PROCESS", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
             | getattr(subprocess, "CREATE_NO_WINDOW", 0))
    with open(db_log_path(), "ab") as log:
        p = subprocess.Popen([spacetime, "start"], cwd=str(root), creationflags=flags,
                             stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, close_fds=True)
    return p.pid


def pid_alive(pid: int) -> bool:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/NH", "/FO", "CSV"],
                             capture_output=True, text=True, timeout=10, creationflags=flags).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return ('"%d"' % pid) in out


class DbServer:
    """Start/stop/publish the local SpacetimeDB server. Side effects are injectable for tests."""

    def __init__(self, root: Path, spacetime: Optional[str], client: DbClient,
                 spawn: Callable[[str, Path], int] = spawn_db,
                 list_procs: Callable[[], list] = query_db_processes,
                 kill: Callable[[int], None] = kill_pid,
                 alive: Callable[[int], bool] = pid_alive,
                 run: Callable = subprocess.run):
        self.root, self.spacetime, self.client = root, spacetime, client
        self._spawn, self._list, self._kill, self._alive, self._run = spawn, list_procs, kill, alive, run
        self.own_pid: Optional[int] = None

    def is_running(self) -> bool:
        return self.client.ping()

    def start(self) -> str:
        """'already' or 'started'."""
        if self.is_running():
            return "already"
        if not self.spacetime:
            raise DbError("spacetime CLI not found: put it on PATH or set SPACETIME_BIN")
        self.own_pid = self._spawn(self.spacetime, self.root)
        return "started"

    def owns_server(self) -> bool:
        return self.own_pid is not None and self._alive(self.own_pid)

    def stop_own(self) -> bool:
        """Kill the process tree god started. False when there is none."""
        if not self.owns_server():
            self.own_pid = None
            return False
        self._kill(self.own_pid)
        self.own_pid = None
        return True

    def external_processes(self) -> list:
        return self._list()

    def kill_processes(self, procs: list) -> None:
        for p in procs:
            self._kill(p.pid)

    def publish(self) -> tuple:
        """(ok, output) of `spacetime publish database-narrator --server local --yes` in database/."""
        if not self.spacetime:
            return False, "spacetime CLI not found: put it on PATH or set SPACETIME_BIN"
        flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        try:
            r = self._run(publish_args(self.spacetime), cwd=str(self.root / DB_DIR), capture_output=True,
                          text=True, timeout=DB_PUBLISH_TIMEOUT, creationflags=flags,
                          encoding="utf-8", errors="replace")
        except (OSError, subprocess.SubprocessError) as e:
            return False, "Could not run spacetime: %s" % e
        return r.returncode == 0, ((r.stdout or "") + (r.stderr or "")).strip()


def db_status_text(running: bool, owned: bool, spacetime_found: bool = True) -> str:
    if running:
        text = "DB: running (%s)%s" % (DB_URL, ", started by god" if owned else "")
    else:
        text = "DB: stopped"
    if not spacetime_found:
        text += "  (spacetime CLI not found: set SPACETIME_BIN)"
    return text


def movement_args(profile: str, values: dict) -> list:
    """Arguments of the upsert_movement_profile reducer from the god form. Raises ValueError on bad input."""
    if not profile.strip():
        raise ValueError("profile is empty")
    args: list = [profile.strip()]
    for field in MOVEMENT_FIELDS:
        try:
            number = float(str(values.get(field, "")).strip())
        except ValueError:
            raise ValueError("%s must be a number" % field) from None
        if number < 0.0:
            raise ValueError("%s must not be negative" % field)
        args.append(number)
    return args


def movement_row(table: "SqlTable", profile: str) -> Optional[dict]:
    """The movement_profile row of `profile` as {column: value}, or None."""
    for row in table.rows:
        values = dict(zip(table.columns, row))
        if values.get("profile") == profile:
            return values
    return None
