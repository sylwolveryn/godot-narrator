class_name EntityForm
extends RefCounted
## The two forms of the player character (task-017): the original single glyph and the grown multi-glyph entity.
## Plain names, stored in PersistentProgress.entity_form and carried by SignalBus.entity_form_changed.

const SINGLE: StringName = &"single"
const GROWN: StringName = &"grown"
## Task-091: the brain, a 2x2 block of Japanese glyphs (unlocked by a fully discovered map and two teleports).
const BRAIN: StringName = &"brain"


static func is_valid(form: StringName) -> bool:
	return form == SINGLE or form == GROWN or form == BRAIN
