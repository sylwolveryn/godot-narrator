import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import core  # noqa: E402
from core import Proc, GameController  # noqa: E402

ROOT = Path("E:/git/godot-narrator")

SAMPLE = '''[gd_resource type="Resource" script_class="PersistentProgress" format=3]

[ext_resource type="Script" path="res://scripts/core/persistent_progress.gd" id="1_fxqky"]

[resource]
script = ExtResource("1_fxqky")
identity_glyph = "\u03c8"
run_count = 10
revealed_cells = {
&"m1_awakening": PackedVector2Array(20, 10, 19, 11)
}
death_count = 9
heard_beats = PackedStringArray("wake_first", "idle_still")
future_flag = true
'''


class Paths(unittest.TestCase):
    def test_save_path_from_appdata(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "project.godot").write_text('config/name="Foo"\n')
            p = core.save_path(Path(d), {"APPDATA": "C:/AD"})
            self.assertEqual(p, Path("C:/AD/Godot/app_userdata/Foo/progress.tres"))

    def test_project_name_fallback(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(core.project_name(Path(d)), "Narrator")
            (Path(d) / "project.godot").write_text("[application]\n")
            self.assertEqual(core.project_name(Path(d)), "Narrator")

    def test_real_project_name(self):
        self.assertEqual(core.project_name(core.repo_root()), "Narrator")

    def test_repo_root_is_parent_of_god(self):
        self.assertTrue((core.repo_root() / "project.godot").is_file())

    def test_godot_bin_override_then_path(self):
        self.assertEqual(core.find_godot({"GODOT_BIN": "X"}, lambda n: "P"), "X")
        self.assertEqual(core.find_godot({}, lambda n: "P"), "P")
        self.assertIsNone(core.find_godot({}, lambda n: None))


class Matching(unittest.TestCase):
    def game(self, cmd, name="godot.exe"):
        return core.is_game(Proc(1, name, cmd), ROOT)

    def test_game_matches(self):
        self.assertTrue(self.game('"E:\\godot\\godot.exe" --path E:\\git\\godot-narrator'))
        self.assertTrue(self.game('godot --path "e:/git/godot-narrator/"', "Godot_v4.exe"))

    def test_editor_excluded(self):
        self.assertFalse(self.game('godot.exe -e --path E:\\git\\godot-narrator'))
        self.assertFalse(self.game('godot.exe --editor --path E:\\git\\godot-narrator'))

    def test_other_project_and_other_process(self):
        self.assertFalse(self.game('godot.exe --path E:\\git\\other'))
        self.assertFalse(core.is_game(Proc(1, "python.exe", "--path E:\\git\\godot-narrator"), ROOT))

    def test_headless_tool_excluded(self):
        self.assertFalse(self.game('godot --headless --path E:\\git\\godot-narrator -s tools/x.gd'))

    def test_spike_is_not_the_game(self):
        self.assertTrue(self.game('godot.exe --path E:\\git\\godot-narrator --max-fps 30'))
        for scene in core.SPIKES.values():
            cmd = " ".join(core.spike_args("godot.exe", ROOT, scene))
            self.assertIn("--max-fps", cmd)
            self.assertFalse(self.game(cmd))


class Fake:
    """Fake process table: terminate removes the process unless it is 'stubborn'."""

    def __init__(self, procs=(), stubborn=False):
        self.procs = list(procs)
        self.stubborn = stubborn
        self.terminated, self.killed, self.spawned = [], [], []
        self.now = 0.0

    def list(self):
        return list(self.procs)

    def terminate(self, pid):
        self.terminated.append(pid)
        if not self.stubborn:
            self.procs = [p for p in self.procs if p.pid != pid]

    def kill(self, pid):
        self.killed.append(pid)
        self.procs = [p for p in self.procs if p.pid != pid]

    def spawn(self, godot, root, map_name=None):
        self.spawned.append((godot, root) if map_name is None else (godot, root, map_name))

    def sleep(self, s):
        self.now += s

    def clock(self):
        return self.now


GAME = Proc(10, "godot.exe", 'godot.exe --path E:\\git\\godot-narrator')
EDITOR = Proc(11, "godot.exe", 'godot.exe -e --path E:\\git\\godot-narrator')


class MapChooser(unittest.TestCase):
    """Map chooser (task-060)."""

    def test_list_maps_sorted_txt_only(self):
        with tempfile.TemporaryDirectory() as d:
            maps = Path(d) / "data" / "maps"
            maps.mkdir(parents=True)
            for name in ("m2_arena.txt", "m1_awakening.txt", "notes.md", "m3.TXT"):
                (maps / name).write_text("x")
            (maps / "sub.txt").mkdir()
            self.assertEqual(core.list_maps(Path(d)), ["m1_awakening", "m2_arena", "m3"])

    def test_list_maps_missing_folder(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(core.list_maps(Path(d)), [])

    def test_real_maps(self):
        maps = core.list_maps(core.repo_root())
        self.assertIn("m1_awakening", maps)
        self.assertIn("m2_arena", maps)

    def test_game_args(self):
        base = ["godot", "--path", str(ROOT), "--max-fps", "30"]
        self.assertEqual(core.game_args("godot", ROOT), base)
        self.assertEqual(core.game_args("godot", ROOT, "m2_arena"), base + ["--", "--map=m2_arena"])

    def test_chosen_map_is_not_a_tool_run(self):
        cmd = " ".join(core.game_args("godot.exe", ROOT, "m2_arena"))
        self.assertTrue(core.is_game(Proc(1, "godot.exe", cmd), ROOT))

    def test_choose_map(self):
        self.assertEqual(core.choose_map(["a", "b"], "b"), "b")
        self.assertEqual(core.choose_map(["a", "b"], "gone"), "a")
        self.assertEqual(core.choose_map(["a"], None), "a")
        self.assertIsNone(core.choose_map([], "a"))

    def test_settings_round_trip_and_bad_files(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "settings.json"
            self.assertEqual(core.load_settings(p), {})
            core.save_settings(p, {"map": "m2_arena"})
            self.assertEqual(core.load_settings(p), {"map": "m2_arena"})
            p.write_text("not json")
            self.assertEqual(core.load_settings(p), {})
            p.write_text("[1, 2]")
            self.assertEqual(core.load_settings(p), {})

    def test_controller_starts_on_chosen_map(self):
        f = Fake()
        with tempfile.TemporaryDirectory() as d:
            c = GameController(ROOT, "godot", Path(d) / "progress.tres", f.list, f.terminate, f.kill, f.spawn,
                               f.sleep, f.clock, 1.0)
            c.new_game()
            c.map_name = "m2_arena"
            c.new_game()
        self.assertEqual(f.spawned, [("godot", ROOT), ("godot", ROOT, "m2_arena")])


class Controller(unittest.TestCase):
    def make(self, procs=(), stubborn=False, save_exists=True):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        save = Path(self.tmp.name) / "progress.tres"
        if save_exists:
            save.write_text(SAMPLE, encoding="utf-8")
        f = Fake(procs, stubborn)
        c = GameController(ROOT, "godot", save, f.list, f.terminate, f.kill, f.spawn, f.sleep, f.clock, 1.0)
        return c, f, save

    def test_new_game_deletes_and_starts(self):
        c, f, save = self.make([GAME])
        c.new_game()
        self.assertEqual(f.terminated, [10])
        self.assertFalse(save.exists())
        self.assertEqual(len(f.spawned), 1)

    def test_new_game_without_save_or_game(self):
        c, f, save = self.make(save_exists=False)
        c.new_game()
        self.assertEqual(len(f.spawned), 1)
        self.assertEqual(f.terminated, [])

    def test_new_game_leaves_editor_alone(self):
        c, f, _ = self.make([GAME, EDITOR])
        c.new_game()
        self.assertEqual(f.terminated, [10])
        self.assertIn(EDITOR, f.procs)

    def test_kill_after_timeout(self):
        c, f, _ = self.make([GAME], stubborn=True)
        c.close_game()
        self.assertEqual(f.killed, [10])

    def test_continue_not_running_starts(self):
        c, f, _ = self.make()
        self.assertEqual(c.continue_game(), "started")
        self.assertEqual(len(f.spawned), 1)

    def test_continue_without_save(self):
        c, f, _ = self.make(save_exists=False)
        self.assertEqual(c.continue_game(), "no_save")
        self.assertEqual(f.spawned, [])

    def test_continue_running_warns_then_restarts(self):
        c, f, _ = self.make([GAME, EDITOR])
        self.assertEqual(c.continue_game(), "warned")
        self.assertEqual((f.spawned, f.terminated), ([], []))
        self.assertEqual(c.continue_game(), "restarted")
        self.assertEqual(f.terminated, [10])
        self.assertEqual(len(f.spawned), 1)
        self.assertFalse(c.warned)

    def test_warning_cleared_when_game_stops(self):
        c, f, _ = self.make([GAME])
        c.continue_game()
        self.assertTrue(c.warned)
        f.procs = []
        c.sync(c.is_running())
        self.assertFalse(c.warned)
        self.assertEqual(c.continue_game(), "started")

    def test_no_godot(self):
        c, f, _ = self.make()
        c.godot = None
        with self.assertRaises(RuntimeError):
            c.start()


class UiState(unittest.TestCase):
    def test_continue_disabled_without_save_and_enables_when_it_appears(self):
        self.assertFalse(core.ui_state(False, False, False).continue_enabled)
        self.assertTrue(core.ui_state(True, False, False).continue_enabled)

    def test_reveal_requires_save(self):
        self.assertFalse(core.ui_state(False, True, False).reveal_enabled)
        self.assertTrue(core.ui_state(True, True, False).reveal_enabled)

    def test_warning_state(self):
        s = core.ui_state(True, True, True)
        self.assertIn("already running", s.hint)
        self.assertNotEqual(s.continue_text, "Continue game")
        self.assertEqual(core.ui_state(True, True, False).hint, "")


class Progress(unittest.TestCase):
    def test_parse(self):
        f = core.parse_progress(SAMPLE)
        self.assertEqual(f["run_count"], 10)
        self.assertEqual(f["death_count"], 9)
        self.assertEqual(f["identity_glyph"], "\u03c8")
        self.assertEqual(f["heard_beats"], ["wake_first", "idle_still"])
        self.assertIs(f["future_flag"], True)
        self.assertNotIn("revealed_cells", f)
        self.assertNotIn("script", f)

    def test_real_file_shape_with_big_dictionary(self):
        f = core.parse_progress(SAMPLE.replace("19, 11)", "19, 11, 1, 2)"))
        self.assertEqual(f["death_count"], 9)

    def test_malformed(self):
        for bad in ["", "garbage", "[gd_resource]\n", "[gd_resource]\n[resource]\nrun_count 3\n",
                    "[gd_resource]\n[resource]\nheard_beats = PackedStringArray(\"a\"\n",
                    "[gd_resource]\n[resource]\nrun_count = )\n",
                    "[gd_resource]\n[resource]\nname = \"abc\n"]:
            with self.assertRaises(core.TresError, msg=repr(bad)):
                core.parse_progress(bad)

    def test_read_progress_states_and_readonly(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "progress.tres"
            self.assertEqual(core.read_progress(p), ("missing", None))
            p.write_text("junk", encoding="utf-8")
            state, msg = core.read_progress(p)
            self.assertEqual(state, "error")
            self.assertIn("Malformed", msg)
            p.write_bytes(b"\xff\xfe\x00bad")
            self.assertEqual(core.read_progress(p)[0], "error")
            p.write_text(SAMPLE, encoding="utf-8")
            before = (p.read_bytes(), p.stat().st_mtime_ns)
            self.assertEqual(core.read_progress(p)[0], "ok")
            self.assertEqual(before, (p.read_bytes(), p.stat().st_mtime_ns))

    def test_signature_changes(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "progress.tres"
            self.assertIsNone(core.file_signature(p))
            p.write_text("a")
            s1 = core.file_signature(p)
            p.write_text("abc")
            self.assertNotEqual(s1, core.file_signature(p))

    def test_format_value(self):
        self.assertEqual(core.format_value(["a", "b"]), "2: a, b")
        self.assertEqual(core.format_value([]), "0")
        self.assertEqual(core.format_value(5), "5")


# Real responses captured from the local SpacetimeDB 2.14.1 server (POST /v1/database/<db>/sql).
GLYPH_SQL = (
    '[{"schema":{"elements":[{"name":{"some":"surface"},"algebraic_type":{"String":[]}},'
    '{"name":{"some":"enabled"},"algebraic_type":{"Bool":[]}},'
    '{"name":{"some":"near_intensity"},"algebraic_type":{"F32":[]}},'
    '{"name":{"some":"radius"},"algebraic_type":{"F32":[]}}]},'
    '"rows":[["floor",true,0.55,6.0],["item",false,0.2,3.0]],'
    '"total_duration_micros":295,"stats":{"rows_inserted":0,"rows_deleted":0,"rows_updated":0}}]'
)
VERSION_SQL = (
    '[{"schema":{"elements":[{"name":{"some":"id"},"algebraic_type":{"U32":[]}},'
    '{"name":{"some":"version"},"algebraic_type":{"U64":[]}}]},"rows":[[1,1]],'
    '"total_duration_micros":110,"stats":{"rows_inserted":0,"rows_deleted":0,"rows_updated":0}}]'
)
MISSING_SQL = (
    '[{"schema":{"elements":[{"name":{"some":"key"},"algebraic_type":{"String":[]}},'
    '{"name":{"some":"first_seen"},"algebraic_type":{"Product":{"elements":[{"name":'
    '{"some":"__timestamp_micros_since_unix_epoch__"},"algebraic_type":{"I64":[]}}]}}}]},'
    '"rows":[["X",[1794144082128801]]],"total_duration_micros":168,'
    '"stats":{"rows_inserted":0,"rows_deleted":0,"rows_updated":0}}]'
)


class SqlParsing(unittest.TestCase):
    def test_columns_types_rows(self):
        (t,) = core.parse_sql_response(GLYPH_SQL)
        self.assertEqual(t.columns, ["surface", "enabled", "near_intensity", "radius"])
        self.assertEqual(t.types, ["String", "Bool", "F32", "F32"])
        self.assertEqual(t.rows[0], ["floor", True, 0.55, 6.0])

    def test_u64_singleton(self):
        (t,) = core.parse_sql_response(VERSION_SQL)
        self.assertEqual(t.types, ["U32", "U64"])
        self.assertEqual(t.rows, [[1, 1]])

    def test_timestamp_type_detected(self):
        (t,) = core.parse_sql_response(MISSING_SQL)
        self.assertEqual(t.types, ["String", "Timestamp"])
        self.assertEqual(t.rows[0][1], [1794144082128801])

    def test_format_table(self):
        from datetime import timezone
        (t,) = core.parse_sql_response(MISSING_SQL)
        self.assertEqual(core.format_table(t, timezone.utc), [["X", "2026-11-08 13:21:22"]])
        (g,) = core.parse_sql_response(GLYPH_SQL)
        self.assertEqual(core.format_table(g)[0], ["floor", "true", "0.55", "6.0"])
        self.assertEqual(core.format_table(g)[1][1], "false")

    def test_format_cell(self):
        self.assertEqual(core.format_cell(0.123456, "F64"), "0.123")
        self.assertEqual(core.format_cell(12.5, "F64"), "12.5")
        self.assertEqual(core.format_cell(18446744073709551615, "U64"), "18446744073709551615")
        self.assertEqual(core.format_cell("", "String"), "")
        self.assertEqual(core.format_cell({"some": 1}, "Sum"), '{"some": 1}')
        self.assertEqual(core.format_cell([1500000], "TimeDuration"), "1.5 s")

    def test_unnamed_column_and_empty(self):
        text = '[{"schema":{"elements":[{"name":{"none":[]},"algebraic_type":{"U64":[]}}]},"rows":[]}]'
        (t,) = core.parse_sql_response(text)
        self.assertEqual(t.columns, ["col0"])
        self.assertEqual(t.rows, [])
        self.assertEqual(core.parse_sql_response("[]"), [])

    def test_malformed(self):
        for bad in ("not json", "{}", '[{"rows": []}]', '[1]'):
            with self.assertRaises(core.DbError):
                core.parse_sql_response(bad)

    def test_column_width_clamped(self):
        self.assertEqual(core.column_width("id", ["1"]), core.COLUMN_MIN_PX)
        self.assertEqual(core.column_width("x", ["y" * 500]), core.COLUMN_MAX_PX)


class _Resp:
    def __init__(self, status, text):
        self.status, self._text = status, text

    def read(self):
        return self._text.encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class FakeHttp:
    """Scripted urlopen: maps 'METHOD path' to a list of (status, text) answers."""

    def __init__(self, answers):
        self.answers = {k: list(v) for k, v in answers.items()}
        self.requests = []

    def __call__(self, req, timeout):
        import urllib.error
        path = req.full_url.replace(core.DB_URL, "")
        self.requests.append((req.get_method(), path, req.data, dict(req.header_items())))
        status, text = self.answers["%s %s" % (req.get_method(), path)].pop(0)
        if status >= 400:
            import io
            raise urllib.error.HTTPError(req.full_url, status, "err", {}, io.BytesIO(text.encode()))
        return _Resp(status, text)


IDENTITY = '{"identity":"c200","token":"TOK"}'
SQL_PATH = "/v1/database/%s/sql" % core.DB_NAME


class DbClientTests(unittest.TestCase):
    def test_token_cached_and_sql(self):
        http = FakeHttp({"POST /v1/identity": [(200, IDENTITY)], "POST " + SQL_PATH: [(200, VERSION_SQL)] * 2})
        c = core.DbClient(urlopen=http)
        self.assertEqual(c.read_table("config_version").rows, [[1, 1]])
        c.read_table("config_version")
        self.assertEqual([r[1] for r in http.requests].count("/v1/identity"), 1)
        method, path, body, headers = http.requests[1]
        self.assertEqual(body, b"SELECT * FROM config_version")
        self.assertEqual(headers["Authorization"], "Bearer TOK")

    def test_401_refreshes_token_once(self):
        http = FakeHttp({"POST /v1/identity": [(200, IDENTITY), (200, IDENTITY)],
                         "POST " + SQL_PATH: [(401, "expired"), (200, VERSION_SQL)]})
        c = core.DbClient(urlopen=http)
        self.assertEqual(len(c.sql("SELECT * FROM config_version")), 1)

    def test_call_sends_json_args(self):
        path = "/v1/database/%s/call/report_missing" % core.DB_NAME
        http = FakeHttp({"POST /v1/identity": [(200, IDENTITY)], "POST " + path: [(200, "")]})
        core.DbClient(urlopen=http).call("report_missing", ["X"])
        self.assertEqual(http.requests[-1][2], b'["X"]')

    def test_call_error_raises(self):
        path = "/v1/database/%s/call/nope" % core.DB_NAME
        http = FakeHttp({"POST /v1/identity": [(200, IDENTITY)], "POST " + path: [(404, "no such reducer")]})
        with self.assertRaises(core.DbError):
            core.DbClient(urlopen=http).call("nope")

    def test_unknown_table_rejected(self):
        with self.assertRaises(core.DbError):
            core.DbClient(urlopen=FakeHttp({})).read_table("person; DROP")

    def test_ping(self):
        self.assertTrue(core.DbClient(urlopen=FakeHttp({"GET /v1/ping": [(200, "")]})).ping())

        def down(req, timeout):
            import urllib.error
            raise urllib.error.URLError("refused")

        self.assertFalse(core.DbClient(urlopen=down).ping())


class FakeClient:
    def __init__(self, up):
        self.up = up

    def ping(self):
        return self.up


class DbServerTests(unittest.TestCase):
    def make(self, up=False, alive=True, procs=()):
        self.spawned, self.killed = [], []
        return core.DbServer(ROOT, "spacetime", FakeClient(up),
                             spawn=lambda exe, root: self.spawned.append(exe) or 4242,
                             list_procs=lambda: list(procs), kill=self.killed.append,
                             alive=lambda pid: alive)

    def test_start_when_stopped(self):
        s = self.make(up=False)
        self.assertEqual(s.start(), "started")
        self.assertEqual(s.own_pid, 4242)

    def test_start_when_running_elsewhere(self):
        s = self.make(up=True)
        self.assertEqual(s.start(), "already")
        self.assertEqual(self.spawned, [])

    def test_start_without_cli(self):
        s = self.make()
        s.spacetime = None
        with self.assertRaises(core.DbError):
            s.start()

    def test_stop_own_kills_tracked_tree(self):
        s = self.make()
        s.start()
        self.assertTrue(s.stop_own())
        self.assertEqual(self.killed, [4242])
        self.assertIsNone(s.own_pid)

    def test_stop_own_false_when_not_started_or_dead(self):
        self.assertFalse(self.make().stop_own())
        s = self.make(alive=False)
        s.start()
        self.assertFalse(s.stop_own())
        self.assertEqual(self.killed, [])

    def test_select_db_processes(self):
        procs = [Proc(1, "spacetimedb-standalone.exe", ""), Proc(2, "godot.exe", ""), Proc(3, "Spacetime.exe", "")]
        self.assertEqual([p.pid for p in core.select_db_processes(procs)], [1, 3])

    def test_publish_runs_in_database_dir(self):
        calls = []

        class R:
            returncode, stdout, stderr = 0, "Updated database", ""

        s = core.DbServer(ROOT, "spacetime", FakeClient(True),
                          run=lambda args, **kw: calls.append((args, kw["cwd"])) or R())
        self.assertEqual(s.publish(), (True, "Updated database"))
        self.assertEqual(calls[0][0], ["spacetime", "publish", core.DB_NAME, "--server", "local", "--yes"])
        self.assertEqual(Path(calls[0][1]), ROOT / "database")

    def test_status_text(self):
        self.assertTrue(core.db_status_text(True, False).startswith("DB: running"))
        self.assertIn("started by god", core.db_status_text(True, True))
        self.assertEqual(core.db_status_text(False, False), "DB: stopped")
        self.assertIn("SPACETIME_BIN", core.db_status_text(False, False, spacetime_found=False))


if __name__ == "__main__":
    unittest.main()


class MovementFormTest(unittest.TestCase):
    def test_args_in_reducer_order(self):
        args = core.movement_args(" grown ", {"max_speed": "5.3", "acceleration": "8", "deceleration": " 10 "})
        self.assertEqual(args, ["grown", 5.3, 8.0, 10.0])

    def test_rejects_bad_numbers(self):
        with self.assertRaises(ValueError):
            core.movement_args("single", {"max_speed": "fast", "acceleration": "1", "deceleration": "1"})
        with self.assertRaises(ValueError):
            core.movement_args("single", {"max_speed": "-1", "acceleration": "1", "deceleration": "1"})
        with self.assertRaises(ValueError):
            core.movement_args(" ", {"max_speed": "1", "acceleration": "1", "deceleration": "1"})

    def test_movement_row(self):
        table = core.SqlTable(columns=["profile", "max_speed"], types=["String", "F32"], rows=[["default", 4.5], ["grown", 5.3]])
        self.assertEqual(core.movement_row(table, "grown"), {"profile": "grown", "max_speed": 5.3})
        self.assertIsNone(core.movement_row(table, "single"))
