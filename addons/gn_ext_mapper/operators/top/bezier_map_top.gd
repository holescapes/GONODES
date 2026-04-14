class_name BezierMapTOP
extends GNTopBase
## Bicubic Bezier surface warp with 4x4 control point grid.
## Uses Newton-Raphson inverse mapping from output pixel to source UV.
## Interactive overlay: drag 16 control points directly in the viewer.

# Human-readable parameter names in row-major order (row 0-3 top→bottom,
# col 0-3 left→right).  Matches BezierDragUI widget_state keys.
const _CP_NAMES: PackedStringArray = [
	"top_left", "top_cleft", "top_cright", "top_right",
	"umid_left", "umid_cleft", "umid_cright", "umid_right",
	"lmid_left", "lmid_cleft", "lmid_cright", "lmid_right",
	"bot_left", "bot_cleft", "bot_cright", "bot_right",
]

# Shader uniform names (cpCR where C=col, R=row) in the same row-major order.
const _SHADER_NAMES: PackedStringArray = [
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
	var defaults := [
		[0.0, 0.0], [0.333, 0.0], [0.667, 0.0], [1.0, 0.0],
		[0.0, 0.333], [0.333, 0.333], [0.667, 0.333], [1.0, 0.333],
		[0.0, 0.667], [0.333, 0.667], [0.667, 0.667], [1.0, 0.667],
		[0.0, 1.0], [0.333, 1.0], [0.667, 1.0], [1.0, 1.0],
	]
	# Human-readable labels: Row/Col grid positions
	var row_labels := ["Top", "Upper Mid", "Lower Mid", "Bottom"]
	var col_labels := ["Left", "Center-Left", "Center-Right", "Right"]
	for i in range(16):
		var n: String = _CP_NAMES[i]
		var d: Array = defaults[i]
		var row_idx: int = i / 4
		var col_idx: int = i % 4
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

	for i in range(16):
		var pt := Vector2(get_param_value(_CP_NAMES[i] + "_x"), get_param_value(_CP_NAMES[i] + "_y"))
		_material.set_shader_parameter(_SHADER_NAMES[i], pt)

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
			# _dragging_index is a grid index (row-major). Look up param name.
			var key: String = _CP_NAMES[_dragging_index]
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
	# _CP_NAMES are in row-major order matching the overlay grid layout.
	for i in range(16):
		var key: String = _CP_NAMES[i]
		_overlay.points[i] = Vector2(get_param_value(key + "_x"), get_param_value(key + "_y"))
