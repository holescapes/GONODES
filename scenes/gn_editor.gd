extends Control
## GONODES Editor — Main editor scene.
## Split layout: GNGraphEditor (left/center) + Viewer + Inspector (right).
## Runs a cook engine each frame and displays the output of the last TOP
## in the viewer panel. Includes a debug info label and log toggle.

@onready var graph_editor: GNGraphEditor = $HSplit/GraphPanel/GraphEditor
@onready var viewer: TextureRect = $HSplit/RightPanel/ViewerPanel/Viewer
@onready var inspector: GNParamInspector = $HSplit/RightPanel/InspectorPanel
@onready var info_label: Label = $InfoBar/InfoLabel
@onready var log_toggle: CheckButton = $InfoBar/LogToggle

var network: GNNetwork
var cook_engine: GNCookEngine

## Which node's output to display in the viewer (click to select).
var _viewer_node_id: String = ""


func _ready() -> void:
	_setup_network()
	_setup_cook_engine()

	# Bind graph editor to network
	graph_editor.bind_network(network)
	graph_editor.operator_selected.connect(_on_graph_node_selected)
	graph_editor.operator_deselected.connect(_on_graph_selection_cleared)

	# Bind inspector to network
	inspector.network = network

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


func _on_log_toggled(pressed: bool) -> void:
	GNLogger.enabled = pressed
	if pressed:
		print("[GONODES] Logging ENABLED")
	else:
		print("[GONODES] Logging DISABLED")
