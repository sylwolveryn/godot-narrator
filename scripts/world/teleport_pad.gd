class_name TeleportPad
extends RefCounted
## One teleport of a map (task-068): a group of `T` cells (MapLegend.teleport_char). A working pad is EXACTLY a 3x3 ring
## of T around a channel character (MapLegend.teleport_channels); every other connected group of T cells (8-neighbour
## connectivity, so a ring touching another T is not exact) is a broken pad that never teleports. Pure data; the
## cells under a pad are floor in MapData.types.

## Ring size of a working pad (cells per side) and its ring cell count.
const RING_SIZE: int = 3
const RING_CELLS: int = 8
## Larger than any channel index: added to a negative channel distance so the order wraps around.
const CHANNEL_WRAP: int = 1 << 16

## The T cells of the group (a working pad: its 8 ring cells).
var cells: Array[Vector2i] = []
## Bounding rectangle of the group in cells (a working pad: 3x3).
var rect: Rect2i = Rect2i()
## True for a broken group (no channel, never teleports).
var broken: bool = true
## Working pads: the centre cell, the channel character and its index in MapLegend.teleport_channels.
var centre: Vector2i = Vector2i.ZERO
var channel: String = ""
var channel_index: int = -1


## Groups the T cells of map text: working pads (row-major by top-left) in `out_pads`, broken groups in `out_broken`.
## Returns every cell that belongs to a group (ring, centre and broken cells): the map loader parses them as floor.
static func parse(lines: PackedStringArray, ring_char: String, channels: String,
		out_pads: Array[TeleportPad], out_broken: Array[TeleportPad]) -> Dictionary[Vector2i, bool]:
	var claimed: Dictionary[Vector2i, bool] = {}
	if ring_char == "":
		return claimed
	var rings: Dictionary[Vector2i, bool] = {}
	for y in lines.size():
		var line: String = lines[y]
		for x in line.length():
			if line[x] == ring_char:
				rings[Vector2i(x, y)] = true
	var done: Dictionary[Vector2i, bool] = {}
	for y in lines.size():
		for x in lines[y].length():
			var start := Vector2i(x, y)
			if not rings.has(start) or done.has(start):
				continue
			var pad := TeleportPad.new()
			pad.cells = _flood(start, rings, done)
			pad.rect = _bounds(pad.cells)
			_classify(pad, lines, rings, channels)
			for c in pad.cells:
				claimed[c] = true
			if pad.broken:
				out_broken.append(pad)
			else:
				claimed[pad.centre] = true
				out_pads.append(pad)
	return claimed


## Indices (into `pads`) of the possible destinations of pad `from`: every pad of the next HIGHER channel present on the
## map (channel order, wrapping around from the last channel to the first), never the own channel. Empty when no other
## channel exists. Broken pads are not in `pads`.
static func targets(pads: Array[TeleportPad], from: int) -> Array[int]:
	var out: Array[int] = []
	if from < 0 or from >= pads.size():
		return out
	var own: int = pads[from].channel_index
	var best: int = -1
	var best_rank: int = 0
	for pad in pads:
		if pad.channel_index == own:
			continue
		# Distance upward from the own channel, wrapping: the smallest positive one is the next higher channel.
		var rank: int = pad.channel_index - own
		if rank < 0:
			rank += CHANNEL_WRAP
		if best < 0 or rank < best_rank:
			best = pad.channel_index
			best_rank = rank
	if best < 0:
		return out
	for i in pads.size():
		if pads[i].channel_index == best:
			out.append(i)
	return out


static func _flood(start: Vector2i, rings: Dictionary[Vector2i, bool], done: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	done[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if rings.has(n) and not done.has(n):
					done[n] = true
					stack.append(n)
	return out


static func _bounds(group: Array[Vector2i]) -> Rect2i:
	var r := Rect2i(group[0], Vector2i.ONE)
	for c in group:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r


## A working pad: 8 cells exactly on the border of a 3x3 box, and a channel character in its middle.
static func _classify(pad: TeleportPad, lines: PackedStringArray, rings: Dictionary[Vector2i, bool], channels: String) -> void:
	pad.broken = true
	if pad.cells.size() != RING_CELLS or pad.rect.size != Vector2i(RING_SIZE, RING_SIZE):
		return
	var mid: Vector2i = pad.rect.position + Vector2i.ONE
	if rings.has(mid) or mid.y >= lines.size() or mid.x >= lines[mid.y].length():
		return
	var ch: String = lines[mid.y][mid.x]
	var index: int = channels.find(ch)
	if index < 0:
		return
	pad.broken = false
	pad.centre = mid
	pad.channel = ch
	pad.channel_index = index
