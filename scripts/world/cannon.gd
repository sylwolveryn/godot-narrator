class_name Cannon
extends Interactable
## One cannon `C` of the map (task-073): its merged footprint, its facing on the ground and its firing state. Owned and
## stepped by CannonSystem (the only writer); it is an Interactable, so Interactables hands it the interact action:
## a press fires one ball at once, a hold longer than CannonConfig.autofire_delay starts autofire whose rate rises
## smoothly from autofire_rate_start to autofire_rate_end over autofire_ramp seconds (then stays) until release.

## Index in CannonSystem (and in the cannon_fired signal).
var index: int = -1
var placement: LargeObjectPlacement
## Facing on the ground, radians (0 = +x, PI / 2 = +z). The barrel points this way; balls leave around it.
var facing: float = 0.0
## Turning target while a player stands next to it (radians); NAN when it keeps its facing.
var target_facing: float = NAN

var _config: CannonConfig
## Called with this cannon for every ball to fire.
var _fire: Callable
var _autofire: bool = false
## Autofire phase: a ball leaves every time it reaches 1.
var _phase: float = 0.0


func _init(cannon_index: int, cannon_placement: LargeObjectPlacement, config: CannonConfig, fire: Callable) -> void:
	index = cannon_index
	placement = cannon_placement
	footprint = cannon_placement.rect
	_config = config
	_fire = fire
	facing = deg_to_rad(config.start_facing_degrees)


## Ground direction of the barrel.
func direction() -> Vector3:
	return Vector3(cos(facing), 0.0, sin(facing))


## True while autofire runs.
func is_autofiring() -> bool:
	return _autofire


func interact_pressed() -> void:
	_autofire = false
	_phase = 0.0
	_fire.call(self)


func interact_held(delta: float, held: float) -> void:
	if held < _config.autofire_delay:
		return
	if not _autofire:
		_autofire = true
		_phase = 1.0
	else:
		_phase += _config.autofire_rate(held) * delta
	while _phase >= 1.0:
		_phase -= 1.0
		_fire.call(self)


func interact_released(_held: float, _cancelled: bool) -> void:
	_autofire = false
	_phase = 0.0


## Turns toward the target facing (if any) by at most `max_step` radians.
func turn(max_step: float) -> void:
	if is_nan(target_facing):
		return
	facing = rotate_toward(facing, target_facing, max_step)
