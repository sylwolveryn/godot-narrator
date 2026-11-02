class_name PushConfig
extends Resource
## Tunables of the small-object pushing ability of the grown entity (task-019). Instance: resources/config/push_config.tres.

## Seconds a pushed object takes to slide one cell.
@export var slide_duration: float = 0.2
## Ease curve of the slide (Godot ease(): negative = ease in and out, 1 = linear).
@export var slide_ease: float = -2.0
## Seconds the entity has to press against an object (moving towards it) before it slides.
@export var push_hold_time: float = 0.1
## Seconds after a push before the next one can start.
@export var push_cooldown: float = 0.05
## How far (world units) beyond the collision contact the entity still counts as touching the object.
@export var contact_margin: float = 0.12
## How far (world units) beside the object's collision box the entity's centre may be and still push it.
@export var lateral_tolerance: float = 0.2
## Minimum length (0..1) of the movement input along an axis to push along it.
@export_range(0.0, 1.0) var min_intent: float = 0.35
## Cell types an object may be pushed onto (everything else blocks it: walls, void, items, hazards, the spawn).
@export var allowed_target_types: Array[StringName] = [MapLegend.FLOOR]
## Forms that can push (the single glyph cannot; objects block it like walls).
@export var pushing_forms: Array[StringName] = [EntityForm.GROWN]
