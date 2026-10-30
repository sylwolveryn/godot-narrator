extends SceneTree
## Writes display and rendering project settings into project.godot: fullscreen by default, a
## 1920x1080 reference window size, no engine stretch (the game scales its own pixel sizes from the
## viewport height, see DisplayConfig), the global shader parameters the world shader reads, and
## the render settings the data-encoded 3D buffer needs (no MSAA / FXAA / debanding / 3D glow;
## linear tonemap comes from the default environment). Idempotent.
## Usage: godot --headless --path . -s tools/build_project_settings.gd

## Window.MODE_FULLSCREEN as stored in display/window/size/mode.
const MODE_FULLSCREEN := 3

## The world shader writes data into the 3D buffer, so nothing may touch it afterwards.
const RENDER_SETTINGS := {
	"rendering/anti_aliasing/quality/msaa_3d": 0,
	"rendering/anti_aliasing/quality/screen_space_aa": 0,
	"rendering/anti_aliasing/quality/use_debanding": false,
}

## Global shader parameters (read by shaders/world_encode.gdshader). Values are set at runtime by
## AsciiPostProcess and MapReveal; these are the registrations and neutral defaults.
const SHADER_GLOBALS := {
	"player_pos": {"type": "vec2", "value": Vector2(0.0, 0.0)},
	"light_params": {"type": "vec4", "value": Vector4(0.0, 0.0, 0.0, 0.0)},
	"look_params": {"type": "vec4", "value": Vector4(0.0, 0.0, 0.0, 0.0)},
	"map_params": {"type": "vec4", "value": Vector4(1.0, 0.0, 0.0, 0.0)},
	"reveal_mask": {"type": "sampler2D", "value": ""},
}


func _init() -> void:
	var reference := DisplayConfig.new().reference_size
	ProjectSettings.set_setting("display/window/size/mode", MODE_FULLSCREEN)
	ProjectSettings.set_setting("display/window/size/viewport_width", reference.x)
	ProjectSettings.set_setting("display/window/size/viewport_height", reference.y)
	ProjectSettings.set_setting("display/window/size/resizable", true)
	ProjectSettings.set_setting("display/window/stretch/mode", "disabled")
	for key in RENDER_SETTINGS:
		ProjectSettings.set_setting(key, RENDER_SETTINGS[key])
	for param: String in SHADER_GLOBALS:
		ProjectSettings.set_setting("shader_globals/" + param, SHADER_GLOBALS[param])
	var err: int = ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
	else:
		print("Saved display settings")
	quit(0 if err == OK else 1)
