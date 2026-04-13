class_name GNAssetPromotionDialog
extends AcceptDialog
## Dialog for promoting a SubNetworkNode into a reusable .gnasset custom operator.
##
## Spare parameters on the SubNetwork become the asset's public interface —
## no checkbox selection required.  The dialog shows identity fields
## (name, family, description) and a read-only summary of the spare params
## that will become the asset interface.

signal asset_created(asset_path: String, op_name: String)

var _source_node: SubNetworkNode = null

# ── Identity section ─────────────────────────────────────────────────────────
var _name_edit: LineEdit = null
var _family_edit: LineEdit = null
var _desc_edit: TextEdit = null

# ── Spare params summary (read-only) ────────────────────────────────────────
var _param_scroll: ScrollContainer = null
var _param_vbox: VBoxContainer = null
var _spare_hint_label: Label = null

# ── Save location ───────────────────────────────────────────────────────────
var _location_edit: LineEdit = null


func _init() -> void:
	title = "Promote to Custom Asset"
	ok_button_text = "Create Asset"
	size = Vector2i(500, 480)


func _ready() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)

	# ── Identity ─────────────────────────────────────────────────────────
	var id_label := Label.new()
	id_label.text = "Asset Identity"
	id_label.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(id_label)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 4)
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size.x = 80
	name_hbox.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "MyCustomFilter"
	name_hbox.add_child(_name_edit)
	root_vbox.add_child(name_hbox)

	var family_hbox := HBoxContainer.new()
	family_hbox.add_theme_constant_override("separation", 4)
	var fam_lbl := Label.new()
	fam_lbl.text = "Family:"
	fam_lbl.custom_minimum_size.x = 80
	family_hbox.add_child(fam_lbl)
	_family_edit = LineEdit.new()
	_family_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_edit.placeholder_text = "TOP"
	_family_edit.max_length = 4
	family_hbox.add_child(_family_edit)
	root_vbox.add_child(family_hbox)

	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	root_vbox.add_child(desc_lbl)
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(0, 50)
	_desc_edit.placeholder_text = "What does this asset do?"
	root_vbox.add_child(_desc_edit)

	# ── Asset Interface (spare params summary) ───────────────────────────
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	var params_label := Label.new()
	params_label.text = "Asset Interface (Spare Parameters)"
	params_label.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(params_label)

	_spare_hint_label = Label.new()
	_spare_hint_label.add_theme_font_size_override("font_size", 11)
	_spare_hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_spare_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_spare_hint_label)

	_param_scroll = ScrollContainer.new()
	_param_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_param_scroll.custom_minimum_size = Vector2(0, 120)
	_param_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_param_scroll)

	_param_vbox = VBoxContainer.new()
	_param_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_param_vbox.add_theme_constant_override("separation", 2)
	_param_scroll.add_child(_param_vbox)

	# ── Save Location ────────────────────────────────────────────────────
	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	var loc_hbox := HBoxContainer.new()
	loc_hbox.add_theme_constant_override("separation", 4)
	var loc_lbl := Label.new()
	loc_lbl.text = "Save to:"
	loc_lbl.custom_minimum_size.x = 80
	loc_hbox.add_child(loc_lbl)
	_location_edit = LineEdit.new()
	_location_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_edit.placeholder_text = "res://custom_operators/"
	_location_edit.text = "res://custom_operators/"
	loc_hbox.add_child(_location_edit)
	root_vbox.add_child(loc_hbox)

	add_child(root_vbox)
	confirmed.connect(_on_confirmed)


## Populates the dialog for the given SubNetworkNode.
func setup(subnet: SubNetworkNode) -> void:
	_source_node = subnet
	_name_edit.text = subnet.id.capitalize().replace(" ", "")
	_family_edit.text = GNFamily.get_family_name(subnet.family)
	_desc_edit.text = ""
	_populate_spare_summary()


## Builds a read-only list of spare parameters that will become the asset interface.
func _populate_spare_summary() -> void:
	for child in _param_vbox.get_children():
		child.queue_free()

	if _source_node == null:
		return

	var spare_count: int = _source_node.spare_parameters.size()
	if spare_count == 0:
		_spare_hint_label.text = (
			"This sub-network has no spare parameters.\n"
			+ "The asset will be created with no public interface (valid but parameterless).\n"
			+ "Add spare parameters to the sub-network first to expose controls on the asset."
		)
		_param_scroll.visible = false
		return

	_spare_hint_label.text = (
		"All spare parameters on this sub-network become the asset's public interface."
	)
	_param_scroll.visible = true

	var order := 0
	for sp_name in _source_node.spare_parameters:
		var sp: GNParameter = _source_node.spare_parameters[sp_name]
		var row := Label.new()
		row.text = "  %s  (%s)  =  %s" % [sp.label, _type_name(sp.value_type), str(sp.value)]
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_param_vbox.add_child(row)
		order += 1


func _type_name(vt: GNParameter.ValueType) -> String:
	match vt:
		GNParameter.ValueType.FLOAT: return "float"
		GNParameter.ValueType.INT: return "int"
		GNParameter.ValueType.BOOL: return "bool"
		GNParameter.ValueType.STRING: return "string"
		GNParameter.ValueType.VECTOR2: return "vec2"
		GNParameter.ValueType.VECTOR2I: return "vec2i"
		GNParameter.ValueType.VECTOR3: return "vec3"
		GNParameter.ValueType.VECTOR4: return "vec4"
		GNParameter.ValueType.COLOR: return "color"
		GNParameter.ValueType.ENUM: return "enum"
		GNParameter.ValueType.FILE: return "file"
		GNParameter.ValueType.RAMP: return "ramp"
		_: return "?"


func _on_confirmed() -> void:
	if _source_node == null:
		return

	var op_name: String = _name_edit.text.strip_edges()
	if op_name.is_empty():
		GNLogger.warn("PromotionDialog", "Asset name cannot be empty")
		return

	var family_str: String = _family_edit.text.strip_edges().to_upper()
	var desc: String = _desc_edit.text.strip_edges()
	var save_dir: String = _location_edit.text.strip_edges()
	if save_dir.is_empty():
		save_dir = "res://custom_operators/"

	# Spare parameters become the asset's custom_parameters (the public interface).
	# No promoted params (legacy checkbox model removed) — spare params are the interface.
	var custom_params: Array[Dictionary] = []
	var order := 0
	for sp_name in _source_node.spare_parameters:
		var sp: GNParameter = _source_node.spare_parameters[sp_name]
		custom_params.append({
			"name": sp_name,
			"value_type": sp.value_type,
			"label": sp.label,
			"default_value": GNCustomOperator._variant_to_saveable(sp.value),
			"min_value": sp.min_value,
			"max_value": sp.max_value,
			"step": sp.step,
		})
		order += 1

	# Build .gnasset data
	var asset_data: Dictionary = {
		"identity": {
			"op_name": op_name,
			"family": family_str,
			"description": desc,
		},
		"inner_network": _source_node.inner_network.to_dict(),
		"promoted_parameters": [],
		"custom_parameters": custom_params,
	}

	# Write file
	var file_name := op_name.to_snake_case() + ".gnasset"
	var full_path := save_dir.path_join(file_name)
	var ok := GNCustomOperator.write_asset_json(full_path, asset_data)
	if not ok:
		GNLogger.error("PromotionDialog", "Failed to write asset: %s" % full_path)
		return

	# Register in the extension registry
	var reg := GNExtensionRegistry.instance()
	reg._register_custom_asset(full_path)
	GNLogger.info("PromotionDialog", "Created custom asset '%s' at %s (%d interface params)" % [
		op_name, full_path, custom_params.size()])
	asset_created.emit(full_path, op_name)
