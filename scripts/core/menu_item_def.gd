class_name MenuItemDef
extends Resource
## One entry of the in-world menu (task-018). Data only: what it says, when it is offered and what confirming it asks for.
## Instances: resources/config/menu_items/*.tres, listed by MenuConfig.items (built by tools/build_menu.gd).

## Actions a confirmed item can request. CLOSE is handled by MenuController itself; the others travel on
## SignalBus.menu_action_requested to the data layer that owns them.
const ACTION_CLOSE: StringName = &"close"
const ACTION_SWITCH_FORM: StringName = &"switch_form"
## Shows the origin ledger as a row of sigils (task-043); handled by MenuController itself, nothing is requested upward.
const ACTION_REMEMBER: StringName = &"remember"
## Shows the Language list (task-065); handled by MenuController, which asks LanguageProgress through SignalBus.
const ACTION_LANGUAGE: StringName = &"language"
## Shows the Items list (task-077): what the player consumed, per kind; handled by MenuController.
const ACTION_ITEMS: StringName = &"items"
## Becomes the brain, or back to the single glyph while the brain (task-091); handled by EntityProgression.
const ACTION_BRAIN: StringName = &"brain"

@export var id: StringName = &""
@export var action: StringName = ACTION_CLOSE
## Shown text (short, lowercase reads best as glyphs).
@export var label: String = ""
## Shown instead of `label` while the entity form is `alt_form` (empty alt_form = never).
@export var alt_label: String = ""
@export var alt_form: StringName = &""
## Only offered once the multi-glyph entity is unlocked.
@export var requires_entity: bool = false
## Only offered once any origin claim has been heard (OriginLedger.any_claim_heard).
@export var requires_claim: bool = false
## Only offered once anything was consumed (task-077: the first dirt eaten or diamond picked up).
@export var requires_consumed: bool = false
## Only offered once the brain form is unlocked (task-091).
@export var requires_brain: bool = false
## Pulses as new (task-077) even when it was already offered before new-item tracking began (a save from before it).
@export var announce_new: bool = false
## Confirming it closes the menu (the player then sees the result in the world).
@export var closes_menu: bool = true


## The text for the given entity form.
func text_for(form: StringName) -> String:
	if alt_form != &"" and form == alt_form and alt_label != "":
		return alt_label
	return label
