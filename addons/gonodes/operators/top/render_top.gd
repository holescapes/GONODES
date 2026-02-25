class_name RenderTOP
extends GNTopBase
## Renders a 3D scene to a texture — the bridge from COMPs back to the TOP pipeline.
##
## Takes COMP inputs (GeometryCOMP, CameraCOMP, LightCOMP) and renders them
## into a SubViewport with 3D rendering enabled, producing a GNTextureData output.
##
## Architecture:
##   SOP → GeometryCOMP → RenderTOP → (texture output to other TOPs)
##              ↑              ↑
##          CameraCOMP    LightCOMP
##
## Uses Godot's native 3D renderer (Forward+) via SubViewport for full PBR,
## shadows, reflections, and all built-in rendering features.

var _viewport: SubViewport = null
var _cached_tex_data: GNTextureData = null
var _environment: Environment = null
var _world_env: WorldEnvironment = null

## Track which scene nodes are currently in the viewport
var _managed_children: Array[Node3D] = []


func _init() -> void:
	node_type = "render"
	time_dependent = true
	node_description = "Renders a 3D COMP scene into a 2D texture."


func _init_ports() -> void:
	# Multi-input COMP — accepts geometry, camera, lights
	add_input("comp_in", GNFamily.Type.COMP, true, "Connect GeometryCOMP, CameraCOMP, LightCOMP")
	add_output("out", GNFamily.Type.TOP, "Rendered 3D scene texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1280, 720), "Resolution", "Render resolution"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.1, 0.1, 0.12), "Background Color", "Background clear color"))
	add_parameter(GNParameter.create_bool("transparent_bg", false, "Transparent BG", "Use transparent background"))
	add_parameter(GNParameter.create_bool("use_environment", true, "Use Environment", "Enable environment lighting"))
	add_parameter(GNParameter.create_float("ambient_energy", 0.3, 0.0, 4.0, 0.05, "Ambient Energy", "Ambient light intensity"))
	add_parameter(GNParameter.create_color("ambient_color", Color(0.3, 0.3, 0.4), "Ambient Color", "Ambient light color"))
	add_parameter(GNParameter.create_enum("anti_aliasing",
		PackedStringArray(["Off", "2x MSAA", "4x MSAA", "8x MSAA"]), 2, "Anti-Aliasing", "MSAA quality level"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var bg_color: Color = get_param_value("bg_color")
	var transparent: bool = get_param_value("transparent_bg")
	var use_env: bool = get_param_value("use_environment")
	var aa_mode: int = get_param_value("anti_aliasing")

	# Update viewport settings
	if _viewport.size != res:
		_viewport.size = res

	_viewport.transparent_bg = transparent

	# Anti-aliasing
	match aa_mode:
		0: _viewport.msaa_3d = Viewport.MSAA_DISABLED
		1: _viewport.msaa_3d = Viewport.MSAA_2X
		2: _viewport.msaa_3d = Viewport.MSAA_4X
		3: _viewport.msaa_3d = Viewport.MSAA_8X

	# Update environment
	if _environment != null:
		_environment.background_mode = Environment.BG_COLOR
		_environment.background_color = bg_color
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if use_env else Environment.AMBIENT_SOURCE_DISABLED
		_environment.ambient_light_color = get_param_value("ambient_color")
		_environment.ambient_light_energy = get_param_value("ambient_energy")

	# Remove previously managed children that are no longer connected
	_clear_managed_children()

	# Scan inputs for COMP nodes and add their 3D nodes to the viewport
	# The cook engine passes upstream cached_output via inputs, but we need
	# to access the actual COMP nodes to get their MeshInstance3D/Camera3D/Light3D.
	_populate_scene_from_network()

	# Update output
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Lazily creates the 3D SubViewport and environment.
func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.name = "VP3D_%s" % id
	_viewport.size = Vector2i(1280, 720)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = false
	_viewport.gui_disable_input = true
	_viewport.own_world_3d = true  # Isolated 3D world
	add_child(_viewport)

	# Create environment for the scene
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.1, 0.1, 0.12)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.3, 0.3, 0.4)
	_environment.ambient_light_energy = 0.3

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnv"
	_world_env.environment = _environment
	_viewport.add_child(_world_env)

	# Create output texture data
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size

	GNLogger.debug("RenderTOP", "'%s' 3D viewport created: %s" % [id, str(_viewport.size)])


## Populates the 3D viewport with scene nodes from connected COMPs.
## Walks the network's input connections to find GeometryCOMP, CameraCOMP, LightCOMP nodes.
func _populate_scene_from_network() -> void:
	if _viewport == null:
		return

	# Find the cook engine to get network reference
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network
	var has_camera: bool = false

	# Find all COMP nodes connected to this RenderTOP's input
	for conn in network.get_input_connections(id):
		var upstream_node: GNNode = network.nodes.get(conn.from_node, null)
		if upstream_node == null:
			continue

		if upstream_node is GeometryCOMP:
			var mesh_inst: MeshInstance3D = (upstream_node as GeometryCOMP).get_mesh_instance()
			if mesh_inst != null:
				_adopt_scene_node(mesh_inst)

		elif upstream_node is CameraCOMP:
			var camera: Camera3D = (upstream_node as CameraCOMP).get_camera()
			if camera != null:
				_adopt_scene_node(camera)
				camera.current = true
				has_camera = true

		elif upstream_node is LightCOMP:
			var light: Light3D = (upstream_node as LightCOMP).get_light()
			if light != null:
				_adopt_scene_node(light)

	# If no camera COMP is connected, create a default camera
	if not has_camera:
		_ensure_default_camera()


## Adds a 3D node to the viewport if not already there.
func _adopt_scene_node(node_3d: Node3D) -> void:
	if node_3d.get_parent() == _viewport:
		return  # Already in our viewport
	if node_3d.get_parent() != null:
		node_3d.get_parent().remove_child(node_3d)
	_viewport.add_child(node_3d)
	_managed_children.append(node_3d)


## Removes all managed children from the viewport before re-populating.
func _clear_managed_children() -> void:
	for child in _managed_children:
		if child != null and is_instance_valid(child) and child.get_parent() == _viewport:
			_viewport.remove_child(child)
	_managed_children.clear()


## Creates a default camera if none is provided by a CameraCOMP.
var _default_camera: Camera3D = null

func _ensure_default_camera() -> void:
	if _default_camera == null:
		_default_camera = Camera3D.new()
		_default_camera.name = "DefaultCam"
		_default_camera.position = Vector3(0, 1.5, 3.0)
		_default_camera.rotation_degrees = Vector3(-15, 0, 0)
		_default_camera.fov = 75.0
	if _default_camera.get_parent() != _viewport:
		if _default_camera.get_parent() != null:
			_default_camera.get_parent().remove_child(_default_camera)
		_viewport.add_child(_default_camera)
	_default_camera.current = true
	_managed_children.append(_default_camera)
