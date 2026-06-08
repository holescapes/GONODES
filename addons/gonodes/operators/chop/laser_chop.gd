class_name LaserCHOP
extends GNChopBase
## Laser point-list generator CHOP.
##
## Outputs XY position, RGB colour, and blanking/intensity channels for
## each point in a laser frame.  This is the standard data model used by
## laser DACs (EtherDream, Helios, ShowNET, ILDA files, etc.).
##
## The operator generates or passes through point data — it does **not**
## drive hardware directly.  Actual DAC output will be provided by
## dedicated GDExtension backends (see Roadmap).
##
## **Output channels** (per point, indexed 0…N-1):
##   • `x`  — X position (-1.0 … 1.0, centred)
##   • `y`  — Y position (-1.0 … 1.0, centred)
##   • `r`  — Red   (0.0 … 1.0)
##   • `g`  — Green (0.0 … 1.0)
##   • `b`  — Blue  (0.0 … 1.0)
##   • `i`  — Intensity / blanking (0.0 = blanked, 1.0 = full)
##
## **Built-in test patterns**: Circle, Line, Square, Spiral, ILDA Test.
## Feed an input CHOP to override with custom point data.
##
## TouchDesigner equivalent: Laser CHOP / Laser DAC CHOP.

var CHANNEL_NAMES: PackedStringArray = PackedStringArray(["x", "y", "r", "g", "b", "i"])

enum Pattern {
	CIRCLE,
	LINE,
	SQUARE,
	SPIRAL,
	ILDA_TEST,
}


func _init() -> void:
	node_type = "laser"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Optional: custom point data (overrides pattern)", "In")
	add_output("out", GNFamily.Type.CHOP, "Laser point channels (x, y, r, g, b, i)", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("pattern",
		["Circle", "Line", "Square", "Spiral", "ILDA Test"], 0,
		"Pattern", "Built-in test pattern (overridden by input)"))
	add_parameter(GNParameter.create_int("points", 200, 10, 10000,
		"Points", "Number of points in the generated frame"))
	add_parameter(GNParameter.create_float("scale", 1.0, 0.01, 2.0, 0.01,
		"Scale", "Scale factor for the pattern (1.0 = full range)"))
	add_parameter(GNParameter.create_float("rotation", 0.0, -360.0, 360.0, 0.1,
		"Rotation", "Pattern rotation in degrees"))
	add_parameter(GNParameter.create_bool("animate", false,
		"Animate", "Auto-rotate the pattern over time"))
	add_parameter(GNParameter.create_float("speed", 30.0, 0.1, 360.0, 0.1,
		"Speed", "Rotation speed in degrees/sec (when Animate is on)"))
	add_parameter(GNParameter.create_color("color", Color.GREEN,
		"Color", "Beam colour (applied uniformly unless pattern overrides)"))
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 1.0, 0.01,
		"Intensity", "Global intensity / blanking master"))
	add_parameter(GNParameter.create_int("blank_points", 5, 0, 50,
		"Blank Points", "Extra blanked points inserted at path jumps"))


# ── State ──────────────────────────────────────────────────────────────────────
var _angle_accum: float = 0.0


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output(60.0)

	# If input is provided, pass it through with validation
	var in_chop := _get_input_chop(inputs, 0)
	if in_chop != null:
		return _passthrough(in_chop, out)

	# Generate test pattern
	var num_points: int = get_param_value("points")
	var scale: float = get_param_value("scale")
	var rotation_deg: float = get_param_value("rotation")
	var animate: bool = get_param_value("animate")
	var spd: float = get_param_value("speed")
	var color: Color = get_param_value("color")
	var intensity: float = get_param_value("intensity")
	var blank_pts: int = get_param_value("blank_points")
	var pattern: int = get_param_value("pattern")

	if animate:
		_angle_accum += spd * current_delta
		_angle_accum = fmod(_angle_accum, 360.0)
	var rot_rad: float = deg_to_rad(rotation_deg + _angle_accum)

	# Allocate channel arrays
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	var bs := PackedFloat32Array()
	var inst := PackedFloat32Array()

	xs.resize(num_points)
	ys.resize(num_points)
	rs.resize(num_points)
	gs.resize(num_points)
	bs.resize(num_points)
	inst.resize(num_points)

	match pattern:
		Pattern.CIRCLE:
			_gen_circle(xs, ys, num_points, scale, rot_rad)
		Pattern.LINE:
			_gen_line(xs, ys, num_points, scale, rot_rad)
		Pattern.SQUARE:
			_gen_square(xs, ys, num_points, scale, rot_rad)
		Pattern.SPIRAL:
			_gen_spiral(xs, ys, num_points, scale, rot_rad)
		Pattern.ILDA_TEST:
			_gen_ilda_test(xs, ys, rs, gs, bs, inst, num_points, scale, rot_rad)

	# Apply colour and intensity (unless ILDA test already set them)
	if pattern != Pattern.ILDA_TEST:
		for i in range(num_points):
			rs[i] = color.r
			gs[i] = color.g
			bs[i] = color.b
			inst[i] = intensity

	# Insert blank points at the start (galvo settle)
	for i in range(mini(blank_pts, num_points)):
		inst[i] = 0.0

	out.set_channel("x", xs)
	out.set_channel("y", ys)
	out.set_channel("r", rs)
	out.set_channel("g", gs)
	out.set_channel("b", bs)
	out.set_channel("i", inst)
	out.length = num_points
	return out


## Pass-through: copy input channels, ensuring standard naming exists.
func _passthrough(input: GNChannelData, out: GNChannelData) -> GNChannelData:
	for ch_name in CHANNEL_NAMES:
		var data := input.get_channel(ch_name)
		if data.size() > 0:
			out.set_channel(ch_name, data)
		else:
			# Fill missing channels with defaults
			var fill := PackedFloat32Array()
			fill.resize(input.length if input.length > 0 else 1)
			fill.fill(0.0)
			out.set_channel(ch_name, fill)
	out.length = input.length
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Pattern Generators
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_circle(xs: PackedFloat32Array, ys: PackedFloat32Array,
		count: int, scale: float, rot: float) -> void:
	for i in range(count):
		var t: float = float(i) / float(count) * TAU
		xs[i] = cos(t + rot) * scale
		ys[i] = sin(t + rot) * scale


func _gen_line(xs: PackedFloat32Array, ys: PackedFloat32Array,
		count: int, scale: float, rot: float) -> void:
	for i in range(count):
		var t: float = float(i) / float(count - 1) * 2.0 - 1.0  # -1..1
		xs[i] = t * scale * cos(rot)
		ys[i] = t * scale * sin(rot)


func _gen_square(xs: PackedFloat32Array, ys: PackedFloat32Array,
		count: int, scale: float, rot: float) -> void:
	var per_side := count / 4
	var idx := 0
	# Four sides: right→top→left→bottom
	for side in range(4):
		for j in range(per_side):
			var t: float = float(j) / float(per_side)
			var lx: float = 0.0
			var ly: float = 0.0
			match side:
				0:  # bottom: left to right
					lx = lerpf(-1.0, 1.0, t)
					ly = -1.0
				1:  # right: bottom to top
					lx = 1.0
					ly = lerpf(-1.0, 1.0, t)
				2:  # top: right to left
					lx = lerpf(1.0, -1.0, t)
					ly = 1.0
				3:  # left: top to bottom
					lx = -1.0
					ly = lerpf(1.0, -1.0, t)
			# Apply scale and rotation
			var rx: float = (lx * cos(rot) - ly * sin(rot)) * scale
			var ry: float = (lx * sin(rot) + ly * cos(rot)) * scale
			if idx < count:
				xs[idx] = rx
				ys[idx] = ry
				idx += 1
	# Fill remaining points (if count not divisible by 4)
	while idx < count:
		xs[idx] = xs[idx - 1]
		ys[idx] = ys[idx - 1]
		idx += 1


func _gen_spiral(xs: PackedFloat32Array, ys: PackedFloat32Array,
		count: int, scale: float, rot: float) -> void:
	for i in range(count):
		var t: float = float(i) / float(count)
		var angle: float = t * TAU * 3.0 + rot  # 3 revolutions
		var radius: float = t * scale
		xs[i] = cos(angle) * radius
		ys[i] = sin(angle) * radius


## ILDA 12.2-style test pattern: concentric squares with colour segments.
func _gen_ilda_test(xs: PackedFloat32Array, ys: PackedFloat32Array,
		rs: PackedFloat32Array, gs: PackedFloat32Array,
		bs: PackedFloat32Array, inst: PackedFloat32Array,
		count: int, scale: float, rot: float) -> void:
	# Outer square in white, inner circle in rainbow
	var half := count / 2

	# Outer square (white)
	_gen_square(xs, ys, half, scale, rot)
	for i in range(half):
		rs[i] = 1.0
		gs[i] = 1.0
		bs[i] = 1.0
		inst[i] = 1.0

	# Inner circle (rainbow)
	var cx := PackedFloat32Array()
	var cy := PackedFloat32Array()
	cx.resize(count - half)
	cy.resize(count - half)
	_gen_circle(cx, cy, count - half, scale * 0.5, rot)
	for i in range(count - half):
		var idx := half + i
		xs[idx] = cx[i]
		ys[idx] = cy[i]
		# HSV rainbow around the circle
		var hue: float = float(i) / float(count - half)
		var c := Color.from_hsv(hue, 1.0, 1.0)
		rs[idx] = c.r
		gs[idx] = c.g
		bs[idx] = c.b
		inst[idx] = 1.0
