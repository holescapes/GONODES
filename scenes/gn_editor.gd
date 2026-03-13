extends Control
## GONODES Editor — Main editor scene.
## Split layout: GNGraphEditor (left/center) + Viewer + Inspector (right).
## Runs a cook engine each frame and displays the output of the last TOP
## in the viewer panel. Includes a debug info label and log toggle.
## Supports save/load of patches as `.gnpatch` JSON files.

const GNHelpWindowScene := preload("res://addons/gonodes/ui/gn_help_window.gd")
const _GNMainHelpWindowScript = preload("res://addons/gonodes/ui/gn_main_help_window.gd")
const _SubNetworkNodeScript = preload("res://addons/gonodes/operators/comp/sub_network_node.gd")
const _GNExportDialogScript = preload("res://addons/gonodes/ui/gn_export_dialog.gd")

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
var preview_toggle: CheckButton
var perf_toggle: CheckButton
var vram_toggle: CheckButton
var nrt_toggle: CheckButton
var nrt_fps_spin: SpinBox

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


func _ready() -> void:
	# Wire log toggle early so extension scan results are visible
	log_toggle.toggled.connect(_on_log_toggled)
	GNLogger.enabled = log_toggle.button_pressed
	GNLogger.level = GNLogger.Level.INFO

	# Initialize extension registry — scan for gn_ext_* addon manifests
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()

	_setup_network()
	_setup_cook_engine()
	_setup_file_dialogs()
	_setup_toolbar()
	_setup_log_panel()

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

	# Replace the scene's TextureRect Viewer with a GNViewerPanel
	_setup_viewer_panel()

	# Bind inspector to network
	inspector.network = network

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
	cook_engine.frame_cooked.connect(_check_stress_report)
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


const _TOOLBAR_HEIGHT := 66.0
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

	if not _viewer_node_id.is_empty():
		parts.append("Viewing: %s" % _viewer_node_id)

	info_label.text = " | ".join(parts)

	# Update live previews on all nodes in the graph
	graph_editor.update_previews()

	# Update performance overlays on all nodes
	graph_editor.update_perf_overlays()

	# Update expression reference lines (dashed overlays)
	graph_editor.update_expr_refs()

	# Update warning/error status badges on all nodes
	graph_editor.update_status_badges()


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
func _on_play_pause_toggled(paused: bool) -> void:
	if cook_engine != null:
		cook_engine.cooking_enabled = not paused
	play_button.text = "Play  ▶" if paused else "Pause  ⏸"
	GNLogger.info("Editor", "Cooking %s" % ("PAUSED" if paused else "RESUMED"))


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
	play_button.button_pressed = false  # false = playing (not paused)
	play_button.text = "Pause  ⏸"

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
	_export_dialog.show_for_patch(_current_file_path)


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

	var hw := GNHelpWindowScene.new()
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
	_main_help_window = _GNMainHelpWindowScript.new()
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
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	info_bar.add_child(row1)
	info_bar.move_child(row1, 0)

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

	row1.add_child(VSeparator.new())

	# Play / Pause button
	play_button = Button.new()
	play_button.text = "Pause  ⏸"
	play_button.tooltip_text = "Pause / Resume cooking (Space)"
	play_button.toggle_mode = true
	play_button.button_pressed = false  # false = playing (not paused)
	play_button.toggled.connect(_on_play_pause_toggled)
	row1.add_child(play_button)

	# Reset button
	reset_button = Button.new()
	reset_button.text = "Reset  ⏮"
	reset_button.tooltip_text = "Reset the patch back to frame 0 (Escape)"
	reset_button.pressed.connect(_on_reset_pressed)
	row1.add_child(reset_button)

	row1.add_child(VSeparator.new())

	# Non-Realtime toggle
	nrt_toggle = CheckButton.new()
	nrt_toggle.text = "NRT"
	nrt_toggle.tooltip_text = "Non-Realtime mode — fixed timestep for deterministic, frame-perfect recording"
	nrt_toggle.button_pressed = false
	nrt_toggle.toggled.connect(_on_nrt_toggled)
	row1.add_child(nrt_toggle)

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
	row1.add_child(nrt_fps_spin)

	# Spacer pushes InfoLabel + LogToggle to the right
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer1)

	# Reparent scene-defined InfoLabel and LogToggle into row 1
	info_label.reparent(row1, false)
	info_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	log_toggle.reparent(row1, false)

	# ── Row 2: View & Graph ──────────────────────────────────────────────
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	info_bar.add_child(row2)

	# Preview toggle
	preview_toggle = CheckButton.new()
	preview_toggle.text = "Previews"
	preview_toggle.tooltip_text = "Show / hide inline node previews"
	preview_toggle.button_pressed = true
	preview_toggle.toggled.connect(_on_preview_toggled)
	row2.add_child(preview_toggle)

	# Performance overlay toggle
	perf_toggle = CheckButton.new()
	perf_toggle.text = "Perf"
	perf_toggle.tooltip_text = "Show / hide per-node cook time overlay"
	perf_toggle.button_pressed = false
	perf_toggle.toggled.connect(_on_perf_toggled)
	row2.add_child(perf_toggle)

	# VRAM monitoring toggle
	vram_toggle = CheckButton.new()
	vram_toggle.text = "VRAM"
	vram_toggle.tooltip_text = "Show GPU memory usage in the info bar"
	vram_toggle.button_pressed = false
	vram_toggle.toggled.connect(func(on: bool): _vram_enabled = on)
	row2.add_child(vram_toggle)

	row2.add_child(VSeparator.new())

	# Open Viewer button
	var btn_viewer := Button.new()
	btn_viewer.text = "+ Viewer"
	btn_viewer.tooltip_text = "Open a floating viewer window for the selected TOP node"
	btn_viewer.pressed.connect(func(): open_viewer_window())
	row2.add_child(btn_viewer)

	# Stress Test button
	var btn_stress := Button.new()
	btn_stress.text = "Stress Test"
	btn_stress.tooltip_text = "Build a 55+ node network for performance testing"
	btn_stress.pressed.connect(_on_stress_test_pressed)
	row2.add_child(btn_stress)

	row2.add_child(VSeparator.new())

	# Minimap toggle
	var minimap_toggle := CheckButton.new()
	minimap_toggle.text = "Minimap"
	minimap_toggle.tooltip_text = "Show / hide minimap (M)"
	minimap_toggle.button_pressed = graph_editor.minimap_enabled
	minimap_toggle.toggled.connect(func(on: bool):
		graph_editor.minimap_enabled = on)
	row2.add_child(minimap_toggle)

	# Wire style OptionButton
	var wire_opt := OptionButton.new()
	wire_opt.tooltip_text = "Wire style (W to cycle)"
	for wn in GNGraphEditor._WIRE_STYLE_NAMES:
		wire_opt.add_item(wn)
	wire_opt.selected = 0
	wire_opt.item_selected.connect(func(wire_idx: int):
		graph_editor.set_wire_style(wire_idx))
	row2.add_child(wire_opt)

	# Auto-layout button
	var btn_layout := Button.new()
	btn_layout.text = "Layout"
	btn_layout.tooltip_text = "Auto-layout all nodes (Ctrl+L)"
	btn_layout.pressed.connect(func(): graph_editor.auto_layout())
	row2.add_child(btn_layout)

	row2.add_child(VSeparator.new())

	# Help button
	var btn_help := Button.new()
	btn_help.text = "📖 Help"
	btn_help.tooltip_text = "Open the help reference hub (F1)"
	btn_help.pressed.connect(_toggle_main_help_window)
	row2.add_child(btn_help)

	# Create the export dialog (hidden until needed)
	_export_dialog = _GNExportDialogScript.new()
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
			play_button.button_pressed = not play_button.button_pressed
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
# Stress Test — 55+ node network exercising all 6 families
# ═══════════════════════════════════════════════════════════════════════════════

## Number of warm-up frames before printing the report.
var _stress_warmup_frames: int = -1
const STRESS_WARMUP_COUNT: int = 30

func _on_stress_test_pressed() -> void:
	_on_new_pressed()
	_build_stress_test_network()
	# Rebind everything
	graph_editor.bind_network(network)
	inspector.network = network
	cook_engine.network = network
	cook_engine._nodes_adopted = false
	network.node_renamed.connect(_on_node_renamed)
	graph_editor.clear_undo_history()
	_viewer_node_id = "render_main"
	_push_active_sinks()
	_update_title()
	# Start warm-up countdown — report prints after N frames
	_stress_warmup_frames = STRESS_WARMUP_COUNT
	print("[STRESS] Network built — %d nodes, %d connections. Warming up %d frames…" % [
		network.get_node_count(), network.get_connection_count(), STRESS_WARMUP_COUNT])


## Helper to add a node to the stress test network with position.
func _stress_add(n: GNNode, id: String, x: float, y: float) -> GNNode:
	n.initialize(id)
	n.graph_position = Vector2(x, y)
	network.add_node(n)
	return n


## Builds a large network with 55+ nodes across all 6 families.
## Layout: multiple parallel TOP chains, CHOP generator/filter chains,
## DAT table chains, SOP geometry chains feeding COMPs with MATs,
## merged into a single RenderTOP output.
func _build_stress_test_network() -> void:
	network = GNNetwork.new()

	var col_x := 0  # X offset tracker for laying out columns

	# ═══════════════════════════════════════════════════════════════════════
	# CHOP chain (12 nodes) — generators + filters
	# ═══════════════════════════════════════════════════════════════════════

	var lfo1 := _stress_add(LFO_CHOP.new(), "lfo1", 0, 0)
	lfo1.get_parameter("frequency").set_value(0.5)
	lfo1.get_parameter("amplitude").set_value(1.0)

	var lfo2 := _stress_add(LFO_CHOP.new(), "lfo2", 0, 150)
	lfo2.get_parameter("frequency").set_value(0.3)
	lfo2.get_parameter("waveform").set_value(LFO_CHOP.Waveform.SAWTOOTH)

	_stress_add(NoiseCHOP.new(), "noise_c1", 0, 300)
	var const_c := _stress_add(ConstantCHOP.new(), "const_c1", 0, 450)
	const_c.get_parameter("value0").set_value(2.0)
	_stress_add(WaveCHOP.new(), "wave_c1", 0, 600)

	_stress_add(MathCHOP.new(), "math_c1", 300, 0)
	_stress_add(MathCHOP.new(), "math_c2", 300, 150)
	_stress_add(LagCHOP.new(), "lag_c1", 300, 300)
	_stress_add(FilterCHOP.new(), "filter_c1", 300, 450)
	_stress_add(LimitCHOP.new(), "limit_c1", 300, 600)
	_stress_add(MergeCHOP.new(), "merge_c1", 600, 150)
	_stress_add(NullCHOP.new(), "null_c1", 600, 300)

	# Wire CHOP chain
	network.connect_nodes("lfo1", 0, "math_c1", 0)
	network.connect_nodes("lfo2", 0, "math_c2", 0)
	network.connect_nodes("noise_c1", 0, "lag_c1", 0)
	network.connect_nodes("const_c1", 0, "filter_c1", 0)
	network.connect_nodes("wave_c1", 0, "limit_c1", 0)
	network.connect_nodes("math_c1", 0, "merge_c1", 0)
	network.connect_nodes("math_c2", 0, "merge_c1", 1)
	network.connect_nodes("lag_c1", 0, "null_c1", 0)

	# ═══════════════════════════════════════════════════════════════════════
	# DAT chain (8 nodes)
	# ═══════════════════════════════════════════════════════════════════════
	col_x = 800
	_stress_add(ConstantDAT.new(), "const_d1", col_x, 0)
	_stress_add(ConstantDAT.new(), "const_d2", col_x, 150)
	_stress_add(TextDAT.new(), "text_d1", col_x, 300)
	_stress_add(MergeDAT.new(), "merge_d1", col_x + 300, 0)
	_stress_add(SelectDAT.new(), "select_d1", col_x + 300, 150)
	_stress_add(SortDAT.new(), "sort_d1", col_x + 300, 300)
	_stress_add(TransposeDAT.new(), "transpose_d1", col_x + 600, 0)
	_stress_add(NullDAT.new(), "null_d1", col_x + 600, 150)

	network.connect_nodes("const_d1", 0, "merge_d1", 0)
	network.connect_nodes("const_d2", 0, "merge_d1", 1)
	network.connect_nodes("merge_d1", 0, "transpose_d1", 0)
	network.connect_nodes("text_d1", 0, "select_d1", 0)
	network.connect_nodes("select_d1", 0, "sort_d1", 0)
	network.connect_nodes("sort_d1", 0, "null_d1", 0)

	# Bridges: CHOP → DAT → CHOP round-trip
	_stress_add(CHOPDAT.new(), "chop_to_dat1", col_x + 600, 300)
	_stress_add(DATtoCHOP.new(), "dat_to_chop1", col_x + 900, 300)
	network.connect_nodes("merge_c1", 0, "chop_to_dat1", 0)
	network.connect_nodes("chop_to_dat1", 0, "dat_to_chop1", 0)

	# ═══════════════════════════════════════════════════════════════════════
	# TOP chain A — Noise → Level → Blur → HSV → Threshold → NullTOP (6)
	# ═══════════════════════════════════════════════════════════════════════
	col_x = 0
	var row_y := 900
	var noise_t := _stress_add(NoiseTOP.new(), "noise_t1", col_x, row_y)
	noise_t.get_parameter("resolution").set_value(Vector2i(256, 256))
	_stress_add(LevelTOP.new(), "level_t1", col_x + 300, row_y)
	_stress_add(BlurTOP.new(), "blur_t1", col_x + 600, row_y)
	_stress_add(HSVAdjustTOP.new(), "hsv_t1", col_x + 900, row_y)
	_stress_add(ThresholdTOP.new(), "thresh_t1", col_x + 1200, row_y)
	_stress_add(NullTOP.new(), "null_t1", col_x + 1500, row_y)

	network.connect_nodes("noise_t1", 0, "level_t1", 0)
	network.connect_nodes("level_t1", 0, "blur_t1", 0)
	network.connect_nodes("blur_t1", 0, "hsv_t1", 0)
	network.connect_nodes("hsv_t1", 0, "thresh_t1", 0)
	network.connect_nodes("thresh_t1", 0, "null_t1", 0)

	# ═══════════════════════════════════════════════════════════════════════
	# TOP chain B — Ramp → Transform → Tile → Edge → Composite (5)
	# ═══════════════════════════════════════════════════════════════════════
	row_y = 1100
	var ramp_t := _stress_add(RampTOP.new(), "ramp_t1", col_x, row_y)
	ramp_t.get_parameter("resolution").set_value(Vector2i(256, 256))
	_stress_add(TransformTOP.new(), "xform_t1", col_x + 300, row_y)
	_stress_add(TileTOP.new(), "tile_t1", col_x + 600, row_y)
	_stress_add(EdgeTOP.new(), "edge_t1", col_x + 900, row_y)
	_stress_add(CompositeTOP.new(), "comp_t1", col_x + 1200, row_y)

	network.connect_nodes("ramp_t1", 0, "xform_t1", 0)
	network.connect_nodes("xform_t1", 0, "tile_t1", 0)
	network.connect_nodes("tile_t1", 0, "edge_t1", 0)
	# Composite: chain A + chain B
	network.connect_nodes("null_t1", 0, "comp_t1", 0)
	network.connect_nodes("edge_t1", 0, "comp_t1", 1)

	# ═══════════════════════════════════════════════════════════════════════
	# TOP chain C — Constants, Circle, Rectangle, Cross, Flip (5)
	# ═══════════════════════════════════════════════════════════════════════
	row_y = 1300
	var const_t := _stress_add(ConstantTOP.new(), "const_t1", col_x, row_y)
	const_t.get_parameter("resolution").set_value(Vector2i(256, 256))
	var circle_t := _stress_add(CircleTOP.new(), "circle_t1", col_x + 300, row_y)
	circle_t.get_parameter("resolution").set_value(Vector2i(256, 256))
	var rect_t := _stress_add(RectangleTOP.new(), "rect_t1", col_x + 600, row_y)
	rect_t.get_parameter("resolution").set_value(Vector2i(256, 256))
	_stress_add(CrossTOP.new(), "cross_t1", col_x + 900, row_y)
	_stress_add(FlipTOP.new(), "flip_t1", col_x + 1200, row_y)

	network.connect_nodes("circle_t1", 0, "cross_t1", 0)
	network.connect_nodes("rect_t1", 0, "cross_t1", 1)
	network.connect_nodes("cross_t1", 0, "flip_t1", 0)

	# ═══════════════════════════════════════════════════════════════════════
	# SOP chains (8 nodes) — Two geometry paths
	# ═══════════════════════════════════════════════════════════════════════
	col_x = 2000
	var box_s := _stress_add(BoxSOP.new(), "box_s1", col_x, 0)
	box_s.get_parameter("subdivide_w").set_value(6)
	box_s.get_parameter("subdivide_h").set_value(6)
	box_s.get_parameter("subdivide_d").set_value(6)
	var noise_s := _stress_add(NoiseSOP.new(), "noise_s1", col_x + 300, 0)
	noise_s.get_parameter("amplitude").set_value(0.2)
	noise_s.get_parameter("frequency").set_value(3.0)
	noise_s.get_parameter("speed").set_value(0.5)
	_stress_add(SubdivideSOP.new(), "subdiv_s1", col_x + 600, 0)

	var torus_s := _stress_add(TorusSOP.new(), "torus_s1", col_x, 200)
	torus_s.get_parameter("rings").set_value(48)
	torus_s.get_parameter("ring_segments").set_value(24)
	var xform_s := _stress_add(TransformSOP.new(), "xform_s1", col_x + 300, 200)
	xform_s.get_parameter("ry").set_expression('chop("lfo1", "out") * 360.0')

	var sphere_s := _stress_add(SphereSOP.new(), "sphere_s1", col_x, 400)
	sphere_s.get_parameter("radial_segments").set_value(32)
	sphere_s.get_parameter("rings").set_value(16)
	var grid_s := _stress_add(GridSOP.new(), "grid_s1", col_x, 600)
	grid_s.get_parameter("size_x").set_value(10.0)
	grid_s.get_parameter("size_z").set_value(10.0)
	grid_s.get_parameter("rows").set_value(20)
	grid_s.get_parameter("cols").set_value(20)

	# Wire SOP chains
	network.connect_nodes("box_s1", 0, "noise_s1", 0)
	network.connect_nodes("noise_s1", 0, "subdiv_s1", 0)
	network.connect_nodes("torus_s1", 0, "xform_s1", 0)

	# ═══════════════════════════════════════════════════════════════════════
	# MAT nodes (4)
	# ═══════════════════════════════════════════════════════════════════════
	col_x = 2600
	var mat1 := _stress_add(PBR_MAT.new(), "mat_blue", col_x, 0)
	mat1.get_parameter("albedo_color").set_value(Color(0.1, 0.3, 0.9))
	mat1.get_parameter("metallic").set_value(0.8)
	mat1.get_parameter("roughness").set_value(0.15)

	var mat2 := _stress_add(PBR_MAT.new(), "mat_red", col_x, 200)
	mat2.get_parameter("albedo_color").set_value(Color(0.9, 0.15, 0.1))
	mat2.get_parameter("emission_enabled").set_value(true)
	mat2.get_parameter("emission_color").set_value(Color(0.9, 0.1, 0.05))
	mat2.get_parameter("emission_energy").set_value(0.6)

	var mat3 := _stress_add(PBR_MAT.new(), "mat_green", col_x, 400)
	mat3.get_parameter("albedo_color").set_value(Color(0.1, 0.8, 0.2))
	mat3.get_parameter("roughness").set_value(0.9)

	var mat4 := _stress_add(PBR_MAT.new(), "mat_chrome", col_x, 600)
	mat4.get_parameter("albedo_color").set_value(Color(0.85, 0.85, 0.9))
	mat4.get_parameter("metallic").set_value(0.8)
	mat4.get_parameter("roughness").set_value(0.15)

	# ═══════════════════════════════════════════════════════════════════════
	# COMP nodes — 4 Geometry + Camera + 2 Lights + Merge (8)
	# ═══════════════════════════════════════════════════════════════════════
	col_x = 3000
	var geo1 := _stress_add(GeometryCOMP.new(), "geo1", col_x, 0)
	geo1.get_parameter("tx").set_value(-2.0)
	geo1.get_parameter("ty").set_value(0.5)

	var geo2 := _stress_add(GeometryCOMP.new(), "geo2", col_x, 200)
	geo2.get_parameter("tx").set_value(0.0)

	var geo3 := _stress_add(GeometryCOMP.new(), "geo3", col_x, 400)
	geo3.get_parameter("tx").set_value(2.0)
	geo3.get_parameter("ty").set_value(0.5)

	var geo4 := _stress_add(GeometryCOMP.new(), "geo4", col_x, 600)
	geo4.get_parameter("ty").set_value(-0.5)

	# Wire SOP → Geo + MAT → Geo
	network.connect_nodes("subdiv_s1", 0, "geo1", 0)   # subdivided box
	network.connect_nodes("mat_blue", 0, "geo1", 1)
	network.connect_nodes("xform_s1", 0, "geo2", 0)    # spinning torus
	network.connect_nodes("mat_red", 0, "geo2", 1)
	network.connect_nodes("sphere_s1", 0, "geo3", 0)   # sphere
	network.connect_nodes("mat_green", 0, "geo3", 1)
	network.connect_nodes("grid_s1", 0, "geo4", 0)     # ground plane
	network.connect_nodes("mat_chrome", 0, "geo4", 1)

	# Camera
	var cam := _stress_add(CameraCOMP.new(), "cam_main", col_x, 800)
	cam.get_parameter("tx").set_value(0.0)
	cam.get_parameter("ty").set_value(3.0)
	cam.get_parameter("tz").set_value(5.0)
	cam.get_parameter("use_look_at").set_value(true)
	cam.get_parameter("look_at_x").set_value(0.0)
	cam.get_parameter("look_at_y").set_value(0.0)
	cam.get_parameter("look_at_z").set_value(0.0)
	cam.get_parameter("fov").set_value(55.0)

	# Two lights for more interesting shading
	var light1 := _stress_add(LightCOMP.new(), "light_dir", col_x, 1000)
	light1.get_parameter("type").set_value(0)  # Directional
	light1.get_parameter("rx").set_value(-45.0)
	light1.get_parameter("ry").set_value(30.0)
	light1.get_parameter("energy").set_value(1.0)
	light1.get_parameter("shadows").set_value(true)

	var light2 := _stress_add(LightCOMP.new(), "light_point", col_x, 1200)
	light2.get_parameter("type").set_value(1)  # Omni
	light2.get_parameter("tx").set_value(2.0)
	light2.get_parameter("ty").set_value(3.0)
	light2.get_parameter("tz").set_value(1.0)
	light2.get_parameter("energy").set_value(0.8)
	light2.get_parameter("color").set_value(Color(0.6, 0.8, 1.0))

	# MergeCOMP
	_stress_add(MergeCOMP.new(), "merge_scene", col_x + 400, 300)
	network.connect_nodes("geo1", 0, "merge_scene", 0)
	network.connect_nodes("geo2", 0, "merge_scene", 1)
	network.connect_nodes("geo3", 0, "merge_scene", 2)
	network.connect_nodes("geo4", 0, "merge_scene", 3)

	# ═══════════════════════════════════════════════════════════════════════
	# RenderTOP (1 node) — final output
	# ═══════════════════════════════════════════════════════════════════════
	var render := _stress_add(RenderTOP.new(), "render_main", col_x + 700, 300)
	render.get_parameter("resolution").set_value(Vector2i(1280, 720))
	render.get_parameter("bg_color").set_value(Color(0.06, 0.06, 0.08))
	render.get_parameter("anti_aliasing").set_value(2)
	render.get_parameter("ambient_energy").set_value(0.3)
	network.connect_nodes("merge_scene", 0, "render_main", 0)
	network.connect_nodes("cam_main", 0, "render_main", 1)
	network.connect_nodes("light_dir", 0, "render_main", 2)
	network.connect_nodes("light_point", 0, "render_main", 3)

	# Use composite texture as a material texture on the box (TOP → Geo)
	network.connect_nodes("comp_t1", 0, "geo1", 2)  # TOP texture input

	print("[STRESS] Built %d nodes, %d connections" % [
		network.get_node_count(), network.get_connection_count()])


## Called each frame after cook — if we're in stress warmup, count down and print report.
func _check_stress_report(_frame: int, _cook_time_ms: float) -> void:
	if _stress_warmup_frames < 0:
		return
	_stress_warmup_frames -= 1
	if _stress_warmup_frames > 0:
		return

	# Warmup complete — print the report
	_stress_warmup_frames = -1
	_print_stress_report()


## Prints a per-node cook time report sorted by cost (descending).
func _print_stress_report() -> void:
	var node_count := network.get_node_count()
	var conn_count := network.get_connection_count()

	# Gather per-node stats
	var entries: Array[Dictionary] = []
	var total_ms := 0.0
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		entries.append({
			"id": node.id,
			"type": node.node_type,
			"family": GNFamily.get_family_name(node.family),
			"cook_ms": node.cook_time_ms,
			"dirty": node.dirty,
		})
		total_ms += node.cook_time_ms

	# Sort descending by cook time
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["cook_ms"] > b["cook_ms"])

	# Per-family totals
	var family_totals: Dictionary = {}
	for e in entries:
		var fam: String = e["family"]
		family_totals[fam] = family_totals.get(fam, 0.0) + e["cook_ms"]

	# Print report
	print("")
	print("╔══════════════════════════════════════════════════════════════════╗")
	print("║         GONODES STRESS TEST REPORT — %d NODES                  ║" % node_count)
	print("╠══════════════════════════════════════════════════════════════════╣")
	print("║  Nodes: %d  |  Connections: %d  |  Frame cook: %.2fms" % [
		node_count, conn_count, cook_engine.frame_cook_time_ms])
	print("║  FPS:   %d  |  Total node cook: %.2fms" % [
		Engine.get_frames_per_second(), total_ms])
	print("╠══════════════════════════════════════════════════════════════════╣")
	print("║  PER-FAMILY TOTALS:")
	for fam_name in family_totals:
		print("║    %-8s  %.3fms" % [fam_name, family_totals[fam_name]])
	print("╠══════════════════════════════════════════════════════════════════╣")
	print("║  TOP 15 MOST EXPENSIVE NODES:")
	print("║  %-20s %-14s %-6s %s" % ["ID", "Type", "Family", "Cook (ms)"])
	print("║  " + "—".repeat(58))
	var show_count := mini(entries.size(), 15)
	for i in range(show_count):
		var e: Dictionary = entries[i]
		print("║  %-20s %-14s %-6s %.3f" % [e["id"], e["type"], e["family"], e["cook_ms"]])
	print("╠══════════════════════════════════════════════════════════════════╣")
	if total_ms < 5.0:
		print("║  VERDICT: ✅ EXCELLENT — well under 16ms budget (60 FPS)")
	elif total_ms < 12.0:
		print("║  VERDICT: ✅ GOOD — within 16ms budget (60 FPS)")
	elif total_ms < 16.67:
		print("║  VERDICT: ⚠️  BORDERLINE — near 16ms budget")
	else:
		print("║  VERDICT: ❌ OVER BUDGET — exceeds 16ms (%.1f FPS target)" % (1000.0 / total_ms))
	print("╚══════════════════════════════════════════════════════════════════╝")
	print("")


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
	if not node is _SubNetworkNodeScript:
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
			if subnet_node and subnet_node is _SubNetworkNodeScript:
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
