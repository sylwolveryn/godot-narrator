"""Generates data/maps/m4_dirt_field.txt (task-071): a square dirt field for play and scale tests.

The map is SIZE x SIZE cells: a `#` wall border, `D` (dirt) on every inner cell, and the spawn `@` at the centre
cell (SIZE // 2, SIZE // 2) (the spawn cell is floor). Fully deterministic: running it again writes the same file.

Usage (from the repo root):
    python tools/generate_dirt_field.py              # writes data/maps/m4_dirt_field.txt (200 x 200)
    python tools/generate_dirt_field.py --size 120 --out data/maps/other.txt
"""
import argparse
from pathlib import Path

DEFAULT_SIZE = 200
DEFAULT_OUT = Path("data/maps/m4_dirt_field.txt")
WALL = "#"
DIRT = "D"
SPAWN = "@"


def build(size: int) -> str:
    centre = size // 2
    rows = []
    for y in range(size):
        if y == 0 or y == size - 1:
            rows.append(WALL * size)
            continue
        row = [WALL] + [DIRT] * (size - 2) + [WALL]
        if y == centre:
            row[centre] = SPAWN
        rows.append("".join(row))
    return "\n".join(rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--size", type=int, default=DEFAULT_SIZE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if args.size < 3:
        raise SystemExit("size must be at least 3")
    args.out.write_text(build(args.size), encoding="utf-8", newline="\n")
    print(f"Wrote {args.out} ({args.size} x {args.size})")


if __name__ == "__main__":
    main()
