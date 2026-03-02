class_name ScriptSOP
extends GNSopBase
## User-scripted SOP operator.  Write GDScript to generate or transform
## 3D geometry.  Input ports and inspector parameters are declared via
## comment annotations:
##
##   # @input sop  Source geometry
##   # @param float radius 2.0 Scatter radius
##
## The script must define a cook() function.  An optional setup() function
## runs once after each recompilation.
##
## Available context inside cook() / setup():
##   me      — this GNNode (access id, family, etc.)
##   inputs  — Array[GNData] from upstream nodes
##   op      — pre-prepared GNGeoData (use SurfaceTool to build mesh, then op.set_from_surface_tool())
##   time    — elapsed seconds since start
##   frame   — current frame number
##   dt      — delta time this frame
##   par(n)  — shorthand for me.get_param_value(n)
##   chop(), op_ref(), top(), sop(), dat() — cross-reference other nodes
##
## Geometry building pattern:
##   var st = SurfaceTool.new()
##   st.begin(Mesh.PRIMITIVE_TRIANGLES)
##   # ... add vertices, normals, UVs ...
##   st.generate_normals()
##   op.set_from_surface_tool(st)

const DEFAULT_CODE := """# @input sop Source geometry

# @param int count 50 Number of scattered points
# @param float radius 2.0 Scatter radius
# @param int seed 0 Random seed (0 = use frame)

func cook():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var rng = RandomNumberGenerator.new()
	rng.seed = par("seed") if par("seed") != 0 else frame

	var r = par("radius")
	for i in range(par("count")):
		var pos = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized() * r * rng.randf()
		st.set_normal(Vector3.UP)
		st.add_vertex(pos)

	op.set_from_surface_tool(st)
"""

const _STATIC_PARAMS: PackedStringArray = [
	"time_dependent", "cook_once", "force_active", "code",
]

var _helper: GNScriptHelper = GNScriptHelper.new()
var _last_code: String = ""


func _init() -> void:
	node_type = "scriptsop"
	node_description = "User-scripted SOP. Write GDScript to generate or transform 3D geometry."


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.SOP, false, "Source geometry")
	add_output("out", GNFamily.Type.SOP, "Script output geometry")


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
		return _cached_geo if _cached_geo != null else _prepare_geo()

	var output := _prepare_geo()
	var engine: Node = get_parent()

	if _helper.run_cook(self, inputs, output, engine):
		return output
	else:
		return _cached_geo if _cached_geo != null else output


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("code")
	if not code.is_empty():
		_last_code = code
		_helper.on_code_changed(self, code)
	if d.has("parameters"):
		GNScriptHelper.restore_dynamic_param_values(self, d["parameters"], _STATIC_PARAMS)
