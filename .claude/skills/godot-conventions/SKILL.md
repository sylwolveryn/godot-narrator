---
name: godot-conventions
description: Godot 4.7 GDScript, scene, and architecture conventions for this project. Use when writing or reviewing GDScript, building scenes, or setting up autoloads.
---

# Godot Conventions

## GDScript
- Static typing: `func move(vec: Vector2) -> void:`
- Prefer `Signal`, `Callable`, `Tween` (Godot 4 syntax).
- Use `StringName` for performance-critical lookups.
- Component composition over deep inheritance.
- No `get_tree().root.get_node()` from deep inside logic — use signals or exported refs.
- No `load()` inside `_process` — cache resources in `@onready` or exported vars.

## Scene files
- Do not hand-edit `.tscn` or `.tres` as text.
- Build scenes programmatically via a `extends SceneTree` tool script in `tools/`, or via the Godot MCP.
- Keep node trees shallow; use separate scenes for reusable units.

## Architecture (Layer Cake)
UI (Presentation) → Logic (Controllers/State) → Data (Resources/.tres) → Infrastructure (Autoloads/Signal Bus)
Signals travel UP only. Presentation never writes Data directly.

## Autoloads
- One signal bus autoload maximum. Name it `SignalBus`.
- No game state in autoloads; state lives in resources or a dedicated state node.

## Input
- All input goes through `InputMap`. No raw `Input.is_key_pressed` with keycodes.
- Add actions to `project.godot` under `[input]`.