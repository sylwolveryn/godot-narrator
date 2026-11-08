---
name: godot-potato-perf
description: Godot 4 low-end laptop performance patterns. Use when writing _process, physics, rendering, or particle code.
---

# Low-End Performance Patterns

## Why
Target is integrated GPU (OpenGL 3.3 minimum). Every draw call and every per-frame allocation counts.

## Patterns

### Cache node references
```gdscript
# BAD
func _process(_delta):
    $Sprite2D.modulate.a -= 0.01

# GOOD
@onready var _sprite: Sprite2D = $Sprite2D
func _process(_delta):
    _sprite.modulate.a -= 0.01