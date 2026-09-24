class_name GNParamPresetManager
extends RefCounted
## Manages parameter presets for GONODES operators.
##
## Three capabilities:
##   1. **Copy / Paste** — clipboard-based transfer of all parameter values
##      between nodes of the same operator type (same GDScript class_name).
##   2. **Named Snapshots** — save / load JSON snapshots of a node's parameter
##      state, scoped per operator type (e.g. "NoiseTOP").
##   3. **Global Preset Library** — Both directories are scanned when
##      listing available presets.
##
## All serialization reuses `GNParameter.to_dict()` / `from_dict()` so the
## JSON format stays consistent with `.gnpatch` files.
##
## Directories are managed via [GNPresetPaths] — factory presets ship in
## `res://addons/gonodes/presets/params/`, user presets live under
## `user://gonodes/presets/params/`.


# ═══════════════════════════════════════════════════════════════════════════════
# Clipboard — in-memory copy / paste
# ═══════════════════════════════════════════════════════════════════════════════

## Internal clipboard holding the last copied parameter snapshot.
## Keys: "operator_type" (String), "params" (Dictionary of param_name → dict).
static var _clipboard: Dictionary = {}


## Copies all parameter values from [param node] into the clipboard.
static func copy_params(node: GNNode) -> void:
	if node == null:
		return
	var operator_type: String = node.get_script().get_global_name()
	var params_dict: Dictionary = {}
	for p_name in node.parameters:
		var param: GNParameter = node.parameters[p_name]
		params_dict[p_name] = param.to_dict()
	for sp_name in node.spare_parameters:
		var sp: GNParameter = node.spare_parameters[sp_name]
		params_dict["spare:" + sp_name] = sp.to_dict()
	_clipboard = {
		"operator_type": operator_type,
		"params": params_dict,
	}
	GNLogger.info("PresetManager", "Copied %d parameters from '%s' (%s)" % [
		params_dict.size(), node.id, operator_type])


## Returns true if the clipboard contains params compatible with [param node].
static func can_paste(node: GNNode) -> bool:
	if node == null or _clipboard.is_empty():
		return false
	var operator_type: String = node.get_script().get_global_name()
	return _clipboard.get("operator_type", "") == operator_type


## Pastes clipboard parameters onto [param node].
## Only parameters whose names exist on both sides are applied.
## Returns the number of parameters applied.
static func paste_params(node: GNNode) -> int:
	if not can_paste(node):
		GNLogger.warn("PresetManager", "Cannot paste — clipboard empty or type mismatch")
		return 0
	var params_dict: Dictionary = _clipboard.get("params", {})
	var applied := 0
	for p_name in params_dict:
		if p_name.begins_with("spare:"):
			var sp_name: String = p_name.substr(6)
			var sp: GNParameter = node.spare_parameters.get(sp_name, null)
			if sp != null:
				sp.from_dict(params_dict[p_name])
				applied += 1
		else:
			var param: GNParameter = node.parameters.get(p_name, null)
			if param == null:
				continue
			param.from_dict(params_dict[p_name])
			applied += 1
	# Mark node dirty so it re-cooks
	node.mark_dirty()
	GNLogger.info("PresetManager", "Pasted %d/%d parameters onto '%s'" % [
		applied, params_dict.size(), node.id])
	return applied


## Returns true if the clipboard has any content.
static func has_clipboard() -> bool:
	return not _clipboard.is_empty()


## Returns the operator type stored in the clipboard, or empty string.
static func clipboard_operator_type() -> String:
	return _clipboard.get("operator_type", "")


# ═══════════════════════════════════════════════════════════════════════════════
# Named Snapshots — file-based save / load
# ═══════════════════════════════════════════════════════════════════════════════

## Returns all available preset names for a given operator type.
## Returns Array of { "name": String, "path": String, "is_factory": bool }.
static func get_preset_list(operator_type: String) -> Array:
	var result: Array = []
	var dirs := GNPresetPaths.get_param_preset_dirs(operator_type)
	for i in range(dirs.size()):
		# Last entry is the user directory
		var is_factory: bool = i < dirs.size() - 1
		_scan_preset_dir(dirs[i], is_factory, result)
	return result


## Saves the current parameter state of [param node] as a named preset.
## Creates directories if needed. Returns true on success.
static func save_preset(node: GNNode, preset_name: String) -> bool:
	if node == null or preset_name.is_empty():
		return false
	var operator_type: String = node.get_script().get_global_name()

	# Serialize all parameters (built-in + spare)
	var params_dict: Dictionary = {}
	for p_name in node.parameters:
		var param: GNParameter = node.parameters[p_name]
		params_dict[p_name] = param.to_dict()
	# Include spare parameters — keyed with "spare:" prefix for clarity
	for sp_name in node.spare_parameters:
		var sp: GNParameter = node.spare_parameters[sp_name]
		params_dict["spare:" + sp_name] = sp.to_dict()

	var data: Dictionary = {
		"operator_type": operator_type,
		"preset_name": preset_name,
		"version": 1,
		"params": params_dict,
	}

	# Ensure directory exists
	var dir_path := GNPresetPaths.get_param_preset_save_dir(operator_type)
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			GNLogger.error("PresetManager",
				"Cannot create preset directory: %s (error %d)" % [dir_path, err])
			return false

	# Write JSON
	var file_path := dir_path + "/" + _sanitize_filename(preset_name) + ".json"
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		GNLogger.error("PresetManager",
			"Cannot write preset: %s" % file_path)
		return false
	file.store_string(json_text)
	file.close()
	GNLogger.info("PresetManager", "Saved param preset '%s' → %s" % [preset_name, file_path])
	return true


## Loads a JSON param preset from [param file_path] and applies it to [param node].
## Only parameters whose names exist on both sides are applied.
## Returns the number of parameters applied, or -1 on error.
static func load_preset(node: GNNode, file_path: String) -> int:
	if node == null:
		return -1
	if not FileAccess.file_exists(file_path):
		GNLogger.warn("PresetManager", "Preset not found: %s" % file_path)
		return -1

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		GNLogger.warn("PresetManager", "Cannot open preset: %s" % file_path)
		return -1
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		GNLogger.error("PresetManager", "JSON parse error in %s: %s" % [
			file_path, json.get_error_message()])
		return -1

	var data: Dictionary = json.data
	if not data is Dictionary:
		GNLogger.error("PresetManager", "Invalid preset format in %s" % file_path)
		return -1

	# Type safety check — warn but still apply (user may want cross-type paste)
	var stored_type: String = data.get("operator_type", "")
	var node_type: String = node.get_script().get_global_name()
	if stored_type != node_type:
		GNLogger.warn("PresetManager",
			"Preset type mismatch: preset is '%s', node is '%s'. Applying matching params only." % [
				stored_type, node_type])

	var params_dict: Dictionary = data.get("params", {})
	var applied := 0
	for p_name in params_dict:
		if p_name.begins_with("spare:"):
			var sp_name: String = p_name.substr(6)
			var sp: GNParameter = node.spare_parameters.get(sp_name, null)
			if sp != null:
				sp.from_dict(params_dict[p_name])
				applied += 1
		else:
			var param: GNParameter = node.parameters.get(p_name, null)
			if param == null:
				continue
			param.from_dict(params_dict[p_name])
			applied += 1

	# Mark node dirty so it re-cooks
	node.mark_dirty()
	GNLogger.info("PresetManager", "Loaded preset '%s' → '%s' (%d params)" % [
		data.get("preset_name", "?"), node.id, applied])
	return applied


## Deletes a user preset file. Returns true on success.
## Factory presets cannot be deleted.
static func delete_preset(file_path: String) -> bool:
	# Safety: refuse to delete factory presets
	if file_path.begins_with("res://"):
		GNLogger.warn("PresetManager", "Cannot delete factory preset: %s" % file_path)
		return false
	if not FileAccess.file_exists(file_path):
		return false
	var err := DirAccess.remove_absolute(file_path)
	if err != OK:
		GNLogger.error("PresetManager", "Failed to delete preset: %s (error %d)" % [
			file_path, err])
		return false
	GNLogger.info("PresetManager", "Deleted preset: %s" % file_path)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Reset to Defaults
# ═══════════════════════════════════════════════════════════════════════════════

## Resets all parameters on [param node] to their default (initial) values.
## Constructs a fresh instance of the same operator type, then copies its
## default parameter values onto the existing node.
## Returns the number of parameters reset.
static func reset_to_defaults(node: GNNode) -> int:
	if node == null:
		return 0
	var operator_type: String = node.get_script().get_global_name()

	# Get the script resource to construct a temporary default instance
	var script_res: GDScript = node.get_script() as GDScript
	if script_res == null:
		GNLogger.error("PresetManager", "Cannot resolve script for '%s'" % node.id)
		return 0

	# Construct a temporary instance to capture default param values
	var temp_node: GNNode = script_res.new() as GNNode
	if temp_node == null:
		GNLogger.error("PresetManager", "Cannot instantiate '%s' for defaults" % operator_type)
		return 0
	temp_node.initialize("__temp_defaults__")

	var reset_count := 0
	for p_name in temp_node.parameters:
		var src_param: GNParameter = temp_node.parameters[p_name]
		var dst_param: GNParameter = node.parameters.get(p_name, null)
		if dst_param == null:
			continue
		# Reset to constant mode with default value
		dst_param.mode = GNParameter.Mode.CONSTANT
		dst_param.expression = ""
		dst_param.set_value(src_param.value)
		# Clear per-component expressions
		for i in range(dst_param.component_modes.size()):
			dst_param.component_modes[i] = GNParameter.Mode.CONSTANT
		reset_count += 1

	# Cleanup temporary node
	temp_node.queue_free()

	node.mark_dirty()
	GNLogger.info("PresetManager", "Reset %d parameters to defaults on '%s'" % [
		reset_count, node.id])
	return reset_count


# ═══════════════════════════════════════════════════════════════════════════════
# Internal Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Scans a directory for .json preset files.
static func _scan_preset_dir(dir_path: String, is_factory: bool, result: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var preset_name := fname.get_basename()
			result.append({
				"name": preset_name,
				"path": dir_path + "/" + fname,
				"is_factory": is_factory,
			})
		fname = dir.get_next()
	dir.list_dir_end()


## Sanitizes a string for use as a filename (removes special chars).
static func _sanitize_filename(input: String) -> String:
	var safe := input.strip_edges()
	# Replace problematic chars with underscores
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_\\-\\. ]")
	safe = regex.sub(safe, "_", true)
	# Collapse multiple underscores
	regex.compile("_+")
	safe = regex.sub(safe, "_", true)
	if safe.is_empty():
		safe = "unnamed"
	return safe
