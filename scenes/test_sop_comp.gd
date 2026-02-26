extends Node
## SOP + MAT + COMP test scene — builds a 3D pipeline with per-object materials:
##
##   PBR_MAT (blue) ────────────┐
##                              ├→ GeometryCOMP ──┐
##   BoxSOP → NoiseSOP ─────────┘                 │
##                                                ├→ MergeCOMP ──┐
##   PBR_MAT (orange+glow) ────┐                  │              │
##                             ├→ GeometryCOMP ──┘              ├→ RenderTOP → viewer
##   TorusSOP → TransformSOP ──┘                                │
##                                                CameraCOMP ───┤
##                                                LightCOMP ────┘
##
## Validates:
##   • MAT operators  (PBR_MAT with different settings per object)
##   • SOP generators (BoxSOP, TorusSOP)
##   • SOP filters   (NoiseSOP time-dependent, TransformSOP with expression)
##   • COMP merging  (MergeCOMP scene graph composition)
##   • COMP nodes    (GeometryCOMP with MAT input, CameraCOMP, LightCOMP)
##   • 3D rendering  (RenderTOP → SubViewport → texture output)
##   • Expression binding (LFO_CHOP drives transform rotation)

@onready var viewer: TextureRect = $Viewer
@onready var label: Label = $InfoLabel
@onready var log_toggle: CheckButton = $LogToggle

var network: GNNetwork
var cook_engine: GNCookEngine


func _ready() -> void:
	_setup_network()
	_setup_cook_engine()

	log_toggle.toggled.connect(_on_log_toggled)
	GNLogger.enabled = log_toggle.button_pressed
	GNLogger.level = GNLogger.Level.DEBUG

	print("GONODES SOP/COMP Test — running")


# ═══════════════════════════════════════════════════════════════════════════════
# Network Setup
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_network() -> void:
	network = GNNetwork.new()

	# ── CHOP: LFO to drive torus rotation ──────────────────────────────────
	var lfo := LFO_CHOP.new()
	lfo.initialize("lfo1")
	lfo.get_parameter("frequency").set_value(0.25)
	lfo.get_parameter("amplitude").set_value(360.0)
	lfo.get_parameter("waveform").set_value(LFO_CHOP.Waveform.SAWTOOTH)

	# ── SOP generators ─────────────────────────────────────────────────────
	var box := BoxSOP.new()
	box.initialize("box1")
	box.get_parameter("size_x").set_value(1.0)
	box.get_parameter("size_y").set_value(1.0)
	box.get_parameter("size_z").set_value(1.0)
	box.get_parameter("subdivide_w").set_value(8)
	box.get_parameter("subdivide_h").set_value(8)
	box.get_parameter("subdivide_d").set_value(8)

	var torus := TorusSOP.new()
	torus.initialize("torus1")
	torus.get_parameter("inner_radius").set_value(0.15)
	torus.get_parameter("outer_radius").set_value(0.6)
	torus.get_parameter("rings").set_value(48)
	torus.get_parameter("ring_segments").set_value(24)

	# ── SOP filters ────────────────────────────────────────────────────────
	var noise := NoiseSOP.new()
	noise.initialize("noise_sop1")
	noise.get_parameter("amplitude").set_value(0.15)
	noise.get_parameter("frequency").set_value(3.0)
	noise.get_parameter("speed").set_value(0.8)

	var xform := TransformSOP.new()
	xform.initialize("xform1")
	xform.get_parameter("rx").set_expression('chop("lfo1", "out")')

	# ── MAT operators ─────────────────────────────────────────────────────
	var mat_box := PBR_MAT.new()
	mat_box.initialize("mat_box")
	mat_box.get_parameter("albedo_color").set_value(Color(0.2, 0.5, 0.9))
	mat_box.get_parameter("metallic").set_value(0.7)
	mat_box.get_parameter("roughness").set_value(0.2)

	var mat_torus := PBR_MAT.new()
	mat_torus.initialize("mat_torus")
	mat_torus.get_parameter("albedo_color").set_value(Color(0.9, 0.3, 0.1))
	mat_torus.get_parameter("metallic").set_value(0.1)
	mat_torus.get_parameter("roughness").set_value(0.6)
	mat_torus.get_parameter("emission_enabled").set_value(true)
	mat_torus.get_parameter("emission_color").set_value(Color(0.9, 0.2, 0.05))
	mat_torus.get_parameter("emission_energy").set_value(0.5)

	# ── COMPs ──────────────────────────────────────────────────────────────
	var geo_box := GeometryCOMP.new()
	geo_box.initialize("geo_box")
	geo_box.get_parameter("tx").set_value(-1.2)

	var geo_torus := GeometryCOMP.new()
	geo_torus.initialize("geo_torus")
	geo_torus.get_parameter("tx").set_value(1.2)
	geo_torus.get_parameter("ty").set_value(0.3)

	var merge_comp := MergeCOMP.new()
	merge_comp.initialize("merge_comp1")

	var cam := CameraCOMP.new()
	cam.initialize("cam1")
	cam.get_parameter("tx").set_value(0.0)
	cam.get_parameter("ty").set_value(1.2)
	cam.get_parameter("tz").set_value(3.5)
	cam.get_parameter("rx").set_value(-15.0)
	cam.get_parameter("fov").set_value(60.0)

	var light := LightCOMP.new()
	light.initialize("light1")
	light.get_parameter("type").set_value(0)  # Directional
	light.get_parameter("rx").set_value(-40.0)
	light.get_parameter("ry").set_value(30.0)
	light.get_parameter("energy").set_value(1.2)
	light.get_parameter("shadows").set_value(true)

	# ── Render TOP ─────────────────────────────────────────────────────────
	var render := RenderTOP.new()
	render.initialize("render1")
	render.get_parameter("resolution").set_value(Vector2i(1280, 720))
	render.get_parameter("bg_color").set_value(Color(0.08, 0.08, 0.1))
	render.get_parameter("anti_aliasing").set_value(2)  # 4x MSAA
	render.get_parameter("ambient_energy").set_value(0.4)
	render.get_parameter("ambient_color").set_value(Color(0.25, 0.25, 0.35))

	# ── Add all nodes to the network ───────────────────────────────────────
	network.add_node(lfo)
	network.add_node(box)
	network.add_node(torus)
	network.add_node(noise)
	network.add_node(xform)
	network.add_node(mat_box)
	network.add_node(mat_torus)
	network.add_node(geo_box)
	network.add_node(geo_torus)
	network.add_node(merge_comp)
	network.add_node(cam)
	network.add_node(light)
	network.add_node(render)

	# ── Wire the graph ─────────────────────────────────────────────────────
	# Box → NoiseSOP → GeometryCOMP + PBR_MAT
	network.connect_nodes("box1", 0, "noise_sop1", 0)
	network.connect_nodes("noise_sop1", 0, "geo_box", 0)
	network.connect_nodes("mat_box", 0, "geo_box", 1)
	# Torus → TransformSOP → GeometryCOMP + PBR_MAT
	network.connect_nodes("torus1", 0, "xform1", 0)
	network.connect_nodes("xform1", 0, "geo_torus", 0)
	network.connect_nodes("mat_torus", 0, "geo_torus", 1)
	# Both geos → MergeCOMP → RenderTOP
	network.connect_nodes("geo_box", 0, "merge_comp1", 0)
	network.connect_nodes("geo_torus", 0, "merge_comp1", 0)
	network.connect_nodes("merge_comp1", 0, "render1", 0)
	network.connect_nodes("cam1", 0, "render1", 0)
	network.connect_nodes("light1", 0, "render1", 0)

	print("  Network: %d nodes, wired OK" % network.nodes.size())


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Engine
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_cook_engine() -> void:
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	cook_engine.network = network
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)


func _on_frame_cooked(frame: int, cook_time_ms: float) -> void:
	# Show the RenderTOP output in the viewer
	var render_node: GNNode = network.get_node_by_id("render1")
	if render_node != null and render_node.cached_output is GNTextureData:
		var tex_data: GNTextureData = render_node.cached_output as GNTextureData
		if tex_data.texture != null:
			viewer.texture = tex_data.texture

	# Build info text
	var parts := PackedStringArray()
	parts.append("FPS: %d" % Engine.get_frames_per_second())
	parts.append("Frame: %d" % frame)
	parts.append("Cook: %.2fms" % cook_time_ms)

	# Show node count
	parts.append("Nodes: %d" % network.nodes.size())

	var lfo_node: GNNode = network.get_node_by_id("lfo1")
	if lfo_node != null and lfo_node.cached_output is GNChannelData:
		var lfo_val: float = (lfo_node.cached_output as GNChannelData).get_value("out")
		parts.append("LFO: %.1f°" % lfo_val)

	label.text = " | ".join(parts)


func _on_cook_error(node_id: String, error_msg: String) -> void:
	GNLogger.error("TestSOPCOMP", "Cook error on '%s': %s" % [node_id, error_msg])
	label.text = "ERROR: %s — %s" % [node_id, error_msg]


func _on_log_toggled(pressed: bool) -> void:
	GNLogger.enabled = pressed
	if pressed:
		print("[GONODES] Logging ENABLED (level: DEBUG)")
	else:
		print("[GONODES] Logging DISABLED")
