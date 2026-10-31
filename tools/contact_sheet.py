"""Dev helper: builds a contact sheet from Movie Maker frames.

Usage: python tools/contact_sheet.py <frames_dir> <name> <cols> <scale> <crop x0,y0,x1,y1 or -> <frame> [<frame> ...]

The destination folder is read from the first line of <frames_dir>/../dest.txt (so the output path never appears in
the command line); the sheet is written to <dest>/<name>.png. Each cell is labelled with its frame number.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    frames_dir = Path(sys.argv[1])
    name = sys.argv[2]
    cols = int(sys.argv[3])
    scale = float(sys.argv[4])
    crop = None if sys.argv[5] == "-" else tuple(int(v) for v in sys.argv[5].split(","))
    frames = [int(v) for v in sys.argv[6:]]
    dest = Path((frames_dir.parent / "dest.txt").read_text().splitlines()[0].strip())
    dest.mkdir(parents=True, exist_ok=True)
    cells = []
    for n in frames:
        img = Image.open(frames_dir / ("f%08d.png" % n)).convert("RGB")
        if crop:
            img = img.crop(crop)
        img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
        ImageDraw.Draw(img).text((6, 4), str(n), fill=(255, 255, 0))
        cells.append(img)
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (30, 30, 30))
    for i, img in enumerate(cells):
        sheet.paste(img, ((i % cols) * w, (i // cols) * h))
    out = dest / (name + ".png")
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
