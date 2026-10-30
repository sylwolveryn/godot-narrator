# Godot CLI Reference (verified against 4.7)

## Identify project and version
godot --version
godot --path /path/to/project

## Run and edit
godot --path .                            # run main scene
godot --path . res://scenes/test.tscn     # run a specific scene
godot -e --path .                         # open editor
godot --path . --quit-after 300           # run 300 frames then exit (smoke test)

## Import assets headless (do this before exporting or fresh-clone runs)
godot --headless --import --path .

## Syntax-check GDScript without running
godot --headless --check-only --script res://scripts/player.gd

## Run a standalone GDScript (tooling, build steps)
# Script must `extends SceneTree` and call quit().
godot --headless --path . -s tools/report.gd

## Export
godot --headless --export-release "Windows Desktop" build/game.exe
godot --headless --export-debug   "Linux/X11"      build/game.x86_64
godot --headless --export-pack    "Web"            build/game.pck

## Useful runtime flags
--headless              no window or audio
--verbose / -v          verbose engine logging
--debug / -d            local stdout debugger (stack traces on error)
--quit-after N          quit after N frames
--fixed-fps N           deterministic runs
--disable-render-loop   offline runs

## Verifying a change (minimum evidence)
1. godot --headless --check-only --script <edited>.gd
2. godot --path . --quit-after N   (confirm no runtime errors; watch stdout with --verbose)
3. For UI: look at the rendered result.