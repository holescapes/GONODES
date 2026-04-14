class_name BezierMapTOP
extends GNTopBase
## Bicubic Bezier surface warp with 4x4 control point grid.
## Uses Newton-Raphson inverse mapping from output pixel to source UV.
## Interactive overlay: drag 16 control points directly in the viewer.

# Internal names match shader uniforms: cpCR where C=col (0-3), R=row (0-3)
const _CP_NAMES: PackedStringArray = [
	"cp00", "cp10", "cp20", "cp30",
	"cp01", "cp11", "cp21", "cp31",
	"cp02", "cp12", "cp22", "cp32",
	"cp03", "cp13", "cp23", "cp33",
]

var _overlay: MapperOverlay = null
var _dragging_index: int = -1
var _viewer_ref: WeakRef = WeakRef.new()

const GRAB_RADIUS_UV := 0.035


func _init() -> void:
	node_type = "bezier_map"
	node_description = "Smooth curved surface warp using a 4x4 Bezier control grid."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Bezier-warped texture")


func _init_parameters() -> void:
	# 16 control points (4x4 grid). Default positions form a uniform grid.
	# Named by grid position: Row 0-3 (top to bottom), Col 0-3 (left to right)
	var defaults := [
		[0.0, 0.0], [0.333, 0.0], [0.667, 0.0], [1.0, 0.0],
		[0.0, 0.333], [0.333, 0.333], [0.667, 0.333], [1.0, 0.333],
		[0.0, 0.667], [0.333, 0.667], [0.667, 0.667], [1.0, 0.667],
		[0.0, 1.0], [0.333, 1.0], [0.667, 1.0], [1.0, 1.0],
	]
	# Internal names must stay as cpXY for the shader uniforms
	var names := [
		"cp00", "cp10", "cp20", "cp30",
		"cp01", "cp11", "cp21", "cp31",
		"cp02", "cp12", "cp22", "cp32",
		"cp03", "cp13", "cp23", "cp33",
	]
	# Human-readable labels: Row/Col grid positions
	var row_labels := ["Top", "Upper Mid", "Lower Mid", "Bottom"]
	var col_labels := ["Left", "Center-Left", "Center-Right", "Right"]
	# Map internal index → (col, row) for labeling
	# Grid layout: index = row * 4 + col, names are cpCR where C=col, R=row
	for i in range(16):
		var n: String = names[i]
		var d: Array = defaults[i]
		var col_idx: int = int(n.substr(2, 1))  # cp[C]R → C
		var row_idx: int = int(n.substr(3, 1))  # cpC[R] → R
		var label := "%s %s" % [row_labels[row_idx], col_labels[col_idx]]
		add_parameter(GNParameter.create_float(n + "_x", d[0], -1.0, 2.0, 0.001,
			"%s X" % label, "Horizontal position for control point row %d, col %d" % [row_idx, col_idx]))
		add_parameter(GNParameter.create_float(n + "_y", d[1], -1.0, 2.0, 0.001,
			"%s Y" % label, "Vertical position for control point row %d, col %d" % [row_idx, col_idx]))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BezierMapTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/bezier_warp.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)

	var names := [
		"cp00", "cp10", "cp20", "cp30",
		"cp01", "cp11", "cp21", "cp31",
		"cp02", "cp12", "cp22", "cp32",
		"cp03", "cp13", "cp23", "cp33",
	]
	for n in names:
		var pt := Vector2(get_param_value(n + "_x"), get_param_value(n + "_y"))
		_material.set_shader_parameter(n, pt)

	_sync_overlay_points()

	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═════════════════════════════════════════════════════════════════════════════
# Viewer Overlay
# ═════════════════════════════════════════════════════════════════════════════

func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data is GNTextureData:
		var tex_data: GNTextureData = data as GNTextureData
		if tex_data.texture:
			viewer.set_texture(tex_data.texture,
				"%dx%d" % [tex_data.resolution.x, tex_data.resolution.y])
			_viewer_ref = weakref(viewer)
			_ensure_overlay()
			_sync_overlay_points()
			viewer.set_texture_overlay(_overlay)
			return
	viewer.set_info("No texture output", "")


func handle_viewer_input(event: InputEvent, local_pos: Vector2, viewer = null, port_index: int = 0) -> bool:
	if viewer == null:
		viewer = _viewer_ref.get_ref()
	if viewer == null:
		return false

	var uv: Vector2 = viewer.local_pos_to_uv(local_pos)

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := _overlay.hit_test_uv(uv, GRAB_RADIUS_UV)
				if hit >= 0:
					_dragging_index = hit
					_overlay.active_index = hit
					_overlay.queue_redraw()
					return true
			else:
				if _dragging_index >= 0:
					_dragging_index = -1
					_overlay.active_index = -1
					_overlay.queue_redraw()
					return true

	elif event is InputEventMouseMotion:
		if _dragging_index >= 0:
			# _dragging_index is a grid index (row-major). Convert to param name.
			var col: int = _dragging_index % 4
			var row: int = _dragging_index / 4
			var key := "cp%d%d" % [col, row]
			set_param_value(key + "_x", uv.x)
			set_param_value(key + "_y", uv.y)
			_sync_overlay_points()
			_overlay.queue_redraw()
			mark_dirty()
			return true
		else:
			var hit := _overlay.hit_test_uv(uv, GRAB_RADIUS_UV)
			if hit != _overlay.hovered_index:
				_overlay.hovered_index = hit
				_overlay.queue_redraw()
				return hit >= 0

	return false


func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = MapperOverlay.new()
	_overlay.grid_cols = 4
	_overlay.grid_rows = 4
	_overlay.points.resize(16)


func _sync_overlay_points() -> void:
	if _overlay == null:
		return
	# _CP_NAMES are ordered col-major (cpCR), but the overlay grid is row-major.
	# Internal layout: index i → col = i % 4, row = i / 4
	# Grid points are stored row-major: grid[row * cols + col]
	for i in range(16):
		var key: String = _CP_NAMES[i]
		var col_idx: int = int(key.substr(2, 1))
		var row_idx: int = int(key.substr(3, 1))
		var grid_idx: int = row_idx * 4 + col_idx
		_overlay.points[grid_idx] = Vector2(get_param_value(key + "_x"), get_param_value(key + "_y"))
	# Update column/row mapping for the reverse direction (grid_idx → param name)

	# Also need to map back: when dragging grid point grid_idx, which _CP_NAMES index?
	# grid_idx = row * 4 + col → cp name = "cp" + str(col) + str(row)
