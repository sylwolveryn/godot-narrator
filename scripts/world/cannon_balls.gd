class_name CannonBalls
extends Node
## Cannon balls (task-073), simulation side: a fixed pool of balls in packed arrays (no node per ball), stepped every
## physics step with a cheap grid march (sub-steps of at most half a cell). When a ball enters a new cell:
##  - something destructible there (Destructibles: dirt, a gargoyle, a teleport pad, later enemies) is destroyed
##    through its owner (cause CAUSE_CANNON) and the ball is spent;
##  - something solid and indestructible (walls, void and the map edge, cannons and other indestructible large props,
##    pushable objects) reflects the ball on the axis it hit (both axes in a corner), keeping CannonConfig.bounce_keep of
##    its speed;
##  - anything else (floor, spikes, corruption, items) is passed over.
## The player body reflects a ball too (circle test, reflected on the contact normal); balls never hurt the player.
## A ball lives until it has travelled range_cells, then fades (fade_seconds); a spent ball fades in hit_fade_seconds.
## CannonBallView draws the pool read-only.

const CAUSE_CANNON: StringName = &"cannon"
enum State { FREE, FLYING, FADING }

@export var config: CannonConfig
@export var map_loader: MapLoader
@export var destructibles: Destructibles
## Optional: its body reflects balls.
@export var player: Node3D
## Optional: player body radius (PlayerConfig.body_radius).
@export var player_config: PlayerConfig
## Optional: pushable objects reflect balls.
@export var pushables: PushableObjects

var _state := PackedInt32Array()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()
## Distance travelled (world units) and distance since the launch or the last bounce (the trail never folds back).
var _travel := PackedFloat32Array()
var _straight := PackedFloat32Array()
## Fading: seconds left and the fade length.
var _fade_left := PackedFloat32Array()
var _fade_len := PackedFloat32Array()
var _launched_at := PackedInt32Array()
var _active: int = 0
var _launch_counter: int = 0

## Counters (tests): balls launched, bounces, hits on destructibles, bounces off the player.
var launched: int = 0
var bounces: int = 0
var hits: int = 0
var player_bounces: int = 0


func _ready() -> void:
	if config == null:
		config = CannonConfig.new()
	_alloc()
	SignalBus.run_started.connect(func(_i: int) -> void: clear())
	if map_loader != null:
		map_loader.map_built.connect(func(_m: MapData) -> void: clear())


func capacity() -> int:
	return _state.size()


## Balls flying or fading.
func active_count() -> int:
	return _active


func state_of(i: int) -> int:
	return _state[i]


func position_of(i: int) -> Vector3:
	return _pos[i]


func velocity_of(i: int) -> Vector3:
	return _vel[i]


func size_of(i: int) -> float:
	return _size[i]


func travelled(i: int) -> float:
	return _travel[i]


## Length of straight flight behind the ball (since the launch or the last bounce), world units.
func straight_of(i: int) -> float:
	return _straight[i]


## Opacity 0..1 (1 while flying).
func alpha_of(i: int) -> float:
	if _state[i] == State.FLYING:
		return 1.0
	if _state[i] == State.FADING:
		return clampf(_fade_left[i] / maxf(_fade_len[i], 0.001), 0.0, 1.0)
	return 0.0


## Launch order of a slot (larger = newer).
func launch_order(i: int) -> int:
	return _launched_at[i]


## Removes every ball.
func clear() -> void:
	_state.fill(State.FREE)
	_active = 0


## Launches a ball at `origin` (world, at flight height) along the ground direction `dir` with half-size `size`.
## Returns its slot. A launch point inside something destructible destroys it at once (the ball is spent); inside
## something solid the ball is spent (no ball goes through a wall).
func launch(origin: Vector3, dir: Vector3, size: float) -> int:
	var slot: int = _free_slot()
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var speed: float = config.ball_speed_cells * _cell()
	if _state[slot] == State.FREE:
		_active += 1
	_state[slot] = State.FLYING
	_pos[slot] = origin
	_vel[slot] = flat * speed
	_size[slot] = size
	_travel[slot] = 0.0
	_straight[slot] = 0.0
	_launch_counter += 1
	_launched_at[slot] = _launch_counter
	launched += 1
	var cell: Vector2i = map_loader.world_to_cell(origin)
	if _hit_destructible(slot, cell) or _is_solid(cell):
		_spend(slot, config.hit_fade_seconds)
	return slot


func _physics_process(delta: float) -> void:
	if _active <= 0 or map_loader == null:
		return
	var cell_size: float = _cell()
	var max_step: float = cell_size * 0.5
	var range_len: float = config.range_cells * cell_size
	var reach_r: float = config.ball_radius + (player_config.body_radius if player_config != null else 0.0)
	var count: int = 0
	for i in _state.size():
		var st: int = _state[i]
		if st == State.FREE:
			continue
		if st == State.FADING:
			_fade_left[i] -= delta
			if _fade_left[i] <= 0.0:
				_state[i] = State.FREE
				continue
			count += 1
			continue
		count += 1
		var move: Vector3 = _vel[i] * delta
		var length: float = move.length()
		var n: int = maxi(ceili(length / max_step), 1)
		var sub: Vector3 = move / float(n)
		var sub_len: float = length / float(n)
		for k in n:
			var room: float = range_len - _travel[i]
			if room <= 0.0:
				_spend(i, config.fade_seconds)
				break
			var step: Vector3 = sub if sub_len <= room else sub * (room / sub_len)
			var from: Vector3 = _pos[i]
			var to: Vector3 = from + step
			if player != null and _bounce_off_player(i, to, reach_r):
				break
			var a: Vector2i = map_loader.world_to_cell(from)
			var b: Vector2i = map_loader.world_to_cell(to)
			if a != b:
				if _hit_destructible(i, b):
					_pos[i] = to
					_spend(i, config.hit_fade_seconds)
					break
				if _is_solid(b):
					_bounce(i, a, b)
					break
			_pos[i] = to
			_travel[i] += step.length()
			_straight[i] += step.length()
	_active = count


func _bounce_off_player(i: int, to: Vector3, reach_r: float) -> bool:
	var p: Vector3 = player.global_position
	var off := Vector3(to.x - p.x, 0.0, to.z - p.z)
	if off.length_squared() >= reach_r * reach_r:
		return false
	var normal: Vector3 = off.normalized() if off.length_squared() > 0.0 else -_vel[i].normalized()
	var v: Vector3 = _vel[i]
	if v.dot(normal) >= 0.0:
		return false
	_vel[i] = (v - 2.0 * v.dot(normal) * normal) * config.bounce_keep
	_straight[i] = 0.0
	bounces += 1
	player_bounces += 1
	SignalBus.cannon_ball_bounced.emit(_pos[i])
	return true


## Reflects on the axis crossed from cell `a` into the solid cell `b` (in a corner: the blocked axes, or both).
func _bounce(i: int, a: Vector2i, b: Vector2i) -> void:
	var v: Vector3 = _vel[i]
	var cross_x: bool = a.x != b.x
	var cross_z: bool = a.y != b.y
	if cross_x and cross_z:
		var block_x: bool = _is_solid(Vector2i(b.x, a.y))
		var block_z: bool = _is_solid(Vector2i(a.x, b.y))
		if not block_x and not block_z:
			block_x = true
			block_z = true
		cross_x = block_x
		cross_z = block_z
	if cross_x:
		v.x = -v.x
	if cross_z:
		v.z = -v.z
	_vel[i] = v * config.bounce_keep
	_straight[i] = 0.0
	bounces += 1
	SignalBus.cannon_ball_bounced.emit(_pos[i])


func _hit_destructible(i: int, cell: Vector2i) -> bool:
	if destructibles == null:
		return false
	if destructibles.destroy_at(cell, CAUSE_CANNON) == &"":
		return false
	hits += 1
	return true


## Solid and indestructible for a ball (destructible things are tested first).
func _is_solid(cell: Vector2i) -> bool:
	var map: MapData = map_loader.data
	if not map.in_bounds(cell):
		return true
	var type: StringName = map.type_at(cell)
	if type == MapLegend.WALL or type == MapLegend.VOID or type == MapLegend.DIRT:
		return true
	if map_loader.legend != null and map_loader.legend.is_large(type):
		return true
	return pushables != null and pushables.object_at(cell) >= 0


func _spend(i: int, seconds: float) -> void:
	_state[i] = State.FADING
	_fade_len[i] = maxf(seconds, 0.001)
	_fade_left[i] = _fade_len[i]


func _free_slot() -> int:
	var oldest: int = 0
	for i in _state.size():
		if _state[i] == State.FREE:
			return i
		if _launched_at[i] < _launched_at[oldest]:
			oldest = i
	return oldest


func _cell() -> float:
	return map_loader.world_config.cell_size if map_loader != null and map_loader.world_config != null else 1.0


func _alloc() -> void:
	var n: int = maxi(config.capacity, 1)
	_state.resize(n)
	_state.fill(State.FREE)
	_pos.resize(n)
	_vel.resize(n)
	_size.resize(n)
	_travel.resize(n)
	_straight.resize(n)
	_fade_left.resize(n)
	_fade_len.resize(n)
	_launched_at.resize(n)
	_launched_at.fill(0)
