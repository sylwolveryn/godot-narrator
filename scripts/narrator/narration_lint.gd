class_name NarrationLint
extends RefCounted
## Content lint for narration beats against the origin hypotheses (task-040). Pure functions, used by
## tools/build_narration.gd (which fails the build on errors) and tested by tools/test_narrator.gd.
##
## Errors: a hypothesis id that does not exist, a hypothesis in both supports and contradicts, a nature that
## no beat supports, and (only in strict mode) a nature that no beat contradicts.
## Without strict mode a missing contradicting beat is a warning: contradicting lines for alien and angelic
## are authored in task-044. Strict mode is switched on in data/narration/m1_beats.json ("lint.strict_contradiction")
## by task-042/044 once every nature has a contradicting beat.


## Returns {"errors": PackedStringArray, "warnings": PackedStringArray}. `natures` and `deeds` are hypothesis ids.
static func lint(beats: Array, natures: PackedStringArray, deeds: PackedStringArray, strict_contradiction: bool) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var known := PackedStringArray(natures)
	known.append_array(deeds)
	var supported: Dictionary = {}
	var contradicted: Dictionary = {}
	for beat: NarrationBeat in beats:
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
