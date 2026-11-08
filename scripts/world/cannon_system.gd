class_name CannonSystem
extends Node
## Cannons `C` (task-073), logic side and the only writer of their state. On every map build it makes one Cannon per
## merged cannon footprint (LargeObjectMerger: `C` = 1x1, `CC/CC` = 2x2 ...) and registers it with Interactables.
## Every physics step: a cannon whose reach (the 8 cells around its footprint) holds the player turns smoothly
## (CannonConfig.turn_speed_degrees) to face AWAY from the player (direction player -> footprint centre), so the player
## stands behind it; otherwise it keeps its last facing. Firing (through the interact hold, see Cannon) launches a ball
## from the muzzle (footprint edge along the facing + a margin) in a random direction within the cone around the facing,
## sized by the footprint, into CannonBalls; SignalBus.cannon_fired announces it (boom, muzzle flash).
## The run start puts every cannon back to the start facing.
## Many form (task-077): while the entity form is CannonConfig.many_form (SignalBus.entity_form_changed), autofire is
## many_rate_multiplier times faster and each shot launches many_balls_min..many_balls_max balls (random); the first
## such shot fires the narration event MANY_FIRED_CANNON.

@export var config: CannonConfig
@export var map_loader: MapLoader
@export var player: Node3D
@export var interactables: Interactables
@export var balls: CannonBalls

## Cone picks; tests seed it.
var rng := RandomNumberGenerator.new()

var _cannons: Array[Cannon] = []
## Balls fired since the map was built (tests).
var fired: int = 0
## The entity form last announced (SignalBus.entity_form_changed).
var form: StringName = EntityForm.SINGLE


func _ready() -> void:
	if config == null:
		config = CannonConfig.new()
	rng.randomize()
	SignalBus.run_started.connect(func(_i: int) -> void: reset_facing())
	SignalBus.entity_form_changed.connect(_on_entity_form_changed)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func cannon_count() -> int:
	return _cannons.size()


func cannon(index: int) -> Cannon:
	return _cannons[index]


## Every cannon faces the start direction again.
func reset_facing() -> void:
	for c in _cannons:
		c.facing = deg_to_rad(config.start_facing_degrees)
		c.target_facing = NAN


## True while the many form's cannon rules apply.
func is_many() -> bool:
	return form == config.many_form


## Balls one shot launches: 1, or a random count in the many range while the many form fires.
func balls_per_shot() -> int:
	if not is_many():
		return 1
	var lo: int = maxi(config.many_balls_min, 1)
	return rng.randi_range(lo, maxi(config.many_balls_max, lo))


## One shot of cannon `c` (Cannon calls it on press and on every autofire beat): one ball, several in the many form,
## each in its own random direction within the cone.
func fire(c: Cannon) -> void:
	if balls == null or map_loader == null:
		return
	var half_cone: float = deg_to_rad(config.cone_degrees) * 0.5
	var muzzle: Vector3 = muzzle_of(c)
	for i in balls_per_shot():
		var angle: float = c.facing + rng.randf_range(-half_cone, half_cone)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		balls.launch(muzzle, dir, config.ball_size_for(c.footprint.size))
		fired += 1
		SignalBus.cannon_fired.emit(c.index, muzzle, dir)
	if is_many():
		SignalBus.narration_event.emit(NarrationEvents.MANY_FIRED_CANNON)


## Launch point of cannon `c`: on the footprint edge along its facing plus the muzzle margin, at the flight height.
func muzzle_of(c: Cannon) -> Vector3:
	var s: float = map_loader.world_config.cell_size
	var centre: Vector3 = map_loader.rect_to_world(c.footprint)
	var d: Vector3 = c.direction()
	var hx: float = c.footprint.size.x * s * 0.5
	var hz: float = c.footprint.size.y * s * 0.5
	var t: float = minf(hx / maxf(absf(d.x), 0.0001), hz / maxf(absf(d.z), 0.0001))
	return centre + d * (t + config.muzzle_margin_cells * s) + Vector3.UP * config.ball_height


func _physics_process(delta: float) -> void:
	if player == null or map_loader == null or _cannons.is_empty():
		return
	var cell: Vector2i = map_loader.world_to_cell(player.global_position)
	var reach: int = interactables.config.default_reach if interactables != null and interactables.config != null else 1
	var step: float = deg_to_rad(config.turn_speed_degrees) * delta
	for c in _cannons:
		if c.in_reach(cell, reach):
			var away: Vector3 = map_loader.rect_to_world(c.footprint) - player.global_position
			if Vector2(away.x, away.z).length_squared() > 0.0:
				c.target_facing = atan2(away.z, away.x)
		else:
			c.target_facing = NAN
		c.turn(step)


func _on_entity_form_changed(new_form: StringName, _animate: bool) -> void:
	form = new_form
	var factor: float = config.many_rate_multiplier if is_many() else 1.0
	for c in _cannons:
		c.rate_multiplier = factor


func _on_map_built(map: MapData) -> void:
	for c in _cannons:
		if interactables != null:
			interactables.unregister(c)
	_cannons.clear()
	fired = 0
	for p in map.large_objects:
		if p.type != config.cannon_type:
			continue
		var c := Cannon.new(_cannons.size(), p, config, fire)
		c.rate_multiplier = config.many_rate_multiplier if is_many() else 1.0
		_cannons.append(c)
		if interactables != null:
			interactables.register(c)
