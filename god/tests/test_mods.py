import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import core  # noqa: E402
import mods  # noqa: E402


class Mods(unittest.TestCase):
    def test_defaults_give_requested_args(self):
        self.assertEqual(mods.tool_args(mods.defaults()),
                         ["--language=80", "--dirt=10000", "--diamonds=10000", "--all_forms=1"])
        self.assertEqual(mods.game_args(mods.defaults()), [])

    def test_run_only_mods_are_game_args(self):
        c = mods.defaults()
        c["all_forms"]["on"] = False
        c["fog"]["on"] = True
        c["sight"]["on"] = True
        c["sight"]["sight"] = 5000
        self.assertEqual(mods.game_args(c), ["--fog=0", "--sight=1000"])
        self.assertNotIn("--all_forms=1", mods.tool_args(c))
        self.assertTrue(all(not a.startswith(("--fog", "--sight")) for a in mods.tool_args(c)))
        self.assertIn("All forms", mods.summary(mods.defaults()))

    def test_game_args_reach_only_the_modded_start(self):
        calls = []
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            save = Path(d) / "progress.tres"
            ctl = core.GameController(Path(d), "godot", save, list_procs=lambda: [],
                                      spawn=lambda *a: calls.append(a[2:]), prepare=lambda *a: None)
            ctl.new_game_with_mods([], run_tool=lambda *a: (save.write_text("x") or True, "ok"),
                                   game_args=["--fog=0"])
            ctl.start()
            self.assertEqual(calls, [(None, ["--fog=0"]), ()])
        self.assertEqual(core.game_args("g", Path("r"), "m1", ["--fog=1"])[-3:], ["--", "--map=m1", "--fog=1"])
        self.assertNotIn("--", core.game_args("g", Path("r")))

    def test_off_mod_and_clamp(self):
        c = mods.defaults()
        c["language_expert"]["on"] = False
        c["resources"]["dirt"] = -5
        self.assertEqual(mods.tool_args(c), ["--dirt=0", "--diamonds=10000", "--all_forms=1"])

    def test_merged_ignores_junk(self):
        m = mods.merged({"resources": {"on": False, "dirt": "abc", "diamonds": 7}, "nope": {}})
        self.assertFalse(m["resources"]["on"])
        self.assertEqual(m["resources"]["dirt"], 10000)
        self.assertEqual(m["resources"]["diamonds"], 7)
        self.assertTrue(m["language_expert"]["on"])
        self.assertEqual(mods.merged(None), mods.defaults())

    def test_new_game_with_mods_order(self):
        calls = []
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            save = Path(d) / "progress.tres"
            save.write_text("x")
            ctl = core.GameController(Path(d), "godot", save, list_procs=lambda: [],
                                      spawn=lambda *a: calls.append("spawn"),
                                      prepare=lambda *a: calls.append("prepare"))

            def tool(godot, root, args):
                calls.append(("tool", save.exists(), tuple(args)))
                return True, "PASS dev_new_game"

            ctl.new_game_with_mods(["--dirt=1"], run_tool=tool)
            self.assertEqual(calls, ["prepare", ("tool", False, ("--dirt=1",)), "prepare", "spawn"])

            def bad(godot, root, args):
                return False, "FAIL dev_new_game: x"
            calls.clear()
            with self.assertRaises(RuntimeError):
                ctl.new_game_with_mods([], run_tool=bad)
            self.assertNotIn("spawn", calls)


class Copy(unittest.TestCase):
    def test_rows_json_example(self):
        text = core.rows_json("language_def", ["id", "name"], [["RU_RU", "Russian"], ["MATRIX", "Matrix"]])
        self.assertEqual(json.loads(text), {"language_def": [{"id": "RU_RU", "name": "Russian"},
                                                             {"id": "MATRIX", "name": "Matrix"}]})
        self.assertIn('\n  "language_def": [\n    {\n      "id": "RU_RU"', text)

    def test_cell_value(self):
        self.assertIs(core.cell_value("true", "Bool"), True)
        self.assertEqual(core.cell_value("2.5", "F32"), 2.5)
        self.assertEqual(core.cell_value("7", "U64"), 7)
        self.assertEqual(core.cell_value("#fff", "String"), "#fff")


if __name__ == "__main__":
    unittest.main()
