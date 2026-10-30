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

    def spawn(self, godot, root):
        self.spawned.append((godot, root))

    def sleep(self, s):
        self.now += s

    def clock(self):
        return self.now


GAME = Proc(10, "godot.exe", 'godot.exe --path E:\\git\\godot-narrator')
EDITOR = Proc(11, "godot.exe", 'godot.exe -e --path E:\\git\\godot-narrator')


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


if __name__ == "__main__":
    unittest.main()
