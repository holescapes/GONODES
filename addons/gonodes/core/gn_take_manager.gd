class_name GNTakeManager
extends RefCounted
## Named parameter layer system for instant cross-network preset switching.
##
## A Take is a sparse set of parameter overrides that can be applied to a
## network atomically.  Each Take stores only the parameters that differ from
## the Base state — everything else falls through to the node's current value.
##
## Usage:
##   var mgr = GNTakeManager.new(network)
##   mgr.capture_base()                          # Snapshot current state
##   mgr.capture_take("Intense", node_ids)       # Capture selected/all nodes
##   mgr.apply_take("Intense")                   # Restore overrides
##   mgr.revert_to_base()                        # Restore original state
##   mgr.blend_take("Intense", 0.5)              # 50% blend toward take
##
## File format (.gntake JSON):
##   {
##     "version": 1,
##     "base": { "node_id/param_name": <value_dict>, ... },
##     "takes": {
##       "TakeName": { "node_id/param_name": <value_dict>, ... },
##       ...
##     }
##   }

## Emitted when the active take changes (name is "" for Base).
signal active_take_changed(take_name: String)

## Emitted when a take is created / deleted / renamed.
signal takes_changed()

## The network this manager operates on.
var network: GNNetwork = null

## Snapshot of all parameter values at the time capture_base() was called.
## Key: "node_id/param_name" → Dictionary (GNParameter.to_dict() output)
var _base: Dictionary = {}

## Named takes.  Key: take_name → Dictionary of "node_id/param_name" → value_dict
var _takes: Dictionary = {}

## Name of the currently active take ("" = Base).
var active_take: String = ""


func _init(network: GNNetwork = null) -> void:
	if network != null:
		self.network = network


# ═══════════════════════════════════════════════════════════════════════════════
# Base Snapshot
# ═══════════════════════════════════════════════════════════════════════════════

## Captures the current parameter state of every node as the Base layer.
func capture_base() -> void:
	_base.clear()
	if network == null:
		return
	for nid in network.nodes:
		var node: GNNode = network.nodes[nid]
		for p_name in node.parameters:
			var key := "%s/%s" % [nid, p_name]
			_base[key] = node.parameters[p_name].to_dict()
		for p_name in node.spare_parameters:
			if node.parameters.has(p_name):
				continue
			var key := "%s/%s" % [nid, p_name]
			_base[key] = node.spare_parameters[p_name].to_dict()
	GNLogger.info("TakeManager", "Captured base state (%d params)" % _base.size())


## Returns true if a base snapshot exists.
func has_base() -> bool:
	return not _base.is_empty()


# ═══════════════════════════════════════════════════════════════════════════════
# Take Capture & Management
# ═══════════════════════════════════════════════════════════════════════════════

## Captures the current parameter state into a named Take.
## Only stores parameters that differ from the Base snapshot (sparse delta).
## If [param node_ids] is empty, captures ALL nodes in the network.
func capture_take(take_name: String, node_ids: PackedStringArray = PackedStringArray()) -> void:
	if network == null or take_name.is_empty():
		return
	if _base.is_empty():
		capture_base()

	var delta: Dictionary = {}
	var ids: Array = node_ids if not node_ids.is_empty() else network.nodes.keys()
	for nid in ids:
		var node: GNNode = network.nodes.get(nid, null)
		if node == null:
			continue
		for p_name in node.parameters:
			var key := "%s/%s" % [nid, p_name]
			var current_dict: Dictionary = node.parameters[p_name].to_dict()
			var base_dict: Dictionary = _base.get(key, {})
			if _dicts_differ(current_dict, base_dict):
				delta[key] = current_dict
		for p_name in node.spare_parameters:
			if node.parameters.has(p_name):
				continue
			var key := "%s/%s" % [nid, p_name]
			var current_dict: Dictionary = node.spare_parameters[p_name].to_dict()
			var base_dict: Dictionary = _base.get(key, {})
			if _dicts_differ(current_dict, base_dict):
				delta[key] = current_dict

	_takes[take_name] = delta
	GNLogger.info("TakeManager", "Captured take '%s' (%d overrides)" % [take_name, delta.size()])
	takes_changed.emit()


## Returns an array of take names.
func get_take_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in _takes:
		names.append(key)
	return names


## Removes a named take.
func delete_take(take_name: String) -> void:
	if _takes.erase(take_name):
		if active_take == take_name:
			revert_to_base()
		takes_changed.emit()
		GNLogger.info("TakeManager", "Deleted take '%s'" % take_name)


## Renames a take.
func rename_take(old_name: String, new_name: String) -> void:
	if not _takes.has(old_name) or new_name.is_empty():
		return
	_takes[new_name] = _takes[old_name]
	_takes.erase(old_name)
	if active_take == old_name:
		active_take = new_name
	takes_changed.emit()


## Returns the number of parameter overrides in a take.
func get_take_override_count(take_name: String) -> int:
	var take: Dictionary = _takes.get(take_name, {})
	return take.size()


# ═══════════════════════════════════════════════════════════════════════════════
# Apply & Revert
# ═══════════════════════════════════════════════════════════════════════════════

## Applies a named take — sets all its parameter overrides on the network.
func apply_take(take_name: String) -> void:
	if network == null or not _takes.has(take_name):
		return

	# Revert to base first so we start from a clean state
	if active_take != "" and active_take != take_name:
		_apply_snapshot(_base)

	_apply_snapshot(_takes[take_name])
	active_take = take_name
	active_take_changed.emit(take_name)
	GNLogger.info("TakeManager", "Applied take '%s'" % take_name)


## Reverts all parameters to the Base snapshot.
func revert_to_base() -> void:
	if network == null:
		return
	_apply_snapshot(_base)
	active_take = ""
	active_take_changed.emit("")
	GNLogger.info("TakeManager", "Reverted to base")


## Blends the current state toward a take by [param t] (0.0 = base, 1.0 = take).
## Only blends float, int, and Color parameters — others snap at t >= 0.5.
func blend_take(take_name: String, t: float) -> void:
	if network == null or not _takes.has(take_name):
		return

	var take: Dictionary = _takes[take_name]
	for key in take:
		var parts: PackedStringArray = key.split("/", false, 1)
		if parts.size() < 2:
			continue
		var node: GNNode = network.nodes.get(parts[0], null)
		if node == null:
			continue
		var param: GNParameter = node.parameters.get(parts[1], null)
		if param == null:
			continue

		var base_dict: Dictionary = _base.get(key, {})
		var take_dict: Dictionary = take[key]
		var base_val: Variant = _dict_to_value(base_dict, param)
		var take_val: Variant = _dict_to_value(take_dict, param)

		var blended: Variant = _lerp_value(base_val, take_val, t)
		param.set_value(blended)
		node.mark_dirty()

	active_take = take_name if t >= 1.0 else ""
	active_take_changed.emit(active_take)


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Serializes all takes (including base) to a dictionary for JSON export.
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"base": _base.duplicate(true),
		"takes": _takes.duplicate(true),
	}


## Restores from a previously serialized dictionary.
func from_dict(d: Dictionary) -> void:
	_base = d.get("base", {}).duplicate(true)
	_takes = d.get("takes", {}).duplicate(true)
	active_take = ""
	takes_changed.emit()


## Saves to a .gntake JSON file.
func save_to_file(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var json_text := JSON.stringify(to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GNLogger.error("TakeManager", "Cannot write: %s" % path)
		return false
	file.store_string(json_text)
	file.close()
	GNLogger.info("TakeManager", "Saved takes to: %s" % path)
	return true


## Loads from a .gntake JSON file.
func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		GNLogger.error("TakeManager", "File not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		GNLogger.error("TakeManager", "JSON parse error: %s" % json.get_error_message())
		return false
	if json.data is Dictionary:
		from_dict(json.data as Dictionary)
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

## Applies a snapshot dictionary to the network.
func _apply_snapshot(snapshot: Dictionary) -> void:
	for key in snapshot:
		var parts: PackedStringArray = key.split("/", false, 1)
		if parts.size() < 2:
			continue
		var node: GNNode = network.nodes.get(parts[0], null)
		if node == null:
			continue
		var param: GNParameter = node.parameters.get(parts[1], null)
		if param == null:
			param = node.spare_parameters.get(parts[1], null)
		if param == null:
			continue
		param.from_dict(snapshot[key])
		node.mark_dirty()


## Compares two param dicts for meaningful differences (ignoring readonly/meta keys).
static func _dicts_differ(a: Dictionary, b: Dictionary) -> bool:
	var va: Variant = a.get("value", null)
	var vb: Variant = b.get("value", null)
	if va != vb:
		return true
	var ma: String = a.get("mode", "CONSTANT")
	var mb: String = b.get("mode", "CONSTANT")
	return ma != mb


## Extracts the native value from a param dict, using the param's type for context.
static func _dict_to_value(d: Dictionary, param: GNParameter) -> Variant:
	if d.is_empty():
		return param.value
	var v: Variant = d.get("value", param.value)
	# Handle typed wrapper dicts from GNParameter.to_dict()
	if v is Dictionary:
		var vd := v as Dictionary
		match vd.get("_type", ""):
			"Color":
				return Color(vd.get("r", 0.0), vd.get("g", 0.0), vd.get("b", 0.0), vd.get("a", 1.0))
			"Vector2":
				return Vector2(vd.get("x", 0.0), vd.get("y", 0.0))
			"Vector2i":
				return Vector2i(int(vd.get("x", 0)), int(vd.get("y", 0)))
			"Vector3":
				return Vector3(vd.get("x", 0.0), vd.get("y", 0.0), vd.get("z", 0.0))
			"Vector4":
				return Vector4(vd.get("x", 0.0), vd.get("y", 0.0), vd.get("z", 0.0), vd.get("w", 0.0))
	return v


## Lerps between two values based on their type.
static func _lerp_value(a: Variant, b: Variant, t: float) -> Variant:
	if a is float and b is float:
		return lerpf(a as float, b as float, t)
	if a is int and b is int:
		return int(lerpf(float(a), float(b), t))
	if a is Color and b is Color:
		return (a as Color).lerp(b as Color, t)
	if a is Vector2 and b is Vector2:
		return (a as Vector2).lerp(b as Vector2, t)
	if a is Vector3 and b is Vector3:
		return (a as Vector3).lerp(b as Vector3, t)
	if a is Vector4 and b is Vector4:
		return (a as Vector4).lerp(b as Vector4, t)
	# Non-blendable types snap at midpoint
	return b if t >= 0.5 else a
