extends Node
## SPIKE A (task-027, throwaway). Measurement / capture helper. Does nothing unless user args are given:
##   godot --path . --max-fps 30 --resolution 1920x1080 --windowed res://scenes/spikes/glyph_world/glyph_world.tscn -- perf=300
##   ... -- shots=<dir> [shot_every=45] [shot_count=12] [shot_start=60]
## perf=N logs averages over N frames (after 120 warm-up frames): draw calls, primitives, video mem, GPU and CPU frame time.

const WARMUP_FRAMES: int = 120
const BYTES_PER_MB: float = 1048576.0
const MSEC_PER_SEC: float = 1000.0

var _perf_frames: int = 0
var _shots_dir: String = ""
var _shot_every: int = 45
var _shot_count: int = 12
var _shot_start: int = 60
var _frame: int = 0
var _taken: int = 0
var _sum_draw: float = 0.0
var _sum_prims: float = 0.0
var _sum_gpu: float = 0.0
var _sum_cpu: float = 0.0
var _sum_dt: float = 0.0
var _n: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", false, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"perf":
				_perf_frames = int(kv[1])
			"shots":
				_shots_dir = kv[1]
			"shot_every":
				_shot_every = int(kv[1])
			"shot_count":
				_shot_count = int(kv[1])
			"shot_start":
				_shot_start = int(kv[1])
			"size":
				var wh: PackedStringArray = kv[1].split("x")
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
			"amb":
				(get_node("../WorldMesh") as MeshInstance3D).material_override.set_shader_parameter("ambient_level", float(kv[1]))
	if _perf_frames == 0 and _shots_dir == "":
		set_process(false)
		return
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("PROBE window=%s viewport=%s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])


func _process(delta: float) -> void:
	_frame += 1
	if _perf_frames > 0 and _frame > WARMUP_FRAMES:
		var vp: RID = get_viewport().get_viewport_rid()
		_sum_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_sum_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_sum_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_sum_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		_sum_dt += delta
		_n += 1
		if _n >= _perf_frames:
			print("PERF frames=%d draw_calls=%.1f primitives=%.0f video_mem_mb=%.1f gpu_ms=%.3f cpu_render_ms=%.3f frame_ms=%.2f fps=%.1f" % [
					_n, _sum_draw / _n, _sum_prims / _n,
					Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MB,
					_sum_gpu / _n, _sum_cpu / _n, _sum_dt / _n * MSEC_PER_SEC, _n / _sum_dt])
			get_tree().quit()
	if _shots_dir != "" and _frame >= _shot_start and (_frame - _shot_start) % _shot_every == 0:
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/shot_%02d.png" % [_shots_dir, _taken]
		img.save_png(path)
		print("SHOT %s %s" % [path, img.get_size()])
		_taken += 1
		if _taken >= _shot_count:
			get_tree().quit()
