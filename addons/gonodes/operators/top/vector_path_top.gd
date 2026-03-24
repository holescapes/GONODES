class_name VectorPathTOP
extends GNTopBase
## Anti-aliased 2D vector path rendering TOP.
##
## Draws smooth Bézier curves, polylines, circles, arcs, and polygons
## into a SubViewport using Godot's CanvasItem draw API with
## anti-aliasing enabled.  Approximates Skia-quality 2D vector output
## for motion graphics, data visualization, and generative art.
##
## Input CHOP drives point positions (channels: x0,y0, x1,y1, …).
## Input DAT drives SVG-like path commands (M, L, C, Q, A, Z).
##
## VVVV equivalent: VL.Skia path rendering.

var _draw_control: _VectorDrawControl = null
var _bg: ColorRect = null


func _init() -> void:
	node_type = "vector_path"
	node_description = "Anti-aliased 2D vector path rendering (lines, curves, shapes)."


func _init_ports() -> void:
	add_input("points", GNFamily.Type.CHOP, false, "Point positions (x0,y0,x1,y1,…)")
	add_input("commands", GNFamily.Type.DAT, false, "SVG-like path commands (M,L,C,Q,A,Z)")
	add_output("out", GNFamily.Type.TOP, "Rendered vector graphics texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output texture resolution"))
	add_parameter(GNParameter.create_enum("shape",
		PackedStringArray(["Polyline", "Polygon", "Circle", "Arc", "Path Commands"]), 0,
		"Shape", "Drawing primitive type"))
	add_parameter(GNParameter.create_color("stroke_color", Color.WHITE,
		"Stroke Color", "Line/stroke color"))
	add_parameter(GNParameter.create_float("stroke_width", 2.0, 0.5, 50.0, 0.5,
		"Stroke Width", "Line width in pixels"))
	add_parameter(GNParameter.create_color("fill_color", Color(0.2, 0.4, 0.8, 0.5),
		"Fill Color", "Fill color (polygons/circles)"))
	add_parameter(GNParameter.create_bool("fill", false,
		"Fill", "Enable fill for closed shapes"))
	add_parameter(GNParameter.create_bool("closed", false,
		"Closed", "Close the polyline into a loop"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK,
		"Background", "Background color"))
	# Circle/Arc params
	add_parameter(GNParameter.create_float("radius", 100.0, 1.0, 10000.0, 1.0,
		"Radius", "Circle/arc radius in pixels"))
	add_parameter(GNParameter.create_float("arc_start", 0.0, -360.0, 360.0, 1.0,
		"Arc Start", "Arc start angle in degrees"))
	add_parameter(GNParameter.create_float("arc_end", 360.0, -360.0, 360.0, 1.0,
		"Arc End", "Arc end angle in degrees"))
	add_parameter(GNParameter.create_int("arc_segments", 64, 3, 512,
		"Segments", "Number of segments for circles/arcs"))
	# Line cap/join
	add_parameter(GNParameter.create_enum("line_cap",
		PackedStringArray(["Butt", "Round", "Square"]), 1,
		"Line Cap", "End-cap style for open paths"))
	add_parameter(GNParameter.create_bool("antialiased", true,
		"Anti-aliased", "Enable anti-aliasing on lines"))


func _cook(inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var res: Vector2i = get_param_value("resolution")
	if _viewport.size != res:
		_viewport.size = res

	_bg.color = get_param_value("bg_color")

	# Collect draw data for the control
	_draw_control.shape = get_param_value("shape")
	_draw_control.stroke_color = get_param_value("stroke_color")
	_draw_control.stroke_width = get_param_value("stroke_width")
	_draw_control.fill_color = get_param_value("fill_color")
	_draw_control.do_fill = get_param_value("fill")
	_draw_control.closed = get_param_value("closed")
	_draw_control.radius = get_param_value("radius")
	_draw_control.arc_start_deg = get_param_value("arc_start")
	_draw_control.arc_end_deg = get_param_value("arc_end")
	_draw_control.arc_segments = get_param_value("arc_segments")
	_draw_control.antialiased = get_param_value("antialiased")
	_draw_control.line_cap = get_param_value("line_cap")
	_draw_control.viewport_size = Vector2(res)

	# Build points from CHOP input
	_draw_control.points.clear()
	var chop_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if chop_data != null:
		_points_from_chop(chop_data)

	# Build path commands from DAT input
	_draw_control.path_commands.clear()
	var dat_data: GNTableData = inputs[1] as GNTableData if inputs.size() > 1 and inputs[1] is GNTableData else null
	if dat_data != null:
		_commands_from_dat(dat_data)

	# If no input, generate a default shape
	if _draw_control.points.is_empty() and _draw_control.path_commands.is_empty():
		if _draw_control.shape <= 1:  # Polyline/Polygon — default star
			_generate_default_star(res)

	_draw_control.queue_redraw()

	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# Input Parsing
# ═══════════════════════════════════════════════════════════════════════════════

func _points_from_chop(chop: GNChannelData) -> void:
	var names: PackedStringArray = chop.get_channel_names()
	# Try paired channels: x0,y0,x1,y1,...
	var i: int = 0
	while i + 1 < names.size():
		var nx: String = names[i]
		var ny: String = names[i + 1]
		if (nx.begins_with("x") and ny.begins_with("y")) or \
		   (nx.ends_with("x") and ny.ends_with("y")):
			_draw_control.points.append(Vector2(
				chop.get_value(nx), chop.get_value(ny)))
			i += 2
		else:
			i += 1

	# Fallback: channels named tx,ty (single point)
	if _draw_control.points.is_empty() and names.has("tx") and names.has("ty"):
		_draw_control.points.append(Vector2(chop.get_value("tx"), chop.get_value("ty")))


func _commands_from_dat(dat: GNTableData) -> void:
	if not dat.is_table or dat.table.size() < 2:
		return
	# Expected columns: command, x, y, [x2, y2, x3, y3]
	for row_idx in range(1, dat.table.size()):  # Skip header
		var row: PackedStringArray = dat.table[row_idx]
		if row.is_empty():
			continue
		var cmd := {"type": row[0].strip_edges().to_upper()}
		if row.size() >= 3:
			cmd["x"] = row[1].to_float()
			cmd["y"] = row[2].to_float()
		if row.size() >= 5:
			cmd["x2"] = row[3].to_float()
			cmd["y2"] = row[4].to_float()
		if row.size() >= 7:
			cmd["x3"] = row[5].to_float()
			cmd["y3"] = row[6].to_float()
		_draw_control.path_commands.append(cmd)


func _generate_default_star(res: Vector2i) -> void:
	var cx: float = res.x * 0.5
	var cy: float = res.y * 0.5
	var r_out: float = minf(cx, cy) * 0.8
	var r_in: float = r_out * 0.4
	var spikes: int = 5
	for i in range(spikes * 2):
		var angle: float = PI * 2.0 * float(i) / float(spikes * 2) - PI / 2.0
		var r: float = r_out if i % 2 == 0 else r_in
		_draw_control.points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))


# ═══════════════════════════════════════════════════════════════════════════════
# Viewport Setup
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"), true)

	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_draw_control = _VectorDrawControl.new()
	_draw_control.name = "VectorDraw"
	_viewport.add_child(_draw_control)
	_draw_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ═══════════════════════════════════════════════════════════════════════════════
# Inner Drawing Control
# ═══════════════════════════════════════════════════════════════════════════════

class _VectorDrawControl extends Control:
	## Drawing data set by the parent TOP each cook.
	var shape: int = 0
	var stroke_color: Color = Color.WHITE
	var stroke_width: float = 2.0
	var fill_color: Color = Color(0.2, 0.4, 0.8, 0.5)
	var do_fill: bool = false
	var closed: bool = false
	var radius: float = 100.0
	var arc_start_deg: float = 0.0
	var arc_end_deg: float = 360.0
	var arc_segments: int = 64
	var antialiased: bool = true
	var line_cap: int = 1  # 0=butt, 1=round, 2=square
	var viewport_size: Vector2 = Vector2(512, 512)
	var points: PackedVector2Array = PackedVector2Array()
	var path_commands: Array[Dictionary] = []

	func _draw() -> void:
		match shape:
			0:  # Polyline
				_draw_polyline_shape()
			1:  # Polygon
				_draw_polygon_shape()
			2:  # Circle
				_draw_circle_shape()
			3:  # Arc
				_draw_arc_shape()
			4:  # Path Commands
				_draw_path_commands()


	func _draw_polyline_shape() -> void:
		if points.size() < 2:
			return
		var pts: PackedVector2Array = points
		if closed and pts.size() >= 3:
			pts = pts.duplicate()
			pts.append(pts[0])
		draw_polyline(pts, stroke_color, stroke_width, antialiased)
		# Round caps
		if line_cap == 1 and not closed:
			var cap_r: float = stroke_width * 0.5
			draw_circle(pts[0], cap_r, stroke_color)
			draw_circle(pts[pts.size() - 1], cap_r, stroke_color)


	func _draw_polygon_shape() -> void:
		if points.size() < 3:
			return
		if do_fill:
			draw_colored_polygon(points, fill_color)
		# Outline
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, stroke_color, stroke_width, antialiased)


	func _draw_circle_shape() -> void:
		var center := viewport_size * 0.5
		if do_fill:
			draw_circle(center, radius, fill_color)
		# Outline via arc
		draw_arc(center, radius, 0.0, TAU, arc_segments, stroke_color, stroke_width, antialiased)


	func _draw_arc_shape() -> void:
		var center := viewport_size * 0.5
		var start_rad: float = deg_to_rad(arc_start_deg)
		var end_rad: float = deg_to_rad(arc_end_deg)
		if do_fill:
			# Fill arc as polygon
			var fill_pts := PackedVector2Array()
			fill_pts.append(center)
			var angle_span: float = end_rad - start_rad
			for i in range(arc_segments + 1):
				var t: float = float(i) / float(arc_segments)
				var a: float = start_rad + angle_span * t
				fill_pts.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(fill_pts, fill_color)
		draw_arc(center, radius, start_rad, end_rad, arc_segments,
			stroke_color, stroke_width, antialiased)


	func _draw_path_commands() -> void:
		if path_commands.is_empty():
			return
		# Execute SVG-like commands: M(move), L(line), C(cubic), Q(quad), Z(close)
		var cursor := Vector2.ZERO
		var path_start := Vector2.ZERO
		var segments: PackedVector2Array = PackedVector2Array()

		for cmd: Dictionary in path_commands:
			var t: String = cmd.get("type", "")
			match t:
				"M":
					# Flush previous segments
					if segments.size() >= 2:
						draw_polyline(segments, stroke_color, stroke_width, antialiased)
					segments.clear()
					cursor = Vector2(cmd.get("x", 0.0), cmd.get("y", 0.0))
					path_start = cursor
					segments.append(cursor)
				"L":
					cursor = Vector2(cmd.get("x", 0.0), cmd.get("y", 0.0))
					segments.append(cursor)
				"C":  # Cubic Bézier
					var cp1 := Vector2(cmd.get("x", 0.0), cmd.get("y", 0.0))
					var cp2 := Vector2(cmd.get("x2", 0.0), cmd.get("y2", 0.0))
					var end := Vector2(cmd.get("x3", 0.0), cmd.get("y3", 0.0))
					_cubic_bezier_to(segments, cursor, cp1, cp2, end, 16)
					cursor = end
				"Q":  # Quadratic Bézier
					var cp := Vector2(cmd.get("x", 0.0), cmd.get("y", 0.0))
					var end := Vector2(cmd.get("x2", 0.0), cmd.get("y2", 0.0))
					_quad_bezier_to(segments, cursor, cp, end, 16)
					cursor = end
				"Z":
					segments.append(path_start)
					cursor = path_start

		# Flush remaining
		if segments.size() >= 2:
			draw_polyline(segments, stroke_color, stroke_width, antialiased)


	func _cubic_bezier_to(pts: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> void:
		for i in range(1, steps + 1):
			var t: float = float(i) / float(steps)
			var it: float = 1.0 - t
			var pos: Vector2 = it * it * it * p0 + 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t * p3
			pts.append(pos)


	func _quad_bezier_to(pts: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, steps: int) -> void:
		for i in range(1, steps + 1):
			var t: float = float(i) / float(steps)
			var it: float = 1.0 - t
			var pos: Vector2 = it * it * p0 + 2.0 * it * t * p1 + t * t * p2
			pts.append(pos)
