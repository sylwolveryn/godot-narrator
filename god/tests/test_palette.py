import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import palette  # noqa: E402


class Palette(unittest.TestCase):
    def test_parse_and_format(self):
        self.assertEqual(palette.parse("#5A5A7A, #ffbd70,,#abc"), ["#5a5a7a", "#ffbd70", "#aabbcc"])
        self.assertEqual(palette.format_palette(["#FFF", "#123456"]), "#ffffff,#123456")
        self.assertEqual(palette.parse(""), [])

    def test_bad_colour(self):
        with self.assertRaises(ValueError):
            palette.parse("#12345g")

    def test_detection(self):
        self.assertTrue(palette.is_palette_cell("palette", "String", ""))
        self.assertTrue(palette.is_palette_cell("crystal_palette", "String", "#fff"))
        self.assertTrue(palette.is_palette_cell("trail_color", "String", "#8a6bff"))
        self.assertFalse(palette.is_palette_cell("chars", "String", ".,:;"))
        self.assertFalse(palette.is_palette_cell("palette", "F32", "1"))

    def test_limit_and_text_colour(self):
        self.assertEqual(palette.limit("glyph_anim", "palette"), 6)
        self.assertIsNone(palette.limit("avatar_fx", "trail_color"))
        self.assertEqual(palette.text_color("#ffffff"), "#000000")
        self.assertEqual(palette.text_color("#000000"), "#ffffff")


if __name__ == "__main__":
    unittest.main()
