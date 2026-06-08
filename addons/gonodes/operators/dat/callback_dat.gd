class_name CallbackDAT
extends GNDatBase
## Event-driven callback DAT.  Holds named GDScript snippets that fire
## automatically when specific events occur on a **target node** connected
## to the first input port.
##
## Supported callbacks (each is a code string parameter):
##   onStart        — runs once on the first cook frame
##   onCook         — runs every time the target node finishes cooking
##   onValueChange  — runs when any parameter on the target node changes
##   onCreate       — runs once when the CallbackDAT itself is first cooked
##   onDestroy      — (reserved) would run when the target node is removed
##
## Context variables available in every callback (same as Script operators):
##   me, inputs, op (this DAT's table output), time, frame, dt
##   par(), chop(), top(), sop(), dat(), op_ref()
##   set_par(), network_add_node(), network_connect(), etc.
##   target   — the GNNode connected to the first input (or null)
##   event    — String name of the callback being executed (e.g. "onCook")
##
## The DAT output table logs recent event executions with timestamps.
##
## Wire the target node into input 0.  The CallbackDAT observes signals on
## that node and self-triggers when events happen.

const MAX_LOG_ROWS: int = 50

const DEFAULT_ON_START := """# Runs once on the first cook frame.
# Example: initialise a parameter on the target node.
# if target:
#     set_par(target.id, "speed", 1.0)
print("[CallbackDAT] onStart — target: ", target.id if target else "none")
"""

const DEFAULT_ON_COOK := """# Runs after the target node finishes cooking.
# 'target' is the GNNode connected to input 0.
# Example: read the target's output and log it.
# if target:
#     var v = chop(target.id, "out")
#     print("[onCook] target output: ", v)
"""

const DEFAULT_ON_VALUE_CHANGE := """# Runs when a parameter on the target node changes.
# 'event_param' holds the name of the changed parameter.
# Example: mirror a param change to another node.
# set_par("other_node", event_param, par(target.id, event_param))
"""

const DEFAULT_ON_CREATE := """# Runs once when the CallbackDAT is first cooked.
# Good for one-time setup, building initial graph structure, etc.
# Example:
# var nid = network_add_node("NoiseTOP")
# set_par(nid, "resolution", Vector2i(256, 256))
"""

## Static param names.
const _STATIC_PARAMS: PackedStringArray = [
	"time_dependent", "active", "on_start", "on_cook",
	"on_value_change", "on_create", "log_events",
]

## Script helper for compiling/running callbacks.
var _helpers: Dictionary = {}  # callback name → GNScriptHelper

## Tracks whether onStart has already fired.
var _start_fired: bool = false

## Tracks whether onCreate has already fired.
var _create_fired: bool = false

## The node currently connected to input 0 (target).
var _target_node: GNNode = null

## Signal connection tracking to avoid stale connections.
var _connected_target_id: String = ""

## Event log rows for DAT output.
var _event_log: Array[PackedStringArray] = []

## Pending events queued by signal callbacks to be processed during cook.
var _pending_events: Array[Dictionary] = []


func _init() -> void:
	node_type = "callback"
	thread_safe = false  # event handlers call set_par / network_*


func _init_ports() -> void:
	# Input 0: any family — the target node to observe.
	# We use CHOP as default but accept any family via the palette.
	add_input("target", GNFamily.Type.CHOP, false, "Target node to observe", "Target")
	add_output("out", GNFamily.Type.DAT, "Event log table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame to poll events"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable all callbacks"))
	add_parameter(GNParameter.create_bool("log_events", true,
		"Log Events", "Output event execution log as DAT table"))
	add_parameter(GNParameter.create_string("on_start", DEFAULT_ON_START.strip_edges(),
		"onStart", "Script that runs once on the first cook frame"))
	add_parameter(GNParameter.create_string("on_cook", DEFAULT_ON_COOK.strip_edges(),
		"onCook", "Script that runs after the target node cooks"))
	add_parameter(GNParameter.create_string("on_value_change", DEFAULT_ON_VALUE_CHANGE.strip_edges(),
		"onValueChange", "Script that runs when a target parameter changes"))
	add_parameter(GNParameter.create_string("on_create", DEFAULT_ON_CREATE.strip_edges(),
		"onCreate", "Script that runs once when this CallbackDAT is first cooked"))


func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	super._pre_cook(delta)


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var output := _prepare_table()

	# ── Resolve target node ──
	_resolve_target()

	if not active:
		return _build_log_output(output)

	var engine: Node = get_parent()

	# ── onCreate (once) ──
	if not _create_fired:
		_create_fired = true
		_run_callback("on_create", engine, "onCreate")

	# ── onStart (once) ──
	if not _start_fired:
		_start_fired = true
		_run_callback("on_start", engine, "onStart")

	# ── Process pending events from signal callbacks ──
	var events_copy := _pending_events.duplicate()
	_pending_events.clear()
	for evt in events_copy:
		var cb_name: String = evt.get("callback", "")
		var event_label: String = evt.get("event", "")
		var event_param: String = evt.get("param", "")
		_run_callback(cb_name, engine, event_label, event_param)

	return _build_log_output(output)


# ═══════════════════════════════════════════════════════════════════════════════
# Target Node Observation
# ═══════════════════════════════════════════════════════════════════════════════

## Resolves the target node from the upstream connection and wires signals.
func _resolve_target() -> void:
	var new_target: GNNode = get_input_node(0)

	var new_target_id: String = new_target.id if new_target != null else ""

	# Skip if same target
	if new_target_id == _connected_target_id:
		_target_node = new_target
		return

	# Disconnect old signals
	if _target_node != null and is_instance_valid(_target_node):
		if _target_node.node_cooked.is_connected(_on_target_cooked):
			_target_node.node_cooked.disconnect(_on_target_cooked)
		if _target_node.parameter_changed.is_connected(_on_target_param_changed):
			_target_node.parameter_changed.disconnect(_on_target_param_changed)

	_target_node = new_target
	_connected_target_id = new_target_id

	# Connect new signals
	if _target_node != null:
		_target_node.node_cooked.connect(_on_target_cooked)
		_target_node.parameter_changed.connect(_on_target_param_changed)
		GNLogger.info("CallbackDAT", "'%s' now observing target '%s'" % [id, _target_node.id])


## Signal handler: target node finished cooking.
func _on_target_cooked(_node_id: String) -> void:
	_pending_events.append({
		"callback": "on_cook",
		"event": "onCook",
		"param": "",
	})
	mark_dirty()


## Signal handler: target node parameter changed.
func _on_target_param_changed(_node_id: String, param_name: String) -> void:
	_pending_events.append({
		"callback": "on_value_change",
		"event": "onValueChange",
		"param": param_name,
	})
	mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# Callback Execution
# ═══════════════════════════════════════════════════════════════════════════════

## Compiles (if needed) and runs a callback script.
func _run_callback(param_name: String, engine: Node,
		event_label: String, event_param: String = "") -> void:
	var code: String = get_param_value(param_name)
	if code.strip_edges().is_empty():
		return

	# Get or create helper for this callback
	if not _helpers.has(param_name):
		_helpers[param_name] = GNScriptHelper.new()
	var helper: GNScriptHelper = _helpers[param_name]

	# Wrap the callback code in a cook() function so GNScriptHelper can execute it.
	# Inject 'target' and 'event' as extra context variables.
	var wrapped_code := _wrap_callback_code(code, event_label, event_param)

	# Compile (skips if code unchanged)
	helper.compile(wrapped_code)
	if not helper.script_ok:
		_log_event(event_label, "COMPILE ERROR: %s" % helper.compile_error)
		return

	# Inject extra context
	if helper._instance != null:
		helper._instance.set("target", _target_node)
		helper._instance.set("event", event_label)
		helper._instance.set("event_param", event_param)

	# Run
	var inputs_arr: Array[GNData] = []
	var output := _cached_table if _cached_table != null else GNTableData.new()
	if helper.run_cook(self, inputs_arr, output, engine):
		_log_event(event_label, "OK")
	else:
		_log_event(event_label, "RUNTIME ERROR")


## Wraps user callback code in a cook() function with extra context variables.
func _wrap_callback_code(code: String, event_label: String,
		event_param: String) -> String:
	# Add target/event variables before the user code, plus wrap in cook()
	var lines := PackedStringArray()
	lines.append("var target: GNNode = null")
	lines.append("var event: String = \"%s\"" % event_label)
	lines.append("var event_param: String = \"%s\"" % event_param)
	lines.append("")
	lines.append("func cook():")
	# Indent user code under cook()
	for line in code.split("\n"):
		lines.append("\t" + line)
	return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════════════
# Event Log
# ═══════════════════════════════════════════════════════════════════════════════

## Appends an event to the rolling log.
func _log_event(event_label: String, status: String) -> void:
	var timestamp := "%.2f" % elapsed_time
	_event_log.append(PackedStringArray([timestamp, event_label, status,
		_target_node.id if _target_node != null else ""]))
	# Trim old entries
	while _event_log.size() > MAX_LOG_ROWS:
		_event_log.remove_at(0)


## Builds the DAT output table from the event log.
func _build_log_output(output: GNTableData) -> GNTableData:
	if not get_param_value("log_events"):
		output.is_table = true
		output.has_header = true
		output.table = [PackedStringArray(["time", "event", "status", "target"])]
		return output

	output.is_table = true
	output.has_header = true
	output.table.clear()
	output.table.append(PackedStringArray(["time", "event", "status", "target"]))
	for row in _event_log:
		output.table.append(row)
	return output


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	# Re-compile all callback scripts after load
	for cb_name in ["on_start", "on_cook", "on_value_change", "on_create"]:
		var code: String = get_param_value(cb_name)
		if not code.strip_edges().is_empty():
			if not _helpers.has(cb_name):
				_helpers[cb_name] = GNScriptHelper.new()
