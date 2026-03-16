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

## User-defined spare parameters. Stored separately from built-in parameters.
## Keys are parameter names, values are GNParameter instances.
var spare_parameters: Dictionary = {}

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

## Hash of the last cook's inputs (resolved param values + input timestamps).
## Used by the cook engine's input hash guard (Tier 2) to skip redundant cooks
## when parameters and inputs haven't changed since the previous frame.
## -1 sentinel forces the first cook to always proceed.
var _last_cook_input_hash: int = -1

# ─── Timing (set by GNCookEngine each frame before cooking) ────────────────────

## Delta time for the current frame (seconds).
var current_delta: float = 0.0

## Elapsed time since the cook engine started (seconds).
var elapsed_time: float = 0.0

## Current frame number.
var current_frame: int = 0

# ─── Project Context (set by GNCookEngine each frame) ──────────────────────────

## Absolute path to the project folder for resolving project:// paths.
## Empty when the patch is untitled/unsaved.  Set by the cook engine.
var project_dir: String = ""

# ─── UI Metadata ───────────────────────────────────────────────────────────────

## Position of this node in the graph editor (stored for serialization).
@export var graph_position: Vector2 = Vector2.ZERO

## Per-node preview toggle. When false, inline preview is hidden even if
## the global previews toggle is on. Persists with save/load.
var preview_enabled: bool = true

## When true, the node is bypassed: it passes its first input straight through
## without cooking. If no inputs exist, it outputs null.
var bypass: bool = false

## When true, the node is locked: parameter values cannot be changed by the user
## (inspector controls are disabled). Cook still proceeds normally.
var locked: bool = false

## Whether this node is a structural output sink (e.g., WindowOUT, SpoutOut,
## MIDIOut, OscOUT). Sink nodes are always included in the active cooking chain.
## Set by operators in _init() — the cook engine reads this flag, no hardcoded
## type-name checks needed.
var is_sink: bool = false

## Whether this node is in the active cooking chain (feeds a live sink).
## Set each frame by the cook engine. Inactive nodes keep their cached_output
## but skip cooking to save GPU/CPU time.
var is_active: bool = true

# ─── Node Status (per-cook warnings / errors) ─────────────────────────────────

## Non-empty when this node has a warning to display (set during _cook or by the
## cook engine).  Cleared at the start of each cook cycle.  Shown as a yellow
## badge on the GraphNode in the editor.
var node_warning: String = ""

## Non-empty when this node has an error to display (set during _cook or by the
## cook engine).  Cleared at the start of each cook cycle.  Shown as a red
## badge on the GraphNode in the editor.
var node_error: String = ""

## Whether this node requires GPU compute shader support (RenderingDevice).
## Override to return true in operators that use compute shaders (POP, VOL,
## ComputeShaderTOP, CompositorEffectTOP).  The cook engine checks this before
## cooking and gracefully skips incompatible nodes on the Compatibility renderer.
func requires_compute() -> bool:
	return false


## Whether this node provides a CPU fallback when compute shaders are unavailable.
## Override to return true in families that implement [method _cook_cpu] (POP, VOL).
## When true, the cook engine calls [method _cook_cpu] instead of skipping the node
## on Compatibility / WebGL2 renderers.
func has_cpu_fallback() -> bool:
	return false


## CPU fallback cook method — called instead of [method _cook] when the renderer
## lacks compute shader support and [method has_cpu_fallback] returns true.
## Override in subclasses to provide a pure-CPU implementation.
func _cook_cpu(inputs: Array[GNData]) -> GNData:
	return null

## Renderers this operator supports.  Default: all three Godot backends.
## Override in operators that only work on specific renderers.
## Values: "forward_plus", "mobile", "gl_compatibility".
## The cook engine checks this each frame and skips incompatible operators
## with a warning badge — same graceful degradation as requires_compute().
func supported_renderers() -> PackedStringArray:
	return PackedStringArray(["forward_plus", "mobile", "gl_compatibility"])

## Platforms this operator supports.  Default: all Godot export targets.
## Override in operators restricted to specific operating systems.
## Values: "windows", "macos", "linux", "android", "ios", "web".
## The cook engine checks this each frame and skips incompatible operators
## with a warning badge — same pattern as supported_renderers().
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios", "web"])

# ─── Dynamic Input Ports ───────────────────────────────────────────────────────

## If true, this node auto-grows/shrinks its input ports to always have one
## empty slot after the last connected port.  Set by subclasses via
## [method _enable_dynamic_inputs] in their [method _init_ports] override.
var _dynamic_input: bool = false

## Family type for dynamically created input ports.
var _dynamic_input_family: GNFamily.Type = GNFamily.Type.TOP

## Port name prefix for dynamic inputs (e.g., "in" → "in0", "in1", …).
var _dynamic_input_prefix: String = "in"

## Port description prefix for dynamic inputs (e.g., "Input" → "Input 0", …).
var _dynamic_input_desc: String = "Input"

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

## Emitted when parameters are added, removed, or their visibility changes.
## Listeners (GNParamInspector) should rebuild parameter rows.
signal parameters_changed(node_id: String)

## Emitted after this node is renamed (old_id, new_id).
signal node_renamed(old_id: String, new_id: String)


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
##
## Expression parameters are NOT marked dirty here.  The cook engine evaluates
## them in topological order (so upstream caches are fresh), compares to the
## previous resolved value, and only marks dirty + propagates when a value
## actually changes.  See [method GNCookEngine._try_expression_dirty].
func _pre_cook(delta: float) -> void:
	if time_dependent:
		mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# Preview — Output-Type Based (auto-selects from first output port / cached data)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the preview Control for this node's inline graph display.
## Uses the first output port's family type to decide between a TextureRect
## (TOP) or a Label (everything else).  Override in subclasses that need
## non-data-based previews (COMP scene nodes, UI widgets, etc.).
func create_preview_control() -> Control:
	# TOP output → texture thumbnail
	if output_ports.size() > 0 and output_ports[0].family == GNFamily.Type.TOP:
		var tex_rect := TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return tex_rect
	# Everything else → label
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Updates the preview control from cached_output.  Dispatches by the actual
## output data type so cross-family nodes (e.g. a VOL that outputs a texture)
## get the correct preview automatically.  For multi-output nodes the first
## output (cached_output) is previewed; use a Null node to inspect others.
## Override in subclasses with non-data previews (COMP, UI, OUT).
func update_preview_control(control: Control) -> void:
	if cached_output == null:
		if control is Label:
			(control as Label).text = ""
		elif control is TextureRect:
			(control as TextureRect).texture = null
		return

	# ── Texture (TOP) ──────────────────────────────────────────────────
	if cached_output is GNTextureData:
		if control is TextureRect:
			(control as TextureRect).texture = (cached_output as GNTextureData).texture
		return

	# Everything below uses a Label
	if not (control is Label):
		return
	var label: Label = control as Label

	# ── Channel data (CHOP) ────────────────────────────────────────────
	if cached_output is GNChannelData:
		var ch_data: GNChannelData = cached_output as GNChannelData
		var lines := PackedStringArray()
		for ch_name in ch_data.channels:
			var samples: PackedFloat32Array = ch_data.channels[ch_name]
			if samples.size() > 0:
				lines.append("%s: %.3f" % [ch_name, samples[samples.size() - 1]])
			else:
				lines.append("%s: —" % ch_name)
		label.text = "\n".join(lines) if lines.size() > 0 else ""

	# ── Geometry (SOP) ─────────────────────────────────────────────────
	elif cached_output is GNGeoData:
		var geo: GNGeoData = cached_output as GNGeoData
		if geo.has_geometry() and geo.mesh != null:
			var verts: int = 0
			var surfs: int = geo.mesh.get_surface_count()
			for s in range(surfs):
				var arrays: Array = geo.mesh.surface_get_arrays(s)
				if arrays[Mesh.ARRAY_VERTEX] != null:
					verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			label.text = "%d verts\n%d surfaces" % [verts, surfs]
		else:
			label.text = "no geo"

	# ── Table (DAT) ────────────────────────────────────────────────────
	elif cached_output is GNTableData:
		var tbl: GNTableData = cached_output as GNTableData
		if tbl.table.is_empty():
			label.text = "(empty)"
		else:
			var lines := PackedStringArray()
			if tbl.has_header and tbl.table.size() > 0:
				lines.append(" | ".join(tbl.table[0]))
			var data_start: int = 1 if tbl.has_header else 0
			var max_rows: int = mini(tbl.table.size() - data_start, 3)
			for r in range(max_rows):
				lines.append(" | ".join(tbl.table[data_start + r]))
			if tbl.table.size() - data_start > 3:
				lines.append("… +%d rows" % (tbl.table.size() - data_start - 3))
			label.text = "\n".join(lines)

	# ── Image (IMG) ────────────────────────────────────────────────────
	elif cached_output is GNImageData:
		var img_data: GNImageData = cached_output as GNImageData
		if img_data.image != null:
			var res: Vector2i = img_data.resolution
			label.text = "%d×%d\n%s" % [res.x, res.y, _preview_format_name(img_data.format)]
		else:
			label.text = "no image"

	# ── Particles (POP) ────────────────────────────────────────────────
	elif cached_output is GNParticleData:
		var pd: GNParticleData = cached_output as GNParticleData
		label.text = "%d particles" % pd.particle_count

	# ── Volume (VOL) ──────────────────────────────────────────────────
	elif cached_output is GNVolumeData:
		var vd: GNVolumeData = cached_output as GNVolumeData
		label.text = "%dx%dx%d\n%s" % [
			vd.resolution.x, vd.resolution.y, vd.resolution.z,
			vd.field_name]

	# ── Material (MAT) ────────────────────────────────────────────────
	elif cached_output is GNMaterialData:
		var mat_data: GNMaterialData = cached_output as GNMaterialData
		if mat_data.material != null:
			label.text = mat_data.material_label
		else:
			label.text = "no material"

	# ── Unknown / unhandled ────────────────────────────────────────────
	else:
		label.text = ""


## Short human-readable name for Image.Format (used by IMG preview).
static func _preview_format_name(fmt: Image.Format) -> String:
	match fmt:
		Image.FORMAT_RGBA8: return "RGBA8"
		Image.FORMAT_RGB8: return "RGB8"
		Image.FORMAT_L8: return "L8"
		Image.FORMAT_LA8: return "LA8"
		Image.FORMAT_RGBAF: return "RGBAF"
		Image.FORMAT_RGBAH: return "RGBAH"
		Image.FORMAT_RF: return "RF"
		Image.FORMAT_RGF: return "RGF"
		_: return "fmt:%d" % fmt

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
	GNLogger.debug("GNNode", "Initialized '%s' (%s/%s) — %d in, %d out, %d params" % [
		id, GNFamily.get_family_name(family), node_type,
		input_ports.size(), output_ports.size(), parameters.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Port Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Adds an input port and returns it.  [param port_label] overrides the
## display name in the UI when set (see [method GNPort.display_name]).
func add_input(port_name: String, port_family: GNFamily.Type,
		multi: bool = false, desc: String = "", port_label: String = "") -> GNPort:
	var port := GNPort.create(port_name, port_family, input_ports.size(), true, multi, desc, port_label)
	input_ports.append(port)
	return port


## Adds an output port and returns it.  [param port_label] overrides the
## display name in the UI when set (see [method GNPort.display_name]).
func add_output(port_name: String, port_family: GNFamily.Type,
		desc: String = "", port_label: String = "") -> GNPort:
	var port := GNPort.create(port_name, port_family, output_ports.size(), false, false, desc, port_label)
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
# Dynamic Input Ports — Auto-grow / Auto-shrink
# ═══════════════════════════════════════════════════════════════════════════════

## Enables dynamic input port auto-grow for this node.
## Call from [method _init_ports] instead of [code]add_input(..., true)[/code].
## Creates [param initial_count] numbered input ports (default 1).
## After every connection/disconnection the network calls
## [method update_dynamic_inputs] to ensure one trailing empty slot exists.
func _enable_dynamic_inputs(port_family: GNFamily.Type,
		name_prefix: String = "in", desc_prefix: String = "Input",
		initial_count: int = 1) -> void:
	_dynamic_input = true
	_dynamic_input_family = port_family
	_dynamic_input_prefix = name_prefix
	_dynamic_input_desc = desc_prefix
	for i in range(initial_count):
		add_input("%s%d" % [name_prefix, i], port_family, false,
			"%s %d" % [desc_prefix, i])


## Updates the dynamic input port count so there is always exactly one empty
## port after the highest connected port.  Called by [code]GNNetwork[/code]
## after every connection/disconnection involving this node.
##
## [param connected_ports] — port indices that currently have a wire attached.
func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	if not _dynamic_input:
		return
	var max_port: int = -1
	for p in connected_ports:
		if p > max_port:
			max_port = p
	var desired: int = maxi(max_port + 2, 1)
	if desired != input_ports.size():
		set_input_count(desired, _dynamic_input_family,
			_dynamic_input_prefix, _dynamic_input_desc)


# ═══════════════════════════════════════════════════════════════════════════════
# Parameter Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Registers a parameter under its name.  Called during [method _init_parameters]
## or at runtime for dynamic parameter creation (e.g. ConstantCHOP, RampCHOP).
## Automatically wires [signal GNParameter.value_changed] and
## [signal GNParameter.mode_changed] so the node marks dirty on edits.
func add_parameter(param: GNParameter) -> void:
	parameters[param.param_name] = param
	# Wire dirty-marking signals — safe to call on already-connected params
	if not param.value_changed.is_connected(_on_parameter_changed):
		param.value_changed.connect(_on_parameter_changed)
	if not param.mode_changed.is_connected(_on_parameter_mode_changed):
		param.mode_changed.connect(_on_parameter_mode_changed)


## Adds a user-defined spare parameter. Stored separately from built-in params.
## Emits [signal parameters_changed] so the inspector rebuilds.
func add_spare_parameter(param: GNParameter) -> void:
	spare_parameters[param.param_name] = param
	if not param.value_changed.is_connected(_on_parameter_changed):
		param.value_changed.connect(_on_parameter_changed)
	if not param.mode_changed.is_connected(_on_parameter_mode_changed):
		param.mode_changed.connect(_on_parameter_mode_changed)
	parameters_changed.emit(id)


## Removes a spare parameter by name. Returns true if removed.
func remove_spare_parameter(param_name: String) -> bool:
	if not spare_parameters.has(param_name):
		return false
	var param: GNParameter = spare_parameters[param_name]
	if param.value_changed.is_connected(_on_parameter_changed):
		param.value_changed.disconnect(_on_parameter_changed)
	if param.mode_changed.is_connected(_on_parameter_mode_changed):
		param.mode_changed.disconnect(_on_parameter_mode_changed)
	spare_parameters.erase(param_name)
	parameters_changed.emit(id)
	return true


## Returns true if the node has any spare parameters.
func has_spare_parameters() -> bool:
	return not spare_parameters.is_empty()


## Returns the raw GNParameter object, or null if not found.
func get_parameter(param_name: String) -> GNParameter:
	var p: GNParameter = parameters.get(param_name, null)
	if p != null:
		return p
	return spare_parameters.get(param_name, null)


## Returns the resolved value of a parameter (respecting its current mode).
func get_param_value(param_name: String) -> Variant:
	var param: GNParameter = get_parameter(param_name)
	if param == null:
		push_warning("GNNode '%s': unknown parameter '%s'" % [id, param_name])
		return null
	return param.get_resolved_value()


## Programmatically sets a parameter's constant value.
## Useful for operators that auto-detect values (e.g., resolution from a loaded file).
func set_param_value(p_name: String, new_value: Variant) -> void:
	var param: GNParameter = get_parameter(p_name)
	if param == null:
		push_warning("GNNode '%s': unknown parameter '%s'" % [id, p_name])
		return
	param.set_value(new_value)


## Returns a list of all parameter names.
func get_parameter_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in parameters:
		names.append(key)
	for key in spare_parameters:
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


## Returns the cooked output data for a specific output port index.
## Most nodes have a single output and always return [member cached_output].
## Override in multi-output nodes (e.g., SubNetworkNode) to route different
## ports to different data objects.
func get_output_data(port_index: int) -> GNData:
	return cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Execution (called by GNCookEngine, not directly by users)
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a mutable copy of the given input data.  If the upstream output is
## shared (feeds multiple consumers), duplicates it so in-place modifications
## are safe.  If this node is the sole consumer, returns the original — zero
## copy cost.  Built-in operators that modify input data should use this
## instead of unconditional [code]duplicate()[/code].
func _mutable_input(data: GNData) -> GNData:
	if data == null:
		return null
	if data._shared:
		return data.duplicate_data()
	return data


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


## Called when any parameter's mode changes (constant ↔ expression ↔ bind).
## Marks dirty so the node re-cooks with the new mode's resolved value.
func _on_parameter_mode_changed(param_name: String, _new_mode: int) -> void:
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _to_string() -> String:
	return "[GNNode %s (%s/%s)]" % [id, GNFamily.get_family_name(family), node_type]


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Serializes this node's user-editable state to a Dictionary.
## Captures operator type, graph position, and all parameter values/modes.
## Does NOT serialize ports or cook state (those are rebuilt on construction).
## The "type" field uses the GDScript class_name (e.g. "NoiseTOP") which matches
## the GNExtensionRegistry key, NOT the short node_type (e.g. "noise").
func to_dict() -> Dictionary:
	# Use the GDScript class_name — it matches the registry key exactly.
	var registry_type: String = get_script().get_global_name()
	var d: Dictionary = {
		"type": registry_type,
		"position": [graph_position.x, graph_position.y],
	}

	if not preview_enabled:
		d["preview_enabled"] = false
	if bypass:
		d["bypass"] = true
	if locked:
		d["locked"] = true

	# Save dynamic input port count so it can be restored before connections
	if _dynamic_input and input_ports.size() > 1:
		d["dynamic_input_count"] = input_ports.size()

	# Serialize parameters (only those that differ from defaults, or have expressions)
	var params_dict: Dictionary = {}
	for param_name in parameters:
		var param: GNParameter = parameters[param_name]
		var pd := param.to_dict()
		if not pd.is_empty():
			params_dict[param_name] = pd
	if not params_dict.is_empty():
		d["parameters"] = params_dict

	# Serialize spare parameters (full definition, not just overrides)
	if not spare_parameters.is_empty():
		var spare_dict: Dictionary = {}
		for sp_name in spare_parameters:
			var sp: GNParameter = spare_parameters[sp_name]
			spare_dict[sp_name] = {
				"value_type": sp.value_type,
				"label": sp.label,
				"default_value": sp.default_value,
				"min_value": sp.min_value,
				"max_value": sp.max_value,
				"step": sp.step,
				"enum_options": sp.enum_options,
				"data": sp.to_dict(),
			}
		d["spare_parameters"] = spare_dict

	return d


## Restores parameter values and graph position from a serialized Dictionary.
## Call AFTER initialize() so parameters and ports already exist.
func from_dict(d: Dictionary) -> void:
	# Restore graph position
	if d.has("position"):
		var pos: Array = d["position"]
		if pos.size() >= 2:
			graph_position = Vector2(float(pos[0]), float(pos[1]))

	# Restore per-node preview flag
	if d.has("preview_enabled"):
		preview_enabled = d["preview_enabled"]
	if d.has("bypass"):
		bypass = d["bypass"]
	if d.has("locked"):
		locked = d["locked"]

	# Restore dynamic input port count so connections can reference all ports
	if _dynamic_input and d.has("dynamic_input_count"):
		var count: int = int(d["dynamic_input_count"])
		if count != input_ports.size():
			set_input_count(count, _dynamic_input_family,
				_dynamic_input_prefix, _dynamic_input_desc)

	# Restore parameter values/modes/expressions
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for param_name in params_dict:
			var param: GNParameter = parameters.get(param_name, null)
			if param == null:
				GNLogger.warn("GNNode", "'%s': skipping unknown parameter '%s' during load" % [id, param_name])
				continue
			param.from_dict(params_dict[param_name])

	# Restore spare parameters (full definitions)
	if d.has("spare_parameters"):
		var spare_dict: Dictionary = d["spare_parameters"]
		for sp_name in spare_dict:
			var sp_def: Dictionary = spare_dict[sp_name]
			var vt: int = int(sp_def.get("value_type", GNParameter.ValueType.FLOAT))
			var sp := _create_spare_param_from_def(sp_name, vt, sp_def)
			if sp != null:
				var data: Dictionary = sp_def.get("data", {})
				if not data.is_empty():
					sp.from_dict(data)
				add_spare_parameter(sp)


## Creates a GNParameter from a spare parameter definition dictionary.
static func _create_spare_param_from_def(sp_name: String, vt: int, sp_def: Dictionary) -> GNParameter:
	var label_text: String = sp_def.get("label", sp_name)
	match vt:
		GNParameter.ValueType.FLOAT:
			return GNParameter.create_float(sp_name,
				float(sp_def.get("default_value", 0.0)),
				sp_def.get("min_value", null),
				sp_def.get("max_value", null),
				float(sp_def.get("step", 0.01)),
				label_text)
		GNParameter.ValueType.INT:
			return GNParameter.create_int(sp_name,
				int(sp_def.get("default_value", 0)),
				sp_def.get("min_value", null),
				sp_def.get("max_value", null),
				label_text)
		GNParameter.ValueType.BOOL:
			return GNParameter.create_bool(sp_name,
				bool(sp_def.get("default_value", false)),
				label_text)
		GNParameter.ValueType.STRING:
			return GNParameter.create_string(sp_name,
				str(sp_def.get("default_value", "")),
				label_text)
		GNParameter.ValueType.COLOR:
			var def_val: Variant = sp_def.get("default_value", Color.WHITE)
			var color: Color = Color.WHITE
			if def_val is Color:
				color = def_val
			return GNParameter.create_color(sp_name, color, label_text)
		GNParameter.ValueType.VECTOR2:
			return GNParameter.create_vector2(sp_name, Vector2.ZERO, label_text)
		GNParameter.ValueType.ENUM:
			var options: PackedStringArray = sp_def.get("enum_options", PackedStringArray())
			return GNParameter.create_enum(sp_name, options, 0, label_text)
		_:
			return GNParameter.create_float(sp_name, 0.0, null, null, 0.01, label_text)
