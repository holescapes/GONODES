class_name ScriptIMG
extends GNImgBase
## User-scripted IMG operator.  Write GDScript to generate or transform
## CPU-side Images.  For GPU shaders, use CustomShaderTOP instead.
## For GPU texture output, pipe this into ImgToTOP.
##
## Input ports and inspector parameters are declared via annotations:
##
##   # @input img  Background image
##   # @input chop Animation data
##   # @param vec2i resolution 256,256 Output size
##
## The script must define a cook() function.  An optional setup() function
## runs once after each recompilation.
##
## Available context inside cook() / setup():
##   me      — this GNNode (access id, family, etc.)
##   inputs  — Array[GNData] from upstream nodes
##   op      — GNImageData helper (call op.set_image(img) to output)
##   time    — elapsed seconds since start
##   frame   — current frame number
##   dt      — delta time this frame
##   par(n)  — shorthand for me.get_param_value(n)
##   chop(), op_ref(), top(), sop(), dat() — cross-reference other nodes
##
## Image workflow:
##   var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
##   img.fill(Color.BLACK)
##   # ... draw pixels ...
##   op.set_image(img)

const DEFAULT_CODE := """# @input img Input image

# @param vec2i resolution 256,256 Output resolution
# @param color fill_color #000000 Background fill color

func cook():
	var res = par("resolution")
	var img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	img.fill(par("fill_color"))

	# Example: draw a moving white rectangle
	var cx = int(res.x * (0.5 + 0.4 * sin(time)))
	var cy = res.y / 2
	var half_w = 20
	var half_h = 20
	for x in range(maxi(cx - half_w, 0), mini(cx + half_w, res.x)):
		for y in range(maxi(cy - half_h, 0), mini(cy + half_h, res.y)):
			img.set_pixel(x, y, Color.WHITE)

	op.set_image(img)
"""

const _STATIC_PARAMS: PackedStringArray = [
	"time_dependent", "cook_once", "force_active", "code",
]

var _helper: GNScriptHelper = GNScriptHelper.new()
var _last_code: String = ""


func _init() -> void:
	node_type = "scriptimg"
	node_description = "User-scripted IMG. Write GDScript to generate or transform CPU-side Images."


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Script output image")


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

	# Ensure output infrastructure
	var out := _prepare_image()

	if not _helper.script_ok:
		return out

	var engine: Node = get_parent()

	_helper.run_cook(self, inputs, out, engine)
	return out


## Override from_dict to restore dynamic params after recompilation.
func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("code")
	_last_code = code
	_helper.on_code_changed(self, code)
	if d.has("parameters"):
		GNScriptHelper.restore_dynamic_param_values(self, d["parameters"],
			_STATIC_PARAMS)
