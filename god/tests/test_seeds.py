import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import seeds  # noqa: E402
from core import SqlTable  # noqa: E402


def table(columns, rows):
    return SqlTable(columns, ["?"] * len(columns), rows)


def tiny_seed(speed=4.5, triggered=0):
    data = {name: [] for name in seeds.TABLE_KEYS}
    data["movement_profile"] = [{"profile": "default", "max_speed": speed}]
    data["narration"] = [{"id": 1, "event": "E", "language": "EN", "triggered": triggered, "text_path": "t"}]
    data["config_version"] = [{"id": 1, "version": 0}]
    return data


class Rotation(unittest.TestCase):
    def test_first_save_creates_current_only(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self.assertEqual(seeds.existing_versions(root), [])
            self.assertEqual(seeds.save_rotating(root, tiny_seed(1.0)), ["current"])

    def test_rotation_keeps_three(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for speed in (1.0, 2.0, 3.0, 4.0):
                seeds.save_rotating(root, tiny_seed(speed))
            self.assertEqual(seeds.existing_versions(root), ["current", "previous", "old"])
            speed = {label: seeds.load_seed(seeds.version_path(root, label))["movement_profile"][0]["max_speed"]
                     for label in ("current", "previous", "old")}
            self.assertEqual(speed, {"current": 4.0, "previous": 3.0, "old": 2.0})

    def test_comment_kept_and_tabs(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            cur = seeds.version_path(root, "current")
            cur.parent.mkdir(parents=True)
            cur.write_text(json.dumps({"_comment": "keep me"}), encoding="utf-8")
            seeds.save_rotating(root, tiny_seed())
            text = cur.read_text(encoding="utf-8")
            self.assertTrue(text.startswith('{\n\t"_comment": "keep me"'))


class Order(unittest.TestCase):
    def test_keeps_reference_order_new_last(self):
        rows = [{"kind": "a"}, {"kind": "new"}, {"kind": "c"}, {"kind": "b"}]
        ref = [{"kind": "c"}, {"kind": "a"}, {"kind": "b"}]
        self.assertEqual([r["kind"] for r in seeds.order_like("enemy_def", rows, ref)], ["c", "a", "b", "new"])


class Compare(unittest.TestCase):
    def test_volatile_and_order_and_float_ignored(self):
        a = tiny_seed(4.5, triggered=0)
        b = tiny_seed(4.5000000001, triggered=12)
        b["movement_profile"].insert(0, {"profile": "a", "max_speed": 3})
        a["movement_profile"].append({"profile": "a", "max_speed": 3.0})
        self.assertTrue(seeds.same(a, b))

    def test_real_change_detected(self):
        self.assertFalse(seeds.same(tiny_seed(4.5), tiny_seed(5.0)))

    def test_snapshot_neutralises_counters(self):
        rows = seeds.rows_from_table(table(["id", "event", "triggered"], [[2, "B", 9], [1, "A", 3]]), "narration")
        self.assertEqual(rows, [{"id": 1, "event": "A", "triggered": 0}, {"id": 2, "event": "B", "triggered": 0}])

    def test_matching_version(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            seeds.save_rotating(root, tiny_seed(1.0))
            seeds.save_rotating(root, tiny_seed(2.0))
            self.assertEqual(seeds.matching_version(root, tiny_seed(1.0)), "previous")
            self.assertIsNone(seeds.matching_version(root, tiny_seed(9.0)))


class Sql(unittest.TestCase):
    def test_literals(self):
        self.assertEqual(seeds.literal(True), "true")
        self.assertEqual(seeds.literal(3), "3")
        self.assertEqual(seeds.literal(0.25), "0.25")
        self.assertEqual(seeds.literal("it's"), "'it''s'")

    def test_insert(self):
        sql = seeds.insert_sql("t", [{"a": 1, "b": "x"}, {"a": 2, "b": "y"}])
        self.assertEqual(sql, "INSERT INTO t (a, b) VALUES (1, 'x'), (2, 'y')")
        self.assertIsNone(seeds.insert_sql("t", []))

    def test_plan_skips_player_tables_and_keeps_counters(self):
        plan = dict(seeds.plan_reseed(tiny_seed(), {"_narration_live": [{"event": "E", "language": "EN", "triggered": 7}]}))
        self.assertNotIn("player_language", plan)
        self.assertNotIn("config_version", plan)
        self.assertIn("7,", plan["narration"].replace("7)", "7,"))

    def test_plan_refuses_broken_seed(self):
        bad = tiny_seed()
        del bad["enemy_def"]
        with self.assertRaises(seeds.SeedError):
            seeds.plan_reseed(bad, {})


class Reseed(unittest.TestCase):
    def _fake_db(self):
        db = {name: table(["k"], []) for name in seeds.TABLE_KEYS}
        db["narration"] = table(["id", "event", "language", "triggered", "text_path"], [[1, "E", "EN", 5, "old"]])
        db["movement_profile"] = table(["profile", "max_speed"], [["default", 1.0]])
        return db

    def test_restores_on_failure(self):
        db = self._fake_db()
        ran, logs = [], []

        def run_sql(statement):
            ran.append(statement)
            if statement.startswith("INSERT INTO movement_profile (profile, max_speed) VALUES ('default', 4.5)"):
                raise RuntimeError("boom")

        with self.assertRaises(seeds.SeedError):
            seeds.reseed(tiny_seed(), db.__getitem__, run_sql, lambda: ran.append("BUMP"), logs.append)
        self.assertNotIn("BUMP", ran)
        self.assertIn("INSERT INTO movement_profile (profile, max_speed) VALUES ('default', 1.0)", ran)

    def test_success_bumps(self):
        db = self._fake_db()
        ran = []
        seeds.reseed(tiny_seed(), db.__getitem__, ran.append, lambda: ran.append("BUMP"))
        self.assertEqual(ran[-1], "BUMP")
        self.assertTrue(any("'E', 'EN', 5, 't'" in s for s in ran))


if __name__ == "__main__":
    unittest.main()
