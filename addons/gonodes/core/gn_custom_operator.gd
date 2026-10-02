class_name GNCustomOperator
extends SubNetworkNode
## A custom operator loaded from a .gnasset file.
##
## Extends SubNetworkNode with:
##   - Asset file reference (inner network loaded from .gnasset, not inline)
##   - Promoted parameter proxies (top-level params that read/write inner node params)
##   - Asset identity (custom op_name, family, description, icon)
##
## Serialization: .gnpatch stores only the asset_path + per-instance param overrides,
## NOT the full inner network (that lives in the .gnasset file).

# ─── Asset Identity ────────────────────────────────────────────────────────────

## Path to the source .gnasset file (res://, user://, or absolute).
var asset_path: String = ""

## Asset metadata loaded from the .gnasset identity block.
var asset_identity: Dictionary = {}

## Promoted parameter definitions from the .gnasset file.
## Array of { "inner_node_id", "inner_param_name", "promoted_name", "promoted_order" }
var _promoted_defs: Array[Dictionary] = []

## Map promoted_name → { "inner_node_id": String, "inner_param_name": String }
var _promoted_map: Dictionary = {}

## Custom parameters defined in the .gnasset (created from spare params on re-save).
## These are standalone params (not proxied to inner nodes) — accessible via
## expressions from inner nodes as par("../", "param_name").
var _custom_param_defs: Array[Dictionary] = []

## True when the user is actively editing the asset's inner network in-place.
var asset_editing: bool = false

## Snapshot of the inner network dict taken when asset editing begins, for discard.
var _pre_edit_snapshot: Dictionary = {}


func _init() -> void:
	node_type = "custom_asset"
	node_description = "Custom operator loaded from a .gnasset file."
	family = GNFamily.Type.COMP


func _init_parameters() -> void:
	# Promoted parameters are built dynamically from the asset definition.
	# The base "label" parameter is inherited from SubNetworkNode.
	super._init_parameters()


# ═══════════════════════════════════════════════════════════════════════════════
# Asset Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads the .gnasset file and populates the inner network + promoted params.
## Returns true on success.
func load_from_asset(path: String) -> bool:
	asset_path = path
	var data := _read_asset_json(path)
	if data.is_empty():
		node_error = "Failed to load asset: %s" % path
		return false

	# Parse identity
	asset_identity = data.get("identity", {})
	node_type = asset_identity.get("op_name", "custom_asset")
	node_description = asset_identity.get("description", "Custom operator")
	var family_str: String = asset_identity.get("family", "COMP")
	family = GNFamily.string_to_type(family_str)

	# Load inner network
	_ensure_inner_network()
	var inner_dict: Dictionary = data.get("inner_network", {})
	if not inner_dict.is_empty():
		inner_network.from_dict(inner_dict)
		_ports_dirty = true
		sync_ports_from_tunnels()
		# Wire dirty-propagation so inner widget interactions (drag pads,
		# sliders) bubble up and trigger a re-cook of this operator.
		_connect_inner_dirty_signals()

	# Build promoted parameters
	_promoted_defs.clear()
	_promoted_map.clear()
	var promoted: Array = data.get("promoted_parameters", [])
	for entry in promoted:
		if typeof(entry) != TYPE_DICTIONARY:
			GNLogger.warn("CustomOperator",
				"Skipping invalid promoted_parameters entry (expected Dictionary): %s" % str(entry))
			continue
		var pdef: Dictionary = {
			"inner_node_id": entry.get("inner_node_id", ""),
			"inner_param_name": entry.get("inner_param_name", ""),
			"promoted_name": entry.get("promoted_name", ""),
			"promoted_order": entry.get("promoted_order", 0),
		}
		_promoted_defs.append(pdef)

	# Sort by promoted_order
	_promoted_defs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["promoted_order"] < b["promoted_order"])

	# Create promoted parameter proxies
	for pdef in _promoted_defs:
		var inner_node: GNNode = inner_network.nodes.get(pdef["inner_node_id"], null)
		if inner_node == null:
			continue
		var inner_param: GNParameter = inner_node.parameters.get(pdef["inner_param_name"], null)
		if inner_param == null:
			continue

		# Clone the inner parameter as a promoted top-level param
		var promoted_param: GNParameter = inner_param.duplicate()
		promoted_param.param_name = pdef["promoted_name"]
		promoted_param.label = pdef["promoted_name"]
		add_parameter(promoted_param)

		# Map for proxy read/write
		_promoted_map[pdef["promoted_name"]] = {
			"inner_node_id": pdef["inner_node_id"],
			"inner_param_name": pdef["inner_param_name"],
		}

	# Update label param with asset name
	if parameters.has("label"):
		parameters["label"].value = asset_identity.get("op_name", "Custom")
		parameters["label"].default_value = asset_identity.get("op_name", "Custom")

	# Load custom parameters (standalone params defined on the asset)
	_custom_param_defs.clear()
	var custom_params: Array = data.get("custom_parameters", [])
	for cp_def in custom_params:
		_custom_param_defs.append(cp_def)
		var cp := _create_custom_param_from_def(cp_def)
		if cp != null:
			add_parameter(cp)

	return true


## Syncs promoted parameter values down to inner nodes before cooking.
func _sync_promoted_params_to_inner() -> void:
	for promoted_name in _promoted_map:
		var mapping: Dictionary = _promoted_map[promoted_name]
		var outer_param: GNParameter = parameters.get(promoted_name, null)
		if outer_param == null:
			continue
		var inner_node: GNNode = inner_network.nodes.get(mapping["inner_node_id"], null)
		if inner_node == null:
			continue
		var inner_param: GNParameter = inner_node.parameters.get(mapping["inner_param_name"], null)
		if inner_param == null:
			continue
		# Sync value (constant or resolved)
		var val: Variant = outer_param.get_resolved_value() if outer_param.mode == GNParameter.Mode.EXPRESSION else outer_param.value
		inner_param.set_value(val)
		inner_node.mark_dirty()


func _cook(inputs: Array[GNData]) -> GNData:
	_sync_promoted_params_to_inner()
	return super._cook(inputs)


# ═══════════════════════════════════════════════════════════════════════════════
# Update Asset — re-saves the .gnasset incorporating current spare params
# ═══════════════════════════════════════════════════════════════════════════════

## Re-saves the .gnasset file, promoting current instance spare parameters to
## the asset's custom_parameters so every future instance gets them.
## Returns true on success.
func update_asset() -> bool:
	if asset_path.is_empty():
		GNLogger.error("CustomOperator", "No asset_path set — cannot update")
		return false

	var data := _read_asset_json(asset_path)
	if data.is_empty():
		GNLogger.error("CustomOperator", "Cannot read existing asset: %s" % asset_path)
		return false

	# Merge existing custom_parameters with current spare parameters.
	# Spares on this instance become custom_parameters in the asset definition.
	var existing_custom: Array = data.get("custom_parameters", [])
	var existing_names: Dictionary = {}
	for cp in existing_custom:
		existing_names[cp.get("name", "")] = true

	for sp_name in spare_parameters:
		if existing_names.has(sp_name):
			# Update existing custom param definition with current value as default
			for cp in existing_custom:
				if cp.get("name", "") == sp_name:
					cp["default_value"] = _variant_to_saveable(spare_parameters[sp_name].value)
					break
		else:
			var sp: GNParameter = spare_parameters[sp_name]
			existing_custom.append({
				"name": sp_name,
				"value_type": sp.value_type,
				"label": sp.label,
				"default_value": _variant_to_saveable(sp.value),
				"min_value": sp.min_value,
				"max_value": sp.max_value,
				"step": sp.step,
			})

	data["custom_parameters"] = existing_custom

	var ok := write_asset_json(asset_path, data)
	if ok:
		GNLogger.info("CustomOperator", "Updated asset '%s' with %d custom params" % [
			asset_path, existing_custom.size()])
		# Move spare params → regular custom params on this instance
		for cp_def in existing_custom:
			var cp_name: String = cp_def.get("name", "")
			if spare_parameters.has(cp_name):
				var sp: GNParameter = spare_parameters[cp_name]
				remove_spare_parameter(cp_name)
				add_parameter(sp)
	return ok


## Converts a Variant value into a JSON-safe form.
static func _variant_to_saveable(value: Variant) -> Variant:
	if value is Color:
		return {"_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Vector2:
		return {"_type": "Vector2", "x": value.x, "y": value.y}
	if value is Vector2i:
		return {"_type": "Vector2i", "x": value.x, "y": value.y}
	return value


## Creates a GNParameter from a custom_parameters definition dict.
func _create_custom_param_from_def(cp_def: Dictionary) -> GNParameter:
	var p_name: String = cp_def.get("name", "")
	if p_name.is_empty():
		return null
	var vt: int = int(cp_def.get("value_type", GNParameter.ValueType.FLOAT))
	var p := GNParameter.new()
	p.param_name = p_name
	p.label = cp_def.get("label", p_name)
	p.value_type = vt
	p.default_value = _saveable_to_variant(cp_def.get("default_value", 0.0), vt)
	p.value = p.default_value
	p.min_value = cp_def.get("min_value", 0.0)
	p.max_value = cp_def.get("max_value", 1.0)
	p.step = cp_def.get("step", 0.01)
	return p


## Converts a saved value back to a typed Variant.
static func _saveable_to_variant(value: Variant, vt: int) -> Variant:
	if value is Dictionary:
		var t: String = value.get("_type", "")
		if t == "Color":
			return Color(value.get("r", 0), value.get("g", 0), value.get("b", 0), value.get("a", 1))
		if t == "Vector2":
			return Vector2(value.get("x", 0), value.get("y", 0))
		if t == "Vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return value


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization — compact: asset_path + param overrides only
# ═══════════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"type": node_type if not node_type.is_empty() else "GNCustomOperator",
		"position": [graph_position.x, graph_position.y],
		"asset_path": asset_path,
	}
	if not preview_enabled:
		d["preview_enabled"] = false
	if bypass:
		d["bypass"] = true
	if locked:
		d["locked"] = true

	# Save promoted param overrides (only values that differ from asset defaults)
	var params_dict: Dictionary = {}
	for p_name in _promoted_map:
		var param: GNParameter = parameters.get(p_name, null)
		if param == null:
			continue
		var pd := param.to_dict()
		if not pd.is_empty():
			params_dict[p_name] = pd
	# Save custom parameter overrides
	for cp_def in _custom_param_defs:
		var cp_name: String = cp_def.get("name", "")
		var param: GNParameter = parameters.get(cp_name, null)
		if param == null:
			continue
		var pd := param.to_dict()
		if not pd.is_empty():
			params_dict[cp_name] = pd
	# Also save the label if changed
	if parameters.has("label"):
		var label_pd: Dictionary = parameters["label"].to_dict()
		if not label_pd.is_empty():
			params_dict["label"] = label_pd
	if not params_dict.is_empty():
		d["parameters"] = params_dict

	return d


func from_dict(d: Dictionary) -> void:
	# Load asset first (creates inner network + promoted params)
	var path: String = d.get("asset_path", "")
	if not path.is_empty():
		load_from_asset(path)

	# Restore graph position
	if d.has("position"):
		var pos: Array = d["position"]
		if pos.size() >= 2:
			graph_position = Vector2(float(pos[0]), float(pos[1]))

	if d.has("preview_enabled"):
		preview_enabled = d["preview_enabled"]
	if d.has("bypass"):
		bypass = d["bypass"]
	if d.has("locked"):
		locked = d["locked"]

	# Apply parameter overrides on top of asset defaults
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for p_name in params_dict:
			var param: GNParameter = parameters.get(p_name, null)
			if param != null:
				param.from_dict(params_dict[p_name])


# ═══════════════════════════════════════════════════════════════════════════════
# Asset File I/O
# ═══════════════════════════════════════════════════════════════════════════════

static func _read_asset_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		GNLogger.error("CustomOperator", "Asset file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GNLogger.error("CustomOperator", "Cannot open asset file: %s" % path)
		return {}
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		GNLogger.error("CustomOperator", "JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		var _ret0 := json.data as Dictionary
		return _ret0
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# Edit-in-Place — Phase 3
# ═══════════════════════════════════════════════════════════════════════════════

## Begins asset editing — takes a snapshot of the inner network for discard.
func begin_asset_edit() -> void:
	asset_editing = true
	_pre_edit_snapshot = inner_network.to_dict()
	GNLogger.info("CustomOperator", "Began editing asset: %s" % asset_path)


## Saves the current inner network state back to the .gnasset file.
## Preserves identity and custom_parameters; refreshes promoted parameter
## mappings (drops stale ones, keeps valid ones).
## Returns true on success.
func save_asset_from_inner() -> bool:
	if asset_path.is_empty():
		GNLogger.error("CustomOperator", "No asset_path set — cannot save")
		return false

	var data := _read_asset_json(asset_path)
	if data.is_empty():
		# Build fresh structure if file is missing / corrupt
		data = {"identity": asset_identity}

	# Replace inner network with current live state
	data["inner_network"] = inner_network.to_dict()

	# Validate promoted parameters — drop entries whose inner node/param is gone
	var valid_promoted: Array = []
	for pdef in _promoted_defs:
		var inner_node: GNNode = inner_network.nodes.get(pdef["inner_node_id"], null)
		if inner_node == null:
			GNLogger.warn("CustomOperator", "Dropped promoted param '%s' — inner node '%s' removed" % [
				pdef["promoted_name"], pdef["inner_node_id"]])
			continue
		if not inner_node.parameters.has(pdef["inner_param_name"]):
			GNLogger.warn("CustomOperator", "Dropped promoted param '%s' — inner param '%s.%s' removed" % [
				pdef["promoted_name"], pdef["inner_node_id"], pdef["inner_param_name"]])
			continue
		valid_promoted.append(pdef)
	data["promoted_parameters"] = valid_promoted

	var ok := write_asset_json(asset_path, data)
	if ok:
		_promoted_defs = []
		for vp in valid_promoted:
			_promoted_defs.append(vp)
		asset_editing = false
		_pre_edit_snapshot = {}
		GNLogger.info("CustomOperator", "Saved asset: %s" % asset_path)
	return ok


## Discards in-progress edits by restoring from the pre-edit snapshot.
func discard_asset_edits() -> void:
	if not _pre_edit_snapshot.is_empty():
		inner_network.from_dict(_pre_edit_snapshot)
		sync_ports_from_tunnels()
		_connect_inner_dirty_signals()
	else:
		# Fallback: reload from disk (load_from_asset already connects signals)
		load_from_asset(asset_path)
	asset_editing = false
	_pre_edit_snapshot = {}
	GNLogger.info("CustomOperator", "Discarded asset edits: %s" % asset_path)


## Reloads the inner network from the .gnasset file on disk.
## Used to sync other instances after one instance saves.
func reload_from_asset() -> void:
	var old_overrides: Dictionary = {}
	# Preserve per-instance parameter overrides
	for p_name in _promoted_map:
		var param: GNParameter = parameters.get(p_name, null)
		if param:
			old_overrides[p_name] = param.to_dict()
	for cp_def in _custom_param_defs:
		var cp_name: String = cp_def.get("name", "")
		var param: GNParameter = parameters.get(cp_name, null)
		if param:
			old_overrides[cp_name] = param.to_dict()

	load_from_asset(asset_path)

	# Restore overrides
	for p_name in old_overrides:
		var param: GNParameter = parameters.get(p_name, null)
		if param:
			param.from_dict(old_overrides[p_name])
	mark_dirty()


## Writes a .gnasset file from the given data dictionary. Returns true on success.
static func write_asset_json(path: String, data: Dictionary) -> bool:
	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			GNLogger.error("CustomOperator", "Cannot create directory: %s" % dir_path)
			return false
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GNLogger.error("CustomOperator", "Cannot write asset file: %s" % path)
		return false
	file.store_string(json_text)
	file.close()
	return true
