#!/usr/bin/env bash
# Spike B (TASK-028) helper: run the glyph-morph spike at an exact window size, non-headless.
# Same override.cfg approach as tools/capture_at_size.sh (project starts fullscreen otherwise).
#   perf:    tools/spike_glyph_morph_run.sh perf 1920x1080 SECONDS [spike args...]   -> prints PERF lines, --max-fps 30
#   capture: tools/spike_glyph_morph_run.sh capture 1366x768 OUT_DIR FRAMES [spike args...]   -> Movie Maker PNG frames
# Spike args (see glyph_morph_demo.gd): moment=1..4 count=N cpu hud=0 seed=N
set -euo pipefail
mode="$1"; size="$2"; third="$3"; shift 3
cd "$(dirname "$0")/.."
w="${size%x*}"; h="${size#*x}"
printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/mode=0\n' "$w" "$h" > override.cfg
trap 'rm -f override.cfg' EXIT
scene="res://scenes/spikes/glyph_morph/glyph_morph.tscn"
if [ "$mode" = "perf" ]; then
	timeout 300 godot --path . --max-fps 30 "$scene" -- perf "quit=$third" "$@" | grep -E "PERF|ERROR|BUILD_MS"
else
	frames="$1"; shift
	mkdir -p "$third"
	timeout 900 godot --path . --fixed-fps 30 --quit-after "$frames" --write-movie "$third/f.png" "$scene" -- "$@"
fi
