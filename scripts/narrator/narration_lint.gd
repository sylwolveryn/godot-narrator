class_name NarrationLint
extends RefCounted
## Content lint for narration beats against the origin hypotheses (task-040). Pure functions, used by
## tools/build_narration.gd (which fails the build on errors) and tested by tools/test_narrator.gd.
##
## Errors: a hypothesis id that does not exist, a hypothesis in both supports and contradicts, a nature that
## no beat supports, and (only in strict mode) a nature that no beat contradicts.
## Role rules (task-042): a CLAIM supports exactly one nature; a BROKEN or RECANT beat names a nature in event_param,
## on the matching origin event; BROKEN contradicts it, RECANT supports it.
## Without strict mode a missing contradicting beat is a warning. Strict mode is on in data/narration/m1_beats.json
## ("lint.strict_contradiction") since task-044 gave every nature a contradicting beat.


## Returns {"errors": PackedStringArray, "warnings": PackedStringArray}. `natures` and `deeds` are hypothesis ids.
static func lint(beats: Array, natures: PackedStringArray, deeds: PackedStringArray, strict_contradiction: bool) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var known := PackedStringArray(natures)
	known.append_array(deeds)
	var nature_ids := PackedStringArray(natures)
	var supported: Dictionary = {}
	var contradicted: Dictionary = {}
	for beat: NarrationBeat in beats:
		errors.append_array(_lint_role(beat, nature_ids))
		for id in beat.supports:
			if not known.has(id):
				errors.append("beat '%s' supports unknown hypothesis '%s'" % [beat.id, id])
			supported[id] = true
			if beat.contradicts.has(id):
				errors.append("beat '%s' lists '%s' in both supports and contradicts" % [beat.id, id])
		for id in beat.contradicts:
			if not known.has(id):
				errors.append("beat '%s' contradicts unknown hypothesis '%s'" % [beat.id, id])
			contradicted[id] = true
	for id in natures:
		if not supported.has(id):
			errors.append("nature '%s' has no supporting beat" % id)
		if not contradicted.has(id):
			var message := "nature '%s' has no contradicting beat" % id
			if strict_contradiction:
				errors.append(message)
			else:
				warnings.append(message + " (not strict yet: authored in task-044)")
	return {"errors": errors, "warnings": warnings}


static func _lint_role(beat: NarrationBeat, natures: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	match beat.role:
		NarrationBeat.Role.CLAIM:
			if beat.supports.size() != 1 or not natures.has(beat.supports[0]):
				errors.append("claim beat '%s' must support exactly one nature" % beat.id)
		NarrationBeat.Role.BROKEN, NarrationBeat.Role.RECANT:
			var broken: bool = beat.role == NarrationBeat.Role.BROKEN
			var event: StringName = NarrationEvents.ORIGIN_STRUCK if broken else NarrationEvents.ORIGIN_RECANTED
			if beat.event != event or not natures.has(String(beat.event_param)):
				errors.append("beat '%s' must answer %s with a nature as event_param" % [beat.id, event])
			elif broken and (not beat.contradicts.has(String(beat.event_param)) or not beat.supports.is_empty()):
				errors.append("broken beat '%s' must contradict '%s' and support nothing" % [beat.id, beat.event_param])
			elif not broken and not beat.supports.has(String(beat.event_param)):
				errors.append("recant beat '%s' must support '%s'" % [beat.id, beat.event_param])
	return errors
