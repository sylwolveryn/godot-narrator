extends SceneTree
## Headless test of sprint (task-063) on the real main scene: locked before the first death; afterwards Shift (or a
## gamepad shoulder) raises the top speed, accelerates faster and lets the stop glide; SPRINT_UNLOCKED on the first move.
## Collisions and hazards are switched off so the measured motion does not depend on the map layout.
## Usage: godot --headless --path . --max-fps 30 -s tools/test_sprint.gd

const PHASE_PLAYING := 1
const Support := preload("res://tools/test_support.gd")
const TAG := "sprint"
## Speed share counted as "reached" a top speed, and slack allowed above a top speed.
const REACHED := 0.98
const SPEED_SLACK := 1.01
## Sprint acceleration must reach the normal top speed in at most this share of the normal time (2x accel -> ~0.5).
const MAX_ACCEL_TIME_SHARE := 0.7
## A post-sprint glide must travel at least this many times the normal stop distance.
const MIN_GLIDE_SHARE := 2.0
## Releasing Shift while walking on: the next stop may travel at most this many times the normal stop distance.
const MAX_EASED_STOP_SHARE := 1.2
const STOPPED_SPEED := 0.01
const HOLD_SECONDS := 1.0
const STOP_TIMEOUT := 3.0

var _failures: PackedStringArray = []
var _events: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _stick(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Horizontal speed of the player after each of the next physics steps for `seconds` (physics time).
func _speeds(player: CharacterBody3D, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var steps: int = ceili(seconds * Engine.physics_ticks_per_second)
	for i in steps:
		await physics_frame
		out.append(Vector2(player.velocity.x, player.velocity.z).length())
	return out


## Physics seconds until the speed first reached `target`, or -1.
func _time_to(speeds: PackedFloat32Array, target: float) -> float:
	for i in speeds.size():
		if speeds[i] >= target:
			return float(i + 1) / Engine.physics_ticks_per_second
	return -1.0


func _max(speeds: PackedFloat32Array) -> float:
	var m: float = 0.0
	for s in speeds:
		m = maxf(m, s)
	return m


## Waits until the player has stopped (or the timeout) and returns the distance travelled since `from`.
func _stop_distance(player: CharacterBody3D, from: Vector3) -> float:
	var steps: int = ceili(STOP_TIMEOUT * Engine.physics_ticks_per_second)
	for i in steps:
		await physics_frame
		if player.velocity.length() < STOPPED_SPEED:
			break
	_check(player.velocity.length() < STOPPED_SPEED, "player did not stop within %.1f s" % STOP_TIMEOUT)
	return Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()


func _run() -> void:
	var on_event := func(id: StringName) -> void: _events.append(id)
	root.get_node("SignalBus").connect("narration_event", on_event)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg: RunConfig = main.get_node("RunManager").get("config").duplicate()
	run_cfg.restart_delay = 0.0
	main.get_node("RunManager").set("config", run_cfg)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var player: CharacterBody3D = main.get_node("Player")
	var save: Node = main.get_node("SaveService")
	# Free motion: no walls, no spikes or corruption ending the run mid-measurement.
	player.collision_mask = 0
	main.get_node("HazardMonitor").process_mode = Node.PROCESS_MODE_DISABLED
	(save.get("progress") as PersistentProgress).death_count = 0
	await _wait(0.6)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing")

	# --- No death yet: Shift does nothing. ---
	_check(not player.call(&"is_sprint_available"), "sprint must be locked with 0 deaths")
	_events.clear()
	_key(KEY_SHIFT, true)
	_key(KEY_D, true)
	var normal_speeds: PackedFloat32Array = await _speeds(player, HOLD_SECONDS)
	var normal_top: float = player.get(&"max_speed")
	_check(_max(normal_speeds) <= normal_top * SPEED_SLACK, "locked sprint exceeded the normal top speed (%.2f > %.2f)" % [_max(normal_speeds), normal_top])
	_check(not player.call(&"is_sprinting"), "is_sprinting() true while locked")
	var normal_time: float = _time_to(normal_speeds, normal_top * REACHED)
	_check(normal_time > 0.0, "normal walk never reached its top speed")
	_check(_events.has(NarrationEvents.FIRST_MOVE), "FIRST_MOVE missing on the first move")
	_check(not _events.has(NarrationEvents.SPRINT_UNLOCKED), "SPRINT_UNLOCKED emitted while sprint is locked")
	_key(KEY_D, false)
	_key(KEY_SHIFT, false)
	var normal_stop: float = await _stop_distance(player, player.global_position)
	_check(normal_stop > 0.0, "normal stop measured no travel")

	# --- End the run: the death unlocks sprint for the next spawn. ---
	runs.call("end_run")
	await _wait(0.6)
	_check(runs.get("phase") == PHASE_PLAYING, "second run should be playing")
	_check((save.get("progress") as PersistentProgress).death_count >= 1, "death count should be at least 1 after a run end")
	_check(player.call(&"is_sprint_available"), "sprint must be available after the first death")

	# First move with sprint available: FIRST_MOVE then SPRINT_UNLOCKED, once.
	_events.clear()
	normal_top = player.get(&"max_speed")
	_key(KEY_SHIFT, true)
	_key(KEY_D, true)
	var sprint_speeds: PackedFloat32Array = await _speeds(player, HOLD_SECONDS)
	var sprint_top: float = normal_top * player.get(&"sprint_speed_mult")
	_check(player.call(&"is_sprinting"), "is_sprinting() false while Shift + D held")
	_check((player.get(&"move_intent") as Vector3).length() <= 1.0 + 0.001, "move_intent left 0..1 while sprinting (%.3f)" % (player.get(&"move_intent") as Vector3).length())
	_check(_max(sprint_speeds) >= sprint_top * REACHED, "sprint did not reach its top speed (%.2f < %.2f)" % [_max(sprint_speeds), sprint_top])
	_check(_max(sprint_speeds) <= sprint_top * SPEED_SLACK, "sprint exceeded its top speed (%.2f)" % _max(sprint_speeds))
	var sprint_time: float = _time_to(sprint_speeds, normal_top * REACHED)
	_check(sprint_time > 0.0 and sprint_time <= normal_time * MAX_ACCEL_TIME_SHARE,
		"sprint did not accelerate faster (%.3f s vs normal %.3f s)" % [sprint_time, normal_time])
	var first: int = _events.find(NarrationEvents.FIRST_MOVE)
	var unlocked: int = _events.find(NarrationEvents.SPRINT_UNLOCKED)
	_check(first >= 0 and unlocked == first + 1, "SPRINT_UNLOCKED should follow FIRST_MOVE on the first move: %s" % [_events])

	# Release everything: the stop glides farther than a normal stop.
	_key(KEY_D, false)
	_key(KEY_SHIFT, false)
	var glide: float = await _stop_distance(player, player.global_position)
	_check(glide >= normal_stop * MIN_GLIDE_SHARE, "post-sprint stop did not glide (%.2f vs normal %.2f)" % [glide, normal_stop])

	# Releasing Shift while still walking eases back to normal speed; the later stop is normal again.
	_key(KEY_SHIFT, true)
	_key(KEY_A, true)
	await _speeds(player, HOLD_SECONDS)
	_key(KEY_SHIFT, false)
	var eased: PackedFloat32Array = await _speeds(player, HOLD_SECONDS)
	_check(not player.call(&"is_sprinting"), "still sprinting after Shift was released")
	_check(eased[eased.size() - 1] <= normal_top * SPEED_SLACK, "did not ease back to normal top speed (%.2f)" % eased[eased.size() - 1])
	_check(eased[0] > normal_top * SPEED_SLACK, "speed dropped to normal at once instead of easing")
	_key(KEY_A, false)
	var eased_stop: float = await _stop_distance(player, player.global_position)
	_check(eased_stop <= normal_stop * MAX_EASED_STOP_SHARE, "stop after easing down still glided (%.2f vs %.2f)" % [eased_stop, normal_stop])

	# Gamepad: right shoulder + stick sprints too.
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	_stick(JOY_AXIS_LEFT_X, 1.0)
	var pad_speeds: PackedFloat32Array = await _speeds(player, HOLD_SECONDS)
	_check(player.call(&"is_sprinting"), "gamepad shoulder + stick did not sprint")
	_check(_max(pad_speeds) >= sprint_top * REACHED, "gamepad sprint did not reach the sprint top speed (%.2f)" % _max(pad_speeds))
	_stick(JOY_AXIS_LEFT_X, 0.0)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _stop_distance(player, player.global_position)

	# A later move in the same run does not repeat SPRINT_UNLOCKED.
	_check(_events.count(NarrationEvents.SPRINT_UNLOCKED) == 1, "SPRINT_UNLOCKED repeated within a run: %s" % [_events])

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_sprint (normal top %.2f in %.3f s, sprint top %.2f in %.3f s; stop %.2f, glide %.2f)" % [
			normal_top, normal_time, sprint_top, sprint_time, normal_stop, glide])
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_sprint")
		quit(1)
