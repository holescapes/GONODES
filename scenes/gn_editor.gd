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


## Demo network: Two objects with different MATs → MergeCOMP → RenderTOP.
func _setup_network() -> void:
	network = GNNetwork.new()

	# ── CHOP: LFO drives torus rotation ────────────────────────────────────
	var lfo := LFO_CHOP.new()
	lfo.initialize("lfo1")
	lfo.get_parameter("frequency").set_value(0.25)
	lfo.get_parameter("amplitude").set_value(360.0)
	lfo.get_parameter("waveform").set_value(LFO_CHOP.Waveform.SAWTOOTH)
	lfo.graph_position = Vector2(50, 550)

	# ── SOP generators ─────────────────────────────────────────────────────
	var box := BoxSOP.new()
	box.initialize("box1")
	box.get_parameter("size_x").set_value(1.0)
	box.get_parameter("size_y").set_value(1.0)
	box.get_parameter("size_z").set_value(1.0)
	box.get_parameter("subdivide_w").set_value(8)
	box.get_parameter("subdivide_h").set_value(8)
	box.get_parameter("subdivide_d").set_value(8)
	box.graph_position = Vector2(50, 50)

	var torus := TorusSOP.new()
	torus.initialize("torus1")
	torus.get_parameter("inner_radius").set_value(0.15)
	torus.get_parameter("outer_radius").set_value(0.6)
	torus.get_parameter("rings").set_value(48)
	torus.get_parameter("ring_segments").set_value(24)
	torus.graph_position = Vector2(50, 300)

	# ── SOP filters ────────────────────────────────────────────────────────
	var noise_sop := NoiseSOP.new()
	noise_sop.initialize("noise_sop1")
	noise_sop.get_parameter("amplitude").set_value(0.15)
	noise_sop.get_parameter("frequency").set_value(3.0)
	noise_sop.get_parameter("speed").set_value(0.8)
	noise_sop.graph_position = Vector2(350, 50)

	var xform := TransformSOP.new()
	xform.initialize("xform1")
	xform.get_parameter("rx").set_expression('chop("lfo1", "out")')
	xform.graph_position = Vector2(350, 300)

	# ── MAT operators ─────────────────────────────────────────────────────
	var mat_box := PBR_MAT.new()
	mat_box.initialize("mat_box")
	mat_box.get_parameter("albedo_color").set_value(Color(0.2, 0.5, 0.9))
	mat_box.get_parameter("metallic").set_value(0.7)
	mat_box.get_parameter("roughness").set_value(0.2)
	mat_box.graph_position = Vector2(350, 150)

	var mat_torus := PBR_MAT.new()
	mat_torus.initialize("mat_torus")
	mat_torus.get_parameter("albedo_color").set_value(Color(0.9, 0.3, 0.1))
	mat_torus.get_parameter("metallic").set_value(0.1)
	mat_torus.get_parameter("roughness").set_value(0.6)
	mat_torus.get_parameter("emission_enabled").set_value(true)
	mat_torus.get_parameter("emission_color").set_value(Color(0.9, 0.2, 0.05))
	mat_torus.get_parameter("emission_energy").set_value(0.5)
	mat_torus.graph_position = Vector2(350, 420)

	# ── COMPs ──────────────────────────────────────────────────────────────
	# Each geo gets its own material via MAT input
	var geo_box := GeometryCOMP.new()
	geo_box.initialize("geo_box")
	geo_box.get_parameter("tx").set_value(-1.2)
	geo_box.graph_position = Vector2(700, 50)

	var geo_torus := GeometryCOMP.new()
	geo_torus.initialize("geo_torus")
	geo_torus.get_parameter("tx").set_value(1.2)
	geo_torus.get_parameter("ty").set_value(0.3)
	geo_torus.graph_position = Vector2(700, 300)

	var merge_comp := MergeCOMP.new()
	merge_comp.initialize("merge_comp1")
	merge_comp.graph_position = Vector2(1050, 180)

	var cam := CameraCOMP.new()
	cam.initialize("cam1")
	cam.get_parameter("tx").set_value(0.0)
	cam.get_parameter("ty").set_value(1.2)
	cam.get_parameter("tz").set_value(3.5)
	cam.get_parameter("rx").set_value(-15.0)
	cam.get_parameter("fov").set_value(60.0)
	cam.graph_position = Vector2(1050, 400)

	var light := LightCOMP.new()
	light.initialize("light1")
	light.get_parameter("type").set_value(0)
	light.get_parameter("rx").set_value(-40.0)
	light.get_parameter("ry").set_value(30.0)
	light.get_parameter("energy").set_value(1.2)
	light.get_parameter("shadows").set_value(true)
	light.graph_position = Vector2(1050, 550)

	# ── Render TOP ─────────────────────────────────────────────────────────
	var render := RenderTOP.new()
	render.initialize("render1")
	render.get_parameter("resolution").set_value(Vector2i(1280, 720))
	render.get_parameter("bg_color").set_value(Color(0.08, 0.08, 0.1))
	render.get_parameter("anti_aliasing").set_value(2)
	render.get_parameter("ambient_energy").set_value(0.4)
	render.graph_position = Vector2(1400, 350)

	# ── Add all nodes ──────────────────────────────────────────────────────
	network.add_node(lfo)
	network.add_node(box)
	network.add_node(torus)
	network.add_node(noise_sop)
	network.add_node(xform)
	network.add_node(mat_box)
	network.add_node(mat_torus)
	network.add_node(geo_box)
	network.add_node(geo_torus)
	network.add_node(merge_comp)
	network.add_node(cam)
	network.add_node(light)
	network.add_node(render)

	# ── Wire ───────────────────────────────────────────────────────────────
	# Box → NoiseSOP → GeometryCOMP (geo input 0) + PBR_MAT (mat input 1)
	network.connect_nodes("box1", 0, "noise_sop1", 0)
	network.connect_nodes("noise_sop1", 0, "geo_box", 0)
	network.connect_nodes("mat_box", 0, "geo_box", 1)
	# Torus → TransformSOP → GeometryCOMP (geo input 0) + PBR_MAT (mat input 1)
	network.connect_nodes("torus1", 0, "xform1", 0)
	network.connect_nodes("xform1", 0, "geo_torus", 0)
	network.connect_nodes("mat_torus", 0, "geo_torus", 1)
	# Both geos → MergeCOMP → RenderTOP
	network.connect_nodes("geo_box", 0, "merge_comp1", 0)
	network.connect_nodes("geo_torus", 0, "merge_comp1", 0)
	network.connect_nodes("merge_comp1", 0, "render1", 0)
	network.connect_nodes("cam1", 0, "render1", 0)
	network.connect_nodes("light1", 0, "render1", 0)

	# Default viewer target: rendered 3D output
	_viewer_node_id = "render1"


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

	# Update live previews on all nodes in the graph
	graph_editor.update_previews()

	# Update performance overlays on all nodes
	graph_editor.update_perf_overlays()


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


func _on_preview_toggled(pressed: bool) -> void:
	graph_editor.set_previews_visible(pressed)


func _on_perf_toggled(pressed: bool) -> void:
	graph_editor.set_perf_overlay_visible(pressed)


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

	# Preview toggle
	var preview_toggle := CheckButton.new()
	preview_toggle.text = "Previews"
	preview_toggle.tooltip_text = "Show / hide inline node previews"
	preview_toggle.button_pressed = true
	preview_toggle.toggled.connect(_on_preview_toggled)
	info_bar.add_child(preview_toggle)
	info_bar.move_child(preview_toggle, 5)

	# Performance overlay toggle
	var perf_toggle := CheckButton.new()
	perf_toggle.text = "Perf"
	perf_toggle.tooltip_text = "Show / hide per-node cook time overlay"
	perf_toggle.button_pressed = false
	perf_toggle.toggled.connect(_on_perf_toggled)
	info_bar.add_child(perf_toggle)
	info_bar.move_child(perf_toggle, 6)


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
