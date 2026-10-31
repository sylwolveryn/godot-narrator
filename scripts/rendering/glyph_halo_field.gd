class_name GlyphHaloField
extends Node3D
## Soft additive halos over the items, spikes and corrupting areas of the built map (task-033).
## ONE MultiMesh with one quad per source cell, drawn with shaders/glyph_halo.gdshader: one draw call, no
## per-frame CPU work. The shader reads the reveal mask itself, so halos stay hidden until their cell is
## revealed and dim (or vanish, GlyphWorldConfig.halo_memory) on remembered cells; it also does the slow breathing.
## Depth: the quads are depth-tested, so walls in front hide a halo (cheap occlusion).

const HALO_SHADER: String = "res://shaders/glyph_halo.gdshader"
## Halo kinds, the index into the GlyphWorldConfig halo arrays and the shader's `kind`.
const KIND_ITEM: int = 0
const KIND_SPIKES: int = 1
const KIND_CORRUPT: int = 2
## Edge length of the quad mesh; the shader scales it by the instance scale (= glow radius).
const QUAD_EXTENT: float = 2.0

@export var config: GlyphWorldConfig
@export var map_loader: MapLoader

var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	if config == null:
		config = GlyphWorldConfig.new()
	_material = ShaderMaterial.new()
	_material.shader = load(HALO_SHADER) as Shader
	apply_static()
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


## Number of halos (one per item, spike and corruption cell).
func halo_count() -> int:
	return _multimesh.instance_count if _multimesh != null else 0


## Pushes the look of the config into the halo material.
func apply_static() -> void:
	_material.render_priority = 0
	_material.set_shader_parameter(&"lift", config.halo_lift)
	_material.set_shader_parameter(&"memory", config.halo_memory)
	_material.set_shader_parameter(&"breath_period", config.halo_breath_period)
	_material.set_shader_parameter(&"breath_amount", config.halo_breath_amount)
	_material.set_shader_parameter(&"pool", config.halo_pool)
	_material.set_shader_parameter(&"hue_a", Vector3(config.corrupt_hue_a.r, config.corrupt_hue_a.g, config.corrupt_hue_a.b))
	_material.set_shader_parameter(&"hue_b", Vector3(config.corrupt_hue_b.r, config.corrupt_hue_b.g, config.corrupt_hue_b.b))


func _on_map_built(map: MapData) -> void:
	if _instance != null:
		_instance.queue_free()
		_instance = null
		_multimesh = null
	var cells: Array[Vector2i] = []
	var kinds: Array[int] = []
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var kind: int = _kind_of(map.type_at(c))
			if kind >= 0:
				cells.append(c)
				kinds.append(kind)
	if cells.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = cells.size()
	var world: WorldConfig = map_loader.world_config
	var colors: Array[Color] = [config.item_light_color, config.spike_light_color, config.corrupt_light_color]
	var heights: Array[float] = [config.item_light_height, config.spike_light_height, config.corrupt_light_height]
	for i in cells.size():
		var c: Vector2i = cells[i]
		var kind: int = kinds[i]
		var centre: Vector3 = map_loader.cell_to_world(c) + Vector3.UP * heights[kind]
		_multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * config.halo_size[kind]), centre))
		var col: Color = colors[kind]
		col.a = config.halo_intensity[kind]
		_multimesh.set_instance_color(i, col)
		_multimesh.set_instance_custom_data(i, Color(float(c.x), float(c.y), float(c.x + c.y) * config.halo_phase_step, float(kind)))
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Halos"
	_instance.multimesh = _multimesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.extra_cull_margin = config.halo_lift + world.cell_size * 2.0
	add_child(_instance)


static func _kind_of(type: StringName) -> int:
	if type == MapLegend.ITEM:
		return KIND_ITEM
	if type == MapLegend.SPIKES:
		return KIND_SPIKES
	if type == MapLegend.CORRUPT:
		return KIND_CORRUPT
	return -1
