class_name GNAssetBrowser
extends Window
## Browse registered .gnasset custom operators; install to user://gonodes_assets/.


const USER_ASSETS_DIR := "user://gonodes_assets"


var _search_edit: LineEdit = null
var _family_option: OptionButton = null
var _list: ItemList = null
var _detail: RichTextLabel = null
var _assets: Array[Dictionary] = []
var _filtered: Array[Dictionary] = []


func _init() -> void:
	title = "GONODES Asset Browser"
	size = Vector2i(720, 520)
	min_size = Vector2i(480, 360)
	exclusive = false
	transient = false
	# Expanding children plus wrap_controls grow the window to the screen.
	# The title bar then sits off the display and the window cannot be closed.
	wrap_controls = false


func _ready() -> void:
	close_requested.connect(hide)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search name or description…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_apply_filters)
	filter_row.add_child(_search_edit)
	_family_option = OptionButton.new()
	_family_option.custom_minimum_size.x = 100
	_family_option.item_selected.connect(func(_idx: int) -> void: _apply_filters())
	filter_row.add_child(_family_option)
	root.add_child(filter_row)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(200, 160)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_asset_selected)
	split.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.custom_minimum_size = Vector2(200, 160)
	split.add_child(_detail)
	root.add_child(split)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	var install_btn := Button.new()
	install_btn.text = "Install .gnasset…"
	install_btn.pressed.connect(_on_install_pressed)
	btn_row.add_child(install_btn)
	var uninstall_btn := Button.new()
	uninstall_btn.text = "Uninstall"
	uninstall_btn.pressed.connect(_on_uninstall_pressed)
	btn_row.add_child(uninstall_btn)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh)
	btn_row.add_child(refresh_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)
	root.add_child(btn_row)

	refresh()


func refresh() -> void:
	_assets.clear()
	for item in collect_custom_assets(GNExtensionRegistry.instance()):
		if item is Dictionary:
			_assets.append(item)
	_rebuild_family_options()
	_apply_filters()


static func collect_custom_assets(registry: GNExtensionRegistry) -> Array:
	var result: Array = []
	for op_name in registry._operators:
		var entry: GNExtensionRegistry.OperatorEntry = registry._operators[op_name]
		if not entry.is_custom_asset:
			continue
		var promoted_names: PackedStringArray = []
		var data := GNCustomOperator._read_asset_json(entry.extension_dir)
		var promoted: Array = data.get("promoted_parameters", [])
		for item in promoted:
			if item is Dictionary:
				var pname: String = item.get("promoted_name", "")
				if not pname.is_empty():
					promoted_names.append(pname)
		result.append({
			"name": op_name,
			"description": entry.description,
			"family": entry.family,
			"path": entry.extension_dir,
			"read_only": entry.asset_read_only,
			"section": entry.section,
			"promoted": promoted_names,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))
	return result


## Filters assets by optional family and query substring (name or description).
static func filter_custom_assets(assets: Array, query: String, family: String) -> Array:
	var q := query.strip_edges().to_lower()
	var fam := family.strip_edges()
	var out: Array = []
	for asset in assets:
		if typeof(asset) != TYPE_DICTIONARY:
			continue
		if not fam.is_empty() and str(asset.get("family", "")) != fam:
			continue
		if q.is_empty():
			out.append(asset)
			continue
		var name_lc := str(asset.get("name", "")).to_lower()
		var desc_lc := str(asset.get("description", "")).to_lower()
		if q in name_lc or q in desc_lc:
			out.append(asset)
	return out


func _rebuild_family_options() -> void:
	var families: Array[String] = []
	for asset in _assets:
		var fam: String = asset.get("family", "")
		if not fam.is_empty() and fam not in families:
			families.append(fam)
	families.sort()
	var prev := _family_option.selected
	_family_option.clear()
	_family_option.add_item("All families", 0)
	_family_option.set_item_metadata(0, "")
	for i in families.size():
		_family_option.add_item(families[i], i + 1)
		_family_option.set_item_metadata(i + 1, families[i])
	if prev >= 0 and prev < _family_option.item_count:
		_family_option.select(prev)
	else:
		_family_option.select(0)


func _apply_filters() -> void:
	var family := ""
	var sel := _family_option.selected
	if sel >= 0:
		family = str(_family_option.get_item_metadata(sel))
	var filtered: Array = filter_custom_assets(_assets, _search_edit.text, family)
	_filtered.clear()
	for item in filtered:
		if item is Dictionary:
			_filtered.append(item)
	_list.clear()
	for asset in _filtered:
		var label := "%s  (%s)" % [asset.get("name", "?"), asset.get("family", "?")]
		if asset.get("read_only", false):
			label += "  [read-only]"
		var idx := _list.add_item(label)
		_list.set_item_metadata(idx, asset)
	if _filtered.is_empty():
		_detail.text = "No assets match the current filters."
	elif _list.item_count > 0:
		_list.select(0)
		_on_asset_selected(0)


func _on_asset_selected(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	var asset: Dictionary = _filtered[index]
	var promoted: PackedStringArray = asset.get("promoted", PackedStringArray())
	var promoted_text := "None"
	if promoted.size() > 0:
		promoted_text = ", ".join(Array(promoted))
	var installable := str(asset.get("path", "")).begins_with(USER_ASSETS_DIR)
	_detail.text = (
		"[b]%s[/b]  (%s)\n\n"
		+ "%s\n\n"
		+ "[b]Promoted parameters:[/b] %s\n\n"
		+ "[b]Path:[/b] %s\n"
		+ "[b]Section:[/b] %s\n"
		+ "[b]User-installed:[/b] %s"
	) % [
		asset.get("name", "?"),
		asset.get("family", "?"),
		asset.get("description", ""),
		promoted_text,
		asset.get("path", ""),
		asset.get("section", ""),
		"yes" if installable else "no (extension or project asset)",
	]


func _on_install_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Install Custom Asset"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.gnasset ; GONODES Asset"])
	dialog.file_selected.connect(_install_asset_from_path)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _install_asset_from_path(source_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		_show_info("File not found:\n%s" % source_path)
		return
	if not DirAccess.dir_exists_absolute(USER_ASSETS_DIR):
		var err := DirAccess.make_dir_recursive_absolute(USER_ASSETS_DIR)
		if err != OK:
			_show_info("Could not create %s (error %d)" % [USER_ASSETS_DIR, err])
			return

	var file_name := source_path.get_file()
	var dest_path := USER_ASSETS_DIR.path_join(file_name)
	var src := FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		_show_info("Could not read:\n%s" % source_path)
		return
	var data := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(dest_path, FileAccess.WRITE)
	if dst == null:
		_show_info("Could not write:\n%s" % dest_path)
		return
	dst.store_buffer(data)
	dst.close()

	GNExtensionRegistry.instance().scan_custom_assets()
	refresh()
	_show_info("Installed asset to:\n%s" % dest_path)


func _on_uninstall_pressed() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		_show_info("Select a user-installed asset to uninstall.")
		return
	var asset: Dictionary = _filtered[sel[0]]
	var path: String = asset.get("path", "")
	if not path.begins_with(USER_ASSETS_DIR):
		_show_info("Only assets under user://gonodes_assets/ can be uninstalled.")
		return
	if not FileAccess.file_exists(path):
		_show_info("Asset file is already missing:\n%s" % path)
		GNExtensionRegistry.instance().unregister_custom_asset(asset.get("name", ""), path)
		refresh()
		return

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		_show_info("Failed to delete asset (error %d)" % err)
		return
	GNExtensionRegistry.instance().unregister_custom_asset(asset.get("name", ""), path)
	refresh()
	_show_info("Uninstalled:\n%s" % path)


func _show_info(text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = text
	dlg.confirmed.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
