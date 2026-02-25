class_name GNNode
extends Node
## Base class for all GONODES operators (TOPs, CHOPs, SOPs, etc.).
## Extends Node so operators can parent SubViewports (TOPs), Windows (output),
## and participate in the scene tree lifecycle.  Processing is disabled —
## only the GNCookEngine drives cooking via the cook lifecycle methods.
##
## Subclasses override [method _init_ports], [method _init_parameters], and [method _cook].

# ─── Identity ──────────────────────────────────────────────────────────────────

## Unique node ID within its parent network (e.g., "noise1", "lfo2").
@export var id: String = ""

## Operator type name (e.g., "noise", "lfo", "composite").
@export var node_type: String = ""

## Which operator family this node belongs to.
@export var family: GNFamily.Type = GNFamily.Type.TOP

## Human-readable description of this operator for the palette tooltip.
var node_description: String = ""

# ─── Ports ─────────────────────────────────────────────────────────────────────

## Ordered list of input port definitions.
var input_ports: Array[GNPort] = []

## Ordered list of output port definitions.
var output_ports: Array[GNPort] = []

# ─── Parameters ────────────────────────────────────────────────────────────────

## Map of parameter name → GNParameter.
var parameters: Dictionary = {}

# ─── Cook State ────────────────────────────────────────────────────────────────

## True when this node needs to be re-cooked.
var dirty: bool = true

## Whether this node is time-dependent (always dirty each frame).
var time_dependent: bool = false

## Cached output data from the last successful cook.
var cached_output: GNData = null

## Duration of the last cook in milliseconds (for profiling overlay).
var cook_time_ms: float = 0.0

## True if the last cook completed without errors.
var cook_valid: bool = false

# ─── Timing (set by GNCookEngine each frame before cooking) ────────────────────

## Delta time for the current frame (seconds).
var current_delta: float = 0.0

## Elapsed time since the cook engine started (seconds).
var elapsed_time: float = 0.0

## Current frame number.
var current_frame: int = 0

# ─── UI Metadata ───────────────────────────────────────────────────────────────

## Position of this node in the graph editor (stored for serialization).
@export var graph_position: Vector2 = Vector2.ZERO

# ─── Signals ───────────────────────────────────────────────────────────────────

## Emitted when this node is marked dirty (before cook).
signal node_dirty(node_id: String)

## Emitted after this node finishes cooking.
signal node_cooked(node_id: String)

## Emitted when a parameter value changes.
signal parameter_changed(node_id: String, param_name: String)

## Emitted when input or output ports are added/removed at runtime.
## Listeners (GNGraphEditor, GNNodeView) must rebuild slots and prune stale wires.
signal ports_changed(node_id: String)


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle — Override These in Subclasses
# ═══════════════════════════════════════════════════════════════════════════════

## Called once after construction.  Override to define input/output ports.
func _init_ports() -> void:
	pass


## Called once after construction.  Override to define parameters.
func _init_parameters() -> void:
	pass


## Core cook method.  Override to produce output data from inputs.
## [param inputs] — array of GNData from upstream nodes, ordered by input port index.
## Returns the cooked output GNData, or null on failure.
func _cook(inputs: Array[GNData]) -> GNData:
	return null


## Optional override — called once per frame before cook, even when not dirty.
## Useful for time-dependent nodes to check if they should mark themselves dirty.
func _pre_cook(delta: float) -> void:
	if time_dependent:
		mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════════

## Initializes the node — sets up ports, parameters, and wires internal signals.
## Call this after creating a node instance (constructor can't call virtual methods).
## Disables self-processing — only the cook engine drives cooking.
func initialize(p_id: String) -> void:
	id = p_id
	name = p_id  # Match scene tree name to network ID
	process_mode = PROCESS_MODE_DISABLED
	_init_ports()
	_init_parameters()
	# Wire parameter change signals to mark this node dirty
	for param_name in parameters:
		var param: GNParameter = parameters[param_name]
		if not param.value_changed.is_connected(_on_parameter_changed):
			param.value_changed.connect(_on_parameter_changed)
	GNLogger.debug("GNNode", "Initialized '%s' (%s/%s) — %d in, %d out, %d params" % [
		id, GNFamily.get_family_name(family), node_type,
		input_ports.size(), output_ports.size(), parameters.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Port Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Adds an input port and returns it.
func add_input(port_name: String, port_family: GNFamily.Type,
		multi: bool = false, desc: String = "") -> GNPort:
	var port := GNPort.create(port_name, port_family, input_ports.size(), true, multi, desc)
	input_ports.append(port)
	return port


## Adds an output port and returns it.
func add_output(port_name: String, port_family: GNFamily.Type,
		desc: String = "") -> GNPort:
	var port := GNPort.create(port_name, port_family, output_ports.size(), false, false, desc)
	output_ports.append(port)
	return port


## Returns the input port at [param index], or null if out of range.
func get_input_port(index: int) -> GNPort:
	if index < 0 or index >= input_ports.size():
		return null
	return input_ports[index]


## Returns the output port at [param index], or null if out of range.
func get_output_port(index: int) -> GNPort:
	if index < 0 or index >= output_ports.size():
		return null
	return output_ports[index]


## Replaces all input ports with [param count] sequentially-named ports of the
## given [param port_family].  Emits [signal ports_changed] so the graph editor
## can prune stale connections and rebuild slots.  Use from subclass overrides of
## [method _on_parameter_changed] to implement dynamic port counts.
##
## [param count]       — desired number of input ports (clamped ≥ 0).
## [param port_family] — GNFamily.Type for every port.
## [param name_prefix] — port names become "prefix0", "prefix1", …
## [param desc_prefix] — port descriptions become "Prefix 0", "Prefix 1", …
func set_input_count(count: int, port_family: GNFamily.Type,
		name_prefix: String = "in", desc_prefix: String = "Input") -> void:
	count = maxi(count, 0)
	if count == input_ports.size():
		return  # No change
	input_ports.clear()
	for i in range(count):
		add_input("%s%d" % [name_prefix, i], port_family, false,
			"%s %d" % [desc_prefix, i])
	GNLogger.debug("GNNode", "'%s' input port count → %d" % [id, count])
	ports_changed.emit(id)


## Replaces all output ports with [param count] sequentially-named ports.
## Same semantics as [method set_input_count] but for outputs.
func set_output_count(count: int, port_family: GNFamily.Type,
		name_prefix: String = "out", desc_prefix: String = "Output") -> void:
	count = maxi(count, 0)
	if count == output_ports.size():
		return
	output_ports.clear()
	for i in range(count):
		add_output("%s%d" % [name_prefix, i], port_family,
			"%s %d" % [desc_prefix, i])
	GNLogger.debug("GNNode", "'%s' output port count → %d" % [id, count])
	ports_changed.emit(id)


# ═══════════════════════════════════════════════════════════════════════════════
# Parameter Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Registers a parameter under its name.  Called during [method _init_parameters].
func add_parameter(param: GNParameter) -> void:
	parameters[param.param_name] = param


## Returns the raw GNParameter object, or null if not found.
func get_parameter(param_name: String) -> GNParameter:
	return parameters.get(param_name, null)


## Returns the resolved value of a parameter (respecting its current mode).
func get_param_value(param_name: String) -> Variant:
	var param: GNParameter = parameters.get(param_name, null)
	if param == null:
		push_warning("GNNode '%s': unknown parameter '%s'" % [id, param_name])
		return null
	return param.get_resolved_value()


## Returns a list of all parameter names.
func get_parameter_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in parameters:
		names.append(key)
	return names


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation
# ═══════════════════════════════════════════════════════════════════════════════

## Marks this node as needing a re-cook.
## Does NOT propagate downstream — the cook engine handles propagation.
func mark_dirty() -> void:
	if not dirty:
		dirty = true
		node_dirty.emit(id)


## Clears the dirty flag after a successful cook.
func clear_dirty() -> void:
	dirty = false


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Execution (called by GNCookEngine, not directly by users)
# ═══════════════════════════════════════════════════════════════════════════════

## Executes the cook cycle for this node with the provided input data.
## Returns the cooked output GNData, or null on failure.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var start_time := Time.get_ticks_usec()
	var result := _cook(inputs)
	var end_time := Time.get_ticks_usec()

	cook_time_ms = (end_time - start_time) / 1000.0

	if result != null:
		result.timestamp = frame
		result.valid = true
		cached_output = result
		cook_valid = true
	else:
		# Clear stale cached output so downstream nodes don't read old data
		cached_output = null
		cook_valid = false
		GNLogger.debug("GNNode", "'%s' cook produced null output" % id)

	clear_dirty()
	node_cooked.emit(id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Internal Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

## Called when any parameter's value changes — marks this node dirty.
func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _to_string() -> String:
	return "[GNNode %s (%s/%s)]" % [id, GNFamily.get_family_name(family), node_type]
