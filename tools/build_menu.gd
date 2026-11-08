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

	var remember := MenuItemDef.new()
	remember.id = &"remember"
	remember.action = MenuItemDef.ACTION_REMEMBER
	remember.label = "remember"
	remember.requires_claim = true
	remember.closes_menu = false
	ok = _save(remember, ITEM_DIR + "remember.tres") and ok
	items.append(load(ITEM_DIR + "remember.tres") as MenuItemDef)

	# Language list (task-065): offered whenever the menu is (needs a LanguageProgress in the scene).
	var language := MenuItemDef.new()
	language.id = &"language"
	language.action = MenuItemDef.ACTION_LANGUAGE
	language.label = "language"
	language.closes_menu = false
	ok = _save(language, ITEM_DIR + "language.tres") and ok
	items.append(load(ITEM_DIR + "language.tres") as MenuItemDef)

	# Items list (task-077): offered once anything was consumed; announced as new even on an old save.
	var items_item := MenuItemDef.new()
	items_item.id = &"items"
	items_item.action = MenuItemDef.ACTION_ITEMS
	items_item.label = "items"
	items_item.requires_consumed = true
	items_item.announce_new = true
	items_item.closes_menu = false
	ok = _save(items_item, ITEM_DIR + "items.tres") and ok
	items.append(load(ITEM_DIR + "items.tres") as MenuItemDef)

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
