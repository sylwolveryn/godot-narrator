class_name GlyphLightSource
extends RefCounted
## A static point light of the glyph world (an item, a patch of spikes or corruption). Derived from
## the map by `collect`; GlyphWorldView picks the nearest ones for the shader.

var position: Vector3 = Vector3.ZERO
var radius: float = 1.0
## rgb already multiplied by the intensity.
var color: Vector3 = Vector3.ONE
## Map cells of the source; the light only counts once one of them has been seen or remembered.
var cells: Array[Vector2i] = []
## The source cell nearest to the light position: where occlusion rays start.
var origin_cell: Vector2i = Vector2i.ZERO
## Occlusion of the light: cell -> visibility, filled by `bake_visibility` (static, the map does not change).
var visibility: Dictionary[Vector2i, float] = {}


## All static lights of a map: one per item, one per 4-connected patch of spikes or corruption.
static func collect(map: MapData, world: WorldConfig, look: GlyphWorldConfig) -> Array[GlyphLightSource]:
	var out: Array[GlyphLightSource] = []
	var visited: Dictionary[Vector2i, bool] = {}
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var type: StringName = map.type_at(c)
			if type == MapLegend.ITEM:
				out.append(_make(world, [c], look.item_light_color, look.item_light_intensity,
						look.item_light_radius, look.item_light_height))
			elif (type == MapLegend.SPIKES or type == MapLegend.CORRUPT) and not visited.has(c):
				var patch: Array[Vector2i] = _flood(map, c, type, visited)
				if type == MapLegend.SPIKES:
					out.append(_make(world, patch, look.spike_light_color, look.spike_light_intensity,
							look.spike_light_radius + look.patch_radius_per_cell * _extent(patch), look.spike_light_height))
				else:
					out.append(_make(world, patch, look.corrupt_light_color, look.corrupt_light_intensity,
							look.corrupt_light_radius + look.patch_radius_per_cell * _extent(patch), look.corrupt_light_height))
	return out


static func _make(world: WorldConfig, cells: Array[Vector2i], col: Color, intensity: float, radius: float, height: float) -> GlyphLightSource:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	var centre: Vector2 = sum / float(cells.size())
	var src := GlyphLightSource.new()
	src.position = Vector3(centre.x, 0.0, centre.y) * world.cell_size + Vector3(0.0, height, 0.0)
	src.radius = radius
	src.color = Vector3(col.r, col.g, col.b) * intensity
	src.cells = cells
	var best: float = INF
	for c in cells:
		var d: float = (Vector2(c) + Vector2(0.5, 0.5) - centre).length_squared()
		if d < best:
			best = d
			src.origin_cell = c
	return src


## Computes the static occlusion of the light on a map (see GlyphLightOcclusion).
func bake_visibility(map: MapData, world: WorldConfig, penumbra: float) -> void:
	visibility = GlyphLightOcclusion.compute(map, origin_cell, radius / world.cell_size, penumbra)


## Longest side of the patch's bounding box in cells, minus one (a single cell has extent 0).
static func _extent(cells: Array[Vector2i]) -> float:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return float(maxi(hi.x - lo.x, hi.y - lo.y))


static func _flood(map: MapData, start: Vector2i, type: StringName, visited: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	visited[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		patch.append(c)
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + step
			if not visited.has(n) and map.type_at(n) == type:
				visited[n] = true
				stack.append(n)
	return patch
