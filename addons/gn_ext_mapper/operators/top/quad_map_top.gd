class_name QuadMapTOP
extends GNTopBase
## Four-corner pin perspective warp using DLT homography.
## Maps input texture onto an arbitrary quadrilateral defined by four corner points.
## Interactive overlay: drag corner handles directly in the viewer.

# Corner param keys in order: TL, TR, BL, BR
const _CORNER_KEYS: PackedStringArray = ["tl", "tr", "bl", "br"]

var _overlay: MapperOverlay = null
var _dragging_index: int = -1
var _viewer_ref: WeakRef = WeakRef.new()

# ─ Grab radius in UV space (how close mouse must be to grab a handle) ────────
const GRAB_RADIUS_UV := 0.04


func _init() -> void:
	node_type = "quad_map"
	node_description = "Four-corner perspective warp for projection mapping surfaces."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Warped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tl_x", 0.0, -1.0, 2.0, 0.001, "Top-Left X", "Top-left corner X"))
	add_parameter(GNParameter.create_float("tl_y", 0.0, -1.0, 2.0, 0.001, "Top-Left Y", "Top-left corner Y"))
	add_parameter(GNParameter.create_float("tr_x", 1.0, -1.0, 2.0, 0.001, "Top-Right X", "Top-right corner X"))
	add_parameter(GNParameter.create_float("tr_y", 0.0, -1.0, 2.0, 0.001, "Top-Right Y", "Top-right corner Y"))
	add_parameter(GNParameter.create_float("bl_x", 0.0, -1.0, 2.0, 0.001, "Bottom-Left X", "Bottom-left corner X"))
	add_parameter(GNParameter.create_float("bl_y", 1.0, -1.0, 2.0, 0.001, "Bottom-Left Y", "Bottom-left corner Y"))
	add_parameter(GNParameter.create_float("br_x", 1.0, -1.0, 2.0, 0.001, "Bottom-Right X", "Bottom-right corner X"))
	add_parameter(GNParameter.create_float("br_y", 1.0, -1.0, 2.0, 0.001, "Bottom-Right Y", "Bottom-right corner Y"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("QuadMapTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/quad_warp.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		(_canvas as ColorRect).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("tl", Vector2(get_param_value("tl_x"), get_param_value("tl_y")))
	_material.set_shader_parameter("tr", Vector2(get_param_value("tr_x"), get_param_value("tr_y")))
	_material.set_shader_parameter("bl", Vector2(get_param_value("bl_x"), get_param_value("bl_y")))
	_material.set_shader_parameter("br", Vector2(get_param_value("br_x"), get_param_value("br_y")))

	# Sync overlay points if it exists
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
			# Update the param values for the dragged corner
			var key: String = _CORNER_KEYS[_dragging_index]
			set_param_value(key + "_x", uv.x)
			set_param_value(key + "_y", uv.y)
			_sync_overlay_points()
			_overlay.queue_redraw()
			mark_dirty()
			return true
		else:
			# Hover detection
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
	_overlay.draw_quad_outline = true
	_overlay.points.resize(4)


func _sync_overlay_points() -> void:
	if _overlay == null:
		return
	for i in range(4):
		var key: String = _CORNER_KEYS[i]
		_overlay.points[i] = Vector2(get_param_value(key + "_x"), get_param_value(key + "_y"))

