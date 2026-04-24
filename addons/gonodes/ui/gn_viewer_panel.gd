class_name GNViewerPanel
extends Control
## Minimal host viewer panel — delegates rendering to nodes.
##
## Display modes (mutually exclusive):
##   • Texture   — TextureRect with pan/zoom (set_texture)
##   • Control   — Arbitrary Control child (set_control)
##   • Info      — Centered text label (set_info)
##   • 3D        — Bare SubViewport, populated by the node (get_3d_viewport)
##
## The node's render_for_viewer(viewer, port_index) virtual method chooses which mode
## to activate.  Input is forwarded to node.handle_viewer_input() first;
## only unhandled events are processed for built-in pan/zoom.


const _DEFAULT_BG_COLOR := Color(0.06, 0.06, 0.08)
const ZOOM_MIN := 0.1
const ZOOM_MAX := 16.0
const ZOOM_STEP := 0.1


# ═══════════════════════════════════════════════════════════════════════════════
# Members
# ═══════════════════════════════════════════════════════════════════════════════

var node_id: String = ""
var _displayed_node: WeakRef = WeakRef.new()
var _current_family: int = GNFamily.Type.TOP

# ─ Toolbar ──────────────────────────────────────────────────────────────────
var _toolbar: HBoxContainer = null
var _family_label: Label = null
var _node_label: Label = null
var _zoom_label: Label = null
var _fit_btn: Button = null
var _wireframe_btn: Button = null
var _port_selector: OptionButton = null
var _selected_port_index: int = 0

# ─ Background ───────────────────────────────────────────────────────────────
var _bg: ColorRect = null

# ─ Texture display (pan + zoom) ─────────────────────────────────────────────
var _tex_clip: Control = null
var _tex_display: TextureRect = null
var _tex_overlay: Control = null  # Node-supplied overlay drawing in texture pixel space
var _current_overlay: Control = null  # Ref to the overlay currently parented
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

# ─ Control container ────────────────────────────────────────────────────────
var _control_container: Control = null
var _current_control: Control = null

# ─ 3D SubViewport (lazy) ────────────────────────────────────────────────────
var _3d_viewport: SubViewport = null
var _3d_display: TextureRect = null

# ─ 3D orbit interaction state (per-viewer, used by GNGeoRenderer / GNParticleRenderer) ─
var orbit_yaw: float = 45.0
var orbit_pitch: float = -30.0
var orbit_distance: float = 3.0
var orbit_dragging: bool = false
var wireframe: bool = false

# ─ Volume slice state (per-viewer, used by GNVolumeRenderer) ────────────────
var vol_slice_pos: float = 0.5
var vol_show_mip: bool = false

# ─ Info label ────────────────────────────────────────────────────────────────
var _info_label: Label = null

# ─ Info overlay ──────────────────────────────────────────────────────────────
var _info_overlay: Label = null

# ─ Info bar (bottom) ─────────────────────────────────────────────────────────
var _info_bar: Label = null

# ─ Resize debounce ───────────────────────────────────────────────────────────
var _resize_timer: Timer = null

## Pre-allocate 3D SubViewport in _ready() to avoid hitch on first view.
var eager_3d: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	clip_contents = true

	# Background
	_bg = ColorRect.new()
	_bg.color = _DEFAULT_BG_COLOR
	_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Toolbar (top)
	_toolbar = HBoxContainer.new()
	_toolbar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_toolbar.offset_bottom = 24.0
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)

	_family_label = Label.new()
	_family_label.add_theme_font_size_override("font_size", 11)
	_family_label.text = ""
	_toolbar.add_child(_family_label)

	_node_label = Label.new()
	_node_label.add_theme_font_size_override("font_size", 11)
	_node_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_node_label.text = ""
	_node_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_toolbar.add_child(_node_label)

	_fit_btn = Button.new()
	_fit_btn.text = "Fit"
	_fit_btn.tooltip_text = "Fit to panel (Shift+F)"
	_fit_btn.flat = true
	_fit_btn.add_theme_font_size_override("font_size", 10)
	_fit_btn.pressed.connect(_fit_to_panel)
	_toolbar.add_child(_fit_btn)

	_wireframe_btn = Button.new()
	_wireframe_btn.text = "Wireframe"
	_wireframe_btn.tooltip_text = "Toggle wireframe (W)"
	_wireframe_btn.flat = true
	_wireframe_btn.toggle_mode = true
	_wireframe_btn.add_theme_font_size_override("font_size", 10)
	_wireframe_btn.toggled.connect(_on_wireframe_toggled)
	_wireframe_btn.visible = false
	_toolbar.add_child(_wireframe_btn)

	_port_selector = OptionButton.new()
	_port_selector.flat = true
	_port_selector.add_theme_font_size_override("font_size", 10)
	_port_selector.visible = false
	_port_selector.item_selected.connect(_on_port_selected)
	_toolbar.add_child(_port_selector)

	_zoom_label = Label.new()
	_zoom_label.add_theme_font_size_override("font_size", 10)
	_zoom_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_zoom_label.text = ""
	_toolbar.add_child(_zoom_label)

	# Info bar (bottom)
	_info_bar = Label.new()
	_info_bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_info_bar.offset_top = -18.0
	_info_bar.add_theme_font_size_override("font_size", 10)
	_info_bar.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_info_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_info_bar)

	# Info overlay (semi-transparent, over any display)
	_info_overlay = Label.new()
	_info_overlay.visible = false
	_info_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_info_overlay.add_theme_font_size_override("font_size", 11)
	_info_overlay.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_info_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_info_overlay.add_theme_constant_override("shadow_offset_x", 1)
	_info_overlay.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_info_overlay)

	# Display modes (hidden by default)
	_create_texture_display()
	_create_control_container()
	_create_info_label()
	_hide_all_displays()

	if eager_3d:
		call_deferred("_ensure_3d_viewport")

	# Debounced resize
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.15
	_resize_timer.timeout.connect(_on_resize_settled)
	add_child(_resize_timer)
	resized.connect(_on_panel_resized)


func _get_content_rect() -> Rect2:
	return Rect2(0, 26, size.x, maxf(size.y - 44, 1))


# ═══════════════════════════════════════════════════════════════════════════════
# Texture Display (pan + zoom)
# ═══════════════════════════════════════════════════════════════════════════════

func _create_texture_display() -> void:
	_tex_clip = Control.new()
	_tex_clip.clip_contents = true
	_tex_clip.mouse_filter = MOUSE_FILTER_STOP
	_tex_clip.visible = false
	add_child(_tex_clip)

	_tex_display = TextureRect.new()
	_tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_display.mouse_filter = MOUSE_FILTER_IGNORE
	_tex_clip.add_child(_tex_display)

	# Transparent overlay container — positioned/sized to match _tex_display.
	# Node-owned Controls are reparented here via set_texture_overlay().
	_tex_overlay = Control.new()
	_tex_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_tex_overlay.visible = false
	_tex_clip.add_child(_tex_overlay)

	_tex_clip.gui_input.connect(_on_tex_gui_input)
	_tex_clip.resized.connect(_on_tex_clip_resized)
	_tex_clip.mouse_exited.connect(func() -> void: _panning = false)


func _on_tex_clip_resized() -> void:
	_apply_tex_transform()


func _on_tex_gui_input(event: InputEvent) -> void:
	var node: GNNode = _displayed_node.get_ref() as GNNode
	if node != null:
		var local_pos := Vector2.ZERO
		if event is InputEventMouse:
			local_pos = (event as InputEventMouse).position
		if node.handle_viewer_input(event, local_pos, self, _selected_port_index):
			node.render_for_viewer(self, _selected_port_index)
			return

	# Built-in pan/zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_pan_start = mb.position
			else:
				_panning = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, -ZOOM_STEP)
	elif event is InputEventMouseMotion and _panning:
		var mm: InputEventMouseMotion = event
		_pan += mm.relative
		_apply_tex_transform()


func _zoom_at(mouse_pos: Vector2, delta: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom + delta * _zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, _zoom):
		return
	var ratio: float = _zoom / old_zoom
	var clip_center := _tex_clip.size * 0.5
	_pan = (1.0 - ratio) * (mouse_pos - clip_center) + ratio * _pan
	_apply_tex_transform()
	_update_zoom_label()


func _apply_tex_transform() -> void:
	if _tex_display == null or _tex_display.texture == null:
		return
	var tex_size := Vector2(_tex_display.texture.get_size())
	var display_size := tex_size * _zoom
	var clip_center := _tex_clip.size * 0.5
	var pos := clip_center + _pan - display_size * 0.5
	_tex_display.position = pos
	_tex_display.size = display_size
	# Keep overlay in sync with the texture rect
	if _tex_overlay != null:
		_tex_overlay.position = pos
		_tex_overlay.size = display_size


func _fit_to_panel() -> void:
	if _tex_display == null or _tex_display.texture == null:
		return
	var tex_size := Vector2(_tex_display.texture.get_size())
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var content := _get_content_rect()
	var scale_x := content.size.x / tex_size.x
	var scale_y := content.size.y / tex_size.y
	_zoom = minf(scale_x, scale_y)
	_pan = Vector2.ZERO
	_apply_tex_transform()
	_update_zoom_label()


func _update_zoom_label() -> void:
	if _zoom_label:
		_zoom_label.text = "%d%%" % int(_zoom * 100.0)


# ═══════════════════════════════════════════════════════════════════════════════
# Control Container
# ═══════════════════════════════════════════════════════════════════════════════

func _create_control_container() -> void:
	_control_container = Control.new()
	_control_container.clip_contents = true
	_control_container.mouse_filter = MOUSE_FILTER_STOP
	_control_container.visible = false
	add_child(_control_container)


# ═══════════════════════════════════════════════════════════════════════════════
# Info Label
# ═══════════════════════════════════════════════════════════════════════════════

func _create_info_label() -> void:
	_info_label = Label.new()
	_info_label.visible = false
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_info_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_info_label)


# ═══════════════════════════════════════════════════════════════════════════════
# 3D SubViewport (Lazy)
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_3d_viewport() -> void:
	if _3d_viewport != null:
		return

	_3d_viewport = SubViewport.new()
	_3d_viewport.name = "Viewer3D_VP"
	_3d_viewport.size = _snap_size(_get_content_rect().size)
	_3d_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_3d_viewport.transparent_bg = false
	_3d_viewport.own_world_3d = true
	_3d_viewport.world_3d = World3D.new()
	add_child(_3d_viewport)

	_3d_display = TextureRect.new()
	_3d_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_3d_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_3d_display.texture = _3d_viewport.get_texture()
	_3d_display.mouse_filter = MOUSE_FILTER_STOP
	_3d_display.visible = false
	add_child(_3d_display)

	_3d_display.gui_input.connect(_on_3d_gui_input)


func _on_3d_gui_input(event: InputEvent) -> void:
	var node: GNNode = _displayed_node.get_ref() as GNNode
	if node != null:
		var local_pos := Vector2.ZERO
		if event is InputEventMouse:
			local_pos = (event as InputEventMouse).position
		if node.handle_viewer_input(event, local_pos, self, _selected_port_index):
			node.render_for_viewer(self, _selected_port_index)
			return


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — Display Modes
# ═══════════════════════════════════════════════════════════════════════════════

## Shows a Texture2D with pan/zoom support.
func set_texture(tex: Texture2D, info_bar_text: String = "") -> void:
	if tex == null:
		set_info("No texture", info_bar_text)
		return

	# Fast path: same texture, already visible — just update info + redraw overlay
	if _tex_clip.visible and _tex_display.texture == tex:
		_info_bar.text = info_bar_text
		if _current_overlay != null:
			_current_overlay.queue_redraw()
		return

	_hide_all_displays()
	_tex_clip.visible = true
	_fit_btn.visible = true
	_zoom_label.visible = true

	var content := _get_content_rect()
	_tex_clip.position = content.position
	_tex_clip.size = content.size

	_tex_display.texture = tex
	_fit_to_panel()
	_info_bar.text = info_bar_text


## Shows an arbitrary Control in the content area.
func set_control(control: Control, info_bar_text: String = "") -> void:
	if control == null:
		set_info("No control", info_bar_text)
		return

	# Same control already showing — just update info
	if _control_container.visible and _current_control == control:
		_info_bar.text = info_bar_text
		return

	_hide_all_displays()
	_control_container.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_control_container.position = content.position
	_control_container.size = content.size

	# Reparent the control into our container
	if _current_control != null and _current_control != control:
		if _current_control.get_parent() == _control_container:
			_control_container.remove_child(_current_control)

	_current_control = control
	if control.get_parent() != _control_container:
		if control.get_parent() != null:
			control.get_parent().remove_child(control)
		_control_container.add_child(control)

	control.position = Vector2.ZERO
	control.size = content.size
	_info_bar.text = info_bar_text


## Shows centered text information.
func set_info(text: String, info_bar_text: String = "") -> void:
	_hide_all_displays()
	_info_label.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_info_label.position = content.position
	_info_label.size = content.size
	_info_label.text = text
	_info_bar.text = info_bar_text


## Returns the shared 3D SubViewport (lazy-created).
## Calling this activates 3D display mode.
func get_3d_viewport() -> SubViewport:
	_ensure_3d_viewport()

	# Always clear previous scene children — different nodes (even within the
	# same family) may use entirely different visualization methods
	# (e.g. CameraCOMP vs GeometryCOMP, or MAT sphere vs SOP wireframe).
	for child in _3d_viewport.get_children():
		_3d_viewport.remove_child(child)

	if not _3d_display.visible:
		_hide_all_displays()
		_3d_display.visible = true
		_fit_btn.visible = false
		_zoom_label.visible = false

		var content := _get_content_rect()
		_3d_display.position = content.position
		_3d_display.size = content.size
		_3d_viewport.size = _snap_size(content.size)

	return _3d_viewport


## Sets the bottom info bar text independently of any display mode.
func set_info_bar(text: String) -> void:
	_info_bar.text = text


## Attaches a node-supplied overlay Control that draws in texture pixel space.
## The overlay is positioned/sized to match the texture rect and participates
## in pan/zoom automatically.  Pass [code]null[/code] to remove the overlay.
## The overlay's [code]mouse_filter[/code] is forced to IGNORE — all input
## routes through [method GNNode.handle_viewer_input] as before.
func set_texture_overlay(overlay: Control) -> void:
	_clear_texture_overlay()
	if overlay == null:
		return
	_current_overlay = overlay
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	if overlay.get_parent() != null:
		overlay.get_parent().remove_child(overlay)
	_tex_overlay.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tex_overlay.visible = true


func _clear_texture_overlay() -> void:
	if _tex_overlay == null:
		return
	if _current_overlay != null:
		if _current_overlay.get_parent() == _tex_overlay:
			_tex_overlay.remove_child(_current_overlay)
		_current_overlay = null
	_tex_overlay.visible = false


## Converts a mouse position relative to the texture clip container into
## normalized 0-1 UV coordinates (0,0 = top-left of texture, 1,1 = bottom-right).
## Returns [code]Vector2(-1,-1)[/code] if no texture is displayed.
func local_pos_to_uv(local_pos: Vector2) -> Vector2:
	if _tex_display == null or _tex_display.texture == null:
		return Vector2(-1.0, -1.0)
	var tex_pos := local_pos - _tex_display.position
	var display_size := _tex_display.size
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return Vector2(tex_pos.x / display_size.x, tex_pos.y / display_size.y)


## Converts normalized 0-1 UV coordinates to a position in the texture clip
## container's local space (inverse of [method local_pos_to_uv]).
func uv_to_local_pos(uv: Vector2) -> Vector2:
	if _tex_display == null:
		return Vector2.ZERO
	return _tex_display.position + Vector2(uv.x * _tex_display.size.x, uv.y * _tex_display.size.y)


## Shows or hides a semi-transparent text overlay on top of the current display.
func set_info_overlay(text: String) -> void:
	if _info_overlay == null:
		return
	if text.is_empty():
		_info_overlay.visible = false
		return
	_info_overlay.text = text
	_info_overlay.visible = true
	var content := _get_content_rect()
	_info_overlay.position = content.position + Vector2(6, 4)
	_info_overlay.size = Vector2(content.size.x - 12, content.size.y * 0.4)


## Returns the snapped content area size.
func get_content_size() -> Vector2i:
	return _snap_size(_get_content_rect().size)


## Hides all display modes (public API for nodes).
func hide_all_displays() -> void:
	_hide_all_displays()


# ═══════════════════════════════════════════════════════════════════════════════
# Display Management
# ═══════════════════════════════════════════════════════════════════════════════

func _hide_all_displays() -> void:
	if _tex_clip:
		_tex_clip.visible = false
	_clear_texture_overlay()
	if _control_container:
		_control_container.visible = false
	if _3d_display:
		_3d_display.visible = false
	if _info_label:
		_info_label.visible = false
	if _fit_btn:
		_fit_btn.visible = false
	if _zoom_label:
		_zoom_label.visible = false
	if _info_bar:
		_info_bar.text = ""
	if _info_overlay:
		_info_overlay.visible = false


func _snap_size(s: Vector2) -> Vector2i:
	return Vector2i(
		maxi(64, snappedi(int(s.x), 64)),
		maxi(64, snappedi(int(s.y), 64))
	)


func _on_panel_resized() -> void:
	_resize_timer.start()


func _on_resize_settled() -> void:
	var content := _get_content_rect()
	var snapped := _snap_size(content.size)

	if _tex_clip and _tex_clip.visible:
		_tex_clip.position = content.position
		_tex_clip.size = content.size
		_fit_to_panel()

	if _control_container and _control_container.visible:
		_control_container.position = content.position
		_control_container.size = content.size
		if _current_control != null:
			_current_control.size = content.size

	if _3d_display and _3d_display.visible:
		_3d_display.position = content.position
		_3d_display.size = content.size
		if _3d_viewport:
			_3d_viewport.size = snapped
			# Re-render by asking the node
			var node: GNNode = _displayed_node.get_ref() as GNNode
			if node != null:
				node.render_for_viewer(self, _selected_port_index)

	if _info_label and _info_label.visible:
		_info_label.position = content.position
		_info_label.size = content.size

	if _info_overlay and _info_overlay.visible:
		_info_overlay.position = content.position + Vector2(6, 4)
		_info_overlay.size = Vector2(content.size.x - 12, content.size.y * 0.4)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — Node Management
# ═══════════════════════════════════════════════════════════════════════════════

## Updates the viewer background color (pushed by the editor from Preferences).
func set_bg_color(color: Color) -> void:
	if _bg:
		_bg.color = color

func set_target(p_node_id: String) -> void:
	if node_id == p_node_id:
		return
	node_id = p_node_id
	_selected_port_index = 0
	_zoom = 1.0
	_pan = Vector2.ZERO
	_panning = false
	# Reset 3D orbit state for the new node.
	orbit_yaw = 45.0
	orbit_pitch = -30.0
	orbit_distance = 3.0
	orbit_dragging = false
	wireframe = false
	# Reset volume slice state for the new node.
	vol_slice_pos = 0.5
	vol_show_mip = false
	# Reset custom view state when switching nodes.
	if _current_control != null and _current_control.has_method("reset_view"):
		_current_control.reset_view()
	# Reset wireframe button state.
	if _wireframe_btn:
		_wireframe_btn.button_pressed = false


func update_from_node(node: GNNode) -> void:
	_displayed_node = weakref(node) if node != null else WeakRef.new()
	if node == null:
		_hide_all_displays()
		_update_toolbar("", "")
		return

	var family := node.family
	_current_family = family
	var family_name := GNFamily.get_family_name(family)
	var family_color := GNFamily.get_color(family)
	_update_toolbar(family_name, node.id, family_color)

	# Show wireframe toggle when the renderer or node supports it.
	var renderer := GNFamily.get_renderer(family)
	var show_wire: bool = renderer != null and renderer.supports_wireframe()
	if not show_wire and node.has_method("supports_wireframe"):
		show_wire = node.supports_wireframe()
	if _wireframe_btn:
		_wireframe_btn.visible = show_wire

	# Port selector — show only for multi-output nodes.
	_update_port_selector(node)

	node.render_for_viewer(self, _selected_port_index)


func clear() -> void:
	node_id = ""
	_hide_all_displays()
	_update_toolbar("", "")


func _update_toolbar(family_name: String, p_node_id: String,
		family_color: Color = Color.WHITE) -> void:
	if _family_label:
		_family_label.text = family_name
		_family_label.add_theme_color_override("font_color", family_color)
	if _node_label:
		_node_label.text = p_node_id


func _update_port_selector(node: GNNode) -> void:
	if _port_selector == null:
		return
	var port_count: int = node.output_ports.size()
	if port_count <= 1:
		_port_selector.visible = false
		_selected_port_index = 0
		return
	# Rebuild items only when the node changed (avoid flicker).
	var needs_rebuild: bool = _port_selector.item_count != port_count
	if not needs_rebuild:
		for i in range(port_count):
			var expected: String = "%d: %s" % [i, node.output_ports[i].label \
				if not node.output_ports[i].label.is_empty() \
				else node.output_ports[i].port_name]
			if _port_selector.get_item_text(i) != expected:
				needs_rebuild = true
				break
	if needs_rebuild:
		_port_selector.clear()
		for i in range(port_count):
			var port: GNPort = node.output_ports[i]
			var label: String = port.label if not port.label.is_empty() else port.port_name
			var family_tag: String = GNFamily.get_family_name(port.family)
			_port_selector.add_item("%d: %s" % [i, label], i)
		# Clamp selection in case the node shrank its port count.
		if _selected_port_index >= port_count:
			_selected_port_index = 0
		_port_selector.selected = _selected_port_index
	_port_selector.visible = true


func _on_port_selected(index: int) -> void:
	_selected_port_index = index
	var node: GNNode = _displayed_node.get_ref() as GNNode
	if node != null:
		node.render_for_viewer(self, _selected_port_index)


# ═══════════════════════════════════════════════════════════════════════════════
# Keyboard Shortcuts
# ═══════════════════════════════════════════════════════════════════════════════

func _on_wireframe_toggled(pressed: bool) -> void:
	wireframe = pressed
	var node: GNNode = _displayed_node.get_ref() as GNNode
	if node != null:
		node.render_for_viewer(self, _selected_port_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		# Shift+F = Fit to panel
		if key.keycode == KEY_F and key.shift_pressed and not key.ctrl_pressed:
			_fit_to_panel()
			get_viewport().set_input_as_handled()
		# Home = reset zoom to 1:1
		elif key.keycode == KEY_HOME and not key.ctrl_pressed:
			_zoom = 1.0
			_pan = Vector2.ZERO
			_apply_tex_transform()
			_update_zoom_label()
			get_viewport().set_input_as_handled()
		# W = toggle wireframe (SOP/COMP)
		elif key.keycode == KEY_W and not key.ctrl_pressed and not key.shift_pressed:
			if _wireframe_btn != null and _wireframe_btn.visible:
				_wireframe_btn.button_pressed = not _wireframe_btn.button_pressed
				get_viewport().set_input_as_handled()
		# M = toggle MIP (VOL)
		elif key.keycode == KEY_M and not key.ctrl_pressed and not key.shift_pressed:
			vol_show_mip = not vol_show_mip
			var node: GNNode = _displayed_node.get_ref() as GNNode
			if node != null:
				node.render_for_viewer(self, _selected_port_index)
				get_viewport().set_input_as_handled()
