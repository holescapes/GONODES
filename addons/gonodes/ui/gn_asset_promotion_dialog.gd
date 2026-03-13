class_name GNAssetPromotionDialog
extends AcceptDialog
## Dialog for promoting a SubNetworkNode into a reusable .gnasset custom operator.
##
## Shows identity fields (name, family, description) and a checkbox list of
## inner parameters to promote to the asset's public interface.  On confirm,
## writes the .gnasset file and registers it in the extension registry.

signal asset_created(asset_path: String, op_name: String)

var _source_node: SubNetworkNode = null

# ── Identity section ─────────────────────────────────────────────────────────
var _name_edit: LineEdit = null
var _family_edit: LineEdit = null
var _desc_edit: TextEdit = null

# ── Parameter promotion ──────────────────────────────────────────────────────
var _param_scroll: ScrollContainer = null
var _param_vbox: VBoxContainer = null
var _param_checks: Array[Dictionary] = []  # { "check": CheckBox, "inner_node_id", "param_name" }

# ── Save location ───────────────────────────────────────────────────────────
var _location_edit: LineEdit = null


func _init() -> void:
	title = "Promote to Custom Asset"
	ok_button_text = "Create Asset"
	size = Vector2i(500, 520)


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

	# ── Promoted Parameters ──────────────────────────────────────────────
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	var params_label := Label.new()
	params_label.text = "Promoted Parameters"
	params_label.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(params_label)

	var hint_label := Label.new()
	hint_label.text = "Check parameters to expose on the asset's public interface."
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	root_vbox.add_child(hint_label)

	_param_scroll = ScrollContainer.new()
	_param_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_param_scroll.custom_minimum_size = Vector2(0, 160)
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
	_populate_param_list()


func _populate_param_list() -> void:
	# Clear existing
	for child in _param_vbox.get_children():
		child.queue_free()
	_param_checks.clear()

	if _source_node == null or _source_node.inner_network == null:
		return

	# Enumerate parameters from all inner nodes
	var order := 0
	for node_id in _source_node.inner_network.nodes:
		var inner_node: GNNode = _source_node.inner_network.nodes[node_id]
		if inner_node is InTunnel or inner_node is OutTunnel:
			continue
		for param_name in inner_node.parameters:
			var param: GNParameter = inner_node.parameters[param_name]
			if param.param_name == "label":
				continue  # Skip internal label param
			var check := CheckBox.new()
			check.text = "%s → %s  (%s)" % [node_id, param.label, _type_name(param.value_type)]
			check.add_theme_font_size_override("font_size", 12)
			_param_vbox.add_child(check)
			_param_checks.append({
				"check": check,
				"inner_node_id": node_id,
				"param_name": param_name,
				"promoted_name": "%s_%s" % [node_id, param_name],
				"order": order,
			})
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

	# Collect promoted parameters
	var promoted: Array[Dictionary] = []
	for entry in _param_checks:
		var check: CheckBox = entry["check"]
		if check.button_pressed:
			promoted.append({
				"inner_node_id": entry["inner_node_id"],
				"inner_param_name": entry["param_name"],
				"promoted_name": entry["promoted_name"],
				"promoted_order": entry["order"],
			})

	# Build .gnasset data
	var asset_data: Dictionary = {
		"identity": {
			"op_name": op_name,
			"family": family_str,
			"description": desc,
		},
		"inner_network": _source_node.inner_network.to_dict(),
		"promoted_parameters": promoted,
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
	GNLogger.info("PromotionDialog", "Created custom asset '%s' at %s" % [op_name, full_path])
	asset_created.emit(full_path, op_name)
