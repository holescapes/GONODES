extends Control
## GONODES Editor — Main editor scene.
## Split layout: GNGraphEditor (left/center) + Viewer + Inspector (right).
## Runs a cook engine each frame and displays the output of the last TOP
## in the viewer panel. Includes a debug info label and log toggle.
## Supports save/load of patches as `.gnpatch` JSON files.


@onready var graph_editor: GNGraphEditor = $HSplit/GraphPanel/GraphEditor
@onready var inspector: GNParamInspector = $HSplit/RightPanel/InspectorPanel
@onready var info_label: Label = $InfoBar/InfoLabel
@onready var log_toggle: CheckButton = $InfoBar/LogToggle
@onready var hsplit: HSplitContainer = $HSplit
@onready var right_panel: VSplitContainer = $HSplit/RightPanel

var network: GNNetwork
var cook_engine: GNCookEngine

## Toolbar toggles (created in _setup_toolbar, stored for state persistence).
var play_button: Button
var reset_button: Button
var step_back_button: Button
var step_fwd_button: Button
var speed_spin: SpinBox
var loop_button: Button
var preview_toggle: CheckButton
var perf_toggle: CheckButton
var vram_toggle: CheckButton
var nrt_toggle: CheckButton
var nrt_fps_spin: SpinBox
var _timeline_scrubber: HSlider
var _timeline_time_label: Label
var _loop_mode_idx: int = 0  ## 0=None, 1=Loop, 2=PingPong

## VRAM budget monitoring (opt-in via toolbar toggle).
var _vram_enabled: bool = false
var _vram_budget_mb: float = 0.0   ## User-configurable budget (0 = no limit warning)

## Which node's output to display in the viewer (click to select).
var _viewer_node_id: String = ""

## When true, selection changes do NOT override the viewer target.
var _viewer_pinned: bool = false

## Path to the currently loaded/saved patch file (empty = unsaved).
var _current_file_path: String = ""

## Project manager — manages project folder, path resolution, scanning.
var _project: GNProjectManager = GNProjectManager.new()

## FileDialogs for save and load.
var _save_dialog: FileDialog = null
var _load_dialog: FileDialog = null

## Floating viewer windows — each pinned to a specific node's output.
var _viewer_windows: Array[GNViewerWindow] = []

## Docked viewer panel (replaces the old TextureRect).
var viewer_panel: GNViewerPanel = null

## Log panel (Textport) — collapsible, subscribes to GNLogger.
var log_panel: GNLogPanel = null

## Debug panel — docked tabs for cook chain, active chains, parameter references.
var debug_panel: GNDebugPanel = null

## Debug toggle button on toolbar.
var debug_toggle: CheckButton = null

## Export compatibility report panel.
var compat_panel: GNCompatReportPanel = null

## Compat report toggle button on toolbar.
var compat_toggle: CheckButton = null

## Take manager — named parameter layer presets.
var take_manager: GNTakeManager = null

## Take panel — UI for managing takes.
var take_panel: GNTakePanel = null

## Take toggle button on toolbar.
var take_toggle: CheckButton = null

## Container for per-layer debug toggles (visible when debug is on).
var _debug_layers_container: HBoxContainer = null

## Floating help windows.
var _help_windows: Array = []

## Export dialog for building standalone apps.
var _export_dialog: Window = null

## Main help reference window (singleton — toggled on/off).
var _main_help_window: GNMainHelpWindow = null

## Settings file path for persisting editor state (last opened patch, etc.).
const _SETTINGS_PATH := "user://gonodes_settings.cfg"

# ─── Sub-Network Navigation ───────────────────────────────────────────────────

## Entry in the navigation stack — one per nesting level.
class _NavEntry:
	var network: GNNetwork       ## The GNNetwork at this level
	var subnet_node_id: String   ## The SubNetworkNode ID we dived into ("" for root)
	var scroll_offset: Vector2   ## Saved GraphEdit scroll position
	var zoom: float              ## Saved GraphEdit zoom level
	var viewer_node_id: String   ## Saved viewer target at this level

## Stack of navigation entries — bottom is root, top is current level.
## When at root, the stack has exactly one entry.
var _nav_stack: Array[_NavEntry] = []

## Breadcrumb bar (HBoxContainer with clickable labels).
var _breadcrumb_bar: HBoxContainer = null

## Node ID of the GNCustomOperator currently being edited in-place (“” if none).
var _editing_asset_node_id: String = ""


func _ready() -> void:
	# Wire log toggle early so extension scan results are visible
	log_toggle.toggled.connect(_on_log_toggled)
	GNLogger.enabled = log_toggle.button_pressed
	GNLogger.level = GNLogger.Level.INFO

	# Initialize extension registry — scan for gn_ext_* addon manifests
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()
	GNExtensionRegistry.instance().scan_deprecation()

	_setup_network()
	_setup_cook_engine()
	_setup_file_dialogs()
	_setup_toolbar()
	_setup_log_panel()
	_setup_debug_panel()
	_setup_compat_panel()
	_setup_take_panel()

	# Persist split-container sizes when the user drags them
	hsplit.dragged.connect(func(offset: int): _save_setting("hsplit_offset", offset))
	right_panel.dragged.connect(func(offset: int): _save_setting("vsplit_offset", offset))

	# Restore all persisted UI state (toggles, panel sizes)
	_restore_ui_state()

	# Bind graph editor to network
	graph_editor.bind_network(network)
	graph_editor.operator_selected.connect(_on_graph_node_selected)
	graph_editor.operator_deselected.connect(_on_graph_selection_cleared)
	graph_editor.open_viewer_requested.connect(_on_open_viewer_requested)
	graph_editor.help_requested.connect(_on_help_requested)
	graph_editor.dive_into_requested.connect(_on_dive_into_requested)
	graph_editor.viewer_pin_requested.connect(_on_viewer_pin_requested)
	graph_editor.edit_asset_requested.connect(_on_edit_asset_requested)
	graph_editor.make_unique_requested.connect(_on_make_unique_requested)
	graph_editor.repromote_asset_requested.connect(_on_repromote_asset_requested)

	# Replace the scene's TextureRect Viewer with a GNViewerPanel
	_setup_viewer_panel()

	# Bind inspector to network and undo stack
	inspector.network = network
	inspector.undo_redo = graph_editor._undo_redo

	# Track node renames so viewer target stays correct
	network.node_renamed.connect(_on_node_renamed)

	# Initialize sub-network navigation with root level
	_setup_breadcrumb_bar()
	_init_nav_stack()

	# Print display info
	var displays := WindowOUT.get_display_info()
	for d in displays:
		print("Display %d: %s at %s" % [d["index"], d["size"], d["position"]])
	print("GONODES Editor running (%d display(s))" % displays.size())


## Sets up the network — restores the last opened patch or starts empty.
func _setup_network() -> void:
	var last_path := _load_setting("last_patch_path", "") as String
	if not last_path.is_empty() and FileAccess.file_exists(last_path):
		network = GNNetwork.new()
		var err := network.load_from_file(last_path)
		if err == OK:
			_current_file_path = last_path
			_project.set_from_patch_path(last_path)
			_update_title()
			print("[GONODES] Restored last patch: %s" % last_path)
		else:
			print("[GONODES] Failed to restore '%s' — starting empty" % last_path)
			network = GNNetwork.new()
	else:
		network = GNNetwork.new()


func _setup_cook_engine() -> void:
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	cook_engine.network = network
	cook_engine.project_dir = _project.project_dir
	cook_engine.editor_mode = true
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)

	# Initial sink list
	_push_active_sinks()


## Replaces the scene's placeholder TextureRect with a GNViewerPanel.
func _setup_viewer_panel() -> void:
	var viewer_container: PanelContainer = $HSplit/RightPanel/ViewerPanel
	# Remove the old TextureRect if it exists
	var old_viewer: Node = viewer_container.get_node_or_null("Viewer")
	if old_viewer:
		viewer_container.remove_child(old_viewer)
		old_viewer.queue_free()

	viewer_panel = GNViewerPanel.new()
	viewer_panel.name = "Viewer"
	viewer_panel.eager_3d = true  # Pre-create 3D SubViewports to avoid first-click hitch
	viewer_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	viewer_panel.size_flags_vertical = SIZE_EXPAND_FILL
	viewer_container.add_child(viewer_panel)


## Creates the collapsible log panel between the graph area and the toolbar.
func _setup_log_panel() -> void:
	log_panel = GNLogPanel.new()
	log_panel.visible = false  # hidden by default, toggled by LogToggle
	# Anchor to bottom, just above InfoBar (66px toolbar height)
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(log_panel)
	move_child(log_panel, hsplit.get_index() + 1)  # between HSplit and InfoBar
	_layout_log_panel()


const _TOOLBAR_HEIGHT := 98.0
const _LOG_PANEL_HEIGHT := 160.0

## Recalculates vertical offsets for HSplit, LogPanel, and InfoBar.
func _layout_log_panel() -> void:
	var _info_bar := $InfoBar as VBoxContainer
	if log_panel.visible:
		log_panel.offset_top = -((_TOOLBAR_HEIGHT) + _LOG_PANEL_HEIGHT)
		log_panel.offset_bottom = -(_TOOLBAR_HEIGHT)
		hsplit.offset_bottom = -((_TOOLBAR_HEIGHT) + _LOG_PANEL_HEIGHT)
	else:
		hsplit.offset_bottom = -(_TOOLBAR_HEIGHT)


## Creates the debug panel (docked below graph, hidden by default).
func _setup_debug_panel() -> void:
	debug_panel = GNDebugPanel.new()
	debug_panel.visible = false
	debug_panel.cook_engine = cook_engine
	debug_panel.network = network
	debug_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	debug_panel.node_selected.connect(_on_debug_node_selected)
	add_child(debug_panel)
	move_child(debug_panel, hsplit.get_index() + 1)

	# Wire cook engine + network refs to the graph overlay
	if graph_editor.debug_overlay != null:
		graph_editor.debug_overlay.cook_engine = cook_engine
		graph_editor.debug_overlay.network = network


## Creates the export compatibility report panel (docked below graph, hidden by default).
func _setup_compat_panel() -> void:
	compat_panel = GNCompatReportPanel.new()
	compat_panel.visible = false
	compat_panel.network = network
	compat_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	compat_panel.node_selected.connect(_on_debug_node_selected)
	add_child(compat_panel)
	move_child(compat_panel, hsplit.get_index() + 1)


func _setup_take_panel() -> void:
	take_manager = GNTakeManager.new()
	take_manager.network = network
	take_panel = GNTakePanel.new()
	take_panel.visible = false
	take_panel.setup(take_manager)
	take_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(take_panel)
	move_child(take_panel, hsplit.get_index() + 1)


## Handles take toggle — shows/hides take panel.
func _on_take_toggled(enabled: bool) -> void:
	take_panel.visible = enabled
	_layout_debug_panel()
	_save_setting("take_enabled", enabled)


## Handles compat report toggle.
func _on_compat_toggled(enabled: bool) -> void:
	compat_panel.visible = enabled
	if enabled:
		compat_panel._scan()
	_layout_debug_panel()
	_save_setting("compat_enabled", enabled)


## Handles debug toggle — shows/hides debug panel and overlay.
func _on_debug_toggled(enabled: bool) -> void:
	debug_panel.visible = enabled
	graph_editor.debug_overlay.set_debug_enabled(enabled)
	if _debug_layers_container != null:
		_debug_layers_container.visible = enabled
	_layout_debug_panel()
	_save_setting("debug_enabled", enabled)


## Handles individual debug layer toggles.
func _on_debug_layer_toggled(enabled: bool, layer_idx: int) -> void:
	var overlay := graph_editor.debug_overlay
	if overlay == null:
		return
	match layer_idx:
		0: overlay.show_cook_order = enabled
		1: overlay.show_active_dimming = enabled
		2: overlay.show_dirty_propagation = enabled
		3: overlay.show_sink_labels = enabled
		4: overlay.show_data_flow = enabled
	overlay.queue_redraw()
	if layer_idx == 1:
		overlay._apply_active_dimming()


## Recalculates layout when debug/compat panel visibility changes.
func _layout_debug_panel() -> void:
	var bottom_offset := _TOOLBAR_HEIGHT
	if log_panel.visible:
		bottom_offset += _LOG_PANEL_HEIGHT
	if debug_panel.visible:
		debug_panel.offset_top = -(bottom_offset + 180.0)
		debug_panel.offset_bottom = -(bottom_offset)
		bottom_offset += 180.0
	if compat_panel != null and compat_panel.visible:
		compat_panel.offset_top = -(bottom_offset + 200.0)
		compat_panel.offset_bottom = -(bottom_offset)
		bottom_offset += 200.0
	if take_panel != null and take_panel.visible:
		take_panel.offset_top = -(bottom_offset + 200.0)
		take_panel.offset_bottom = -(bottom_offset)
		bottom_offset += 200.0
	hsplit.offset_bottom = -(bottom_offset)


## Debug panel click-to-select: select node in graph and scroll to it.
func _on_debug_node_selected(node_id: String) -> void:
	_on_graph_node_selected(node_id)
	graph_editor.scroll_to_node(node_id)


## Builds the UI-level sink list and pushes it to the cook engine.
## Called only when viewer targets actually change (not per-frame).
## Structural sinks (is_sink nodes) are auto-detected by the engine.
func _push_active_sinks() -> void:
	if cook_engine == null:
		return
	var sinks: Array[String] = []

	# Main viewer target
	if not _viewer_node_id.is_empty():
		sinks.append(_viewer_node_id)

	# Floating viewer windows
	for vw in _viewer_windows:
		if is_instance_valid(vw) and not vw.node_id.is_empty():
			if vw.node_id not in sinks:
				sinks.append(vw.node_id)

	cook_engine.set_active_sinks(sinks)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

func _on_frame_cooked(frame: int, cook_time_ms: float) -> void:
	# Update docked viewer panel with selected node's output (any family)
	if not _viewer_node_id.is_empty() and viewer_panel != null:
		var view_node: GNNode = network.get_node_by_id(_viewer_node_id)
		if view_node != null:
			viewer_panel.update_from_node(view_node)
		else:
			viewer_panel.clear()

	# Update all floating viewer windows
	_update_viewer_windows()

	# Build info text
	var parts: Array[String] = ["FPS: %d" % Engine.get_frames_per_second()]
	parts.append("Frame: %d" % frame)
	parts.append("Cook: %.2fms" % cook_time_ms)
	var total_nodes := network.get_node_count()
	var active_count: int = cook_engine._active_set.size()
	parts.append("Active: %d/%d" % [active_count, total_nodes])

	# VRAM monitoring (only when toggled on)
	if _vram_enabled:
		var vram_tex: int = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		var vram_buf: int = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
		var vram_total_mb: float = float(vram_tex + vram_buf) / (1024.0 * 1024.0)
		var vram_tex_mb: float = float(vram_tex) / (1024.0 * 1024.0)
		var vram_buf_mb: float = float(vram_buf) / (1024.0 * 1024.0)
		var vram_str: String = "VRAM: %.0fMB (tex %.0f + buf %.0f)" % [
			vram_total_mb, vram_tex_mb, vram_buf_mb]
		if _vram_budget_mb > 0.0 and vram_total_mb > _vram_budget_mb:
			vram_str += " ⚠ >%.0fMB" % _vram_budget_mb
		parts.append(vram_str)

	info_label.text = " | ".join(parts)

	# Update timeline scrubber position (without re-triggering seek)
	if _timeline_scrubber != null and cook_engine != null:
		_timeline_scrubber.set_value_no_signal(cook_engine.elapsed_time)
		var t := cook_engine.elapsed_time
		var mins := int(t) / 60.0
		var secs := fmod(t, 60.0)
		_timeline_time_label.text = "%d:%04.1f / F%d" % [mins, secs, cook_engine.frame_count]

	# Update live previews on all nodes in the graph
	graph_editor.update_previews()

	# Update performance overlays on all nodes
	graph_editor.update_perf_overlays()

	# Update expression reference lines (dashed overlays)
	graph_editor.update_expr_refs()

	# Update warning/error status badges on all nodes
	graph_editor.update_status_badges()

	# Update debug overlay and panel
	if graph_editor.debug_overlay != null:
		graph_editor.debug_overlay.update_overlay()
	if debug_panel != null:
		debug_panel.update_debug_info()


func _on_cook_error(node_id: String, error_msg: String) -> void:
	GNLogger.error("Editor", "Cook error '%s': %s" % [node_id, error_msg])


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Editor Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

## User clicked a node — show its output in the viewer and inspect its parameters.
func _on_graph_node_selected(node_id: String) -> void:
	# Always show inspector for any node type
	inspector.inspect_node(node_id)

	# If the viewer is pinned, don't switch the viewer target on selection
	if _viewer_pinned:
		return

	# Route viewer to any family (not just TOPs)
	var node: GNNode = network.get_node_by_id(node_id)
	if node:
		_viewer_node_id = node_id
		if viewer_panel:
			viewer_panel.set_target(node_id)
		_push_active_sinks()
		GNLogger.info("Editor", "Viewer → '%s' (%s)" % [node_id, GNFamily.get_family_name(node.family)])


func _on_graph_selection_cleared() -> void:
	inspector.clear_inspection()


## Context menu "Open Viewer" — spawn a floating viewer window for the node.
func _on_open_viewer_requested(node_id: String) -> void:
	open_viewer_window(node_id)


## Eye button on a node — toggle pin to the docked viewer (any family).
## Clicking the same pinned node again unpins it (returns to follow-selection).
func _on_viewer_pin_requested(node_id: String) -> void:
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		return

	# Toggle: if the same node is already pinned, unpin it
	if _viewer_pinned and _viewer_node_id == node_id:
		_viewer_pinned = false
		GNLogger.info("Editor", "Unpinned viewer from '%s'" % node_id)
	else:
		_viewer_pinned = true
		_viewer_node_id = node_id
		if viewer_panel:
			viewer_panel.set_target(node_id)
		_push_active_sinks()
		GNLogger.info("Editor", "Pinned viewer → '%s' (%s)" % [
			node_id, GNFamily.get_family_name(node.family)])

	graph_editor.update_viewer_pin_highlights(
		_viewer_node_id if _viewer_pinned else "")


## Keep viewer target in sync when a node is renamed.
func _on_node_renamed(old_id: String, new_id: String) -> void:
	if _viewer_node_id == old_id:
		_viewer_node_id = new_id
	# Update floating viewer windows
	for vw in _viewer_windows:
		vw.handle_node_renamed(old_id, new_id)
	_push_active_sinks()


func _on_log_toggled(pressed: bool) -> void:
	GNLogger.enabled = pressed
	_save_setting("log_enabled", pressed)
	if log_panel:
		log_panel.visible = pressed
		_layout_log_panel()
	if pressed:
		print("[GONODES] Logging ENABLED")
	else:
		print("[GONODES] Logging DISABLED")


func _on_preview_toggled(pressed: bool) -> void:
	graph_editor.set_previews_visible(pressed)
	_save_setting("preview_enabled", pressed)


func _on_perf_toggled(pressed: bool) -> void:
	graph_editor.set_perf_overlay_visible(pressed)
	_save_setting("perf_enabled", pressed)


## Toggles cooking on/off (play/pause).
func _on_play_pause_pressed() -> void:
	var is_playing := cook_engine != null and cook_engine.cooking_enabled
	if cook_engine != null:
		cook_engine.cooking_enabled = not is_playing
	play_button.text = "▶️" if is_playing else "⏸"
	GNLogger.info("Editor", "Cooking %s" % ("PAUSED" if is_playing else "RESUMED"))


## Resets the cook engine: time/frame back to 0, destroys all runtime scene
## nodes (physics bodies, meshes, etc.), and re-cooks from scratch so the
## patch restarts from its initial state.
func _on_reset_pressed() -> void:
	if cook_engine == null:
		return

	# 1. Pause cooking so nothing fires while we tear down
	cook_engine.cooking_enabled = false

	# 2. Reset engine counters (frame, time, internal state maps)
	cook_engine.reset()

	# 3. Destroy every operator's runtime scene node so physics bodies,
	#    soft bodies, joints, etc. are freed and recreated cleanly.
	#    Then reset any RenderTOP viewports so they re-adopt nodes fresh.
	if network != null:
		for node_id in network.nodes:
			var node: GNNode = network.nodes[node_id]
			if node.has_method("destroy_scene_node"):
				node.destroy_scene_node()
		for node_id in network.nodes:
			var node: GNNode = network.nodes[node_id]
			if node.has_method("reset_viewport"):
				node.reset_viewport()

	# 4. Resume cooking — the next cook_frame will rebuild everything
	cook_engine.cooking_enabled = true

	# 5. Sync play button back to "playing" state
	play_button.text = "⏸"

	GNLogger.info("Editor", "Patch reset — restarting from frame 0")


## Toggles non-realtime mode on the cook engine.
func _on_nrt_toggled(pressed: bool) -> void:
	if cook_engine != null:
		cook_engine.non_realtime = pressed
	_save_setting("nrt_enabled", pressed)
	GNLogger.info("Editor", "Non-Realtime mode: %s" % ("ON" if pressed else "OFF"))


## Updates the non-realtime FPS on the cook engine.
func _on_nrt_fps_changed(value: float) -> void:
	if cook_engine != null:
		cook_engine.non_realtime_fps = value
	_save_setting("nrt_fps", value)


## Steps backward one frame.
func _on_step_back_pressed() -> void:
	if cook_engine != null:
		cook_engine.step_backward()
		play_button.text = "▶️"


## Steps forward one frame.
func _on_step_fwd_pressed() -> void:
	if cook_engine != null:
		cook_engine.step_forward()
		play_button.text = "▶️"


## Changes playback speed.
func _on_speed_changed(value: float) -> void:
	if cook_engine != null:
		cook_engine.playback_speed = value


## Cycles loop mode: Off → Loop → Ping-Pong.
func _on_loop_pressed() -> void:
	_loop_mode_idx = (_loop_mode_idx + 1) % 3
	if cook_engine != null:
		cook_engine.loop_mode = _loop_mode_idx
	var labels := ["Loop: Off", "Loop: On", "Loop: P-P"]
	loop_button.text = labels[_loop_mode_idx]


## Handles scrubber drag — seeks to the selected time.
func _on_scrubber_changed(value: float) -> void:
	if cook_engine != null:
		cook_engine.seek_time(value)


## Opens the export dialog for Quick Build.
func _on_build_pressed() -> void:
	if _current_file_path.is_empty():
		# Must save first — can't build an unsaved patch
		var dlg := AcceptDialog.new()
		dlg.title = "Save Required"
		dlg.dialog_text = "Please save your patch before building.\nUse File > Save (Ctrl+S)."
		dlg.confirmed.connect(func(): dlg.queue_free())
		dlg.canceled.connect(func(): dlg.queue_free())
		add_child(dlg)
		dlg.popup_centered()
		return
	_export_dialog.show_for_patch(_current_file_path, network)


func _on_host_io_pressed() -> void:
	if network == null:
		return

	var dlg := AcceptDialog.new()
	dlg.title = "Host I/O Manifest"
	dlg.min_size = Vector2i(600, 500)

	var vbox := VBoxContainer.new()
	dlg.add_child(vbox)

	var desc := Label.new()
	desc.text = "Declares this patch's interface for host applications.\nAuto-generated from HostIn/HostOut bridge operators."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var text_edit := TextEdit.new()
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size = Vector2(580, 350)
	var manifest_json: String = network.get_host_io_json()
	# Pretty-print
	var json := JSON.new()
	if json.parse(manifest_json) == OK:
		text_edit.text = JSON.stringify(json.data, "\t")
	else:
		text_edit.text = manifest_json
	vbox.add_child(text_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var btn_gen := Button.new()
	btn_gen.text = "Regenerate from Bridge Operators"
	btn_gen.tooltip_text = "Scan network for HostIn*/HostOut* nodes and rebuild the manifest"
	btn_gen.pressed.connect(func():
		network.generate_host_io()
		var refreshed: String = network.get_host_io_json()
		var j := JSON.new()
		if j.parse(refreshed) == OK:
			text_edit.text = JSON.stringify(j.data, "\t")
		else:
			text_edit.text = refreshed
	)
	btn_row.add_child(btn_gen)

	var btn_apply := Button.new()
	btn_apply.text = "Apply Changes"
	btn_apply.tooltip_text = "Save the edited manifest into the patch (will be written on next File > Save)"
	btn_apply.pressed.connect(func():
		var j := JSON.new()
		if j.parse(text_edit.text) == OK and j.data is Dictionary:
			network.host_io = j.data
			GNLogger.info("Editor", "Host I/O manifest updated (%d inputs, %d outputs)" % [
				(j.data as Dictionary).get("inputs", []).size(),
				(j.data as Dictionary).get("outputs", []).size()])
		else:
			GNLogger.warn("Editor", "Host I/O manifest is not valid JSON — not applied")
	)
	btn_row.add_child(btn_apply)

	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


# ═══════════════════════════════════════════════════════════════════════════════
# Viewer Windows
# ═══════════════════════════════════════════════════════════════════════════════

## Opens a floating viewer window for the given node (or the current viewer target).
func open_viewer_window(target_node_id: String = "") -> void:
	var nid: String = target_node_id if not target_node_id.is_empty() else _viewer_node_id
	if nid.is_empty():
		return

	var vw := GNViewerWindow.new()
	vw.node_id = nid
	# Offset each new window slightly so they don't stack exactly
	var offset := _viewer_windows.size() * 30
	vw.position = Vector2i(200 + offset, 150 + offset)
	vw.closed.connect(_on_viewer_window_closed)
	add_child(vw)
	_viewer_windows.append(vw)
	_push_active_sinks()
	GNLogger.info("Editor", "Opened viewer window for '%s'" % nid)


## Called when a floating viewer window is closed by the user.
func _on_viewer_window_closed(vw: GNViewerWindow) -> void:
	_viewer_windows.erase(vw)
	_push_active_sinks()


## Updates all floating viewer windows with their pinned node's output.
func _update_viewer_windows() -> void:
	for vw in _viewer_windows:
		if not is_instance_valid(vw):
			continue
		var node: GNNode = network.get_node_by_id(vw.node_id)
		vw.update_from_node(node)


## Closes all floating viewer windows.
func _close_all_viewer_windows() -> void:
	for vw in _viewer_windows.duplicate():
		if is_instance_valid(vw):
			vw.queue_free()
	_viewer_windows.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Help Windows
# ═══════════════════════════════════════════════════════════════════════════════

## Opens a help window for the given node.
func _on_help_requested(node_id: String) -> void:
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		push_warning("[GONODES] Help requested for unknown node '%s'" % node_id)
		return

	# If a help window for this node is already open, just focus it
	for hw in _help_windows:
		if is_instance_valid(hw) and hw.gn_node == node:
			hw.grab_focus()
			return

	var hw := GNHelpWindow.new()
	hw.show_help_for(node)
	var offset := _help_windows.size() * 30
	hw.position = Vector2i(300 + offset, 100 + offset)
	hw.closed.connect(_on_help_window_closed)
	hw.example_patch_requested.connect(_on_example_patch_requested)
	add_child(hw)
	hw.popup_centered()
	_help_windows.append(hw)
	GNLogger.info("Editor", "Opened help window for '%s'" % node_id)


## Called when a help window is closed.
func _on_help_window_closed(hw: Window) -> void:
	_help_windows.erase(hw)


## Handles "Open Example Patch" — loads the .gnpatch into a new floating editor.
func _on_example_patch_requested(patch_path: String) -> void:
	if not FileAccess.file_exists(patch_path):
		push_error("[GONODES] Example patch not found: %s" % patch_path)
		return

	# Load the example into a new Window containing a fresh editor instance
	var editor_scene := load("res://scenes/gn_editor.tscn")
	if editor_scene == null:
		push_error("[GONODES] Failed to load editor scene for example patch")
		return

	var win := Window.new()
	win.title = "Example — %s" % patch_path.get_file().get_basename()
	win.size = Vector2i(1280, 720)
	win.min_size = Vector2i(800, 500)
	win.wrap_controls = true
	win.close_requested.connect(win.queue_free)

	var editor_instance: Control = editor_scene.instantiate()
	win.add_child(editor_instance)
	add_child(win)
	win.popup_centered()

	# After the editor is ready, load the example patch into it
	editor_instance.call_deferred("_load_from_path", patch_path)
	GNLogger.info("Editor", "Opened example patch: %s" % patch_path)


## Closes all floating help windows.
func _close_all_help_windows() -> void:
	for hw in _help_windows.duplicate():
		if is_instance_valid(hw):
			hw.queue_free()
	_help_windows.clear()


## Toggles the main help reference window (singleton — created on first use).
func _toggle_main_help_window() -> void:
	if _main_help_window != null and is_instance_valid(_main_help_window):
		_main_help_window.visible = not _main_help_window.visible
		if _main_help_window.visible:
			_main_help_window.grab_focus()
		return
	_main_help_window = GNMainHelpWindow.new()
	add_child(_main_help_window)
	_main_help_window.popup_centered()


# ═══════════════════════════════════════════════════════════════════════════════
# Save / Load
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the FileDialogs for save and load.
func _setup_file_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.title = "Save Patch"
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.filters = PackedStringArray(["*.gnpatch ; GONODES Patch"])
	_save_dialog.min_size = Vector2i(700, 500)
	_save_dialog.file_selected.connect(_on_save_file_selected)
	add_child(_save_dialog)

	_load_dialog = FileDialog.new()
	_load_dialog.title = "Open Patch"
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_load_dialog.filters = PackedStringArray(["*.gnpatch ; GONODES Patch"])
	_load_dialog.min_size = Vector2i(700, 500)
	_load_dialog.file_selected.connect(_on_load_file_selected)
	add_child(_load_dialog)


## Adds New / Open / Save buttons to the InfoBar.
func _setup_toolbar() -> void:
	var info_bar := $InfoBar as VBoxContainer
	info_bar.add_theme_constant_override("separation", 2)

	# ── Row 1: File & Project ────────────────────────────────────────────
	var scroll1 := ScrollContainer.new()
	scroll1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll1.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(scroll1)
	info_bar.move_child(scroll1, 0)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll1.add_child(row1)

	var btn_new := Button.new()
	btn_new.text = "New"
	btn_new.tooltip_text = "New patch (Ctrl+N)"
	btn_new.pressed.connect(_on_new_pressed)
	row1.add_child(btn_new)

	var btn_open := Button.new()
	btn_open.text = "Open"
	btn_open.tooltip_text = "Open patch (Ctrl+O)"
	btn_open.pressed.connect(_on_open_pressed)
	row1.add_child(btn_open)

	var btn_save := Button.new()
	btn_save.text = "Save"
	btn_save.tooltip_text = "Save patch (Ctrl+S)"
	btn_save.pressed.connect(_on_save_pressed)
	row1.add_child(btn_save)

	var btn_save_as := Button.new()
	btn_save_as.text = "Save As"
	btn_save_as.tooltip_text = "Save patch as… (Ctrl+Shift+S)"
	btn_save_as.pressed.connect(_on_save_as_pressed)
	row1.add_child(btn_save_as)

	row1.add_child(VSeparator.new())

	# Build button — opens the export dialog for Quick Build
	var btn_build := Button.new()
	btn_build.text = "Build"
	btn_build.tooltip_text = "Export patch as a standalone application (Quick Build)"
	btn_build.pressed.connect(_on_build_pressed)
	row1.add_child(btn_build)

	var btn_host_io := Button.new()
	btn_host_io.text = "Host I/O"
	btn_host_io.tooltip_text = "View / edit the Host I/O manifest for embedded integration"
	btn_host_io.pressed.connect(_on_host_io_pressed)
	row1.add_child(btn_host_io)

	row1.add_child(VSeparator.new())

	# ── Graph View ──

	# Preview toggle
	preview_toggle = CheckButton.new()
	preview_toggle.text = "Previews"
	preview_toggle.tooltip_text = "Show / hide inline node previews"
	preview_toggle.button_pressed = true
	preview_toggle.toggled.connect(_on_preview_toggled)
	row1.add_child(preview_toggle)

	# Minimap toggle
	var minimap_toggle := CheckButton.new()
	minimap_toggle.text = "Minimap"
	minimap_toggle.tooltip_text = "Show / hide minimap (M)"
	minimap_toggle.button_pressed = graph_editor.minimap_enabled
	minimap_toggle.toggled.connect(func(on: bool):
		graph_editor.minimap_enabled = on)
	row1.add_child(minimap_toggle)

	# Wire style OptionButton
	var wire_opt := OptionButton.new()
	wire_opt.tooltip_text = "Wire style (W to cycle)"
	for wn in GNGraphEditor._WIRE_STYLE_NAMES:
		wire_opt.add_item(wn)
	wire_opt.selected = 0
	wire_opt.item_selected.connect(func(wire_idx: int):
		graph_editor.set_wire_style(wire_idx))
	row1.add_child(wire_opt)

	# Auto-layout button
	var btn_layout := Button.new()
	btn_layout.text = "Layout"
	btn_layout.tooltip_text = "Auto-layout all nodes (Ctrl+L)"
	btn_layout.pressed.connect(func(): graph_editor.auto_layout())
	row1.add_child(btn_layout)

	# Open Viewer button
	var btn_viewer := Button.new()
	btn_viewer.text = "+ Viewer"
	btn_viewer.tooltip_text = "Open a floating viewer window for the selected node"
	btn_viewer.pressed.connect(func(): open_viewer_window())
	row1.add_child(btn_viewer)

	# Help button
	var btn_help := Button.new()
	btn_help.text = "📖 Help"
	btn_help.tooltip_text = "Open the help reference hub (F1)"
	btn_help.pressed.connect(_toggle_main_help_window)
	row1.add_child(btn_help)

	# ── Timeline & Transport Row ─────────────────────────────────────────
	var scroll_tl := ScrollContainer.new()
	scroll_tl.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_tl.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(scroll_tl)
	var tl_row := HBoxContainer.new()
	tl_row.add_theme_constant_override("separation", 4)
	tl_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_tl.add_child(tl_row)

	# Play / Pause button
	play_button = Button.new()
	play_button.text = "⏸"
	play_button.tooltip_text = "Pause / Resume cooking (Space)"
	play_button.pressed.connect(_on_play_pause_pressed)
	tl_row.add_child(play_button)

	# Reset button
	reset_button = Button.new()
	reset_button.text = "⏮"
	reset_button.tooltip_text = "Reset the patch back to frame 0 (Escape)"
	reset_button.pressed.connect(_on_reset_pressed)
	tl_row.add_child(reset_button)

	# Step backward button
	step_back_button = Button.new()
	step_back_button.text = "⏪"
	step_back_button.tooltip_text = "Step back one frame"
	step_back_button.pressed.connect(_on_step_back_pressed)
	tl_row.add_child(step_back_button)

	# Step forward button
	step_fwd_button = Button.new()
	step_fwd_button.text = "⏩"
	step_fwd_button.tooltip_text = "Step forward one frame"
	step_fwd_button.pressed.connect(_on_step_fwd_pressed)
	tl_row.add_child(step_fwd_button)

	# Speed multiplier
	speed_spin = SpinBox.new()
	speed_spin.min_value = 0.0
	speed_spin.max_value = 10.0
	speed_spin.value = 1.0
	speed_spin.step = 0.1
	speed_spin.suffix = "x"
	speed_spin.tooltip_text = "Global playback speed multiplier"
	speed_spin.custom_minimum_size.x = 80
	speed_spin.value_changed.connect(_on_speed_changed)
	tl_row.add_child(speed_spin)

	# Loop mode cycle button
	loop_button = Button.new()
	loop_button.text = "Loop: Off"
	loop_button.tooltip_text = "Cycle loop mode: Off → Loop → Ping-Pong (requires time range)"
	loop_button.pressed.connect(_on_loop_pressed)
	tl_row.add_child(loop_button)

	# Non-Realtime toggle
	nrt_toggle = CheckButton.new()
	nrt_toggle.text = "NRT"
	nrt_toggle.tooltip_text = "Non-Realtime mode — fixed timestep for deterministic, frame-perfect recording"
	nrt_toggle.button_pressed = false
	nrt_toggle.toggled.connect(_on_nrt_toggled)
	tl_row.add_child(nrt_toggle)

	# Non-Realtime FPS SpinBox
	nrt_fps_spin = SpinBox.new()
	nrt_fps_spin.min_value = 1.0
	nrt_fps_spin.max_value = 240.0
	nrt_fps_spin.value = 30.0
	nrt_fps_spin.step = 1.0
	nrt_fps_spin.suffix = " fps"
	nrt_fps_spin.tooltip_text = "Target FPS for non-realtime mode"
	nrt_fps_spin.editable = true
	nrt_fps_spin.custom_minimum_size.x = 90
	nrt_fps_spin.value_changed.connect(_on_nrt_fps_changed)
	tl_row.add_child(nrt_fps_spin)

	tl_row.add_child(VSeparator.new())

	_timeline_time_label = Label.new()
	_timeline_time_label.text = "0:00.0 / F0"
	_timeline_time_label.custom_minimum_size.x = 120
	tl_row.add_child(_timeline_time_label)

	_timeline_scrubber = HSlider.new()
	_timeline_scrubber.min_value = 0.0
	_timeline_scrubber.max_value = 600.0  # 10 minutes default
	_timeline_scrubber.step = 0.01
	_timeline_scrubber.value = 0.0
	_timeline_scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_scrubber.tooltip_text = "Drag to scrub time — click to seek"
	_timeline_scrubber.value_changed.connect(_on_scrubber_changed)
	tl_row.add_child(_timeline_scrubber)

	# ── Row 3: Debug, Monitoring & Panels ────────────────────────────────
	var scroll3 := ScrollContainer.new()
	scroll3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll3.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(scroll3)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	row3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll3.add_child(row3)

	# Performance overlay toggle
	perf_toggle = CheckButton.new()
	perf_toggle.text = "Perf"
	perf_toggle.tooltip_text = "Show / hide per-node cook time overlay"
	perf_toggle.button_pressed = false
	perf_toggle.toggled.connect(_on_perf_toggled)
	row3.add_child(perf_toggle)

	# VRAM monitoring toggle
	vram_toggle = CheckButton.new()
	vram_toggle.text = "VRAM"
	vram_toggle.tooltip_text = "Show GPU memory usage in the status bar"
	vram_toggle.button_pressed = false
	vram_toggle.toggled.connect(func(on: bool): _vram_enabled = on)
	row3.add_child(vram_toggle)

	# Debug overlay + panel toggle
	debug_toggle = CheckButton.new()
	debug_toggle.text = "Debug"
	debug_toggle.tooltip_text = "Show debug overlay (cook order, active chain, dirty flash, data flow) + debug panel (F2)"
	debug_toggle.button_pressed = false
	debug_toggle.toggled.connect(_on_debug_toggled)
	row3.add_child(debug_toggle)

	# Debug layer toggles (only visible when debug is on)
	_debug_layers_container = HBoxContainer.new()
	_debug_layers_container.add_theme_constant_override("separation", 2)
	_debug_layers_container.visible = false

	var layer_names := ["#Order", "Dim", "Dirty", "Sinks", "Flow"]
	var layer_tooltips := [
		"Cook order badges (#1, #2, …)",
		"Dim inactive nodes to 40% opacity",
		"Orange flash on nodes dirtied this frame",
		"Sink halo rings + upstream colored dots",
		"Data dimensions on wires (resolution, channels, vertices)",
	]
	for i in range(5):
		var cb := CheckButton.new()
		cb.text = layer_names[i]
		cb.tooltip_text = layer_tooltips[i]
		cb.button_pressed = true
		cb.add_theme_font_size_override("font_size", 11)
		cb.toggled.connect(_on_debug_layer_toggled.bind(i))
		_debug_layers_container.add_child(cb)
	row3.add_child(_debug_layers_container)

	row3.add_child(VSeparator.new())

	# Log panel toggle
	log_toggle.text = "Logs"
	log_toggle.reparent(row3, false)

	# Compat report toggle
	compat_toggle = CheckButton.new()
	compat_toggle.text = "Compat"
	compat_toggle.tooltip_text = "Show export compatibility report — scan network against target platform/renderer"
	compat_toggle.button_pressed = false
	compat_toggle.toggled.connect(_on_compat_toggled)
	row3.add_child(compat_toggle)

	take_toggle = CheckButton.new()
	take_toggle.text = "Takes"
	take_toggle.tooltip_text = "Show take manager — capture, apply and blend named parameter snapshots (Shift+T)"
	take_toggle.button_pressed = false
	take_toggle.toggled.connect(_on_take_toggled)
	row3.add_child(take_toggle)

	# Spacer pushes status info to the right
	var spacer3 := Control.new()
	spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(spacer3)

	# Reparent scene-defined InfoLabel to right end of status row
	info_label.reparent(row3, false)
	info_label.size_flags_horizontal = Control.SIZE_SHRINK_END

	# Create the export dialog (hidden until needed)
	_export_dialog = GNExportDialog.new()
	_export_dialog.visible = false
	add_child(_export_dialog)


## Keyboard shortcuts for file operations and sub-network navigation.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.keycode:
				KEY_S:
					if event.shift_pressed:
						_on_save_as_pressed()
					else:
						_on_save_pressed()
					get_viewport().set_input_as_handled()
				KEY_O:
					_on_open_pressed()
					get_viewport().set_input_as_handled()
				KEY_N:
					_on_new_pressed()
					get_viewport().set_input_as_handled()
		# Backspace — dive out of sub-network (when not renaming)
		elif event.keycode == KEY_SPACE:
			var focus_owner := get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox:
				return
			play_button.pressed.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var focus_owner := get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox:
				return
			_on_reset_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE and _nav_stack.size() > 1:
			var focus_owner := get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit:
				return
			_navigate_to_depth(_nav_stack.size() - 2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1:
			_toggle_main_help_window()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			debug_toggle.button_pressed = not debug_toggle.button_pressed
			get_viewport().set_input_as_handled()


## New patch — clears everything and starts fresh.
func _on_new_pressed() -> void:
	_viewer_node_id = ""
	_viewer_pinned = false
	if viewer_panel:
		viewer_panel.clear()
	_close_all_viewer_windows()
	_close_all_help_windows()
	inspector.clear_inspection()
	graph_editor._unbind_network()

	# Stop cook engine and remove old network's nodes from tree
	cook_engine.network = null
	_remove_network_nodes_from_tree()

	# Create fresh network
	network = GNNetwork.new()
	_current_file_path = ""
	_project.clear()
	cook_engine.project_dir = ""

	# Rebind everything
	graph_editor.bind_network(network)
	inspector.network = network
	cook_engine.network = network
	cook_engine._nodes_adopted = false

	network.node_renamed.connect(_on_node_renamed)
	graph_editor.clear_undo_history()
	graph_editor.update_viewer_pin_highlights("")

	_push_active_sinks()
	_update_title()
	GNLogger.info("Editor", "New patch created")


## Open — show file dialog.
func _on_open_pressed() -> void:
	_load_dialog.popup_centered()


## Save — save to current path or show Save As dialog.
func _on_save_pressed() -> void:
	if _current_file_path.is_empty():
		_on_save_as_pressed()
		return
	_save_to_path(_current_file_path)


## Save As — always show file dialog.
func _on_save_as_pressed() -> void:
	_save_dialog.popup_centered()


## Called when user picks a file in the Save dialog.
func _on_save_file_selected(path: String) -> void:
	_save_to_path(path)


## Called when user picks a file in the Load dialog.
func _on_load_file_selected(path: String) -> void:
	_load_from_path(path)


## Saves the current network to the given path.
func _save_to_path(path: String) -> void:
	# Ensure project folder exists for this patch
	_project.set_from_patch_path(path)
	_project.ensure_ready()
	cook_engine.project_dir = _project.project_dir

	var err := network.save_to_file(path)
	if err == OK:
		_current_file_path = path
		_save_setting("last_patch_path", path)
		_update_title()
		print("[GONODES] Saved patch: %s" % path)
	else:
		push_error("[GONODES] Failed to save patch to '%s' (error %d)" % [path, err])


## Loads a network from the given path.
func _load_from_path(path: String) -> void:
	_viewer_node_id = ""
	_viewer_pinned = false
	if viewer_panel:
		viewer_panel.clear()
	_close_all_viewer_windows()
	_close_all_help_windows()
	inspector.clear_inspection()
	graph_editor._unbind_network()

	# Stop cook engine and remove old network's nodes from the scene tree
	cook_engine.network = null
	_remove_network_nodes_from_tree()

	# Create fresh network and load into it
	network = GNNetwork.new()
	var err := network.load_from_file(path)
	if err != OK:
		push_error("[GONODES] Failed to load patch from '%s' (error %d)" % [path, err])
		return

	_current_file_path = path
	_save_setting("last_patch_path", path)

	# Set up project folder for this patch
	_project.set_from_patch_path(path)
	cook_engine.project_dir = _project.project_dir

	# Rebind everything — cook engine will adopt nodes on next frame
	graph_editor.bind_network(network)
	inspector.network = network
	cook_engine.network = network
	cook_engine._nodes_adopted = false  # Force re-adoption of loaded nodes

	network.node_renamed.connect(_on_node_renamed)
	graph_editor.clear_undo_history()
	graph_editor.update_viewer_pin_highlights("")

	_push_active_sinks()
	_update_title()
	print("[GONODES] Loaded patch: %s (%d nodes, %d connections)" % [
		path, network.get_node_count(), network.get_connection_count()])


## Removes all current network node instances from the scene tree.
func _remove_network_nodes_from_tree() -> void:
	if network == null:
		return
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node.is_inside_tree():
			node.get_parent().remove_child(node)


## Updates the window title to show the current file name.
func _update_title() -> void:
	if _current_file_path.is_empty():
		get_window().title = "GONODES Editor — Untitled"
	else:
		var file_name := _current_file_path.get_file()
		get_window().title = "GONODES Editor — %s" % file_name


# ═══════════════════════════════════════════════════════════════════════════════
# Settings Persistence
# ═══════════════════════════════════════════════════════════════════════════════

## Saves a key-value pair to the user settings file.
func _save_setting(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	# Load existing settings first so we don't clobber other keys
	if FileAccess.file_exists(_SETTINGS_PATH):
		cfg.load(_SETTINGS_PATH)
	cfg.set_value("editor", key, value)
	cfg.save(_SETTINGS_PATH)


## Loads a setting value, returning [param default] if the key doesn't exist.
func _load_setting(key: String, default: Variant = null) -> Variant:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(_SETTINGS_PATH):
		return default
	if cfg.load(_SETTINGS_PATH) != OK:
		return default
	return cfg.get_value("editor", key, default)


## Restores all persisted UI state — toggles, split offsets, etc.
## Called once at the end of _ready(), after toolbar and panels are set up.
func _restore_ui_state() -> void:
	# Toggles — set button_pressed which fires the toggled signal automatically
	var saved_preview: bool = _load_setting("preview_enabled", true)
	preview_toggle.set_pressed_no_signal(saved_preview)
	graph_editor.set_previews_visible(saved_preview)

	var saved_perf: bool = _load_setting("perf_enabled", false)
	perf_toggle.set_pressed_no_signal(saved_perf)
	graph_editor.set_perf_overlay_visible(saved_perf)

	var saved_log: bool = _load_setting("log_enabled", false)
	log_toggle.set_pressed_no_signal(saved_log)
	GNLogger.enabled = saved_log
	if log_panel:
		log_panel.visible = saved_log
		_layout_log_panel()

	# Non-Realtime mode
	var saved_nrt: bool = _load_setting("nrt_enabled", false)
	nrt_toggle.set_pressed_no_signal(saved_nrt)
	if cook_engine != null:
		cook_engine.non_realtime = saved_nrt

	var saved_nrt_fps: float = _load_setting("nrt_fps", 30.0)
	nrt_fps_spin.set_value_no_signal(saved_nrt_fps)
	if cook_engine != null:
		cook_engine.non_realtime_fps = saved_nrt_fps

	# Split container offsets
	var saved_hsplit: int = _load_setting("hsplit_offset", -400)
	hsplit.split_offset = saved_hsplit

	var saved_vsplit: int = _load_setting("vsplit_offset", 0)
	right_panel.split_offset = saved_vsplit

	# Debug overlay + panel
	var saved_debug: bool = _load_setting("debug_enabled", false)
	debug_toggle.set_pressed_no_signal(saved_debug)
	if saved_debug:
		_on_debug_toggled(true)

	# Take panel
	var saved_take: bool = _load_setting("take_enabled", false)
	take_toggle.set_pressed_no_signal(saved_take)
	if saved_take:
		_on_take_toggled(true)


# ═══════════════════════════════════════════════════════════════════════════════
# Sub-Network Navigation
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the breadcrumb bar above the graph editor inside GraphPanel.
func _setup_breadcrumb_bar() -> void:
	_breadcrumb_bar = HBoxContainer.new()
	_breadcrumb_bar.name = "BreadcrumbBar"

	# Style: dark background, small padding
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0

	var panel := PanelContainer.new()
	panel.name = "BreadcrumbPanel"
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(_breadcrumb_bar)

	# Insert at top of GraphPanel (before GraphEditor) using a VBoxContainer
	var graph_panel: PanelContainer = $HSplit/GraphPanel
	var vbox := VBoxContainer.new()
	vbox.name = "GraphVBox"

	# Reparent GraphEditor into the VBox
	graph_panel.remove_child(graph_editor)
	graph_panel.add_child(vbox)
	vbox.add_child(panel)
	vbox.add_child(graph_editor)
	graph_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Start hidden — only show when inside a sub-network
	panel.visible = false


## Initializes the navigation stack with the root network.
func _init_nav_stack() -> void:
	_nav_stack.clear()
	var root := _NavEntry.new()
	root.network = network
	root.subnet_node_id = ""
	root.scroll_offset = graph_editor.scroll_offset
	root.zoom = graph_editor.zoom
	root.viewer_node_id = _viewer_node_id
	_nav_stack.append(root)


## Called when the user wants to dive into a SubNetworkNode.
func _on_dive_into_requested(node_id: String) -> void:
	var node: GNNode = _current_network().get_node_by_id(node_id)
	if not node is SubNetworkNode:
		return
	var subnet = node
	subnet._ensure_inner_network()

	# Save current view state
	var current := _nav_stack.back() as _NavEntry
	current.scroll_offset = graph_editor.scroll_offset
	current.zoom = graph_editor.zoom
	current.viewer_node_id = _viewer_node_id

	# Push new level onto the stack
	var entry := _NavEntry.new()
	entry.network = subnet.inner_network
	entry.subnet_node_id = node_id
	entry.scroll_offset = Vector2.ZERO
	entry.zoom = 0.8
	entry.viewer_node_id = ""
	_nav_stack.append(entry)

	# Switch the graph editor to the inner network
	_switch_to_network(subnet.inner_network)

	# Reset viewer
	_viewer_node_id = ""
	_viewer_pinned = false
	if viewer_panel:
		viewer_panel.clear()

	# Update breadcrumb
	_update_breadcrumb()

	GNLogger.info("Editor", "Dived into sub-network '%s' (depth %d)" % [
		node_id, _nav_stack.size() - 1])


## Navigates back to a specific depth in the navigation stack.
## depth=0 is root, depth=1 is first sub-network, etc.
func _navigate_to_depth(target_depth: int) -> void:
	if target_depth < 0 or target_depth >= _nav_stack.size():
		return
	if target_depth == _nav_stack.size() - 1:
		return  # Already there

	# Save current view state before leaving
	var current := _nav_stack.back() as _NavEntry
	current.scroll_offset = graph_editor.scroll_offset
	current.zoom = graph_editor.zoom
	current.viewer_node_id = _viewer_node_id

	# Sync ports on every sub-network we are leaving so parent views
	# show up-to-date input/output ports after the user edited tunnels.
	for i in range(_nav_stack.size() - 1, target_depth, -1):
		var leaving: _NavEntry = _nav_stack[i] as _NavEntry
		if not leaving.subnet_node_id.is_empty():
			# Find the SubNetworkNode in the PARENT level's network
			var parent_entry: _NavEntry = _nav_stack[i - 1] as _NavEntry
			var subnet_node: GNNode = parent_entry.network.get_node_by_id(
				leaving.subnet_node_id)
			if subnet_node and subnet_node is SubNetworkNode:
				subnet_node.sync_ports_from_tunnels()

	# Pop entries until we reach target depth
	while _nav_stack.size() > target_depth + 1:
		_nav_stack.pop_back()

	# Restore target level
	var target := _nav_stack.back() as _NavEntry
	_switch_to_network(target.network)

	# Restore view state
	graph_editor.scroll_offset = target.scroll_offset
	graph_editor.zoom = target.zoom
	_viewer_node_id = target.viewer_node_id
	if not _viewer_node_id.is_empty():
		_push_active_sinks()

	# Update breadcrumb
	_update_breadcrumb()

	GNLogger.info("Editor", "Navigated to depth %d" % target_depth)


## Returns the network currently being displayed.
func _current_network() -> GNNetwork:
	if _nav_stack.is_empty():
		return network
	return (_nav_stack.back() as _NavEntry).network


## Switches the graph editor and inspector to a different network.
## Clears undo history to prevent cross-level undo which would operate
## on the wrong network reference.
func _switch_to_network(net: GNNetwork) -> void:
	graph_editor.clear_undo_history()
	graph_editor.bind_network(net)
	inspector.network = net


## Rebuilds the breadcrumb bar labels from the navigation stack.
func _update_breadcrumb() -> void:
	# Clear existing breadcrumb children
	for child in _breadcrumb_bar.get_children():
		child.queue_free()

	# Find the panel wrapper to show/hide
	var panel: PanelContainer = _breadcrumb_bar.get_parent() as PanelContainer
	if panel:
		panel.visible = _nav_stack.size() > 1

	for i in range(_nav_stack.size()):
		var entry: _NavEntry = _nav_stack[i] as _NavEntry

		# Separator
		if i > 0:
			var sep := Label.new()
			sep.text = " / "
			sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			sep.add_theme_font_size_override("font_size", 13)
			_breadcrumb_bar.add_child(sep)

		# Clickable label
		var btn := Button.new()
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 13)
		if i == 0:
			btn.text = "root"
		else:
			btn.text = entry.subnet_node_id
		# Highlight current level
		if i == _nav_stack.size() - 1:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
			btn.disabled = true
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
			var depth := i
			btn.pressed.connect(_navigate_to_depth.bind(depth))
		_breadcrumb_bar.add_child(btn)

	# Asset edit-mode banner
	if not _editing_asset_node_id.is_empty():
		var asset_node: GNNode = network.get_node_by_id(_editing_asset_node_id)
		var asset_label := _editing_asset_node_id
		if asset_node is GNCustomOperator:
			var co := asset_node as GNCustomOperator
			asset_label = co.asset_path.get_file() if not co.asset_path.is_empty() else _editing_asset_node_id

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_breadcrumb_bar.add_child(spacer)

		var edit_label := Label.new()
		edit_label.text = "Editing: %s" % asset_label
		edit_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		edit_label.add_theme_font_size_override("font_size", 13)
		_breadcrumb_bar.add_child(edit_label)

		var save_btn := Button.new()
		save_btn.text = "Save"
		save_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		save_btn.pressed.connect(_on_asset_edit_save)
		_breadcrumb_bar.add_child(save_btn)

		var discard_btn := Button.new()
		discard_btn.text = "Discard"
		discard_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		discard_btn.pressed.connect(_on_asset_edit_discard)
		_breadcrumb_bar.add_child(discard_btn)

		var repromote_btn := Button.new()
		repromote_btn.text = "Re-promote\u2026"
		repromote_btn.pressed.connect(func() -> void: _on_repromote_asset_requested(_editing_asset_node_id))
		_breadcrumb_bar.add_child(repromote_btn)


# ═══════════════════════════════════════════════════════════════════════════════
# Asset Edit-in-Place
# ═══════════════════════════════════════════════════════════════════════════════

## Called when the user right-clicks a GNCustomOperator → "Edit Asset…".
func _on_edit_asset_requested(node_id: String) -> void:
	var node: GNNode = _current_network().get_node_by_id(node_id)
	if not node is GNCustomOperator:
		return
	var co := node as GNCustomOperator
	co.begin_asset_edit()
	_editing_asset_node_id = node_id

	# Dive into the inner network (reuse existing mechanism)
	_on_dive_into_requested(node_id)


## Saves the edited asset back to disk and reloads sibling instances.
func _on_asset_edit_save() -> void:
	if _editing_asset_node_id.is_empty():
		return
	var co := network.get_node_by_id(_editing_asset_node_id) as GNCustomOperator
	if co == null:
		return

	if not co.save_asset_from_inner():
		GNLogger.error("Editor", "Failed to save asset: %s" % co.asset_path)
		return

	# Reload ALL instances of the same asset across the entire project
	var asset_path: String = co.asset_path
	var reloaded: int = _reload_asset_instances_recursive(network, asset_path, _editing_asset_node_id)
	if reloaded > 0:
		GNLogger.info("Editor", "Reloaded %d instance(s) of '%s' across all networks" % [reloaded, asset_path])

	# Navigate back to root/parent level
	_editing_asset_node_id = ""
	_navigate_to_depth(maxi(0, _nav_stack.size() - 2))

	GNLogger.info("Editor", "Asset saved and instances reloaded: %s" % asset_path)


## Discards in-progress edits and navigates back.
func _on_asset_edit_discard() -> void:
	if _editing_asset_node_id.is_empty():
		return
	var co := network.get_node_by_id(_editing_asset_node_id) as GNCustomOperator
	if co != null:
		co.discard_asset_edits()

	_editing_asset_node_id = ""
	_navigate_to_depth(maxi(0, _nav_stack.size() - 2))

	GNLogger.info("Editor", "Asset edits discarded")


## Recursively walks a GNNetwork and all nested SubNetworkNode inner_networks,
## reloading every GNCustomOperator whose asset_path matches [param target_path].
## Skips the node with [param skip_id] (the one that just saved).
## Returns the count of reloaded instances.
func _reload_asset_instances_recursive(net: GNNetwork, target_path: String, skip_id: String) -> int:
	var count: int = 0
	for nid in net.nodes:
		var node: GNNode = net.nodes[nid]
		if node is GNCustomOperator:
			var co := node as GNCustomOperator
			# Reload if same asset and not the one that just saved
			if co.asset_path == target_path and nid != skip_id:
				co.reload_from_asset()
				count += 1
			# Also recurse into this custom operator's inner network
			if co.inner_network != null:
				count += _reload_asset_instances_recursive(co.inner_network, target_path, skip_id)
		elif node is SubNetworkNode:
			var sn := node as SubNetworkNode
			if sn.inner_network != null:
				count += _reload_asset_instances_recursive(sn.inner_network, target_path, skip_id)
	return count


## Converts a GNCustomOperator into a plain SubNetworkNode (detaches from asset).
func _on_make_unique_requested(node_id: String) -> void:
	var node: GNNode = _current_network().get_node_by_id(node_id)
	if not node is GNCustomOperator:
		return
	var co := node as GNCustomOperator

	# Snapshot the inner network
	var inner_dict: Dictionary = co.inner_network.to_dict()
	var old_pos: Vector2 = co.graph_position

	# Collect all connections to/from this node
	var incoming: Array = []
	var outgoing: Array = []
	for conn in _current_network().connections:
		if conn.to_node == node_id:
			incoming.append({"from": conn.from_node, "from_port": conn.from_port, "to_port": conn.to_port})
		if conn.from_node == node_id:
			outgoing.append({"to": conn.to_node, "to_port": conn.to_port, "from_port": conn.from_port})

	# Remove old custom operator node + its connections
	_current_network().remove_node(node_id)

	# Create plain SubNetworkNode
	var subnet := SubNetworkNode.new()
	subnet.initialize(node_id)
	subnet.graph_position = old_pos
	subnet._ensure_inner_network()
	subnet.inner_network.from_dict(inner_dict)
	subnet.sync_ports_from_tunnels()
	_current_network().add_node(subnet)

	# Restore connections
	for c in incoming:
		_current_network().connect_nodes(c["from"], c["from_port"], node_id, c["to_port"])
	for c in outgoing:
		_current_network().connect_nodes(node_id, c["from_port"], c["to"], c["to_port"])

	# Refresh UI
	graph_editor.bind_network(_current_network())
	GNLogger.info("Editor", "Made '%s' unique — detached from asset" % node_id)


## Re-opens the promotion dialog on the custom asset's inner network.
func _on_repromote_asset_requested(node_id: String) -> void:
	var node: GNNode = network.get_node_by_id(node_id)
	if not node is GNCustomOperator:
		# If we're currently dived in, the node is in the root network
		if _nav_stack.size() > 0:
			node = (_nav_stack[0] as _NavEntry).network.get_node_by_id(node_id)
	if not node is SubNetworkNode:
		return

	# Reuse the graph editor's promotion dialog
	graph_editor._show_promote_to_asset_dialog_for(node as SubNetworkNode)
