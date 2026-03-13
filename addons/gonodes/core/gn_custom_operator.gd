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

	# Build promoted parameters
	_promoted_defs.clear()
	_promoted_map.clear()
	var promoted: Array = data.get("promoted_parameters", [])
	for entry in promoted:
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
# Serialization — compact: asset_path + param overrides only
# ═══════════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"type": "GNCustomOperator",
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
		return json.data as Dictionary
	return {}


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
