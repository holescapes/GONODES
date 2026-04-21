class_name GNEmbeddedHost
extends Node
## GDScript singleton for embedded (LibGodot) mode — v2.5 multi-patch.
##
## Registered as an Engine singleton in _ready().  The C bootstrap layer
## writes the gonodes_instance_s pointer to GONODES_BRIDGE_INSTANCE_PTR
## (one-time init), and this singleton passes it to GNHostBridge.
##
## All per-frame IPC uses GNHostBridge direct pointer access:
##   - Inbound:  GNHostBridge.drain_commands() reads the C ring buffer
##   - Outbound: GNHostBridge.set_*_output() writes to C response slots
##
## CPU data injection (pixels, geometry, volume, particles, CHOP, DAT)
## passes pointer addresses through the command queue.  This singleton
## reads the pointer addresses from commands and calls GNHostBridge
## (GDExtension) static methods to memcpy data from C memory into
## Godot types.  No temp files, no serialization, no env vars per frame.

const SINGLETON_NAME := "GNEmbeddedHost"

# ─── Patch State ───────────────────────────────────────────────────────────────

## Per-patch state container.
class PatchState:
	var id: int = 0
	var path: String = ""
	var network: GNNetwork = null
	var cook_engine: GNCookEngine = null
	var loaded: bool = false

	# Host I/O registries (per-patch).
	var texture_inputs: Dictionary = {}
	var chop_inputs: Dictionary = {}
	var dat_inputs: Dictionary = {}
	var param_overrides: Dictionary = {}
	var texture_outputs: Dictionary = {}
	var chop_outputs: Dictionary = {}
	var dat_outputs: Dictionary = {}

	# Stateful reload.
	var saved_chop_values: Dictionary = {}
	var saved_timer_positions: Dictionary = {}


## All loaded patches, keyed by patch ID (int).
var patches: Dictionary = {}

## Project manager (shared across patches).
var _project: GNProjectManager = GNProjectManager.new()

## Cached GNHostBridge instance for dynamic dispatch (null if native lib missing).
var _bridge: Object = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	Engine.register_singleton(SINGLETON_NAME, self)
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()

	# Initialize the bridge if the native library is available.
	if ClassDB.class_exists(&"GNHostBridge"):
		_bridge = ClassDB.instantiate(&"GNHostBridge")
		var ptr_str := OS.get_environment("GONODES_BRIDGE_INSTANCE_PTR")
		if not ptr_str.is_empty():
			_bridge.call(&"set_instance", int(ptr_str))
	else:
		GNLogger.info("EmbeddedHost", "GNHostBridge not available — embedded mode disabled")

	GNLogger.info("EmbeddedHost", "GNEmbeddedHost v2.5 ready — multi-patch mode")


func _process(delta: float) -> void:
	_drain_and_dispatch()

	for patch_id in patches:
		var ps: PatchState = patches[patch_id]
		if not ps.loaded:
			continue

		_flush_inputs(ps)

		if ps.cook_engine != null and ps.cook_engine.cooking_enabled:
			ps.cook_engine.current_delta = delta
			ps.cook_engine.elapsed_time += delta
			ps.cook_engine.frame_count += 1

		_collect_outputs(ps)
		_publish_to_bridge(ps)


func _exit_tree() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		Engine.unregister_singleton(SINGLETON_NAME)


# ═══════════════════════════════════════════════════════════════════════════════
# Patch Management
# ═══════════════════════════════════════════════════════════════════════════════

## Load a .gnpatch file into a new patch slot.
func load_patch(patch_id: int, path: String) -> int:
	GNLogger.info("EmbeddedHost", "Loading patch #%d: %s" % [patch_id, path])

	if not FileAccess.file_exists(path):
		GNLogger.error("EmbeddedHost", "Patch file not found: %s" % path)
		return -2

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GNLogger.error("EmbeddedHost", "Cannot open patch: %s" % path)
		return -2

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		GNLogger.error("EmbeddedHost", "JSON parse error: %s" % json.get_error_message())
		return -3

	var data: Dictionary = json.data
	if not data is Dictionary:
		GNLogger.error("EmbeddedHost", "Patch root is not a Dictionary")
		return -3

	# Create patch state.
	var ps := PatchState.new()
	ps.id = patch_id
	ps.path = path

	# Build the network.
	ps.network = GNNetwork.new()
	ps.network.from_dict(data)

	# Set project directory.
	var dir := path.get_base_dir()
	_project.project_dir = dir

	# Create and configure the cook engine.
	ps.cook_engine = GNCookEngine.new()
	ps.cook_engine.name = "CookEngine_P%d" % patch_id
	add_child(ps.cook_engine)
	ps.cook_engine.network = ps.network
	ps.cook_engine.project_dir = dir
	ps.cook_engine.editor_mode = false

	# Adopt network nodes into the scene tree.
	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]
		ps.cook_engine.add_child(node)

	ps.loaded = true
	patches[patch_id] = ps

	GNLogger.info("EmbeddedHost", "Patch #%d loaded: %d nodes, %d connections" % [
		patch_id, ps.network.nodes.size(), ps.network.connections.size()])
	return 0


## Unload a specific patch.
func unload_patch(patch_id: int) -> void:
	if not patches.has(patch_id):
		return

	var ps: PatchState = patches[patch_id]
	GNLogger.info("EmbeddedHost", "Unloading patch #%d" % patch_id)

	if ps.cook_engine != null:
		ps.cook_engine.cooking_enabled = false
		ps.cook_engine.queue_free()
		ps.cook_engine = null

	ps.network = null
	ps.loaded = false
	patches.erase(patch_id)


## Reload a specific patch, preserving runtime state.
func reload_patch(patch_id: int) -> int:
	if not patches.has(patch_id):
		return -8

	var ps: PatchState = patches[patch_id]
	if not ps.loaded or ps.path.is_empty():
		return -8

	GNLogger.info("EmbeddedHost", "Reloading patch #%d (stateful)" % patch_id)

	_save_runtime_state(ps)
	var path := ps.path
	unload_patch(patch_id)
	var result := load_patch(patch_id, path)

	if result == 0 and patches.has(patch_id):
		_restore_runtime_state(patches[patch_id])

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Host I/O (called by C API via singleton methods)
# ═══════════════════════════════════════════════════════════════════════════════

func set_texture_input(patch_id: int, node_id: String, handle: int,
                       width: int, height: int, format: int) -> void:
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	ps.texture_inputs[node_id] = {
		"handle": handle, "width": width, "height": height, "format": format,
	}


func set_chop_input(patch_id: int, node_id: String, channel_name: String,
                    samples: PackedFloat32Array) -> void:
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	if not ps.chop_inputs.has(node_id):
		ps.chop_inputs[node_id] = {}
	ps.chop_inputs[node_id][channel_name] = samples


func set_dat_input(patch_id: int, node_id: String, json_data: String) -> void:
	if not patches.has(patch_id):
		return
	patches[patch_id].dat_inputs[node_id] = json_data


func set_param_override(patch_id: int, node_id: String, param_name: String,
                        value_json: String) -> void:
	if not patches.has(patch_id):
		return
	var key := "%s:%s" % [node_id, param_name]
	patches[patch_id].param_overrides[key] = value_json


func get_texture_output(patch_id: int, node_id: String) -> Dictionary:
	if not patches.has(patch_id):
		return {}
	return patches[patch_id].texture_outputs.get(node_id, {})


func get_chop_output(patch_id: int, node_id: String) -> Dictionary:
	if not patches.has(patch_id):
		return {}
	return patches[patch_id].chop_outputs.get(node_id, {})


func get_dat_output(patch_id: int, node_id: String) -> String:
	if not patches.has(patch_id):
		return ""
	return patches[patch_id].dat_outputs.get(node_id, "")


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Command Dispatch (via GNHostBridge direct pointer access)
# ═══════════════════════════════════════════════════════════════════════════════

## Command type constants (must match gn_cmd_type in gn_bridge_structs.h).
const CMD_LOAD_PATCH := 1
const CMD_UNLOAD_PATCH := 2
const CMD_RELOAD_PATCH := 3
const CMD_SET_TEXTURE := 4
const CMD_SET_CHOP := 5
const CMD_SET_TABLE := 6
const CMD_SET_PARAM := 7
const CMD_SET_PIXELS := 8
const CMD_SET_GEOMETRY := 9
const CMD_SET_VOLUME := 10
const CMD_SET_PARTICLES := 11
const CMD_SET_TRANSPORT := 12
const CMD_TRANSPORT_SEEK := 13
const CMD_TRANSPORT_SPEED := 14
const CMD_CREATE_NODE := 15
const CMD_DELETE_NODE := 16
const CMD_CONNECT := 17
const CMD_DISCONNECT := 18
const CMD_FIRE_EVENT := 19
const CMD_MIDI_EVENT := 20
const CMD_OSC_MESSAGE := 21
const CMD_SET_RESOLUTION := 22

## Drain the C command queue via GNHostBridge and dispatch each command.
func _drain_and_dispatch() -> void:
	if _bridge == null:
		return
	var commands: Array = _bridge.call(&"drain_commands")
	for cmd: Dictionary in commands:
		var type: int = cmd.get("type", 0)
		var patch_id: int = cmd.get("patch_id", 0)
		var key: String = cmd.get("key", "")
		var key2: String = cmd.get("key2", "")
		var data: String = cmd.get("data", "")
		var ival: Array = cmd.get("ival", [0, 0, 0, 0])
		var dval: float = cmd.get("dval", 0.0)
		var uval: int = cmd.get("uval", 0)

		match type:
			CMD_LOAD_PATCH:
				load_patch(patch_id, data)

			CMD_UNLOAD_PATCH:
				unload_patch(patch_id)

			CMD_RELOAD_PATCH:
				reload_patch(patch_id)

			CMD_SET_TRANSPORT:
				if patches.has(patch_id):
					var ps: PatchState = patches[patch_id]
					if ps.cook_engine != null:
						ps.cook_engine.cooking_enabled = (int(ival[0]) == 1)

			CMD_TRANSPORT_SPEED:
				pass  # Speed is stored C-side; no GDScript action needed.

			CMD_TRANSPORT_SEEK:
				if patches.has(patch_id):
					var ps: PatchState = patches[patch_id]
					if ps.cook_engine != null:
						ps.cook_engine.elapsed_time = dval

			CMD_SET_TEXTURE:
				set_texture_input(patch_id, key, uval,
					int(ival[0]), int(ival[1]), int(ival[2]))

			CMD_SET_CHOP:
				# data = "addr", ival[0] = sample_count
				var ch_addr := int(data)
				var ch_count := int(ival[0])
				if ch_addr != 0 and ch_count > 0:
					var samples: PackedFloat32Array = _bridge.call(&"read_float32", ch_addr, ch_count)
					set_chop_input(patch_id, key, key2, samples)

			CMD_SET_TABLE:
				# data = "addr,len"
				var dat_parts := data.split(",")
				if dat_parts.size() >= 2:
					var dat_addr := int(dat_parts[0])
					var dat_len := int(dat_parts[1])
					if dat_addr != 0 and dat_len > 0:
						var raw_bytes: PackedByteArray = _bridge.call(&"read_bytes", dat_addr, dat_len)
						var json_str: String = raw_bytes.get_string_from_utf8()
						set_dat_input(patch_id, key, json_str)

			CMD_SET_PARAM:
				set_param_override(patch_id, key, key2, data)

			CMD_SET_PIXELS:
				# data = "addr", ival = [w, h, fmt, ...]
				_handle_pixel_input_cmd(patch_id, key, data,
					int(ival[0]), int(ival[1]), int(ival[2]))

			CMD_SET_GEOMETRY:
				# data = "pos_addr,nrm_addr,uv_addr,col_addr,idx_addr",
				# ival = [vtx_count, idx_count, ...]
				_handle_geometry_input_cmd(patch_id, key, data,
					int(ival[0]), int(ival[1]))

			CMD_SET_VOLUME:
				# data = "addr", ival = [w, h, d, ch], key2 = field_name
				_handle_volume_input_cmd(patch_id, key, data,
					int(ival[0]), int(ival[1]), int(ival[2]), int(ival[3]), key2)

			CMD_SET_PARTICLES:
				# data = "pos_addr,vel_addr,col_addr,age_addr",
				# ival = [count, ...]
				_handle_particle_input_cmd(patch_id, key, data, int(ival[0]))

			CMD_CREATE_NODE:
				if patches.has(patch_id):
					_create_node_in_patch(patches[patch_id], key, data)

			CMD_DELETE_NODE:
				if patches.has(patch_id):
					_delete_node_in_patch(patches[patch_id], key)

			CMD_CONNECT:
				if patches.has(patch_id):
					_connect_in_patch(patches[patch_id], key, int(ival[0]),
					                  key2, int(ival[1]))

			CMD_DISCONNECT:
				if patches.has(patch_id):
					_disconnect_in_patch(patches[patch_id], key, int(ival[0]),
					                     key2, int(ival[1]))

			CMD_FIRE_EVENT:
				if patches.has(patch_id):
					var ps: PatchState = patches[patch_id]
					if ps.network and ps.network.nodes.has(key):
						var node: GNNode = ps.network.nodes[key]
						if node.has_method("_on_host_event"):
							node.call("_on_host_event", data)

			CMD_MIDI_EVENT:
				if patches.has(patch_id):
					_inject_midi_event(patches[patch_id], data)

			CMD_OSC_MESSAGE:
				if patches.has(patch_id):
					_inject_osc_message(patches[patch_id],
						"%s|%s" % [key, data])

			CMD_SET_RESOLUTION:
				if patches.has(patch_id):
					var ps: PatchState = patches[patch_id]
					if ps.network and ps.network.nodes.has(key):
						var node: GNNode = ps.network.nodes[key]
						var res := Vector2i(int(ival[0]), int(ival[1]))
						if node.has_method("set_resolution_override"):
							node.call("set_resolution_override", res)
						elif "resolution" in node.parameters:
							node.set_param_value("resolution", res)
							node.mark_dirty()


## Flush host input data into bridge operator nodes (per-patch).
func _flush_inputs(ps: PatchState) -> void:
	if not ps.loaded or ps.network == null:
		return

	for node_id in ps.texture_inputs:
		if ps.network.nodes.has(node_id):
			var node: GNNode = ps.network.nodes[node_id]
			if node.has_method("_set_host_texture"):
				var data: Dictionary = ps.texture_inputs[node_id]
				node.call("_set_host_texture", data.handle, data.width,
				          data.height, data.format)

	for node_id in ps.chop_inputs:
		if ps.network.nodes.has(node_id):
			var node: GNNode = ps.network.nodes[node_id]
			if node.has_method("_set_host_channels"):
				node.call("_set_host_channels", ps.chop_inputs[node_id])

	for node_id in ps.dat_inputs:
		if ps.network.nodes.has(node_id):
			var node: GNNode = ps.network.nodes[node_id]
			if node.has_method("_set_host_table"):
				node.call("_set_host_table", ps.dat_inputs[node_id])

	for key in ps.param_overrides:
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2:
			var node_id := parts[0]
			var param_name := parts[1]
			if ps.network.nodes.has(node_id):
				var node: GNNode = ps.network.nodes[node_id]
				var json := JSON.new()
				if json.parse(ps.param_overrides[key]) == OK:
					node.set_param_value(param_name, json.data)
					node.mark_dirty()


## Collect output data from bridge operators (per-patch).
func _collect_outputs(ps: PatchState) -> void:
	if not ps.loaded or ps.network == null:
		return

	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]

		if node.has_method("_get_host_texture"):
			var tex_info: Dictionary = node.call("_get_host_texture")
			if not tex_info.is_empty():
				ps.texture_outputs[node_id] = tex_info

		if node.has_method("_get_host_channels"):
			var ch_data: Dictionary = node.call("_get_host_channels")
			if not ch_data.is_empty():
				ps.chop_outputs[node_id] = ch_data

		if node.has_method("_get_host_table"):
			var table_json: String = node.call("_get_host_table")
			if not table_json.is_empty():
				ps.dat_outputs[node_id] = table_json


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Publish to Bridge (direct pointer writes via GNHostBridge)
# ═══════════════════════════════════════════════════════════════════════════════

func _publish_to_bridge(ps: PatchState) -> void:
	if _bridge == null or not ps.loaded or ps.network == null:
		return

	var pid := ps.id

	# List all nodes.
	var nodes_arr: Array = []
	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]
		nodes_arr.append({
			"id": node.id,
			"type": node.node_type,
			"family": GNFamily.get_family_name(node.family),
		})
	_bridge.call(&"set_nodes_json", pid, JSON.stringify(nodes_arr))

	# List all connections.
	var conns_arr: Array = []
	for conn in ps.network.connections:
		conns_arr.append({
			"from": conn.from_node,
			"from_port": conn.from_port,
			"to": conn.to_node,
			"to_port": conn.to_port,
		})
	_bridge.call(&"set_connections_json", pid, JSON.stringify(conns_arr))

	# Per-node info and parameters.
	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]

		var inputs_arr: Array = []
		for p in node.input_ports:
			inputs_arr.append({
				"name": p.port_name,
				"family": GNFamily.get_family_name(p.family),
			})
		var outputs_arr: Array = []
		for p in node.output_ports:
			outputs_arr.append({
				"name": p.port_name,
				"family": GNFamily.get_family_name(p.family),
			})
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
		_bridge.call(&"set_node_info_json", pid, node_id, JSON.stringify(info))
		_bridge.call(&"set_params_json", pid, node_id, JSON.stringify(params_arr))

		for pname in node.parameters:
			var param: GNParameter = node.parameters[pname]
			_bridge.call(&"set_param_output", pid, node_id, pname,
				JSON.stringify(param.value))

	# Publish cook stats.
	if ps.cook_engine != null:
		_bridge.call(&"set_stats", pid, ps.cook_engine.frame_cook_time_ms,
		             ps.cook_engine.frame_count)

	# Publish host I/O manifest.
	_bridge.call(&"set_host_io_json", pid, _get_host_io(ps))

	# Publish texture outputs.
	for node_id in ps.texture_outputs:
		var tex: Dictionary = ps.texture_outputs[node_id]
		_bridge.call(&"set_tex_output", pid, node_id,
			int(tex.get("handle", 0)),
			int(tex.get("width", 0)),
			int(tex.get("height", 0)),
			int(tex.get("format", 0)),
			int(tex.get("channels", 4)),
			int(tex.get("graphics_api", 0)))

	# Publish CHOP outputs.
	for node_id in ps.chop_outputs:
		var ch_data: Dictionary = ps.chop_outputs[node_id]
		for ch_name in ch_data:
			var samples: PackedFloat32Array = ch_data[ch_name]
			_bridge.call(&"set_chop_output", pid, node_id, ch_name, samples)

	# Publish DAT outputs.
	for node_id in ps.dat_outputs:
		_bridge.call(&"set_dat_output", pid, node_id, ps.dat_outputs[node_id])

	# Publish transport time.
	if ps.cook_engine != null:
		_bridge.call(&"set_transport_time", pid, ps.cook_engine.elapsed_time)


# ═══════════════════════════════════════════════════════════════════════════════
# Internal: Stateful Reload
# ═══════════════════════════════════════════════════════════════════════════════

func _save_runtime_state(ps: PatchState) -> void:
	ps.saved_chop_values.clear()
	ps.saved_timer_positions.clear()

	if ps.network == null:
		return

	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]

		if node.cached_output != null and node.cached_output.valid:
			var state: Dictionary = node.cached_output.save_state()
			if not state.is_empty():
				ps.saved_chop_values[node_id] = state

		if node.node_type == "timer" and node.has_method("get_elapsed"):
			ps.saved_timer_positions[node_id] = node.call("get_elapsed")


func _restore_runtime_state(ps: PatchState) -> void:
	if ps.network == null:
		return

	for node_id in ps.saved_chop_values:
		if ps.network.nodes.has(node_id):
			var node: GNNode = ps.network.nodes[node_id]
			if node.cached_output != null:
				node.cached_output.restore_state(ps.saved_chop_values[node_id])

	for node_id in ps.saved_timer_positions:
		if ps.network.nodes.has(node_id):
			var node: GNNode = ps.network.nodes[node_id]
			if node.has_method("set_elapsed"):
				node.call("set_elapsed", ps.saved_timer_positions[node_id])

	ps.saved_chop_values.clear()
	ps.saved_timer_positions.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Host I/O Manifest
# ═══════════════════════════════════════════════════════════════════════════════

func _get_host_io(ps: PatchState) -> String:
	if not ps.loaded or ps.network == null:
		return "{}"
	return ps.network.get_host_io_json()


# ═══════════════════════════════════════════════════════════════════════════════
# Utilities
# ═══════════════════════════════════════════════════════════════════════════════

func _get_file_mtime(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_modified_time(path)


## Delete a node from a loaded patch's network.
func _delete_node_in_patch(ps: PatchState, node_id: String) -> void:
	if ps.network == null or not ps.network.nodes.has(node_id):
		return
	var node: GNNode = ps.network.nodes[node_id]
	ps.network.nodes.erase(node_id)
	ps.network.connections = ps.network.connections.filter(
		func(c: GNConnection) -> bool:
			return c.from_node != node_id and c.to_node != node_id)
	if node.get_parent() != null:
		node.queue_free()


## Connect two nodes in a loaded patch.
func _connect_in_patch(ps: PatchState, from_node: String, from_port: int,
                       to_node: String, to_port: int) -> void:
	if ps.network == null:
		return
	var conn := GNConnection.new()
	conn.from_node = from_node
	conn.from_port = from_port
	conn.to_node = to_node
	conn.to_port = to_port
	ps.network.connections.append(conn)
	if ps.network.nodes.has(to_node):
		ps.network.nodes[to_node].mark_dirty()


## Disconnect two nodes in a loaded patch.
func _disconnect_in_patch(ps: PatchState, from_node: String, from_port: int,
                          to_node: String, to_port: int) -> void:
	if ps.network == null:
		return
	ps.network.connections = ps.network.connections.filter(
		func(c: GNConnection) -> bool:
			return not (c.from_node == from_node and c.from_port == from_port
			       and c.to_node == to_node and c.to_port == to_port))
	if ps.network.nodes.has(to_node):
		ps.network.nodes[to_node].mark_dirty()


## Create a new node in a loaded patch's network.
func _create_node_in_patch(ps: PatchState, node_id: String, node_type: String) -> void:
	if ps.network == null:
		return
	if ps.network.nodes.has(node_id):
		GNLogger.warn("EmbeddedHost", "Node '%s' already exists in patch #%d" % [
			node_id, ps.id])
		return
	var node: GNNode = GNExtensionRegistry.instance().create_instance(node_type)
	if node == null:
		GNLogger.error("EmbeddedHost", "Unknown node_type '%s' for create" % node_type)
		return
	node.initialize(node_id)
	ps.network.nodes[node_id] = node
	if ps.cook_engine != null:
		ps.cook_engine.add_child(node)


## Inject a MIDI event into all MidiInCHOP nodes in the patch.
func _inject_midi_event(ps: PatchState, csv: String) -> void:
	var parts := csv.split(",")
	if parts.size() < 3:
		return
	var midi_data := PackedByteArray()
	midi_data.resize(3)
	midi_data[0] = int(parts[0])  # status
	midi_data[1] = int(parts[1])  # data1
	midi_data[2] = int(parts[2])  # data2
	var channel := int(parts[3]) if parts.size() > 3 else 0
	var port := int(parts[4]) if parts.size() > 4 else 0
	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]
		if node.has_method("_inject_midi"):
			node.call("_inject_midi", midi_data, channel, port)


## Inject an OSC message into all OscInCHOP nodes in the patch.
func _inject_osc_message(ps: PatchState, data: String) -> void:
	var sep := data.find("|")
	if sep < 0:
		return
	var address := data.substr(0, sep)
	var args_json := data.substr(sep + 1)
	for node_id in ps.network.nodes:
		var node: GNNode = ps.network.nodes[node_id]
		if node.has_method("_inject_osc"):
			node.call("_inject_osc", address, args_json)


## Handle pixel input from command: data = "addr", ival = [w, h, fmt].
func _handle_pixel_input_cmd(patch_id: int, node_id: String, data: String,
                             width: int, height: int, format: int) -> void:
	var addr := int(data)
	if addr == 0 or width <= 0 or height <= 0:
		return
	var bpp_map := {0: 4, 1: 8, 2: 16, 3: 1, 4: 2, 5: 4, 6: 2, 7: 4}
	var bpp: int = bpp_map.get(format, 4)
	var raw: PackedByteArray = _bridge.call(&"read_bytes", addr, width * height * bpp)
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	if ps.network == null or not ps.network.nodes.has(node_id):
		return
	var node: GNNode = ps.network.nodes[node_id]
	if node.has_method("_set_host_pixels"):
		node.call("_set_host_pixels", raw, width, height, format)


## Handle geometry input from command: data = "pos,nrm,uv,col,idx",
## ival = [vtx_count, idx_count].
func _handle_geometry_input_cmd(patch_id: int, node_id: String, data: String,
                                vtx_count: int, idx_count: int) -> void:
	var parts := data.split(",")
	if parts.size() < 5:
		return
	var pos_addr := int(parts[0])
	var nrm_addr := int(parts[1])
	var uv_addr := int(parts[2])
	var col_addr := int(parts[3])
	var idx_addr := int(parts[4])
	if pos_addr == 0 or vtx_count <= 0:
		return
	var positions: PackedVector3Array = _bridge.call(&"read_vector3", pos_addr, vtx_count)
	var normals: PackedVector3Array = _bridge.call(&"read_vector3", nrm_addr, vtx_count) \
		if nrm_addr != 0 else PackedVector3Array()
	var uvs: PackedVector2Array = _bridge.call(&"read_vector2", uv_addr, vtx_count) \
		if uv_addr != 0 else PackedVector2Array()
	var colors: PackedColorArray = _bridge.call(&"read_color", col_addr, vtx_count) \
		if col_addr != 0 else PackedColorArray()
	var indices: PackedInt32Array = _bridge.call(&"read_int32", idx_addr, idx_count) \
		if idx_addr != 0 and idx_count > 0 else PackedInt32Array()
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	if ps.network == null or not ps.network.nodes.has(node_id):
		return
	var node: GNNode = ps.network.nodes[node_id]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	if not normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = normals
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not indices.is_empty():
		arrays[Mesh.ARRAY_INDEX] = indices
	if node.has_method("_set_host_geometry"):
		node.call("_set_host_geometry", arrays)
	elif node.has_method("_set_host_geometry_direct"):
		node.call("_set_host_geometry_direct", positions, normals, uvs, indices)


## Handle volume input from command: data = "addr", ival = [w, h, d, ch],
## key2 = field_name.
func _handle_volume_input_cmd(patch_id: int, node_id: String, data: String,
                              width: int, height: int, depth: int,
                              channels: int, field_name: String) -> void:
	var addr := int(data)
	if addr == 0:
		return
	var voxel_count := width * height * depth * channels
	var voxels: PackedFloat32Array = _bridge.call(&"read_float32", addr, voxel_count)
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	if ps.network == null or not ps.network.nodes.has(node_id):
		return
	var node: GNNode = ps.network.nodes[node_id]
	if node.has_method("_set_host_volume"):
		node.call("_set_host_volume", voxels, Vector3i(width, height, depth), channels)


## Handle particle input from command: data = "pos,vel,col,age",
## count from ival.
func _handle_particle_input_cmd(patch_id: int, node_id: String, data: String,
                                count: int) -> void:
	var parts := data.split(",")
	if parts.size() < 4:
		return
	var pos_addr := int(parts[0])
	var vel_addr := int(parts[1])
	var col_addr := int(parts[2])
	var age_addr := int(parts[3])
	if pos_addr == 0 or count <= 0:
		return
	var positions: PackedVector3Array = _bridge.call(&"read_vector3", pos_addr, count)
	var velocities: PackedVector3Array = _bridge.call(&"read_vector3", vel_addr, count) \
		if vel_addr != 0 else PackedVector3Array()
	var colors: PackedColorArray = _bridge.call(&"read_color", col_addr, count) \
		if col_addr != 0 else PackedColorArray()
	var ages: PackedFloat32Array = _bridge.call(&"read_float32", age_addr, count) \
		if age_addr != 0 else PackedFloat32Array()
	if not patches.has(patch_id):
		return
	var ps: PatchState = patches[patch_id]
	if ps.network == null or not ps.network.nodes.has(node_id):
		return
	var node: GNNode = ps.network.nodes[node_id]
	if node.has_method("_set_host_particles"):
		node.call("_set_host_particles", positions, velocities, colors, ages)
