"""Generates data/maps/m5_shapes.txt (task-074): the 200 x 200 dirt field of m4 with floor routes carved from shapes.

Base: SIZE x SIZE cells, `#` wall border, `D` (dirt) on every inner cell, spawn `@` at the centre (SIZE // 2, SIZE // 2).
Floor `.` is carved along these curves (centre C = the spawn, angles in radians, y grows downwards):
  - plaza:      a disk of PLAZA_RADIUS around the spawn (room to stand next to the cannons).
  - golden spiral: r = SPIRAL_A * PHI ** (theta / (pi / 2)) (grows by the golden ratio every quarter turn), from
                 r = SPIRAL_A to SPIRAL_R_MAX, SPIRAL_WIDTH cells wide.
  - rings:      concentric circles at RING_RADII, widths RING_WIDTHS.
  - rose:       r = ROSE_R * |cos(ROSE_K * theta)| (2 * ROSE_K petals through the centre), ROSE_WIDTH wide.
  - Lissajous:  x = LISS_A * sin(LISS_FA * t + LISS_PHASE), y = LISS_A * sin(LISS_FB * t), LISS_WIDTH wide.
  - spokes:     SPOKES radial lines from r = SPOKE_FROM to SPOKE_TO, starting at SPOKE_OFFSET, SPOKE_WIDTH wide.
A connectivity pass then joins every carved component that does not reach the spawn with a straight 1-cell tunnel
towards the centre, so all routes are connected to the spawn.

Placed on carved floor (seeded random, SEED, so the file is the same on every run):
  - CANNONS: `C` cells next to the spawn (in the plaza).
  - L / R wall crawlers on ring cells (CRAWLERS_PER_HAND each, at least CRAWLER_MIN_DIST from the spawn).
  - H hunters at least HUNTER_MIN_DIST from the spawn (HUNTERS), so the start is safe.
  - W wanderers at least WANDERER_MIN_DIST from the spawn (WANDERERS).
  - O black holes (BLACK_HOLES) at least HOLE_MIN_DIST from the spawn.
Enemies keep ENEMY_SPACING cells (Chebyshev) from each other and from anything else placed.

Usage (from the repo root):
    python tools/generate_shapes_map.py                 # writes data/maps/m5_shapes.txt
    python tools/generate_shapes_map.py --out data/maps/other.txt --seed 7
"""
import argparse
import math
import random
from collections import deque
from pathlib import Path

SIZE = 200
DEFAULT_OUT = Path("data/maps/m5_shapes.txt")
SEED = 5
WALL, DIRT, FLOOR, SPAWN = "#", "D", ".", "@"
CANNON, CRAWL_L, CRAWL_R, HUNTER, WANDERER, HOLE = "C", "L", "R", "H", "W", "O"

PHI = (1.0 + math.sqrt(5.0)) / 2.0
PLAZA_RADIUS = 5.5
SPIRAL_A = 3.0
SPIRAL_R_MAX = 96.0
SPIRAL_WIDTH = 2
RING_RADII = (18, 32, 47, 62, 78, 92)
RING_WIDTHS = (1, 2, 1, 2, 1, 2)
ROSE_R = 60.0
ROSE_K = 3
ROSE_WIDTH = 1
LISS_A = 86.0
LISS_FA = 3
LISS_FB = 2
LISS_PHASE = math.pi / 2.0
LISS_WIDTH = 1
SPOKES = 8
SPOKE_FROM = 18
SPOKE_TO = 92
SPOKE_OFFSET = math.pi / 8.0
SPOKE_WIDTH = 1
# Curve sampling: points per cell of arc length (dense enough that no cell of a curve is skipped).
SAMPLES_PER_CELL = 3

CANNON_CELLS = ((-3, -2), (3, 2))
CRAWLERS_PER_HAND = 6
CRAWLER_MIN_DIST = 25
HUNTERS = 6
HUNTER_MIN_DIST = 55
WANDERERS = 8
WANDERER_MIN_DIST = 22
BLACK_HOLES = 2
HOLE_MIN_DIST = 40
ENEMY_SPACING = 6


class Grid:
    def __init__(self, size: int):
        self.size = size
        self.c = size // 2
        self.cells = [[DIRT] * size for _ in range(size)]
        for i in range(size):
            for row, col in ((0, i), (size - 1, i), (i, 0), (i, size - 1)):
                self.cells[row][col] = WALL

    def inside(self, x: int, y: int) -> bool:
        return 1 <= x < self.size - 1 and 1 <= y < self.size - 1

    def cell_of(self, x: float, y: float):
        return int(math.floor(self.c + 0.5 + x)), int(math.floor(self.c + 0.5 + y))

    def carve_cell(self, cx: int, cy: int, width: int) -> None:
        """Carves a width x width block around cell (cx, cy)."""
        lo = -((width - 1) // 2)
        for dy in range(lo, lo + width):
            for dx in range(lo, lo + width):
                if self.inside(cx + dx, cy + dy):
                    self.cells[cy + dy][cx + dx] = FLOOR

    def carve(self, x: float, y: float, width: int) -> None:
        """Carves the block of the cell holding (x, y) (centre-relative coordinates)."""
        self.carve_cell(*self.cell_of(x, y), width)

    def polyline(self, points, width: int) -> None:
        """Carves along the points; a diagonal step between two cells also carves the corner cell, so every route is
        4-connected (enemies and the player move on the 4 grid directions)."""
        prev = None
        last = None
        for p in points:
            if prev is not None:
                steps = max(1, int(math.dist(prev, p) * SAMPLES_PER_CELL))
                for k in range(steps + 1):
                    t = k / steps
                    cell = self.cell_of(prev[0] + (p[0] - prev[0]) * t, prev[1] + (p[1] - prev[1]) * t)
                    if cell == last:
                        continue
                    if last is not None and cell[0] != last[0] and cell[1] != last[1]:
                        self.carve_cell(cell[0], last[1], width)
                    self.carve_cell(cell[0], cell[1], width)
                    last = cell
            prev = p


def polar(r: float, theta: float):
    return (r * math.cos(theta), r * math.sin(theta))


def carve_shapes(g: Grid) -> None:
    for y in range(-int(PLAZA_RADIUS) - 1, int(PLAZA_RADIUS) + 2):
        for x in range(-int(PLAZA_RADIUS) - 1, int(PLAZA_RADIUS) + 2):
            if x * x + y * y <= PLAZA_RADIUS * PLAZA_RADIUS:
                g.carve(x, y, 1)
    # Golden spiral.
    theta_max = math.log(SPIRAL_R_MAX / SPIRAL_A, PHI) * (math.pi / 2.0)
    pts, theta = [], 0.0
    while theta <= theta_max:
        r = SPIRAL_A * PHI ** (theta / (math.pi / 2.0))
        pts.append(polar(r, theta))
        theta += 1.0 / max(r, 1.0) / SAMPLES_PER_CELL
    g.polyline(pts, SPIRAL_WIDTH)
    # Rings.
    for radius, width in zip(RING_RADII, RING_WIDTHS):
        n = int(2 * math.pi * radius * SAMPLES_PER_CELL)
        g.polyline([polar(radius, 2 * math.pi * k / n) for k in range(n + 1)], width)
    # Rose.
    n = int(2 * math.pi * ROSE_R * SAMPLES_PER_CELL * ROSE_K)
    g.polyline([polar(ROSE_R * abs(math.cos(ROSE_K * th)), th) for th in (2 * math.pi * k / n for k in range(n + 1))], ROSE_WIDTH)
    # Lissajous.
    n = int(2 * math.pi * LISS_A * SAMPLES_PER_CELL * (LISS_FA + LISS_FB))
    g.polyline([(LISS_A * math.sin(LISS_FA * t + LISS_PHASE), LISS_A * math.sin(LISS_FB * t))
                for t in (2 * math.pi * k / n for k in range(n + 1))], LISS_WIDTH)
    # Spokes.
    for s in range(SPOKES):
        a = SPOKE_OFFSET + 2 * math.pi * s / SPOKES
        g.polyline([polar(SPOKE_FROM, a), polar(SPOKE_TO, a)], SPOKE_WIDTH)


def flood(g: Grid, start):
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in seen and g.inside(nx, ny) and g.cells[ny][nx] != DIRT:
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def connect(g: Grid) -> int:
    """Joins every component not reaching the spawn with a straight tunnel towards the centre. Returns tunnels dug."""
    tunnels = 0
    reach = flood(g, (g.c, g.c))
    done = set(reach)
    for y in range(g.size):
        for x in range(g.size):
            if g.cells[y][x] != FLOOR or (x, y) in done:
                continue
            component = flood(g, (x, y))
            done |= component
            if component & reach:
                continue
            # Walk 4-connected from the component's cell nearest to the centre until the spawn's region is reached.
            px, py = min(component, key=lambda p: math.hypot(p[0] - g.c, p[1] - g.c))
            while (px, py) not in reach:
                if abs(g.c - px) >= abs(g.c - py):
                    px += 1 if g.c > px else -1
                else:
                    py += 1 if g.c > py else -1
                g.cells[py][px] = FLOOR
            reach = flood(g, (g.c, g.c))
            done |= reach
            tunnels += 1
    return tunnels


def place(g: Grid, rng: random.Random) -> dict:
    c = g.c
    g.cells[c][c] = SPAWN
    for dx, dy in CANNON_CELLS:
        g.cells[c + dy][c + dx] = CANNON
    taken = [(c + dx, c + dy) for dx, dy in CANNON_CELLS] + [(c, c)]
    floor = [(x, y) for y in range(g.size) for x in range(g.size) if g.cells[y][x] == FLOOR]
    rng.shuffle(floor)

    def ring_cell(x: int, y: int) -> bool:
        r = math.hypot(x - c, y - c)
        return any(abs(r - rr) <= 1.0 for rr in RING_RADII)

    def free_spot(x: int, y: int) -> bool:
        return all(max(abs(x - tx), abs(y - ty)) >= ENEMY_SPACING for tx, ty in taken)

    counts = {}

    def put(char: str, n: int, min_dist: float, extra=lambda x, y: True) -> None:
        got = 0
        for x, y in floor:
            if got >= n:
                break
            if g.cells[y][x] != FLOOR or math.hypot(x - c, y - c) < min_dist or not extra(x, y) or not free_spot(x, y):
                continue
            g.cells[y][x] = char
            taken.append((x, y))
            got += 1
        counts[char] = got

    put(CRAWL_L, CRAWLERS_PER_HAND, CRAWLER_MIN_DIST, ring_cell)
    put(CRAWL_R, CRAWLERS_PER_HAND, CRAWLER_MIN_DIST, ring_cell)
    put(HUNTER, HUNTERS, HUNTER_MIN_DIST)
    put(WANDERER, WANDERERS, WANDERER_MIN_DIST)
    put(HOLE, BLACK_HOLES, HOLE_MIN_DIST)
    return counts


def build(seed: int):
    g = Grid(SIZE)
    carve_shapes(g)
    tunnels = connect(g)
    counts = place(g, random.Random(seed))
    return "\n".join("".join(row) for row in g.cells) + "\n", tunnels, counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--seed", type=int, default=SEED)
    args = parser.parse_args()
    text, tunnels, counts = build(args.seed)
    args.out.write_text(text, encoding="utf-8", newline="\n")
    floor = sum(row.count(FLOOR) for row in text.splitlines())
    print(f"Wrote {args.out} ({SIZE} x {SIZE}), {floor} floor cells, {tunnels} joining tunnels, placed {counts}")


if __name__ == "__main__":
    main()
