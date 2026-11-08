"""Seed versions (task-020.06): save the DB lookup tables into data/db/seed.json and reseed the DB from it.

Three versions are kept as JSON files next to each other:
    current  -> data/db/seed.json       (what the game bundles and loads when the DB is offline)
    previous -> data/db/seed.prev.json
    old      -> data/db/seed.old.json
Saving rotates them: old <- previous, previous <- current, current <- the DB state. A missing file is simply skipped.

Gameplay counters live in some seed tables too (narration.triggered, player_language.understanding,
config_version.version). They are written to a seed with their neutral value, ignored when comparing, and never
overwritten by a reseed. player_language and config_version are not reseeded at all (player data / reload counter).
No tkinter here, so it is unit-testable.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Callable, Optional

SEED_DIR = "data/db"
# (label, file name), newest first.
VERSIONS = (("current", "seed.json"), ("previous", "seed.prev.json"), ("old", "seed.old.json"))
COMMENT_KEY = "_comment"
DEFAULT_COMMENT = ("Bundled copy of the SpacetimeDB lookup tables (database/spacetimedb/src/lib.rs seeds the same rows). "
                   "Used when the DB is offline.")
# The tables a seed holds, in file order, with their primary key.
TABLE_KEYS = {
    "event_def": "id",
    "language_def": "id",
    "narration": "id",
    "glyph_anim": "surface",
    "config_version": "id",
    "movement_profile": "profile",
    "avatar_fx": "profile",
    "player_language": "language",
    "map_settings": "map_id",
    "enemy_def": "kind",
}
# Columns changed by playing, not by tuning: neutral value in a seed, ignored by comparisons, kept by a reseed.
VOLATILE = {
    "narration": {"triggered": 0},
    "player_language": {"understanding": 0.0},
    "config_version": {"version": 0},
}
NOT_RESEEDED = ("player_language", "config_version")
# Comparison precision for floats (F32 columns come back as the nearest double).
FLOAT_DIGITS = 6


class SeedError(RuntimeError):
    pass


# --------------------------------------------------------------------------- files

def version_paths(root: Path) -> list:
    """[(label, path)] for all three versions, newest first (files may not exist)."""
    return [(label, root / SEED_DIR / name) for label, name in VERSIONS]


def version_path(root: Path, label: str) -> Path:
    for name, path in version_paths(root):
        if name == label:
            return path
    raise SeedError("unknown seed version %r" % label)


def existing_versions(root: Path) -> list:
    """Labels of the versions whose file exists, newest first."""
    return [label for label, path in version_paths(root) if path.is_file()]


def load_seed(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise SeedError("cannot read %s: %s" % (path.name, e))
    if not isinstance(data, dict):
        raise SeedError("%s is not a JSON object" % path.name)
    return data


def dump_seed(data: dict) -> str:
    return json.dumps(data, indent="\t", ensure_ascii=False) + "\n"


def _write(path: Path, text: str) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8", newline="\n")
    os.replace(tmp, path)


def order_like(name: str, rows: list, reference) -> list:
    """`rows` in the order their keys have in `reference` (the seed being replaced), new rows after, so a saved seed
    differs from the old one only where the data changed."""
    key = TABLE_KEYS.get(name)
    if key is None or not isinstance(reference, list):
        return rows
    rank = {}
    for i, row in enumerate(reference):
        if isinstance(row, dict) and row.get(key) not in rank:
            rank[row.get(key)] = i
    known = [r for r in rows if r.get(key) in rank]
    known.sort(key=lambda r: rank[r.get(key)])
    return known + [r for r in rows if r.get(key) not in rank]


def save_rotating(root: Path, tables: dict) -> list:
    """Rotate the versions (old <- previous <- current) and write `tables` as the new current.
    Returns the labels that exist afterwards."""
    paths = dict(version_paths(root))
    current, previous, old = paths["current"], paths["previous"], paths["old"]
    comment = DEFAULT_COMMENT
    before: dict = {}
    if current.is_file():
        try:
            before = load_seed(current)
            comment = before.get(COMMENT_KEY, DEFAULT_COMMENT)
        except SeedError:
            pass
    data = {COMMENT_KEY: comment}
    for name, rows in tables.items():
        data[name] = order_like(name, rows, before.get(name))
    text = dump_seed(data)
    current.parent.mkdir(parents=True, exist_ok=True)
    if previous.is_file():
        os.replace(previous, old)
    if current.is_file():
        os.replace(current, previous)
    _write(current, text)
    return existing_versions(root)


# --------------------------------------------------------------------------- DB <-> seed rows

def rows_from_table(table, name: str) -> list:
    """SqlTable -> list of row dicts in column order, sorted by key, volatile columns neutralised."""
    neutral = VOLATILE.get(name, {})
    rows = []
    for raw in table.rows:
        row = {}
        for column, value in zip(table.columns, raw):
            row[column] = neutral.get(column, value)
        rows.append(row)
    key = TABLE_KEYS[name]
    rows.sort(key=lambda r: _sort_key(r.get(key)))
    return rows


def _sort_key(value):
    return (0, value, "") if isinstance(value, (int, float)) and not isinstance(value, bool) else (1, 0, str(value))


def snapshot(read_table: Callable) -> dict:
    """The seed tables as they are in the DB now. read_table(name) -> SqlTable."""
    return {name: rows_from_table(read_table(name), name) for name in TABLE_KEYS}


def _canon_value(value):
    if isinstance(value, float):
        return round(value, FLOAT_DIGITS)
    return value


def canonical(data: dict) -> dict:
    """Comparable form: seed tables only, volatile columns neutral, rows sorted by key, floats rounded.
    An int and a float with the same value compare equal (JSON may write 3 for 3.0)."""
    out = {}
    for name, key in TABLE_KEYS.items():
        neutral = VOLATILE.get(name, {})
        rows = []
        for row in data.get(name) or []:
            if not isinstance(row, dict):
                continue
            rows.append({col: _canon_value(float(v) if isinstance(v, int) and not isinstance(v, bool) else v)
                         if col not in neutral else neutral[col] for col, v in row.items()})
        rows.sort(key=lambda r: _sort_key(r.get(key)))
        out[name] = rows
    return out


def same(a: dict, b: dict) -> bool:
    return canonical(a) == canonical(b)


def matching_version(root: Path, db_tables: dict) -> Optional[str]:
    """The newest version label whose file equals the DB state, or None."""
    for label in existing_versions(root):
        try:
            if same(load_seed(version_path(root, label)), db_tables):
                return label
        except SeedError:
            continue
    return None


# --------------------------------------------------------------------------- reseed

def literal(value) -> str:
    """A SpacetimeDB SQL literal for a JSON scalar."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    raise SeedError("unsupported value %r" % (value,))


def insert_sql(name: str, rows: list) -> Optional[str]:
    """One multi-row INSERT for a table (None when there are no rows). All rows must have the same columns."""
    if not rows:
        return None
    columns = list(rows[0].keys())
    values = []
    for row in rows:
        if list(row.keys()) != columns:
            raise SeedError("%s: rows have different columns" % name)
        values.append("(" + ", ".join(literal(row[c]) for c in columns) + ")")
    return "INSERT INTO %s (%s) VALUES %s" % (name, ", ".join(columns), ", ".join(values))


def plan_reseed(seed: dict, db_tables: dict) -> list:
    """[(table, insert_sql or None)] to make the DB tables equal the seed. Volatile columns keep their DB values
    (narration.triggered by event + language). Raises SeedError before anything is written when the seed is unusable."""
    plan = []
    for name in TABLE_KEYS:
        if name in NOT_RESEEDED:
            continue
        rows = seed.get(name)
        if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
            raise SeedError("seed has no usable %s table" % name)
        rows = [dict(r) for r in rows]
        if name == "narration":
            triggered = {(r.get("event"), r.get("language")): r.get("triggered", 0)
                         for r in db_tables.get("_narration_live", [])}
            for r in rows:
                r["triggered"] = triggered.get((r.get("event"), r.get("language")), 0)
        plan.append((name, insert_sql(name, rows)))
    return plan


def reseed(seed: dict, read_table: Callable, run_sql: Callable, bump: Callable, log: Callable = lambda _t: None) -> int:
    """Replace the reseedable DB tables with the seed's rows. run_sql(statement) runs one owner SQL statement.
    On a failure the touched tables are restored from a backup taken first. Returns the number of rows written."""
    # The real narration counters (not neutralised), carried over into the new rows.
    raw = read_table("narration")
    live = [dict(zip(raw.columns, r)) for r in raw.rows]
    plan = plan_reseed(seed, {"_narration_live": live})
    backup = []
    for name, _sql in plan:
        t = read_table(name)
        backup.append((name, insert_sql(name, [dict(zip(t.columns, r)) for r in t.rows])))
    done = []
    written = 0
    try:
        for name, sql in plan:
            done.append(name)
            run_sql("DELETE FROM %s" % name)
            if sql:
                run_sql(sql)
            count = len(seed.get(name) or [])
            written += count
            log("  %s: %d rows" % (name, count))
    except Exception as e:
        log("  failed on %s, restoring the previous rows" % (done[-1] if done else "?"))
        for name, sql in backup:
            if name not in done:
                continue
            try:
                run_sql("DELETE FROM %s" % name)
                if sql:
                    run_sql(sql)
            except Exception as e2:  # report, keep restoring the others
                log("  could not restore %s: %s" % (name, e2))
        raise SeedError("reseed failed: %s" % e)
    bump()
    return written
