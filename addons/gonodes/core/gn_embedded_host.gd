class_name GNEmbeddedHost
extends Node
## GDScript singleton for embedded (LibGodot) mode.
##
## Registered as an Engine singleton in _ready().  The C API (gonodes_host.cpp)
## communicates with this node via environment variables during each Godot
## iteration.  This replaces player_main.gd for headless embedded operation.
##
## Responsibilities:
##   • Load / unload / reload .gnpatch files
##   • Drive the GNCookEngine each frame
##   • Flush input injections from the host into bridge operators
##   • Export output data from bridge operators back to the host
##   • Provide introspection JSON for the C API
##   • File-watch and auto-reload support

const SINGLETON_NAME := "GNEmbeddedHost"

# ─── Core State ────────────────────────────────────────────────────────────────

var network: GNNetwork = null
var cook_engine: GNCookEngine = null

## Whether a patch is currently loaded and cooking.
var patch_loaded: bool = false

## Absolute path to the loaded .gnpatch file.
var patch_path: String = ""

## Project directory (derived from patch path).
var _project: GNProjectManager = GNProjectManager.new()

# ─── Host I/O Registries ──────────────────────────────────────────────────────

## Texture inputs from the host: node_id → { handle: int, width: int, height: int, format: int }
var _texture_inputs: Dictionary = {}

## CHOP inputs from the host: node_id → { channel_name: PackedFloat32Array }
var _chop_inputs: Dictionary = {}

## DAT inputs from the host: node_id → String (JSON)
var _dat_inputs: Dictionary = {}

## Parameter overrides from the host: "node_id:param_name" → String (JSON value)
var _param_overrides: Dictionary = {}

## Texture outputs for the host: node_id → { handle: int, width: int, height: int }
var _texture_outputs: Dictionary = {}

## CHOP outputs for the host: node_id → { channel_name: PackedFloat32Array }
var _chop_outputs: Dictionary = {}

## DAT outputs for the host: node_id → String (JSON)
var _dat_outputs: Dictionary = {}

# ─── Hot Reload ────────────────────────────────────────────────────────────────

## File watch timer for auto-reload.
var _reload_timer: float = 0.0
var _reload_interval: float = 0.5
var _auto_reload: bool = false
var _last_mtime: int = 0

## Saved runtime state for stateful reload.
var _saved_chop_values: Dictionary = {}
var _saved_timer_positions: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Register as a singleton so the C API can find us.
	Engine.register_singleton(SINGLETON_NAME, self)

	# Initialize extension registry for operator discovery.
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()

	GNLogger.info("EmbeddedHost", "GNEmbeddedHost ready — singleton registered")


func _process(delta: float) -> void:
	# Check for commands from the C API (env var protocol).
	_poll_commands()

	# Flush host input injections into bridge operators.
	_flush_inputs()

	# Cook one frame.
	if cook_engine != null and cook_engine.cooking_enabled:
		cook_engine.current_delta = delta
		cook_engine.elapsed_time += delta
		cook_engine.frame_count += 1

	# Collect outputs from bridge operators.
	_collect_outputs()

	# Publish introspection data.
	_publish_introspection()


func _exit_tree() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		Engine.unregister_singleton(SINGLETON_NAME)


# ═══════════════════════════════════════════════════════════════════════════════
# Patch Management
# ═══════════════════════════════════════════════════════════════════════════════

## Load a .gnpatch file and boot the cook engine.
func load_patch(path: String) -> int:
	if patch_loaded:
		unload_patch()

	GNLogger.info("EmbeddedHost", "Loading patch: %s" % path)

	# Read and parse the .gnpatch file.
	if not FileAccess.file_exists(path):
		GNLogger.error("EmbeddedHost", "Patch file not found: %s" % path)
		return -2  # GONODES_ERR_FILE_NOT_FOUND

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GNLogger.error("EmbeddedHost", "Cannot open patch: %s" % path)
		return -2

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		GNLogger.error("EmbeddedHost", "JSON parse error in patch: %s" % json.get_error_message())
		return -3  # GONODES_ERR_PARSE_ERROR

	var data: Dictionary = json.data
	if not data is Dictionary:
		GNLogger.error("EmbeddedHost", "Patch root is not a Dictionary")
		return -3

	# Build the network.
	network = GNNetwork.new()
	network.from_dict(data)

	# Set project directory.
	patch_path = path
	var dir := path.get_base_dir()
	_project.project_dir = dir

	# Create and configure the cook engine.
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	add_child(cook_engine)
	cook_engine.network = network
	cook_engine.project_dir = dir
	cook_engine.editor_mode = false

	# Adopt network nodes into the scene tree.
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		cook_engine.add_child(node)

	patch_loaded = true
	_last_mtime = _get_file_mtime(path)

	GNLogger.info("EmbeddedHost", "Patch loaded: %d nodes, %d connections" % [
		network.nodes.size(), network.connections.size()])
	return 0


## Unload the current patch and tear down the cook engine.
func unload_patch() -> void:
	if not patch_loaded:
		return

	GNLogger.info("EmbeddedHost", "Unloading patch")

	# Remove and free all operator nodes.
	if cook_engine != null:
		cook_engine.cooking_enabled = false
		cook_engine.queue_free()
		cook_engine = null

	network = null
	patch_loaded = false
	patch_path = ""

	# Clear I/O registries.
	_texture_inputs.clear()
	_chop_inputs.clear()
	_dat_inputs.clear()
	_param_overrides.clear()
	_texture_outputs.clear()
	_chop_outputs.clear()
	_dat_outputs.clear()


## Reload the current patch, preserving runtime state.
func reload_patch() -> int:
	if not patch_loaded or patch_path.is_empty():
		return -8  # GONODES_ERR_NOT_LOADED

	GNLogger.info("EmbeddedHost", "Reloading patch (stateful)")

	# Save runtime state from CHOP nodes.
	_save_runtime_state()

	# Reload.
	var path := patch_path
	unload_patch()
	var result := load_patch(path)

	if result == 0:
		# Restore runtime state.
		_restore_runtime_state()

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Host I/O
# ═══════════════════════════════════════════════════════════════════════════════

## Register a texture from the host for a HostInTOP node.
func set_texture_input(node_id: String, handle: int, width: int, height: int, format: int) -> void:
	_texture_inputs[node_id] = {
		"handle": handle,
		"width": width,
		"height": height,
		"format": format,
	}


## Register CHOP channel data from the host for a HostInCHOP node.
func set_chop_input(node_id: String, channel_name: String, samples: PackedFloat32Array) -> void:
	if not _chop_inputs.has(node_id):
		_chop_inputs[node_id] = {}
	_chop_inputs[node_id][channel_name] = samples


## Register DAT table data from the host for a HostInDAT node.
func set_dat_input(node_id: String, json_data: String) -> void:
	_dat_inputs[node_id] = json_data


## Set a parameter override from the host.
func set_param_override(node_id: String, param_name: String, value_json: String) -> void:
	var key := "%s:%s" % [node_id, param_name]
	_param_overrides[key] = value_json


## Get a texture output handle for the host.
func get_texture_output(node_id: String) -> Dictionary:
	return _texture_outputs.get(node_id, {})


## Get CHOP channel data for the host.
func get_chop_output(node_id: String) -> Dictionary:
	return _chop_outputs.get(node_id, {})


## Get DAT table data for the host.
func get_dat_output(node_id: String) -> String:
	return _dat_outputs.get(node_id, "")


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Command Polling
# ═══════════════════════════════════════════════════════════════════════════════

## Poll environment variables for commands from the C API.
func _poll_commands() -> void:
	# Load patch command.
	var load_path := OS.get_environment("GONODES_LOAD_PATCH")
	if not load_path.is_empty():
		OS.set_environment("GONODES_LOAD_PATCH", "")
		load_patch(load_path)

	# Unload command.
	if OS.get_environment("GONODES_UNLOAD_PATCH") == "1":
		OS.set_environment("GONODES_UNLOAD_PATCH", "")
		unload_patch()

	# Reload command.
	if OS.get_environment("GONODES_RELOAD_PATCH") == "1":
		OS.set_environment("GONODES_RELOAD_PATCH", "")
		reload_patch()


## Flush host input data into bridge operator nodes.
func _flush_inputs() -> void:
	if not patch_loaded or network == null:
		return

	# Flush texture inputs to HostInTOP nodes.
	for node_id in _texture_inputs:
		if network.nodes.has(node_id):
			var node: GNNode = network.nodes[node_id]
			if node.has_method("_set_host_texture"):
				var data: Dictionary = _texture_inputs[node_id]
				node.call("_set_host_texture", data.handle, data.width, data.height, data.format)

	# Flush CHOP inputs to HostInCHOP nodes.
	for node_id in _chop_inputs:
		if network.nodes.has(node_id):
			var node: GNNode = network.nodes[node_id]
			if node.has_method("_set_host_channels"):
				node.call("_set_host_channels", _chop_inputs[node_id])

	# Flush DAT inputs to HostInDAT nodes.
	for node_id in _dat_inputs:
		if network.nodes.has(node_id):
			var node: GNNode = network.nodes[node_id]
			if node.has_method("_set_host_table"):
				node.call("_set_host_table", _dat_inputs[node_id])

	# Apply parameter overrides.
	for key in _param_overrides:
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2:
			var node_id := parts[0]
			var param_name := parts[1]
			if network.nodes.has(node_id):
				var node: GNNode = network.nodes[node_id]
				var json := JSON.new()
				if json.parse(_param_overrides[key]) == OK:
					node.set_param_value(param_name, json.data)
					node.mark_dirty()


## Collect output data from bridge operators for the host.
func _collect_outputs() -> void:
	if not patch_loaded or network == null:
		return

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]

		# HostOutTOP — texture output
		if node.has_method("_get_host_texture"):
			var tex_info: Dictionary = node.call("_get_host_texture")
			if not tex_info.is_empty():
				_texture_outputs[node_id] = tex_info

		# HostOutCHOP — channel output
		if node.has_method("_get_host_channels"):
			var ch_data: Dictionary = node.call("_get_host_channels")
			if not ch_data.is_empty():
				_chop_outputs[node_id] = ch_data

		# HostOutDAT — table output
		if node.has_method("_get_host_table"):
			var table_json: String = node.call("_get_host_table")
			if not table_json.is_empty():
				_dat_outputs[node_id] = table_json


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Introspection Publishing
# ═══════════════════════════════════════════════════════════════════════════════

## Write introspection JSON to env vars for the C API to read.
func _publish_introspection() -> void:
	if not patch_loaded or network == null:
		return

	# List all nodes.
	var nodes_arr: Array = []
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		nodes_arr.append({
			"id": node.id,
			"type": node.node_type,
			"family": GNFamily.get_family_name(node.family),
		})
	OS.set_environment("GONODES_LIST_NODES", JSON.stringify(nodes_arr))

	# List all connections.
	var conns_arr: Array = []
	for conn in network.connections:
		conns_arr.append({
			"from": conn.from_node,
			"from_port": conn.from_port,
			"to": conn.to_node,
			"to_port": conn.to_port,
		})
	OS.set_environment("GONODES_LIST_CONNECTIONS", JSON.stringify(conns_arr))

	# Per-node info and parameters (only for nodes queried by C API).
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]

		# Node info.
		var inputs_arr: Array = []
		for p in node.input_ports:
			inputs_arr.append({"name": p.port_name, "family": GNFamily.get_family_name(p.family)})
		var outputs_arr: Array = []
		for p in node.output_ports:
			outputs_arr.append({"name": p.port_name, "family": GNFamily.get_family_name(p.family)})
		var params_arr: Array = []
		for pname in node.parameters:
			var param: GNParameter = node.parameters[pname]
			params_arr.append({
				"name": pname,
				"type": param.type_name(),
				"value": param.value,
			})

		var info := {
			"id": node.id,
			"type": node.node_type,
			"family": GNFamily.get_family_name(node.family),
			"inputs": inputs_arr,
			"outputs": outputs_arr,
			"parameters": params_arr,
			"cook_time_ms": node.cook_time_ms,
			"active": node.is_active,
		}
		OS.set_environment("GONODES_NODE_INFO_%s" % node_id, JSON.stringify(info))
		OS.set_environment("GONODES_LIST_PARAMS_%s" % node_id, JSON.stringify(params_arr))

		# Publish output parameter values for C API get_parameter().
		for pname in node.parameters:
			var param: GNParameter = node.parameters[pname]
			OS.set_environment(
				"GONODES_OUT_PARAM_%s_%s" % [node_id, pname],
				JSON.stringify(param.value))

	# Publish cook stats.
	if cook_engine != null:
		OS.set_environment("GONODES_COOK_TIME_MS", "%.3f" % cook_engine.frame_cook_time_ms)
		OS.set_environment("GONODES_COOK_COUNT", str(cook_engine.frame_count))


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Stateful Reload
# ═══════════════════════════════════════════════════════════════════════════════

## Save CHOP channel values and timer positions for stateful reload.
func _save_runtime_state() -> void:
	_saved_chop_values.clear()
	_saved_timer_positions.clear()

	if network == null:
		return

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]

		# Save CHOP cached values.
		if node.cached_output is GNChannelData:
			var ch: GNChannelData = node.cached_output as GNChannelData
			var saved: Dictionary = {}
			for ch_name in ch.channels:
				saved[ch_name] = ch.channels[ch_name].duplicate()
			_saved_chop_values[node_id] = saved

		# Save timer positions.
		if node.node_type == "timer" and node.has_method("get_elapsed"):
			_saved_timer_positions[node_id] = node.call("get_elapsed")


## Restore CHOP channel values and timer positions after reload.
func _restore_runtime_state() -> void:
	if network == null:
		return

	for node_id in _saved_chop_values:
		if network.nodes.has(node_id):
			var node: GNNode = network.nodes[node_id]
			if node.cached_output is GNChannelData:
				var ch: GNChannelData = node.cached_output as GNChannelData
				var saved: Dictionary = _saved_chop_values[node_id]
				for ch_name in saved:
					ch.channels[ch_name] = saved[ch_name]

	for node_id in _saved_timer_positions:
		if network.nodes.has(node_id):
			var node: GNNode = network.nodes[node_id]
			if node.has_method("set_elapsed"):
				node.call("set_elapsed", _saved_timer_positions[node_id])

	_saved_chop_values.clear()
	_saved_timer_positions.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Utilities
# ═══════════════════════════════════════════════════════════════════════════════

func _get_file_mtime(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_modified_time(path)
