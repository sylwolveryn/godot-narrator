class_name GlyphVisibilityMap
extends RefCounted
## The per-cell light visibility the glyph-surface shader reads (task-036): two RGBA8 textures
## (`texture_a` = light slots 0..3 in r,g,b,a; `texture_b` = slots 4..7), each (2 * map width + 1) x map height.
##  - Floor region (x < width): visibility of the cell itself, 0 for solid cells (walls, uneaten dirt; sampled bilinear).
##  - Wall region (x >= width + 1): for a solid cell, the best visibility among its open 4-neighbours
##    (read nearest; wall tops and the floor quad under a wall). Column `width` stays 0 as a seam.
## Slot values come from GlyphLightOcclusion. A slot is either replaced at once (`assign`, static lights;
## they fade through their intensity instead) or blended over time (`blend`, the player light, so the
## shadow edges glide when the player changes cell). Pure data, no nodes.

const SLOTS: int = 8
const SLOTS_PER_TEXTURE: int = 4
const EPSILON: float = 0.002
const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var texture_a: ImageTexture
var texture_b: ImageTexture
var size: Vector2i = Vector2i.ZERO

var _map: MapData
var _image_a: Image
var _image_b: Image
var _values: Array[PackedFloat32Array] = []
## Cells with a non-zero value per slot.
var _touched: Array[Dictionary] = []
## Running blends per slot: cell -> target value.
var _blends: Array[Dictionary] = []
var _blend_rate: float = 1.0
var _dirty: bool = false


## Allocates the textures for a map. `blend_time` is the seconds a blended slot takes to change fully.
func setup(map: MapData, blend_time: float) -> void:
	_map = map
	size = Vector2i(map.width, map.height)
	_blend_rate = 1.0 / maxf(blend_time, 0.001)
	_values.clear()
	_touched.clear()
	_blends.clear()
	for i in SLOTS:
		var values := PackedFloat32Array()
		values.resize(size.x * size.y)
		_values.append(values)
		_touched.append({})
		_blends.append({})
	_image_a = Image.create_empty(2 * size.x + 1, size.y, false, Image.FORMAT_RGBA8)
	_image_b = Image.create_empty(2 * size.x + 1, size.y, false, Image.FORMAT_RGBA8)
	texture_a = ImageTexture.create_from_image(_image_a)
	texture_b = ImageTexture.create_from_image(_image_b)


## Stored visibility of a cell for a slot (floor-region value).
func value_at(slot: int, cell: Vector2i) -> float:
	if not _in_bounds(cell):
		return 0.0
	return _values[slot][cell.y * size.x + cell.x]


## The texel the shader reads: floor region for open cells, wall region for wall cells (see the class comment).
func texel(texture_index: int, cell: Vector2i, wall_region: bool) -> Color:
	var image: Image = _image_a if texture_index == 0 else _image_b
	return image.get_pixel(cell.x + (size.x + 1 if wall_region else 0), cell.y)


## True while a blend is still running.
func is_blending() -> bool:
	for slot in SLOTS:
		if not _blends[slot].is_empty():
			return true
	return false


## Replaces a slot's values at once; `values` is cell -> visibility (empty clears the slot).
func assign(slot: int, values: Dictionary[Vector2i, float]) -> void:
	var changed: Array[Vector2i] = []
	for cell: Vector2i in _touched[slot]:
		_values[slot][cell.y * size.x + cell.x] = 0.0
		changed.append(cell)
	_touched[slot].clear()
	_blends[slot].clear()
	for cell: Vector2i in values:
		if _in_bounds(cell):
			_values[slot][cell.y * size.x + cell.x] = values[cell]
			_touched[slot][cell] = true
			changed.append(cell)
	for cell in changed:
		_write(slot, cell)
	_dirty = true


## Moves a slot towards `values` over the blend time.
func blend(slot: int, values: Dictionary[Vector2i, float]) -> void:
	var pending: Dictionary = _blends[slot]
	pending.clear()
	for cell: Vector2i in _touched[slot]:
		if not values.has(cell):
			pending[cell] = 0.0
	for cell: Vector2i in values:
		if _in_bounds(cell):
			pending[cell] = values[cell]


## Advances running blends and uploads the textures when anything changed.
func step(delta: float) -> void:
	for slot in SLOTS:
		var pending: Dictionary = _blends[slot]
		if pending.is_empty():
			continue
		var done: Array[Vector2i] = []
		for cell: Vector2i in pending:
			var i: int = cell.y * size.x + cell.x
			var current: float = _values[slot][i]
			var target: float = pending[cell]
			current = move_toward(current, target, delta * _blend_rate)
			_values[slot][i] = current
			if current > EPSILON:
				_touched[slot][cell] = true
			_write(slot, cell)
			if absf(current - target) < EPSILON:
				_values[slot][i] = target
				_write(slot, cell)
				if target <= EPSILON:
					_touched[slot].erase(cell)
				done.append(cell)
		for cell in done:
			pending.erase(cell)
		_dirty = true
	if _dirty:
		_dirty = false
		texture_a.update(_image_a)
		texture_b.update(_image_b)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Rewrites one slot's channel of a cell's floor texel and of the wall texels around it.
func _write(slot: int, cell: Vector2i) -> void:
	var image: Image = _image_a if slot < SLOTS_PER_TEXTURE else _image_b
	var channel: int = slot % SLOTS_PER_TEXTURE
	_set_channel(image, cell.x, cell.y, channel, 0.0 if is_solid(_map.type_at(cell)) else _values[slot][cell.y * size.x + cell.x])
	for step_cell in NEIGHBOURS:
		var wall: Vector2i = cell + step_cell
		if _in_bounds(wall) and is_solid(_map.type_at(wall)):
			_set_channel(image, wall.x + size.x + 1, wall.y, channel, _wall_value(slot, wall))


func _wall_value(slot: int, wall: Vector2i) -> float:
	var best: float = 0.0
	for step_cell in NEIGHBOURS:
		var n: Vector2i = wall + step_cell
		if _in_bounds(n) and not is_solid(_map.type_at(n)):
			best = maxf(best, _values[slot][n.y * size.x + n.x])
	return best


## Cell types drawn as solid blocks whose tops read the wall region: walls and dirt (task-070; eaten dirt is floor).
static func is_solid(type: StringName) -> bool:
	return type == MapLegend.WALL or type == MapLegend.DIRT


func _set_channel(image: Image, x: int, y: int, channel: int, value: float) -> void:
	var c: Color = image.get_pixel(x, y)
	c[channel] = value
	image.set_pixel(x, y, c)
