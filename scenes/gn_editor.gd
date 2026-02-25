extends Control
## GONODES Editor — Main editor scene.
## Split layout: GNGraphEditor (left/center) + Viewer + Inspector (right).
## Runs a cook engine each frame and displays the output of the last TOP
## in the viewer panel. Includes a debug info label and log toggle.
## Supports save/load of patches as `.gnpatch` JSON files.

@onready var graph_editor: GNGraphEditor = $HSplit/GraphPanel/GraphEditor
@onready var viewer: TextureRect = $HSplit/RightPanel/ViewerPanel/Viewer
@onready var inspector: GNParamInspector = $HSplit/RightPanel/InspectorPanel
@onready var info_label: Label = $InfoBar/InfoLabel
@onready var log_toggle: CheckButton = $InfoBar/LogToggle

var network: GNNetwork
var cook_engine: GNCookEngine

## Which node's output to display in the viewer (click to select).
var _viewer_node_id: String = ""

## Path to the currently loaded/saved patch file (empty = unsaved).
var _current_file_path: String = ""

## FileDialogs for save and load.
var _save_dialog: FileDialog = null
var _load_dialog: FileDialog = null


func _ready() -> void:
	# Initialize extension registry — scan for gn_ext_* addon manifests
	GNExtensionRegistry.instance().scan_extensions()

	_setup_network()
	_setup_cook_engine()
	_setup_file_dialogs()
	_setup_toolbar()

	# Bind graph editor to network
	graph_editor.bind_network(network)
	graph_editor.operator_selected.connect(_on_graph_node_selected)
	graph_editor.operator_deselected.connect(_on_graph_selection_cleared)

	# Bind inspector to network
	inspector.network = network

	# Track node renames so viewer target stays correct
	network.node_renamed.connect(_on_node_renamed)

	# Wire log toggle
	log_toggle.toggled.connect(_on_log_toggled)
	GNLogger.enabled = log_toggle.button_pressed
	GNLogger.level = GNLogger.Level.DEBUG

	# Print display info
	var displays := WindowTOP.get_display_info()
	for d in displays:
		print("Display %d: %s at %s" % [d["index"], d["size"], d["position"]])
	print("GONODES Editor running (%d display(s))" % displays.size())


## Creates the same demo network from Phase 2 test for initial testing.
func _setup_network() -> void:
	network = GNNetwork.new()

	# --- Create nodes ---
	var lfo := LFO_CHOP.new()
	lfo.initialize("lfo1")
	lfo.get_parameter("frequency").set_value(0.5)
	lfo.get_parameter("amplitude").set_value(1.0)
	lfo.get_parameter("waveform").set_value(LFO_CHOP.Waveform.SINE)
	lfo.graph_position = Vector2(50, 200)

	var noise := NoiseTOP.new()
	noise.initialize("noise1")
	noise.get_parameter("scale").set_value(6.0)
	noise.get_parameter("resolution").set_value(Vector2i(512, 512))
	noise.get_parameter("monochrome").set_value(true)
	noise.get_parameter("time_offset").set_expression('chop("lfo1", "out") * 5.0')
	noise.graph_position = Vector2(350, 100)

	var level := LevelTOP.new()
	level.initialize("level1")
	level.get_parameter("contrast").set_value(2.5)
	level.get_parameter("brightness").set_value(0.8)
	level.get_parameter("gamma").set_value(0.6)
	level.get_parameter("invert").set_value(true)
	level.graph_position = Vector2(650, 100)

	var win := WindowTOP.new()
	win.initialize("win1")
	win.get_parameter("title").set_value("GONODES Output")
	win.get_parameter("monitor").set_value(0)
	win.get_parameter("window_mode").set_value(WindowTOP.WindowMode.WINDOWED)
	win.get_parameter("resolution").set_value(Vector2i(800, 600))
	win.graph_position = Vector2(950, 100)

	# --- Add to network ---
	network.add_node(lfo)
	network.add_node(noise)
	network.add_node(level)
	network.add_node(win)

	# --- Wire ---
	network.connect_nodes("noise1", 0, "level1", 0)
	network.connect_nodes("level1", 0, "win1", 0)

	# Default viewer target: last TOP before output
	_viewer_node_id = "level1"


func _setup_cook_engine() -> void:
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	cook_engine.network = network
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

func _on_frame_cooked(frame: int, cook_time_ms: float) -> void:
	# Update viewer with selected node's output
	if not _viewer_node_id.is_empty():
		var view_node: GNNode = network.get_node_by_id(_viewer_node_id)
		if view_node and view_node.cached_output is GNTextureData:
			var tex_data: GNTextureData = view_node.cached_output as GNTextureData
			if tex_data.texture:
				viewer.texture = tex_data.texture

	# Build info text
	var parts: Array[String] = ["FPS: %d" % Engine.get_frames_per_second()]
	parts.append("Frame: %d" % frame)
	parts.append("Cook: %.2fms" % cook_time_ms)
	parts.append("Nodes: %d" % network.get_node_count())

	if not _viewer_node_id.is_empty():
		parts.append("Viewing: %s" % _viewer_node_id)

	info_label.text = " | ".join(parts)


func _on_cook_error(node_id: String, error_msg: String) -> void:
	GNLogger.error("Editor", "Cook error '%s': %s" % [node_id, error_msg])


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Editor Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

## User clicked a node — show its output in the viewer (if it's a TOP)
## and inspect its parameters.
func _on_graph_node_selected(node_id: String) -> void:
	# Always show inspector for any node type
	inspector.inspect_node(node_id)

	# Route viewer to TOPs only
	var node: GNNode = network.get_node_by_id(node_id)
	if node and node.family == GNFamily.Type.TOP:
		_viewer_node_id = node_id
		GNLogger.info("Editor", "Viewer → '%s'" % node_id)


func _on_graph_selection_cleared() -> void:
	inspector.clear_inspection()


## Keep viewer target in sync when a node is renamed.
func _on_node_renamed(old_id: String, new_id: String) -> void:
	if _viewer_node_id == old_id:
		_viewer_node_id = new_id


func _on_log_toggled(pressed: bool) -> void:
	GNLogger.enabled = pressed
	if pressed:
		print("[GONODES] Logging ENABLED")
	else:
		print("[GONODES] Logging DISABLED")


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
	var info_bar: HBoxContainer = $InfoBar

	# Add a separator and buttons BEFORE the info label (insert at front)
	var btn_new := Button.new()
	btn_new.text = "New"
	btn_new.tooltip_text = "New patch (Ctrl+N)"
	btn_new.pressed.connect(_on_new_pressed)
	info_bar.add_child(btn_new)
	info_bar.move_child(btn_new, 0)

	var btn_open := Button.new()
	btn_open.text = "Open"
	btn_open.tooltip_text = "Open patch (Ctrl+O)"
	btn_open.pressed.connect(_on_open_pressed)
	info_bar.add_child(btn_open)
	info_bar.move_child(btn_open, 1)

	var btn_save := Button.new()
	btn_save.text = "Save"
	btn_save.tooltip_text = "Save patch (Ctrl+S)"
	btn_save.pressed.connect(_on_save_pressed)
	info_bar.add_child(btn_save)
	info_bar.move_child(btn_save, 2)

	var btn_save_as := Button.new()
	btn_save_as.text = "Save As"
	btn_save_as.tooltip_text = "Save patch as… (Ctrl+Shift+S)"
	btn_save_as.pressed.connect(_on_save_as_pressed)
	info_bar.add_child(btn_save_as)
	info_bar.move_child(btn_save_as, 3)

	# Separator between buttons and info label
	var sep := VSeparator.new()
	info_bar.add_child(sep)
	info_bar.move_child(sep, 4)


## Keyboard shortcuts for file operations.
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


## New patch — clears everything and starts fresh.
func _on_new_pressed() -> void:
	_viewer_node_id = ""
	viewer.texture = null
	inspector.clear_inspection()
	graph_editor._unbind_network()

	# Stop cook engine and remove old network's nodes from tree
	cook_engine.network = null
	_remove_network_nodes_from_tree()

	# Create fresh network
	network = GNNetwork.new()
	_current_file_path = ""

	# Rebind everything
	graph_editor.bind_network(network)
	inspector.network = network
	cook_engine.network = network
	cook_engine._nodes_adopted = false

	network.node_renamed.connect(_on_node_renamed)
	graph_editor.clear_undo_history()

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
	var err := network.save_to_file(path)
	if err == OK:
		_current_file_path = path
		_update_title()
		print("[GONODES] Saved patch: %s" % path)
	else:
		push_error("[GONODES] Failed to save patch to '%s' (error %d)" % [path, err])


## Loads a network from the given path.
func _load_from_path(path: String) -> void:
	_viewer_node_id = ""
	viewer.texture = null
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

	# Rebind everything — cook engine will adopt nodes on next frame
	graph_editor.bind_network(network)
	inspector.network = network
	cook_engine.network = network
	cook_engine._nodes_adopted = false  # Force re-adoption of loaded nodes

	network.node_renamed.connect(_on_node_renamed)
	graph_editor.clear_undo_history()

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
