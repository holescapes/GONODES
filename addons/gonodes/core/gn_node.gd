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
@export var family: int = GNFamily.Type.TOP

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

## Per-output-port demand flags, stamped by the cook engine each frame
## before cooking.  For multi-output nodes, ports that feed no active
## downstream node (via wires, wireless Select operators, or expression
## references) are marked false — the operator can skip expensive work
## for those ports via [method is_output_demanded].
## Single-output nodes ignore this (always demanded when active).
var _demanded_outputs: Array[bool] = []

## Duration of the last cook in milliseconds (for profiling overlay).
var cook_time_ms: float = 0.0

## True if the last cook completed without errors.
var cook_valid: bool = false

## True if this node was actually cooked during the current frame.
var cooked_this_frame: bool = false

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

## Whether this node's _cook() is safe to run on a worker thread.
## Default true.  Override to false in operators that call set_par(),
## network_add_node(), or use non-thread-safe I/O (StreamPeerTCP, AudioServer, etc.).
var thread_safe: bool = true

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
## Defaults to false — the cook engine stamps is_active on the first frame
## when _active_set_dirty triggers.  This prevents the debug overlay from
## showing all nodes as active before the first cook cycle.
var is_active: bool = false:
	set(value):
		if is_active != value:
			is_active = value
			_on_active_changed(value)

# ─── Node Status (per-cook warnings / errors) ─────────────────────────────────

## Non-empty when this node has a warning to display (set during _cook or by the
## cook engine).  Cleared at the start of each cook cycle.  Shown as a yellow
## badge on the GraphNode in the editor.
var node_warning: String = ""

## Non-empty when this node has an error to display (set during _cook or by the
## cook engine).  Cleared at the start of each cook cycle.  Shown as a red
## badge on the GraphNode in the editor.
var node_error: String = ""

# ─── Deprecation ───────────────────────────────────────────────────────────────

## When true, this operator is deprecated.  Set in the subclass _init().
## Deprecated operators remain fully functional but show visual warnings.
var deprecated: bool = false

## Human-readable deprecation message (e.g. "Use FitTOP instead — it supports
## all fit modes plus filtering.").  Shown in the title bar tooltip, help
## window, and palette.
var deprecation_message: String = ""

## Class name of the recommended replacement operator (e.g. "FitTOP").
## Used by the help window to link to the replacement.
var deprecated_replacement: String = ""

## When non-empty, this node is a placeholder for an operator type that could
## not be loaded (missing extension, newer GONODES version, etc.).  Holds the
## original serialized Dictionary so it can be re-saved without data loss.
## Connections to/from the placeholder are preserved.  The cook engine skips
## placeholders.
var _placeholder_data: Dictionary = {}

## Returns true if this node is a load-time placeholder for a missing operator.
func is_placeholder() -> bool:
	return not _placeholder_data.is_empty()

## Whether this node requires GPU compute shader support (RenderingDevice).
## Override to return true in operators that use compute shaders (POP, VOL,
## ComputeShaderTOP, CompositorEffectTOP).  The cook engine checks this before
## cooking and gracefully skips incompatible nodes on the Compatibility renderer.
func requires_compute() -> bool:
	return false


## Whether this node must cook on the main thread (GPU / renderer access).
## Override to return true in base classes that use SubViewport rendering (TOP),
## compute shaders (POP, VOL), or any other renderer API.  The cook engine
## batches main-thread nodes separately from parallelisable CPU nodes.
## Extension families that need GPU access should override this in their base.
func requires_main_thread() -> bool:
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
var _dynamic_input_family: int = GNFamily.Type.TOP

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


# ═══════════════════════════════════════════════════════════════════════════════
# Switch / Null Shared Helpers
# ═══════════════════════════════════════════════════════════════════════════════
# These exist in GNNode (not in a mixin) because GDScript lacks multiple
# inheritance.  Family bases override _is_family_data(); Switch and Null
# subclasses delegate to these one-liners instead of copy-pasting logic.

## Returns true if [param data] matches the expected data type for this
## operator's family.  Override in each family base (e.g. GNTopBase checks
## [code]data is GNTextureData[/code]).  Default accepts any non-null data.
func _is_family_data(data: GNData) -> bool:
	return data != null


## Standard Switch parameter setup: index + null_on_missing.
func _switch_init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Input Index",
		"Which input to output (0-based)"))
	add_parameter(GNParameter.create_bool("null_on_missing", false, "Null on Missing",
		"When true, output null instead of holding the previous frame when the "
		+ "selected input is empty. Useful as a programmatic gate."))


## Clamps the "index" parameter max to match the current dynamic input count.
## Call from [method update_dynamic_inputs] after [code]super()[/code].
func _switch_clamp_index() -> void:
	var idx_param := get_parameter("index")
	if idx_param:
		var max_idx: int = maxi(input_ports.size() - 2, 0)
		idx_param.max_value = max_idx
		if int(idx_param.value) > max_idx:
			idx_param.set_value(max_idx)


## Returns [code]PackedInt32Array([selected_index])[/code] for active-chain
## pruning — only the selected input's upstream chain is cooked.
func _switch_active_indices() -> PackedInt32Array:
	var idx: int = clampi(get_param_value("index"), 0, maxi(input_ports.size() - 1, 0))
	return PackedInt32Array([idx])


## Standard discrete Switch cook: select input by index, hold cached_output
## on miss (or null if null_on_missing is true).
func _switch_cook(inputs: Array[GNData]) -> GNData:
	if inputs.is_empty():
		return cached_output
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)
	if idx < inputs.size() and _is_family_data(inputs[idx]):
		return inputs[idx]
	if get_param_value("null_on_missing"):
		return null
	return cached_output


## Standard Null cook: pass the first input through unchanged.
func _null_cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and _is_family_data(inputs[0]):
		return inputs[0]
	return null


## Override to declare wireless (non-wire) dependencies on other nodes.
## Returns an array of node IDs that this node reads from without a wire
## connection (e.g. SelectTOP referencing a remote TOP by name).
## The cook engine uses this to include those nodes in the active set
## and to order them before this node in the topological sort.
## Default implementation scans all parameters for node_ref_family >= -1
## (created via GNParameter.create_node_ref) and returns their non-empty
## values.  Only override if you need custom logic beyond param scanning.
func get_remote_dependencies() -> Array[String]:
	var deps: Array[String] = []
	for p: GNParameter in parameters.values():
		if p.node_ref_family >= -1:
			var val: String = str(p.value)
			if not val.is_empty():
				deps.append(val)
	return deps


## Returns the input port indices that are actually consumed this frame.
## Empty array (default) means ALL connected inputs are active.
## Override in operators like SwitchTOP that only read one (or two) inputs
## at a time — the cook engine will skip upstream chains for inactive ports.
func get_active_input_indices() -> PackedInt32Array:
	return PackedInt32Array()


## Returns a Dictionary mapping parameter names to their expected target
## family type (GNFamily.Type enum value, or -1 for any).  Used by the
## rename system to propagate ID changes and by the inspector UI to show
## a filtered node-picker dropdown.
## Default implementation scans all parameters for node_ref_family >= -1.
## Only override if you need custom logic beyond param scanning.
func get_node_reference_params() -> Dictionary:
	var refs: Dictionary = {}
	for p: GNParameter in parameters.values():
		if p.node_ref_family >= -1:
			refs[p.param_name] = p.node_ref_family
	return refs


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
# Export — Polymorphic output export (graph editor delegates here)
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true if this node has at least one exportable output (data or scene).
## Override in subclasses with non-data exports (e.g. COMP scene nodes).
func can_export_output() -> bool:
	return not get_exportable_outputs().is_empty()


## Returns an array of exportable output descriptors, one per port that has
## valid data with export filters.  Each entry:
##   { "port": int, "label": String, "filters": Array[Dictionary] }
## Override in subclasses that produce non-data exports.
func get_exportable_outputs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(output_ports.size()):
		var data: GNData = get_output_data(i)
		if data == null or not data.valid:
			continue
		var filters := data.get_export_filters()
		if filters.is_empty():
			continue
		var label: String = output_ports[i].label
		if label.is_empty():
			label = output_ports[i].port_name
		if label.is_empty():
			label = GNFamily.get_family_name(output_ports[i].family)
		result.append({ "port": i, "label": label, "filters": filters })
	return result


## Returns file-dialog filters for exporting this node's output.
## When [param port_index] is -1, returns filters for the first exportable port.
## Override in subclasses with non-data exports.
func get_export_filters(port_index: int = -1) -> Array[Dictionary]:
	if port_index >= 0:
		var data: GNData = get_output_data(port_index)
		if data != null:
			return data.get_export_filters()
		return []
	# Legacy: first exportable port
	var outputs := get_exportable_outputs()
	if not outputs.is_empty():
		return outputs[0]["filters"]
	return []


## Exports this node's output to disk.  Returns OK on success.
## When [param port_index] is -1, exports the first exportable port.
## Override in subclasses with non-data exports.
func export_output(path: String, port_index: int = -1) -> Error:
	if port_index >= 0:
		var data: GNData = get_output_data(port_index)
		if data != null and data.valid:
			return data.export_to_file(path)
		return ERR_UNAVAILABLE
	# Legacy: first exportable port
	if cached_output != null and cached_output.valid:
		return cached_output.export_to_file(path)
	return ERR_UNAVAILABLE


# ═══════════════════════════════════════════════════════════════════════════════
# Preview — Output-Type Based (auto-selects from first output port / cached data)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the preview Control for this node's inline graph display.
## Family base classes override this (GNTopBase returns a TextureRect,
## all others return a Label).  This fallback creates a Label.
func create_preview_control() -> Control:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Renders into the on-node preview host.  Mirrors the viewer panel paradigm:
## the host provides set_texture(), set_text(), set_control() and the node
## pushes data into it.  Family base classes provide default implementations;
## individual operators can override for custom rendering without touching
## base classes.
##
## The [param host] exposes a minimal API (GNPreviewHost):
##   host.set_texture(tex)   — display a Texture2D thumbnail
##   host.set_text(text)     — display short text (channel list, table summary)
##   host.set_control(ctrl)  — embed a custom Control
##
## Default implementation dispatches to the GNDataRenderer for the output's
## data family.  Individual nodes can override for custom previews.
func render_for_preview(host) -> void:
	if cached_output != null:
		var renderer = GNFamily.get_renderer(cached_output.get_family())
		if renderer != null:
			renderer.render_for_preview(cached_output, host)
			return
	if cached_output != null and host.has_method("set_text"):
		host.set_text(cached_output.get_preview_text())
	elif host.has_method("set_text"):
		host.set_text("")


## Updates the preview control from cached_output.  Family base classes override
## this with type-specific logic (GNTopBase → TextureRect, GNChopBase → channel
## labels, etc.).  This fallback handles nodes that don't extend a family base
## (e.g. GDScriptSCRIPT / PythonSCRIPT) by delegating to the data's get_preview_text().
func update_preview_control(control: Control) -> void:
	if cached_output == null:
		if control is Label:
			(control as Label).text = ""
		elif control is TextureRect:
			(control as TextureRect).texture = null
		return

	# Delegate to polymorphic get_preview_text()
	if control is Label:
		(control as Label).text = cached_output.get_preview_text()


# ═══════════════════════════════════════════════════════════════════════════════
# Viewer Display — Per-Node Viewer Visualization
# ═══════════════════════════════════════════════════════════════════════════════

## Renders this node's output into the viewer panel (or SnapshotTOP adapter).
## Dispatches rendering to the GNDataRenderer registered for the data type.
## Individual operators can override this for custom visualization (e.g.
## CameraCOMP frustum, LightCOMP cone, mapper TOP control points).
##
## The [param viewer] parameter is untyped to avoid a core → UI dependency.
## It exposes a minimal host API:
##   viewer.set_texture(tex, info)          — display a Texture2D
##   viewer.set_control(control)            — embed a Control (Tree, waveform)
##   viewer.set_info(text, info_bar_text)   — plain text label
##   viewer.set_info_overlay(text)          — semi-transparent overlay on 3D
##   viewer.get_3d_viewport() -> SubViewport — shared 3D SubViewport
##   viewer.get_content_size() -> Vector2i  — available display area
##   viewer.hide_all_displays()             — clear all displays
##
## [param port_index] selects which output port to render.  The viewer panel
## passes the user-selected port from its port dropdown.  Defaults to 0.
## The renderer is chosen by the data instance's family, so multi-type nodes
## (e.g. a TOP with a CHOP on port 1) get correct rendering per port.
func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data != null:
		var renderer = GNFamily.get_renderer(data.get_family())
		if renderer != null:
			renderer.render_for_viewer(data, viewer)
			return
		viewer.set_info(data.get_preview_text(), "")
	else:
		viewer.set_info("No output", "")


## Called by the viewer panel when the user interacts with this node's display.
## Individual operators can override for custom interaction (e.g. mapper TOP
## control point dragging, WebRender mouse forwarding).
## Return [code]true[/code] to consume the event.  If the operator does not
## consume it, the base dispatches to the family's [GNDataRenderer] for
## default data-type interaction (orbit drag, scroll-to-slice, etc.).
func handle_viewer_input(_event: InputEvent, _local_pos: Vector2, viewer = null, port_index: int = 0) -> bool:
	if viewer == null:
		return false
	var data: GNData = get_output_data(port_index)
	if data != null:
		var renderer = GNFamily.get_renderer(data.get_family())
		if renderer != null:
			return renderer.handle_viewer_input(data, _event, viewer)
	return false


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
	_apply_visibility_rules()  # Set initial visibility from declarative rules
	GNLogger.debug("GNNode", "Initialized '%s' (%s/%s) — %d in, %d out, %d params" % [
		id, GNFamily.get_family_name(family), node_type,
		input_ports.size(), output_ports.size(), parameters.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Port Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Adds an input port and returns it.  [param port_label] overrides the
## display name in the UI when set (see [method GNPort.display_name]).
func add_input(port_name: String, port_family: int,
		multi: bool = false, desc: String = "", port_label: String = "") -> GNPort:
	var port := GNPort.create(port_name, port_family, input_ports.size(), true, multi, desc, port_label)
	input_ports.append(port)
	return port


## Adds an output port and returns it.  [param port_label] overrides the
## display name in the UI when set (see [method GNPort.display_name]).
func add_output(port_name: String, port_family: int,
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


## Returns the upstream GNNode connected to input [param port], or null.
## Walks the parent cook-engine's network graph to find the connection.
func get_input_node(port: int) -> GNNode:
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return null
	for conn in eng.network.get_input_connections(id):
		if conn.to_port == port:
			return eng.network.nodes.get(conn.from_node, null)
	return null


## Returns all upstream GNNodes sorted by input port index.
## Optionally skips ports below [param min_port] (useful when port 0 carries
## a different family, e.g. a DAT config input on TabContainerUI).
func get_input_nodes_sorted(min_port: int = 0) -> Array[GNNode]:
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return []
	var conns: Array = eng.network.get_input_connections(id).duplicate()
	conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)
	var result: Array[GNNode] = []
	for conn in conns:
		if conn.to_port < min_port:
			continue
		var node: GNNode = eng.network.nodes.get(conn.from_node, null)
		if node != null:
			result.append(node)
	return result


## Replaces all input ports with [param count] sequentially-named ports of the
## given [param port_family].  Emits [signal ports_changed] so the graph editor
## can prune stale connections and rebuild slots.  Use from subclass overrides of
## [method _on_parameter_changed] to implement dynamic port counts.
##
## [param count]       — desired number of input ports (clamped ≥ 0).
## [param port_family] — GNFamily.Type for every port.
## [param name_prefix] — port names become "prefix0", "prefix1", …
## [param desc_prefix] — port descriptions become "Prefix 0", "Prefix 1", …
func set_input_count(count: int, port_family: int,
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
func set_output_count(count: int, port_family: int,
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
func _enable_dynamic_inputs(port_family: int,
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
		GNLogger.warn("Node", "'%s': unknown parameter '%s'" % [id, param_name])
		return null
	return param.get_resolved_value()


## Programmatically sets a parameter's constant value.
## Useful for operators that auto-detect values (e.g., resolution from a loaded file).
func set_param_value(p_name: String, new_value: Variant) -> void:
	var param: GNParameter = get_parameter(p_name)
	if param == null:
		GNLogger.warn("Node", "'%s': unknown parameter '%s'" % [id, p_name])
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


## Refreshes all dynamic enum params by calling their callbacks.
## Resolves saved indices against the live device list using name matching.
## If the saved name is no longer available, sets node_warning and keeps the
## stale index — does NOT silently redirect to a different device.
## Call once on first _cook() for any node with dynamic enum device params.
func refresh_dynamic_enums() -> void:
	for param_name in parameters:
		var param: GNParameter = parameters[param_name]
		if param.value_type != GNParameter.ValueType.ENUM:
			continue
		if not param.dynamic_enum_callback.is_valid():
			continue
		var fresh: PackedStringArray = param.dynamic_enum_callback.call()
		if fresh.is_empty():
			continue
		var prev_name: String = param.saved_enum_label
		param.enum_options = fresh
		var new_idx: int = -1
		if not prev_name.is_empty():
			for i in range(fresh.size()):
				if fresh[i] == prev_name:
					new_idx = i
					break
		if new_idx >= 0:
			param.value = new_idx
			param.saved_enum_label = fresh[new_idx]
		else:
			# Device gone -- warn without redirecting to another device
			if not prev_name.is_empty() and not prev_name.begins_with("(") and prev_name != "All":
				node_warning = "Device '%s' not found. Reconnect or re-select." % prev_name



## Returns the human-readable label for an ENUM parameter.
## Returns saved_enum_label if set, else the current option text from enum_options,
## else empty string. Use in expressions via par_label().
func get_enum_label(param_name: String) -> String:
	var p: GNParameter = get_parameter(param_name)
	if p == null or p.value_type != GNParameter.ValueType.ENUM:
		return ""
	if not p.saved_enum_label.is_empty():
		return p.saved_enum_label
	var idx: int = int(p.get_resolved_value())
	if idx >= 0 and idx < p.enum_options.size():
		return p.enum_options[idx]
	return ""

## Clears the dirty flag after a successful cook.
func clear_dirty() -> void:
	dirty = false


## Returns true if the given output port has demand from an active consumer
## this frame.  Demand is detected from four sources:
##   1. Wire connections to active downstream nodes
##   2. Wireless Select operators referencing this node by name
##   3. Expression references (chop(), top(), dat(), etc.) in other nodes
##   4. Viewer sinks displaying a specific output port
##
## Each port is evaluated independently — no port is auto-demanded.
## The operator's [method _cook] unconditional code IS the shared core.
## Per-port post-processing should be guarded with this method:
##
## [codeblock]
## func _cook(inputs) -> GNData:
##     _run_detection(inputs)               # shared core — always
##     if is_output_demanded(0):
##         _build_overlay()                 # port 0 — only if demanded
##     if is_output_demanded(1):
##         _extract_tracking_data()         # port 1 — only if demanded
##     return cached_output
## [/codeblock]
##
## For operators where a secondary port depends on the primary cook path
## (e.g., MovieFileInTOP: video decode is always needed), keep the shared
## work unconditional and guard only the secondary post-processing:
##
## [codeblock]
## func _cook(inputs) -> GNData:
##     var result := _decode_video(inputs)  # shared — always (audio needs this)
##     if is_output_demanded(1):
##         _pull_audio()                    # port 1 — only if demanded
##     return result
## [/codeblock]
func is_output_demanded(port_index: int) -> bool:
	if port_index < _demanded_outputs.size():
		return _demanded_outputs[port_index]
	# Fallback: single-output or not yet stamped → always demanded
	return true


## Returns the cooked output data for a specific output port index.
## Most nodes have a single output and always return [member cached_output].
## Override in multi-output nodes (e.g., SubNetworkNode) to route different
## ports to different data objects.
func get_output_data(port_index: int) -> GNData:
	return cached_output


## Returns the cooked output data for a port matched by name.
## Accepts either [member GNPort.port_name] or [member GNPort.label]
## (case-insensitive).  Returns [code]null[/code] if no port matches.
## This enables expression syntax like [code]vol("fluid1", "Density")[/code].
func get_output_data_by_name(port_name_or_label: String) -> GNData:
	var lower := port_name_or_label.to_lower()
	for port in output_ports:
		if port.port_name.to_lower() == lower:
			return get_output_data(port.index)
		if not port.label.is_empty() and port.label.to_lower() == lower:
			return get_output_data(port.index)
	return null


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
	cooked_this_frame = true

	if result != null:
		result.timestamp = frame
		result.valid = true
		cached_output = result
		cook_valid = true
	else:
		cached_output = null
		# Null is valid for sinks and UI nodes — they produce side-effects,
		# not GNData.  Only flag as invalid if the node has output ports
		# that downstream nodes expect data from.
		if is_sink or family == GNFamily.Type.UI or output_ports.is_empty():
			cook_valid = true
		else:
			cook_valid = false
			GNLogger.debug("GNNode", "'%s' cook produced null output" % id)

	clear_dirty()
	node_cooked.emit(id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Internal Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

## Called when any parameter's value changes — marks this node dirty.
## Also evaluates declarative visibility rules if any sibling parameter
## references the changed parameter.
func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	mark_dirty()
	parameter_changed.emit(id, param_name)
	_apply_visibility_rules(param_name)


## Called when any parameter's mode changes (constant ↔ expression ↔ bind).
## Marks dirty so the node re-cooks with the new mode's resolved value.
func _on_parameter_mode_changed(param_name: String, _new_mode: int) -> void:
	mark_dirty()
	parameter_changed.emit(id, param_name)


## Evaluates declarative [member GNParameter.visibility_rule] entries.
## Called when [param changed_param] updates — checks if any sibling parameter
## has a visibility_rule referencing it, then sets [member GNParameter.visible].
## Emits [signal parameters_changed] once if any visibility state changed.
##
## Pass "" to evaluate ALL rules (used on load / init).
func _apply_visibility_rules(changed_param: String = "") -> void:
	var any_changed := false
	for key in parameters:
		var param: GNParameter = parameters[key]
		var rule: Dictionary = param.visibility_rule
		if rule.is_empty():
			continue
		var ctrl_name: String = rule.get("param", "")
		if ctrl_name.is_empty():
			continue
		# Skip rules that don't reference the changed parameter (unless full eval)
		if not changed_param.is_empty() and ctrl_name != changed_param:
			continue
		var ctrl_param: GNParameter = parameters.get(ctrl_name, null)
		if ctrl_param == null:
			continue
		var allowed_values: Array = rule.get("values", [])
		var current_value = ctrl_param.value if ctrl_param.resolved_value == null else ctrl_param.resolved_value
		var new_visible: bool = allowed_values.has(int(current_value))
		if param.visible != new_visible:
			param.visible = new_visible
			any_changed = true
	if any_changed:
		parameters_changed.emit(id)


## Called when this node transitions between active and inactive states.
## Override in subclasses that own scene-tree children which process
## independently (e.g. VideoStreamPlayer, AudioStreamPlayer).
func _on_active_changed(_active: bool) -> void:
	pass


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
	# Placeholder nodes preserve the original serialized data so re-saving a patch
	# that contains operators from missing extensions doesn't lose information.
	if not _placeholder_data.is_empty():
		# Update only the position (user may have moved it in the editor)
		var d := _placeholder_data.duplicate(true)
		d["position"] = [graph_position.x, graph_position.y]
		return d

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

	# Evaluate declarative visibility rules after all params are restored
	_apply_visibility_rules()


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
