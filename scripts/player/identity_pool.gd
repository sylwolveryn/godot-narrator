class_name IdentityPool
extends Resource
## The set of exotic glyphs a character identity can be drawn from.

@export var glyphs: PackedStringArray = PackedStringArray(["ꙮ", "ᚠ", "ঔ", "༄", "☿", "⍟", "ψ", "ж", "ʘ", "∰"])
## Used when `glyphs` is empty so a character always has an identity.
@export var fallback_glyph: String = "@"


## Picks one glyph at random. Pass an rng for deterministic tests.
func pick(rng: RandomNumberGenerator = null) -> String:
	if glyphs.is_empty():
		return fallback_glyph
	var index: int = rng.randi_range(0, glyphs.size() - 1) if rng != null else randi_range(0, glyphs.size() - 1)
	return glyphs[index]
