class_name GridMask
extends RefCounted
## A box of the map grid as one byte per cell (0 = not looked at yet, 1 = open, 2 = blocks), made once per sweep so the hot ray loops of
## SightLine and GlyphLightOcclusion read a PackedByteArray instead of calling MapData.type_at per ray step
## (performance pass of the sight work, see tools/bench_sight.gd). Cells outside the box count as blocking; build the
## box with enough margin for every ray. Cells outside the map have type VOID (MapData.type_at). Cells are classified
## lazily, the first time a ray or a sweep touches them, so a big box costs only what is actually looked at. Pure data.

## Extra cells around the radius: a ray may end one cell beyond it (side offset of up to half a cell) and the DDA
## may step one past.
const MARGIN: int = 2

var x0: int = 0
var y0: int = 0
var w: int = 0
var h: int = 0
var solid := PackedByteArray()
var _types: Array[StringName] = []
var _mw: int = 0
var _mh: int = 0
var _blocking: Dictionary = {}
var _extra: Dictionary = {}
var _void_value: int = OPEN

const UNKNOWN: int = 0
const OPEN: int = 1
const SOLID: int = 2

## span -> offsets within the square of that span, nearest first (built once per span).
static var _offsets: Dictionary[int, Array] = {}
## Cells between two clock reads in a budgeted sweep (reading the clock per cell would cost more than it saves).
const CLOCK_EVERY: int = 16


## Every offset with |x|, |y| <= span, sorted by distance from the centre (a sweep can stop at the first one out of
## reach, and nearer cells come first). Shared and cached: do not modify.
static func offsets(span: int) -> Array:
	if _offsets.has(span):
		return _offsets[span]
	var out: Array = []
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			out.append(Vector2i(dx, dy))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	_offsets[span] = out
	return out


## The box of cells within `span` (+ MARGIN) of `centre`; a cell blocks when its type is a key of `blocking`.
## `extra` (optional) adds more blocking types (e.g. MapData.light_blocking_types).
static func around(map: MapData, centre: Vector2i, span: int, blocking: Dictionary, extra: Dictionary = {}) -> GridMask:
	var m := GridMask.new()
	var reach: int = span + MARGIN
	m.x0 = centre.x - reach
	m.y0 = centre.y - reach
	m.w = reach * 2 + 1
	m.h = m.w
	m.solid.resize(m.w * m.h)
	m.solid.fill(UNKNOWN)
	m._types = map.types
	m._mw = map.width
	m._mh = map.height
	m._blocking = blocking
	m._extra = extra
	m._void_value = SOLID if blocking.has(MapLegend.VOID) or extra.has(MapLegend.VOID) else OPEN
	return m


## True when the cell blocks (outside the box: blocks).
func blocks(cell: Vector2i) -> bool:
	var lx: int = cell.x - x0
	var ly: int = cell.y - y0
	if lx < 0 or ly < 0 or lx >= w or ly >= h:
		return true
	var i: int = ly * w + lx
	var v: int = solid[i]
	if v == UNKNOWN:
		v = _classify(i, cell.x, cell.y)
	return v == SOLID


## Looks up and stores whether map cell (x, y), at box index i, blocks.
func _classify(i: int, x: int, y: int) -> int:
	var v: int = _void_value
	if x >= 0 and y >= 0 and x < _mw and y < _mh:
		var t: StringName = _types[y * _mw + x]
		v = SOLID if _blocking.has(t) or _extra.has(t) else OPEN
	solid[i] = v
	return v


## Sight ray (SightLine semantics): true when the line a -> b (cell units) reaches `target` or its end without
## crossing a blocking cell; the target itself never blocks.
func sight_clear(a: Vector2, b: Vector2, target: Vector2i) -> bool:
	var cx: int = floori(a.x)
	var cy: int = floori(a.y)
	var ex: int = floori(b.x)
	var ey: int = floori(b.y)
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var sx: int = int(signf(dx))
	var sy: int = int(signf(dy))
	var tdx: float = INF
	var tdy: float = INF
	var tmx: float = INF
	var tmy: float = INF
	if sx != 0:
		tdx = absf(1.0 / dx)
		tmx = ((cx + (1 if sx > 0 else 0)) - a.x) / dx
	if sy != 0:
		tdy = absf(1.0 / dy)
		tmy = ((cy + (1 if sy > 0 else 0)) - a.y) / dy
	var guard: int = absi(ex - cx) + absi(ey - cy) + SightLine.EXTRA_STEPS
	while (cx != ex or cy != ey) and guard > 0:
		guard -= 1
		if tmx < tmy:
			cx += sx
			tmx += tdx
		else:
			cy += sy
			tmy += tdy
		if cx == target.x and cy == target.y:
			return true
		var lx: int = cx - x0
		var ly: int = cy - y0
		if lx < 0 or ly < 0 or lx >= w or ly >= h:
			return false
		var i: int = ly * w + lx
		var v: int = solid[i]
		if v == UNKNOWN:
			v = _classify(i, cx, cy)
		if v == SOLID:
			return false
	return true


## Light ray (GlyphLightOcclusion semantics): true when the line a -> b crosses no blocking cell before b's cell.
func light_clear(a: Vector2, b: Vector2) -> bool:
	var cx: int = floori(a.x)
	var cy: int = floori(a.y)
	var ex: int = floori(b.x)
	var ey: int = floori(b.y)
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var sx: int = int(signf(dx))
	var sy: int = int(signf(dy))
	var tdx: float = INF
	var tdy: float = INF
	var tmx: float = INF
	var tmy: float = INF
	if sx != 0:
		tdx = absf(1.0 / dx)
		tmx = ((cx + (1 if sx > 0 else 0)) - a.x) / dx
	if sy != 0:
		tdy = absf(1.0 / dy)
		tmy = ((cy + (1 if sy > 0 else 0)) - a.y) / dy
	var guard: int = absi(ex - cx) + absi(ey - cy) + GlyphLightOcclusion.EXTRA_STEPS
	while (cx != ex or cy != ey) and guard > 0:
		guard -= 1
		if tmx < tmy:
			cx += sx
			tmx += tdx
		else:
			cy += sy
			tmy += tdy
		if cx == ex and cy == ey:
			return true
		var lx: int = cx - x0
		var ly: int = cy - y0
		if lx < 0 or ly < 0 or lx >= w or ly >= h:
			return false
		var i: int = ly * w + lx
		var v: int = solid[i]
		if v == UNKNOWN:
			v = _classify(i, cx, cy)
		if v == SOLID:
			return false
	return true
