#!/usr/bin/env bash
# Records a Movie Maker capture at an exact resolution (non-headless).
# Movie Maker ignores --resolution and records at the project viewport size
# (display/window/size/viewport_width/height), and the project starts fullscreen. A temporary
# override.cfg next to project.godot sets a windowed viewport of the target size for this run.
# Usage: tools/capture_at_size.sh WxH <out_dir> <quit_after_frames> <capture_tool.gd> [tool args after --]
# Example: tools/capture_at_size.sh 2560x1080 /tmp/shots 400 tools/capture_narrator.gd ttl12
set -euo pipefail
size="$1"; out="$2"; frames="$3"; tool="$4"; shift 4
cd "$(dirname "$0")/.."
w="${size%x*}"; h="${size#*x}"
mkdir -p "$out"
printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/mode=0\n' "$w" "$h" > override.cfg
trap 'rm -f override.cfg' EXIT
if [ "$#" -gt 0 ]; then extra=(-- "$@"); else extra=(); fi
timeout 300 godot --path . --fixed-fps 30 --quit-after "$frames" --write-movie "$out/f.png" -s "$tool" "${extra[@]}"
