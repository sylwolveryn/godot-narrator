extends SceneTree
## Builds the in-world menu resources (task-018): the item definitions in res://resources/config/menu_items/ and
## res://resources/config/menu_config.tres. Idempotent. Add items here (data-driven), then rebuild.
## Usage: godot --headless --path . -s tools/build_menu.gd

const DIR := "res://resources/config/"
const ITEM_DIR := "res://resources/config/menu_items/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEM_DIR))
	var ok := true
	var items: Array[MenuItemDef] = []

	var switch_form := MenuItemDef.new()
	switch_form.id = &"switch_form"
	switch_form.action = MenuItemDef.ACTION_SWITCH_FORM
	switch_form.label = "become many"
	switch_form.alt_label = "become one"
	switch_form.alt_form = EntityForm.GROWN
	switch_form.requires_entity = true
	switch_form.closes_menu = true
	ok = _save(switch_form, ITEM_DIR + "switch_form.tres") and ok
	items.append(load(ITEM_DIR + "switch_form.tres") as MenuItemDef)

	var close := MenuItemDef.new()
	close.id = &"close"
	close.action = MenuItemDef.ACTION_CLOSE
	close.label = "return"
	close.closes_menu = true
	ok = _save(close, ITEM_DIR + "close.tres") and ok
	items.append(load(ITEM_DIR + "close.tres") as MenuItemDef)

	var config := MenuConfig.new()
	config.items = items
	ok = _save(config, DIR + "menu_config.tres") and ok
	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		return false
	print("Saved ", path)
	return true
