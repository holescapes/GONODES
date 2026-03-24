class_name ScriptDAT
extends GNDatBase
## User-scripted DAT operator.  Write GDScript to generate or transform
## table/text data.  Input ports and inspector parameters are declared via
## comment annotations:
##
##   # @input dat  Upstream table
##   # @param int rows 10 Number of rows
##
## The script must define a cook() function.  An optional setup() function
## runs once after each recompilation.
##
## Available context inside cook() / setup():
##   me      — this GNNode (access id, family, etc.)
##   inputs  — Array[GNData] from upstream nodes
##   op      — pre-prepared GNTableData (call set_headers, append_row, set_text, etc.)
##   time    — elapsed seconds since start
##   frame   — current frame number
##   dt      — delta time this frame
##   par(n)  — shorthand for me.get_param_value(n)
##   chop(), op_ref(), top(), sop(), dat() — cross-reference other nodes

const DEFAULT_CODE := """# @input dat Input table

# @param int rows 5 Number of data rows
# @param string prefix Row Row name prefix

func cook():
	op.set_headers(PackedStringArray(["name", "index", "time"]))
	var n = par("rows")
	var pfx = par("prefix")
	for i in range(n):
		op.append_row(PackedStringArray([
			"%s_%d" % [pfx, i],
			str(i),
			"%.2f" % time,
		]))
"""

const _STATIC_PARAMS: PackedStringArray = [
	"time_dependent", "cook_once", "force_active", "code",
]

var _helper: GNScriptHelper = GNScriptHelper.new()
var _last_code: String = ""


func _init() -> void:
	node_type = "script"
	thread_safe = false  # user code can call set_par / network_*


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.DAT, false, "Input table", "Input 0")
	add_output("out", GNFamily.Type.DAT, "Script output table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", false,
		"Time Dependent", "Re-cook every frame even when inputs haven't changed"))
	add_parameter(GNParameter.create_bool("cook_once", false,
		"Cook Once", "Pulse: toggle ON to force a single cook, auto-resets to OFF"))
	add_parameter(GNParameter.create_bool("force_active", false,
		"Force Active", "Keep this node's chain alive even without a downstream sink (headless/side-effect scripts)"))
	add_parameter(GNParameter.create_string("code", DEFAULT_CODE.strip_edges(),
		"Script Code", "GDScript code with cook() function and @param/@input annotations"))


func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	is_sink = get_param_value("force_active")
	# Cook-once pulse: mark dirty for one frame, then auto-reset
	if get_param_value("cook_once"):
		mark_dirty()
		set_param_value("cook_once", false)
	super._pre_cook(delta)


func _cook(inputs: Array[GNData]) -> GNData:
	var code: String = get_param_value("code")

	if code != _last_code:
		_last_code = code
		_helper.on_code_changed(self, code)

	if not _helper.script_ok:
		return _cached_table if _cached_table != null else _prepare_table()

	var output := _prepare_table()
	var engine: Node = get_parent()

	if _helper.run_cook(self, inputs, output, engine):
		return output
	else:
		return _cached_table if _cached_table != null else output


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("code")
	if not code.is_empty():
		_last_code = code
		_helper.on_code_changed(self, code)
	if d.has("parameters"):
		GNScriptHelper.restore_dynamic_param_values(self, d["parameters"], _STATIC_PARAMS)
