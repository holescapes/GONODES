class_name GNViewerPanel
extends Control
## Family-aware viewer panel that displays the output of any node family.
##
## Replaces the old TextureRect-only viewer. Switches visualization mode
## based on the pinned node's **output data type** (not family):
##   • GNTextureData  — Full-resolution TextureRect with pan/zoom (1:1 pixel mode)
##   • GNImageData    — Same as TOP (uploads Image → ImageTexture)
##   • GNChannelData  — GNWaveformView (GPU-accelerated _draw() polylines)
##   • GNTableData    — Tree spreadsheet widget (scrollable, column headers)
##   • GNGeoData      — SubViewport with Camera3D + MeshInstance3D (lazy, 3D)
##   • GNMaterialData — SubViewport with preview sphere (lazy, 3D)
##   • GNParticleData — MultiMesh point cloud
##   • GNVolumeData   — Three orthogonal slices + MIP
##   • Extension data — via register_display_handler()
##
## Only one child visualization is visible at a time.
## The 3D SubViewport is allocated lazily — if you never view a SOP or MAT,
## no SubViewport is created.


# ═══════════════════════════════════════════════════════════════════════════════
# Extension Display Handler Registry
# ═══════════════════════════════════════════════════════════════════════════════

## Extension-registered display handlers.
## Key: GDScript class name (String, e.g. "GNSDFData")
## Value: Callable(output: GNData, viewer: GNViewerPanel)
## The callable should call viewer._show_info(), viewer._show_texture(), etc.
static var _ext_display_handlers: Dictionary = {}

## Register a custom display handler for an extension data type.
## Extensions call this during _enter_tree() so the viewer knows how to
## display their custom GNData subclass.
##
## Example (in gn_ext_sdf plugin.gd _enter_tree):
##   GNViewerPanel.register_display_handler("GNSDFData", func(output, viewer):
##       var sd = output as GNSDFData
##       if sd.sdf_tree.is_empty():
##           viewer.show_info("Empty SDF tree", "")
##       else:
##           viewer.show_info(sd.get_preview_text(), "hash: %d" % sd.tree_hash))
static func register_display_handler(data_class_name: String, handler: Callable) -> void:
	_ext_display_handlers[data_class_name] = handler


## Returns true if a legacy extension display handler exists for the given class.
func has_ext_display_handler(data_class_name: String) -> bool:
	return _ext_display_handlers.has(data_class_name)


## Invokes a legacy extension display handler for the given data class.
func call_ext_display_handler(data_class_name: String, output) -> void:
	if _ext_display_handlers.has(data_class_name):
		_hide_all_displays()
		var handler: Callable = _ext_display_handlers[data_class_name]
		handler.call(output, self)

## Public helper: show a texture in the viewer. Used by extension display handlers.
func show_texture(tex: Texture2D, info: String) -> void:
	_show_texture(tex, info)
	_update_zoom_label()


## Background color for the panel.
const BG_COLOR := Color(0.06, 0.06, 0.08)


# ═══════════════════════════════════════════════════════════════════════════════
# Members
# ═══════════════════════════════════════════════════════════════════════════════

## The node ID currently targeted by this viewer.
var node_id: String = ""

## Weak reference to the currently displayed GNNode (for input forwarding).
var _displayed_node: WeakRef = WeakRef.new()

## The family of the currently viewed node (cached for mode switching).
var _current_family: int = GNFamily.Type.TOP

## Toolbar
var _toolbar: HBoxContainer = null
var _family_label: Label = null
var _node_label: Label = null
var _resolution_label: Label = null
var _zoom_label: Label = null
var _fit_btn: Button = null

## Background
var _bg: ColorRect = null

# ─── TOP / IMG display (pan + zoom) ──────────────────────────────────────────

## Container that clips the texture display area.
var _tex_clip: Control = null

## The texture rect displayed at native resolution, repositioned by pan/zoom.
var _tex_display: TextureRect = null

## Current zoom level (1.0 = 1:1 pixel).
var _zoom: float = 1.0

## Pan offset in pixels (relative to the center of _tex_clip).
var _pan: Vector2 = Vector2.ZERO

## Whether a pan drag is active.
var _panning: bool = false

## Last mouse position during pan drag.
var _pan_start: Vector2 = Vector2.ZERO

## Minimum / maximum zoom.
const ZOOM_MIN := 0.1
const ZOOM_MAX := 16.0
const ZOOM_STEP := 0.1

## Cached ImageTexture for IMG family — avoids recreating every frame.
var _img_texture: ImageTexture = null

# ─── CHOP display ────────────────────────────────────────────────────────────

var _waveform: GNWaveformView = null

# ─── DAT display (spreadsheet) ───────────────────────────────────────────────

var _spreadsheet: Tree = null

# ─── SOP display (3D viewport) ───────────────────────────────────────────────

var _3d_viewport: SubViewport = null
var _3d_camera: Camera3D = null
var _3d_mesh_instance: MeshInstance3D = null
var _3d_light: DirectionalLight3D = null
var _3d_display: TextureRect = null   ## Shows the SubViewport output

## Material override applied to the mesh when viewing COMPs with materials.
var _3d_material_override: Material = null

## Extra MeshInstance3Ds temporarily added for multi-mesh viewer (MergeCOMP, etc.).
var _3d_extra_meshes: Array[MeshInstance3D] = []

## Semi-transparent text overlay on top of the 3D display (set by operators).
var _3d_info_overlay: Label = null

## Orbit camera state
var _orbit_yaw: float = 45.0
var _orbit_pitch: float = -30.0
var _orbit_distance: float = 3.0
var _orbit_dragging: bool = false
var _orbit_start: Vector2 = Vector2.ZERO

## Wireframe toggle
var _wireframe_mode: bool = false
var _wireframe_btn: Button = null


## Axis gizmo root — rescaled each frame to keep constant screen size
var _gizmo_root: Node3D = null
const GIZMO_SCREEN_FRACTION := 0.08  ## Fraction of orbit distance for gizmo size

# ─── MAT display (material preview sphere) ────────────────────────────────────

var _mat_viewport: SubViewport = null
var _mat_camera: Camera3D = null
var _mat_sphere: MeshInstance3D = null
var _mat_light: DirectionalLight3D = null
var _mat_display: TextureRect = null

# ─── UI display (2D SubViewport snapshot) ─────────────────────────────────────

var _ui_viewport: SubViewport = null
var _ui_display: TextureRect = null
var _ui_preview_control: Control = null  ## duplicate() of the real Control

# ─── POP display (3D viewport with MultiMesh point cloud) ────────────────────

var _pop_viewport: SubViewport = null
var _pop_camera: Camera3D = null
var _pop_multimesh: MultiMeshInstance3D = null
var _pop_light: DirectionalLight3D = null
var _pop_display: TextureRect = null
var _pop_gizmo_root: Node3D = null

## POP orbit state (reuses same mechanics as SOP orbit)
var _pop_orbit_yaw: float = 45.0
var _pop_orbit_pitch: float = -30.0
var _pop_orbit_distance: float = 5.0
var _pop_orbit_dragging: bool = false

## POP GPU render toggle (false = MultiMesh, true = GPU direct)
var _pop_gpu_mode: bool = false
var _pop_gpu_btn: Button = null

## POP point size multiplier
var _pop_point_size: float = 0.02

# ─── VOL display (three orthogonal slices + MIP) ─────────────────────────────

var _vol_container: VBoxContainer = null
var _vol_slice_xy: TextureRect = null
var _vol_slice_xz: TextureRect = null
var _vol_slice_yz: TextureRect = null
var _vol_mip_display: TextureRect = null
var _vol_mip_mode: bool = false
var _vol_mip_btn: Button = null
var _vol_slice_pos: float = 0.5  ## Normalized slice position (0..1)
var _vol_slice_img_xy: ImageTexture = null
var _vol_slice_img_xz: ImageTexture = null
var _vol_slice_img_yz: ImageTexture = null
var _vol_mip_img: ImageTexture = null

# ─── Fallback info label ─────────────────────────────────────────────────────

var _info_label: Label = null

# ─── Info bar (bottom) ────────────────────────────────────────────────────────

var _info_bar: Label = null

# ─── Resize debounce ─────────────────────────────────────────────────────────

var _resize_timer: Timer = null

## When true, 3D SubViewports (SOP/MAT) are pre-allocated via call_deferred
## in _ready() to avoid a hitch on first view.  Set to true for the docked
## viewer; floating viewer windows leave this false (lazy creation).
var eager_3d: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	clip_contents = true

	# Background
	_bg = ColorRect.new()
	_bg.color = BG_COLOR
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
	_wireframe_btn.text = "Wire"
	_wireframe_btn.tooltip_text = "Toggle wireframe view (W)"
	_wireframe_btn.flat = true
	_wireframe_btn.toggle_mode = true
	_wireframe_btn.add_theme_font_size_override("font_size", 10)
	_wireframe_btn.toggled.connect(_on_wireframe_toggled)
	_wireframe_btn.visible = false
	_toolbar.add_child(_wireframe_btn)

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

	# Create all display modes (hidden by default)
	_create_texture_display()
	_create_waveform_display()
	_create_spreadsheet_display()
	_create_info_label()

	# Default: show nothing
	_hide_all_displays()

	# Deferred warm-up: pre-create 3D viewports so first SOP/MAT click has no hitch
	if eager_3d:
		call_deferred("_warm_up_3d")

	# Debounced resize: fires once after the user finishes dragging the panel edge
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.15
	_resize_timer.timeout.connect(_on_resize_settled)
	add_child(_resize_timer)
	resized.connect(_on_panel_resized)


## Content area rect (below toolbar, above info bar).
func _get_content_rect() -> Rect2:
	return Rect2(0, 26, size.x, maxf(size.y - 44, 1))


## Pre-creates the SOP and MAT SubViewports off the main frame to avoid a hitch.
func _warm_up_3d() -> void:
	_ensure_3d_viewport()
	_ensure_mat_viewport()


# ═══════════════════════════════════════════════════════════════════════════════
# UI — 2D SubViewport Snapshot (Lazy)
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_ui_viewport() -> void:
	if _ui_viewport != null:
		return

	_ui_viewport = SubViewport.new()
	_ui_viewport.name = "UI_Viewer_VP"
	_ui_viewport.transparent_bg = true
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ui_viewport.disable_3d = true
	_ui_viewport.gui_disable_input = true
	_ui_viewport.size = _snap_size(_get_content_rect().size)
	add_child(_ui_viewport)

	# Display TextureRect
	_ui_display = TextureRect.new()
	_ui_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ui_display.texture = _ui_viewport.get_texture()
	_ui_display.mouse_filter = MOUSE_FILTER_IGNORE
	_ui_display.visible = false
	add_child(_ui_display)


func _show_ui_preview(ui_node: GNUiBase) -> void:
	_ensure_ui_viewport()

	var control := ui_node.get_control_node()
	if control == null:
		_show_info("No UI control", "")
		return

	# Remove old preview duplicate
	if _ui_preview_control != null and _ui_preview_control.get_parent() == _ui_viewport:
		_ui_viewport.remove_child(_ui_preview_control)
		_ui_preview_control.queue_free()
		_ui_preview_control = null

	# Duplicate the real control for non-destructive snapshot
	_ui_preview_control = control.duplicate()
	_ui_viewport.add_child(_ui_preview_control)

	# Size the viewport to match the content area
	var content := _get_content_rect()
	_ui_viewport.size = _snap_size(content.size)

	# Give the duplicated control the full viewport size
	_ui_preview_control.position = Vector2.ZERO
	_ui_preview_control.size = Vector2(_ui_viewport.size)

	_hide_all_displays()
	_ui_display.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	_ui_display.position = content.position
	_ui_display.size = content.size

	# Render one frame
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Info bar: show widget_state
	var state_parts: PackedStringArray = []
	for key in ui_node.widget_state:
		state_parts.append("%s: %s" % [key, ui_node.widget_state[key]])
	_info_bar.text = ", ".join(state_parts) if state_parts.size() > 0 else "(no state)"


# ═══════════════════════════════════════════════════════════════════════════════
# TOP / IMG — Full Resolution Pan + Zoom
# ═══════════════════════════════════════════════════════════════════════════════

func _create_texture_display() -> void:
	_tex_clip = Control.new()
	_tex_clip.clip_contents = true
	_tex_clip.mouse_filter = MOUSE_FILTER_STOP
	_tex_clip.visible = false
	add_child(_tex_clip)

	_tex_display = TextureRect.new()
	_tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_display.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_display.mouse_filter = MOUSE_FILTER_IGNORE
	_tex_clip.add_child(_tex_display)

	# Wire input events for pan/zoom
	_tex_clip.gui_input.connect(_on_tex_gui_input)
	_tex_clip.resized.connect(_on_tex_clip_resized)
	_tex_clip.mouse_exited.connect(func() -> void: _panning = false)


func _on_tex_clip_resized() -> void:
	_apply_tex_transform()


## Handles mouse input for pan (left-click or middle-click drag) and zoom (scroll wheel).
## If the displayed node's handle_viewer_input() returns true, the event is
## consumed and pan/zoom is skipped.
func _on_tex_gui_input(event: InputEvent) -> void:
	var node: GNNode = _displayed_node.get_ref() as GNNode
	if node != null:
		var local_pos := Vector2.ZERO
		if event is InputEventMouse:
			local_pos = (event as InputEventMouse).position
		if node.handle_viewer_input(event, local_pos):
			return
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


## Zooms toward/away from the mouse cursor position.
func _zoom_at(mouse_pos: Vector2, delta: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom + delta * _zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, _zoom):
		return

	# Adjust pan so the point under the cursor stays fixed
	var ratio: float = _zoom / old_zoom
	var clip_center := _tex_clip.size * 0.5
	_pan = clip_center + (_pan - clip_center + (mouse_pos - clip_center)) * ratio - (mouse_pos - clip_center)

	_apply_tex_transform()
	_update_zoom_label()


## Applies the current pan + zoom to the TextureRect.
func _apply_tex_transform() -> void:
	if _tex_display == null or _tex_display.texture == null:
		return
	var tex_size := Vector2(_tex_display.texture.get_size())
	var display_size := tex_size * _zoom
	var clip_center := _tex_clip.size * 0.5
	var pos := clip_center + _pan - display_size * 0.5
	_tex_display.position = pos
	_tex_display.size = display_size


## Fits the texture to the panel (like the old STRETCH_KEEP_ASPECT_CENTERED).
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


## Updates the TOP/IMG texture display with the given texture.
## If the same texture is already displayed, just updates the info text
## without resetting layout (preserves pan/zoom during cook updates).
func _show_texture(tex: Texture2D, info_text: String = "") -> void:
	# Fast path: if we're already showing this texture, just refresh info
	if _tex_clip.visible and _tex_display.texture == tex:
		_info_bar.text = info_text
		return

	_hide_all_displays()
	_tex_clip.visible = true
	_fit_btn.visible = true
	_zoom_label.visible = true

	# Layout the clip area to the content rect
	var content := _get_content_rect()
	_tex_clip.position = content.position
	_tex_clip.size = content.size

	_tex_display.texture = tex

	# New texture — auto-fit
	_fit_to_panel()
	_info_bar.text = info_text


# ═══════════════════════════════════════════════════════════════════════════════
# CHOP — Waveform Display
# ═══════════════════════════════════════════════════════════════════════════════

func _create_waveform_display() -> void:
	_waveform = GNWaveformView.new()
	_waveform.visible = false
	_waveform.mouse_filter = MOUSE_FILTER_STOP
	_waveform.mouse_exited.connect(func() -> void: _waveform._dragging = false)
	add_child(_waveform)


func _show_waveform(ch_data: GNChannelData) -> void:
	# Fast path — if already showing waveform, just update data (preserve zoom/pan)
	if _waveform.visible:
		_waveform.set_channel_data(ch_data)
		_update_waveform_info(ch_data)
		return

	_hide_all_displays()
	_waveform.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_waveform.position = content.position
	_waveform.size = content.size
	_waveform.set_channel_data(ch_data)
	_update_waveform_info(ch_data)


func _update_waveform_info(ch_data: GNChannelData) -> void:
	var ch_count := ch_data.channels.size()
	var sample_info := "%d ch" % ch_count
	if ch_data.length > 1:
		sample_info += " × %d samples" % ch_data.length
	sample_info += " @ %.0f Hz" % ch_data.sample_rate
	_info_bar.text = sample_info


# ═══════════════════════════════════════════════════════════════════════════════
# DAT — Spreadsheet Display
# ═══════════════════════════════════════════════════════════════════════════════

func _create_spreadsheet_display() -> void:
	_spreadsheet = Tree.new()
	_spreadsheet.visible = false
	_spreadsheet.columns = 1
	_spreadsheet.select_mode = Tree.SELECT_ROW
	_spreadsheet.hide_root = true
	_spreadsheet.allow_reselect = false
	_spreadsheet.set_column_expand(0, true)
	add_child(_spreadsheet)


func _show_spreadsheet(tbl: GNTableData) -> void:
	_hide_all_displays()
	_spreadsheet.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_spreadsheet.position = content.position
	_spreadsheet.size = content.size

	# Clear and rebuild
	_spreadsheet.clear()

	if tbl.table.is_empty():
		_info_bar.text = "(empty table)"
		return

	# Determine column count from the first row
	var col_count: int = 0
	for row in tbl.table:
		if row.size() > col_count:
			col_count = row.size()
	if col_count == 0:
		_info_bar.text = "(empty table)"
		return

	_spreadsheet.columns = col_count
	for c in col_count:
		_spreadsheet.set_column_expand(c, true)
		_spreadsheet.set_column_clip_content(c, true)

	# Header row
	var root := _spreadsheet.create_item()
	var data_start: int = 0
	if tbl.has_header and tbl.table.size() > 0:
		var header_row: Array = tbl.table[0]
		for c in col_count:
			if c < header_row.size():
				_spreadsheet.set_column_title(c, str(header_row[c]))
			else:
				_spreadsheet.set_column_title(c, "")
		_spreadsheet.set_column_titles_visible(true)
		data_start = 1
	else:
		_spreadsheet.set_column_titles_visible(false)

	# Data rows
	for r in range(data_start, tbl.table.size()):
		var row: Array = tbl.table[r]
		var item := _spreadsheet.create_item(root)
		for c in col_count:
			if c < row.size():
				item.set_text(c, str(row[c]))
			else:
				item.set_text(c, "")

	var row_count: int = tbl.table.size() - data_start
	_info_bar.text = "%d rows × %d cols" % [row_count, col_count]


# ═══════════════════════════════════════════════════════════════════════════════
# SOP — 3D Viewport (Lazy)
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_3d_viewport() -> void:
	if _3d_viewport != null:
		return

	var scene := GNViewerRenderer.create_sop_viewport(_snap_size(_get_content_rect().size))
	_3d_viewport = scene["viewport"]
	_3d_camera = scene["camera"]
	_3d_mesh_instance = scene["mesh_instance"]
	_gizmo_root = scene["gizmo_root"]
	add_child(_3d_viewport)

	# Display TextureRect
	_3d_display = TextureRect.new()
	_3d_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_3d_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_3d_display.texture = _3d_viewport.get_texture()
	_3d_display.mouse_filter = MOUSE_FILTER_STOP
	_3d_display.visible = false
	add_child(_3d_display)

	_3d_display.gui_input.connect(_on_3d_gui_input)
	_3d_display.mouse_exited.connect(func() -> void: _orbit_dragging = false)

	# Overlay label (top-left of 3D display, semi-transparent)
	_3d_info_overlay = Label.new()
	_3d_info_overlay.visible = false
	_3d_info_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_3d_info_overlay.add_theme_font_size_override("font_size", 11)
	_3d_info_overlay.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_3d_info_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_3d_info_overlay.add_theme_constant_override("shadow_offset_x", 1)
	_3d_info_overlay.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_3d_info_overlay)

	_update_orbit_camera()


func _show_3d_mesh(geo_data: GNGeoData, material: Material = null) -> void:
	_ensure_3d_viewport()
	_clear_extra_meshes()

	# Apply or clear material override
	_3d_material_override = material
	_3d_mesh_instance.material_override = material

	# Fast path — if already showing 3D, just update mesh (preserve orbit state)
	if _3d_display.visible:
		if geo_data.mesh != null:
			_3d_mesh_instance.mesh = geo_data.mesh
		else:
			_3d_mesh_instance.mesh = null
		_apply_wireframe_mode()
		_update_gizmo_scale()
		var content := _get_content_rect()
		_3d_viewport.size = _snap_size(content.size)
		_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_info_bar.text = "%d verts, %d surfaces" % [geo_data.vertex_count,
			geo_data.mesh.get_surface_count() if geo_data.mesh else 0]
		return

	_hide_all_displays()
	_3d_display.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false
	_wireframe_btn.visible = true

	var content := _get_content_rect()
	_3d_display.position = content.position
	_3d_display.size = content.size

	# Resize SubViewport to match content
	_3d_viewport.size = _snap_size(content.size)

	# Update mesh
	if geo_data.mesh != null:
		_3d_mesh_instance.mesh = geo_data.mesh
	else:
		_3d_mesh_instance.mesh = null

	_apply_wireframe_mode()
	_update_gizmo_scale()

	# Render one frame
	_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Info
	_info_bar.text = "%d verts, %d surfaces" % [geo_data.vertex_count,
		geo_data.mesh.get_surface_count() if geo_data.mesh else 0]


## Removes any extra MeshInstance3Ds added by show_3d_scene().
func _clear_extra_meshes() -> void:
	for mi in _3d_extra_meshes:
		if is_instance_valid(mi) and mi.get_parent() != null:
			mi.get_parent().remove_child(mi)
			mi.queue_free()
	_3d_extra_meshes.clear()


## Shows multiple meshes with optional per-mesh materials in the 3D orbit viewer.
## entries: Array of { "mesh": Mesh, "material": Material or null, "transform": Transform3D }
func _show_3d_scene(entries: Array, info_text: String) -> void:
	_ensure_3d_viewport()
	_clear_extra_meshes()

	# Primary mesh instance shows the first entry
	_3d_mesh_instance.mesh = null
	_3d_mesh_instance.material_override = null
	_3d_mesh_instance.transform = Transform3D.IDENTITY

	if entries.size() > 0:
		var first: Dictionary = entries[0]
		_3d_mesh_instance.mesh = first.get("mesh")
		_3d_mesh_instance.material_override = first.get("material")
		var xform = first.get("transform")
		if xform is Transform3D:
			_3d_mesh_instance.transform = xform

	# Additional entries get their own MeshInstance3D in the viewport
	for i in range(1, entries.size()):
		var entry: Dictionary = entries[i]
		var mi := MeshInstance3D.new()
		mi.name = "ScenePreview_%d" % i
		mi.mesh = entry.get("mesh")
		mi.material_override = entry.get("material")
		var xform = entry.get("transform")
		if xform is Transform3D:
			mi.transform = xform
		_3d_viewport.add_child(mi)
		_3d_extra_meshes.append(mi)

	if not _3d_display.visible:
		_hide_all_displays()
		_3d_display.visible = true
		_fit_btn.visible = false
		_zoom_label.visible = false
		_wireframe_btn.visible = true

		var content := _get_content_rect()
		_3d_display.position = content.position
		_3d_display.size = content.size
		_3d_viewport.size = _snap_size(content.size)
	else:
		var content := _get_content_rect()
		_3d_viewport.size = _snap_size(content.size)

	_apply_wireframe_mode()
	_update_gizmo_scale()
	_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_info_bar.text = info_text


## Orbit camera input on the 3D display (left-click or middle-click to orbit).
func _on_3d_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_orbit_dragging = true
				_orbit_start = mb.position
			else:
				_orbit_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_orbit_distance = maxf(_orbit_distance - 0.3, 0.5)
			_update_orbit_camera()
			if _3d_viewport:
				_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_orbit_distance = minf(_orbit_distance + 0.3, 20.0)
			_update_orbit_camera()
			if _3d_viewport:
				_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif event is InputEventMouseMotion and _orbit_dragging:
		var mm: InputEventMouseMotion = event
		_orbit_yaw += mm.relative.x * 0.5
		_orbit_pitch = clampf(_orbit_pitch - mm.relative.y * 0.5, -89.0, 89.0)
		_update_orbit_camera()
		if _3d_viewport:
			_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_orbit_camera() -> void:
	if _3d_camera == null:
		return
	GNViewerRenderer.apply_orbit_camera(_3d_camera, _orbit_yaw, _orbit_pitch, _orbit_distance)
	_update_gizmo_scale()


## NOTE: Axis gizmo is now created by GNViewerRenderer.create_sop_viewport().


## Rescales the axis gizmo so it occupies a constant fraction of the screen
## regardless of orbit distance.  Called after every camera move / zoom.
func _update_gizmo_scale() -> void:
	GNViewerRenderer.update_gizmo_scale(_gizmo_root, _orbit_distance, GIZMO_SCREEN_FRACTION)


## Toggles between solid mesh and wireframe rendering.
func _on_wireframe_toggled(pressed: bool) -> void:
	_wireframe_mode = pressed
	_apply_wireframe_mode()
	if _3d_viewport:
		_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Toggles wireframe rendering via the SubViewport debug-draw mode.
func _apply_wireframe_mode() -> void:
	if _3d_viewport == null:
		return
	GNViewerRenderer.render_sop(_3d_viewport, _3d_mesh_instance,
		_3d_mesh_instance.mesh, _wireframe_mode)


# ═══════════════════════════════════════════════════════════════════════════════
# MAT — Material Preview Sphere (Lazy)
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_mat_viewport() -> void:
	if _mat_viewport != null:
		return

	var scene := GNViewerRenderer.create_mat_viewport(_snap_size(_get_content_rect().size))
	_mat_viewport = scene["viewport"]
	_mat_sphere = scene["sphere"]
	add_child(_mat_viewport)

	# Display
	_mat_display = TextureRect.new()
	_mat_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mat_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mat_display.texture = _mat_viewport.get_texture()
	_mat_display.mouse_filter = MOUSE_FILTER_IGNORE
	_mat_display.visible = false
	add_child(_mat_display)


func _show_material(mat_data: GNMaterialData) -> void:
	_ensure_mat_viewport()
	_hide_all_displays()
	_mat_display.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_mat_display.position = content.position
	_mat_display.size = content.size
	_mat_viewport.size = _snap_size(content.size)

	# Delegate rendering to the shared renderer
	GNViewerRenderer.render_mat(_mat_viewport, _mat_sphere,
		mat_data.material if mat_data.material != null else null)

	var mat_name := ""
	if mat_data.material != null:
		mat_name = mat_data.material.get_class()
	_info_bar.text = "Material: %s" % mat_name


# ═══════════════════════════════════════════════════════════════════════════════
# COMP / Fallback Info Label
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


func _show_info(text: String, info_bar_text: String = "") -> void:
	_hide_all_displays()
	_info_label.visible = true
	_fit_btn.visible = false
	_zoom_label.visible = false

	var content := _get_content_rect()
	_info_label.position = content.position
	_info_label.size = content.size
	_info_label.text = text
	_info_bar.text = info_bar_text


## Public API for extension display handlers.
## Extensions call viewer.show_info(text, info_bar) from their display handler.
func show_info(text: String, info_bar_text: String = "") -> void:
	_show_info(text, info_bar_text)


## Public API for extension display handlers.
## Call this before setting up your custom display.
func hide_all_displays() -> void:
	_hide_all_displays()


## Returns the content rect (Rect2) available for custom extension displays.
func get_content_rect() -> Rect2:
	return _get_content_rect()


## Public: display a CPU-side Image with auto-cached ImageTexture.
## Handles efficient upload (create once, update in-place, re-layout on resize).
func show_image(image: Image, info: String) -> void:
	var needs_layout := false
	if _img_texture == null:
		_img_texture = ImageTexture.create_from_image(image)
		needs_layout = true
	else:
		var old_size := _img_texture.get_size()
		_img_texture.update(image)
		if Vector2i(_img_texture.get_size()) != Vector2i(old_size):
			needs_layout = true
	if needs_layout:
		_show_texture(_img_texture, info)
		_update_zoom_label()
	else:
		if _info_bar:
			_info_bar.text = info


## Public: display CHOP waveform.
func show_waveform(ch_data: GNChannelData) -> void:
	_show_waveform(ch_data)


## Public: display DAT spreadsheet.
func show_spreadsheet(tbl: GNTableData) -> void:
	_show_spreadsheet(tbl)


## Public: display SOP 3D mesh in orbit viewport.
func show_3d_mesh(geo_data: GNGeoData) -> void:
	_show_3d_mesh(geo_data)


## Public: display SOP 3D mesh with a material applied (for COMPs).
func show_3d_mesh_with_material(geo_data: GNGeoData, material: Material) -> void:
	_show_3d_mesh(geo_data, material)


## Public: display multiple meshes in a composed 3D scene (for MergeCOMP, etc.).
## entries: Array of { "mesh": Mesh, "material": Material, "transform": Transform3D }
func show_3d_scene(entries: Array, info_text: String) -> void:
	_show_3d_scene(entries, info_text)


## Public: display MAT preview sphere.
func show_material(mat_data: GNMaterialData) -> void:
	_show_material(mat_data)


## Public: display POP point cloud.
func show_pop_particles(pd: GNParticleData) -> void:
	_show_pop_particles(pd)


## Public: display VOL orthogonal slices + MIP.
func show_vol_slices(vd: GNVolumeData) -> void:
	_show_vol_slices(vd)


## Public: display UI widget snapshot.  Accepts a GNUiBase (untyped to avoid
## import dependency from extensions).
func show_ui_preview(ui_node) -> void:
	_show_ui_preview(ui_node)


## Public: refresh the zoom percentage label.
func update_zoom_label() -> void:
	_update_zoom_label()


## Public: show a semi-transparent text overlay on top of the 3D display.
## Call after show_3d_mesh / show_3d_scene.  Pass "" to hide.
func set_info_overlay(text: String) -> void:
	if _3d_info_overlay == null:
		return
	if text.is_empty():
		_3d_info_overlay.visible = false
		return
	_3d_info_overlay.text = text
	_3d_info_overlay.visible = true
	# Position at top-left of the 3D display content area
	var content := _get_content_rect()
	_3d_info_overlay.position = content.position + Vector2(6, 4)
	_3d_info_overlay.size = Vector2(content.size.x - 12, content.size.y * 0.4)


# ═══════════════════════════════════════════════════════════════════════════════
# Display Management
# ═══════════════════════════════════════════════════════════════════════════════

func _hide_all_displays() -> void:
	if _tex_clip:
		_tex_clip.visible = false
	if _waveform:
		_waveform.visible = false
	if _spreadsheet:
		_spreadsheet.visible = false
	if _3d_display:
		_3d_display.visible = false
	if _mat_display:
		_mat_display.visible = false
	if _ui_display:
		_ui_display.visible = false
	if _pop_display:
		_pop_display.visible = false
	if _vol_container:
		_vol_container.visible = false
	if _vol_mip_display:
		_vol_mip_display.visible = false
	if _pop_gpu_btn:
		_pop_gpu_btn.visible = false
	if _vol_mip_btn:
		_vol_mip_btn.visible = false
	if _info_label:
		_info_label.visible = false
	if _fit_btn:
		_fit_btn.visible = false
	if _zoom_label:
		_zoom_label.visible = false
	if _wireframe_btn:
		_wireframe_btn.visible = false
	if _info_bar:
		_info_bar.text = ""
	if _3d_info_overlay:
		_3d_info_overlay.visible = false


## Snaps a size to the nearest 64px boundary (avoids SubViewport resize churn).
func _snap_size(s: Vector2) -> Vector2i:
	return Vector2i(
		maxi(64, snappedi(int(s.x), 64)),
		maxi(64, snappedi(int(s.y), 64))
	)


## Restart the debounce timer on every resize event.
func _on_panel_resized() -> void:
	_resize_timer.start()


## Called once after resizing has stopped for 0.15s.
## Resizes all active SubViewports + display rects to the new content area.
func _on_resize_settled() -> void:
	var content := _get_content_rect()
	var snapped := _snap_size(content.size)

	# ── TOP / IMG ──
	if _tex_clip and _tex_clip.visible:
		_tex_clip.position = content.position
		_tex_clip.size = content.size
		_apply_tex_transform()

	# ── CHOP ──
	if _waveform and _waveform.visible:
		_waveform.position = content.position
		_waveform.size = content.size

	# ── DAT ──
	if _spreadsheet and _spreadsheet.visible:
		_spreadsheet.position = content.position
		_spreadsheet.size = content.size

	# ── SOP (3D) ──
	if _3d_display and _3d_display.visible:
		_3d_display.position = content.position
		_3d_display.size = content.size
		if _3d_viewport:
			_3d_viewport.size = snapped
			_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# ── MAT ──
	if _mat_display and _mat_display.visible:
		_mat_display.position = content.position
		_mat_display.size = content.size
		if _mat_viewport:
			_mat_viewport.size = snapped
			_mat_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# ── UI ──
	if _ui_display and _ui_display.visible:
		_ui_display.position = content.position
		_ui_display.size = content.size
		if _ui_viewport:
			_ui_viewport.size = snapped
			_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# ── POP ──
	if _pop_display and _pop_display.visible:
		_pop_display.position = content.position
		_pop_display.size = content.size
		if _pop_viewport:
			_pop_viewport.size = snapped
			_pop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# ── VOL ──
	if _vol_container and _vol_container.visible:
		_vol_container.position = content.position
		_vol_container.size = content.size

	# ── Info label ──
	if _info_label and _info_label.visible:
		_info_label.position = content.position
		_info_label.size = content.size

	# ── 3D info overlay ──
	if _3d_info_overlay and _3d_info_overlay.visible:
		_3d_info_overlay.position = content.position + Vector2(6, 4)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the node being viewed.  Call _before_ update_from_node().
func set_target(p_node_id: String) -> void:
	if node_id == p_node_id:
		return
	node_id = p_node_id
	# Reset pan/zoom when switching nodes
	_zoom = 1.0
	_pan = Vector2.ZERO
	_panning = false
	_img_texture = null  # Force full layout on next IMG update
	_orbit_yaw = 45.0
	_orbit_pitch = -30.0
	_orbit_distance = 3.0
	_orbit_dragging = false
	_wireframe_mode = false
	if _wireframe_btn:
		_wireframe_btn.button_pressed = false
	# Reset POP orbit
	_pop_orbit_yaw = 45.0
	_pop_orbit_pitch = -30.0
	_pop_orbit_distance = 5.0
	_pop_orbit_dragging = false
	_pop_gpu_mode = false
	# Reset VOL slice
	_vol_slice_pos = 0.5
	_vol_mip_mode = false
	_vol_slice_img_xy = null
	_vol_slice_img_xz = null
	_vol_slice_img_yz = null
	_vol_mip_img = null
	if _waveform:
		_waveform.reset_view()


## Main update entry point — called each cook frame by the editor.
## Delegates display to the node's own display_in_viewer() virtual method.
## Each family base class (GNTopBase, GNChopBase, etc.) provides the default
## visualization; individual operators can override for custom display.
## Legacy extension handlers (register_display_handler) are checked as a
## fallback for extensions that haven't migrated to the virtual method.
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

	# Primary path: let the node decide how to display itself.
	# Family base classes provide sensible defaults; individual operators
	# can override display_in_viewer() for custom visualization.
	node.display_in_viewer(self)


## Clears the viewer display.
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


# ═══════════════════════════════════════════════════════════════════════════════
# POP — 3D Particle Point Cloud Viewer (MultiMesh)
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_pop_viewport() -> void:
	if _pop_viewport != null:
		return

	var scene := GNViewerRenderer.create_pop_viewport(_snap_size(_get_content_rect().size))
	_pop_viewport = scene["viewport"]
	_pop_camera = scene["camera"]
	_pop_multimesh = scene["multimesh_instance"]
	_pop_gizmo_root = scene["gizmo_root"]
	add_child(_pop_viewport)

	# Display TextureRect
	_pop_display = TextureRect.new()
	_pop_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pop_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pop_display.texture = _pop_viewport.get_texture()
	_pop_display.mouse_filter = MOUSE_FILTER_STOP
	_pop_display.visible = false
	add_child(_pop_display)

	_pop_display.gui_input.connect(_on_pop_gui_input)
	_pop_display.mouse_exited.connect(func() -> void: _pop_orbit_dragging = false)

	# GPU mode toggle button
	_pop_gpu_btn = Button.new()
	_pop_gpu_btn.text = "GPU"
	_pop_gpu_btn.tooltip_text = "Toggle GPU direct rendering (G)"
	_pop_gpu_btn.flat = true
	_pop_gpu_btn.toggle_mode = true
	_pop_gpu_btn.add_theme_font_size_override("font_size", 10)
	_pop_gpu_btn.toggled.connect(func(pressed: bool) -> void:
		_pop_gpu_mode = pressed
	)
	_pop_gpu_btn.visible = false
	_toolbar.add_child(_pop_gpu_btn)

	_update_pop_orbit_camera()


func _show_pop_particles(pd: GNParticleData) -> void:
	_ensure_pop_viewport()

	if not GNViewerRenderer.render_pop(_pop_viewport, _pop_multimesh, pd, _pop_point_size):
		_show_info("No GPU context", "")
		return

	# Show display
	if not _pop_display.visible:
		_hide_all_displays()
		_pop_display.visible = true
		_pop_gpu_btn.visible = true
		_fit_btn.visible = false
		_zoom_label.visible = false
		_wireframe_btn.visible = false
		var content := _get_content_rect()
		_pop_display.position = content.position
		_pop_display.size = content.size

	var content := _get_content_rect()
	_pop_viewport.size = _snap_size(content.size)
	_pop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Gizmo scale
	if _pop_gizmo_root:
		var gizmo_size: float = _pop_orbit_distance * GIZMO_SCREEN_FRACTION
		_pop_gizmo_root.scale = Vector3(gizmo_size, gizmo_size, gizmo_size)

	_info_bar.text = "%d particles, stride %d B" % [pd.particle_count, pd.stride]


func _on_pop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pop_orbit_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_pop_orbit_distance = maxf(_pop_orbit_distance - 0.3, 0.5)
			_update_pop_orbit_camera()
			if _pop_viewport:
				_pop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_pop_orbit_distance = minf(_pop_orbit_distance + 0.3, 50.0)
			_update_pop_orbit_camera()
			if _pop_viewport:
				_pop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif event is InputEventMouseMotion and _pop_orbit_dragging:
		var mm: InputEventMouseMotion = event
		_pop_orbit_yaw += mm.relative.x * 0.5
		_pop_orbit_pitch = clampf(_pop_orbit_pitch - mm.relative.y * 0.5, -89.0, 89.0)
		_update_pop_orbit_camera()
		if _pop_viewport:
			_pop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_pop_orbit_camera() -> void:
	if _pop_camera == null:
		return
	GNViewerRenderer.apply_orbit_camera(_pop_camera, _pop_orbit_yaw, _pop_orbit_pitch, _pop_orbit_distance)


# ═══════════════════════════════════════════════════════════════════════════════
# VOL — Three Orthogonal Slices + MIP Viewer
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_vol_display() -> void:
	if _vol_container != null:
		return

	# Container for slices (VBox with HBox rows)
	_vol_container = VBoxContainer.new()
	_vol_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vol_container.visible = false
	_vol_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_vol_container)

	# Top row: XY and XZ slices
	var top_row := HBoxContainer.new()
	top_row.size_flags_vertical = SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 2)
	_vol_container.add_child(top_row)

	_vol_slice_xy = _make_vol_slice_rect()
	_vol_slice_xy.tooltip_text = "XY slice (top view)"
	top_row.add_child(_vol_slice_xy)

	_vol_slice_xz = _make_vol_slice_rect()
	_vol_slice_xz.tooltip_text = "XZ slice (front view)"
	top_row.add_child(_vol_slice_xz)

	# Bottom row: YZ slice
	var bot_row := HBoxContainer.new()
	bot_row.size_flags_vertical = SIZE_EXPAND_FILL
	bot_row.add_theme_constant_override("separation", 2)
	_vol_container.add_child(bot_row)

	_vol_slice_yz = _make_vol_slice_rect()
	_vol_slice_yz.tooltip_text = "YZ slice (side view)"
	bot_row.add_child(_vol_slice_yz)

	# MIP display (hidden by default, replaces slices when toggled)
	_vol_mip_display = TextureRect.new()
	_vol_mip_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vol_mip_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vol_mip_display.size_flags_horizontal = SIZE_EXPAND_FILL
	_vol_mip_display.size_flags_vertical = SIZE_EXPAND_FILL
	_vol_mip_display.visible = false
	_vol_mip_display.mouse_filter = MOUSE_FILTER_IGNORE
	bot_row.add_child(_vol_mip_display)

	# MIP toggle button
	_vol_mip_btn = Button.new()
	_vol_mip_btn.text = "MIP"
	_vol_mip_btn.tooltip_text = "Toggle Maximum Intensity Projection (M)"
	_vol_mip_btn.flat = true
	_vol_mip_btn.toggle_mode = true
	_vol_mip_btn.add_theme_font_size_override("font_size", 10)
	_vol_mip_btn.toggled.connect(func(pressed: bool) -> void:
		_vol_mip_mode = pressed
		if _vol_slice_xy: _vol_slice_xy.visible = not pressed
		if _vol_slice_xz: _vol_slice_xz.visible = not pressed
		if _vol_slice_yz: _vol_slice_yz.visible = not pressed
		if _vol_mip_display: _vol_mip_display.visible = pressed
	)
	_vol_mip_btn.visible = false
	_toolbar.add_child(_vol_mip_btn)

	# Scroll on the container to change slice position
	_vol_container.gui_input.connect(_on_vol_gui_input)


func _make_vol_slice_rect() -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = SIZE_EXPAND_FILL
	tr.size_flags_vertical = SIZE_EXPAND_FILL
	tr.mouse_filter = MOUSE_FILTER_PASS
	return tr


func _show_vol_slices(vd: GNVolumeData) -> void:
	_ensure_vol_display()

	var ctx := GNGpuContext.get_context()
	if ctx.rd == null or not vd.rd_texture.is_valid():
		_show_info("No GPU context", "")
		return

	# Read back the full 3D texture to CPU
	var raw: PackedByteArray = ctx.rd.texture_get_data(vd.rd_texture, 0)
	var res: Vector3i = vd.resolution
	var bpv: int = vd.bytes_per_voxel()

	# Extract slices via shared renderer
	var slice_z: int = clampi(int(_vol_slice_pos * (res.z - 1)), 0, res.z - 1)
	var slice_y: int = clampi(int(_vol_slice_pos * (res.y - 1)), 0, res.y - 1)
	var slice_x: int = clampi(int(_vol_slice_pos * (res.x - 1)), 0, res.x - 1)

	# XY slice (fixed Z)
	var xy_img := GNViewerRenderer.extract_vol_slice_xy(raw, res, bpv, slice_z, vd.data_format)
	if _vol_slice_img_xy == null:
		_vol_slice_img_xy = ImageTexture.create_from_image(xy_img)
	else:
		_vol_slice_img_xy.update(xy_img)
	_vol_slice_xy.texture = _vol_slice_img_xy

	# XZ slice (fixed Y)
	var xz_img := GNViewerRenderer.extract_vol_slice_xz(raw, res, bpv, slice_y, vd.data_format)
	if _vol_slice_img_xz == null:
		_vol_slice_img_xz = ImageTexture.create_from_image(xz_img)
	else:
		_vol_slice_img_xz.update(xz_img)
	_vol_slice_xz.texture = _vol_slice_img_xz

	# YZ slice (fixed X)
	var yz_img := GNViewerRenderer.extract_vol_slice_yz(raw, res, bpv, slice_x, vd.data_format)
	if _vol_slice_img_yz == null:
		_vol_slice_img_yz = ImageTexture.create_from_image(yz_img)
	else:
		_vol_slice_img_yz.update(yz_img)
	_vol_slice_yz.texture = _vol_slice_img_yz

	# MIP if toggled
	if _vol_mip_mode:
		var mip_img := GNViewerRenderer.compute_vol_mip(raw, res, bpv, vd.data_format)
		if _vol_mip_img == null:
			_vol_mip_img = ImageTexture.create_from_image(mip_img)
		else:
			_vol_mip_img.update(mip_img)
		_vol_mip_display.texture = _vol_mip_img

	# Show
	if not _vol_container.visible:
		_hide_all_displays()
		_vol_container.visible = true
		_vol_mip_btn.visible = true
		_fit_btn.visible = false
		_zoom_label.visible = false
		_wireframe_btn.visible = false
		var content := _get_content_rect()
		_vol_container.position = content.position
		_vol_container.size = content.size

	_info_bar.text = "%dx%dx%d %s (slice %.0f%%)" % [
		res.x, res.y, res.z, vd.field_name, _vol_slice_pos * 100.0]


func _on_vol_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_vol_slice_pos = clampf(_vol_slice_pos + 0.02, 0.0, 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_vol_slice_pos = clampf(_vol_slice_pos - 0.02, 0.0, 1.0)


## NOTE: Volume slice/MIP extraction and voxel reading are now in GNViewerRenderer.


## Keyboard shortcut handler.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
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
		# W = toggle wireframe (SOP viewer)
		elif key.keycode == KEY_W and not key.ctrl_pressed and not key.shift_pressed:
			if _3d_display != null and _3d_display.visible and _wireframe_btn != null:
				_wireframe_btn.button_pressed = not _wireframe_btn.button_pressed
				get_viewport().set_input_as_handled()
