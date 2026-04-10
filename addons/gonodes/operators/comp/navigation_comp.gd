class_name NavigationCOMP
extends GNCompBase
## AI pathfinding — navigates a COMP toward a target using NavigationServer3D.
##
## Creates a NavigationRegion3D with a baked NavigationMesh and a
## NavigationAgent3D that steers the source COMP along the computed path.
## The nav mesh is generated from the upstream SOP floor geometry.
##
## Uses Godot's native NavigationServer3D + NavigationAgent3D + NavigationMesh.

var _region: NavigationRegion3D = null
var _agent: NavigationAgent3D = null
var _nav_mesh: NavigationMesh = null
var _body: CharacterBody3D = null
var _mesh_instance: MeshInstance3D = null
var _last_floor_mesh: Mesh = null


func _init() -> void:
	node_type = "navigation"


func _init_ports() -> void:
	add_input("agent_in", GNFamily.Type.COMP, true, "COMP to navigate (the moving agent)", "Agent")
	add_input("floor_in", GNFamily.Type.SOP, false, "Floor/terrain SOP for nav mesh baking", "Floor SOP")
	add_output("out", GNFamily.Type.COMP, "Navigation component")


func _init_parameters() -> void:
	# Agent properties
	add_parameter(GNParameter.create_float("speed", 3.0, 0.1, 50.0, 0.1,
		"Speed", "Agent movement speed (m/s)"))
	add_parameter(GNParameter.create_float("agent_radius", 0.5, 0.1, 5.0, 0.1,
		"Agent Radius", "Navigation agent radius for avoidance"))
	add_parameter(GNParameter.create_float("agent_height", 1.8, 0.1, 10.0, 0.1,
		"Agent Height", "Navigation agent height"))

	# Target position
	add_parameter(GNParameter.create_float("target_x", 5.0, null, null, 0.1,
		"Target X", "Navigation target X"))
	add_parameter(GNParameter.create_float("target_y", 0.0, null, null, 0.1,
		"Target Y", "Navigation target Y"))
	add_parameter(GNParameter.create_float("target_z", 5.0, null, null, 0.1,
		"Target Z", "Navigation target Z"))

	# Start position
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.1, "Start X", "Agent start X"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.1, "Start Y", "Agent start Y"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.1, "Start Z", "Agent start Z"))

	# Nav mesh
	add_parameter(GNParameter.create_float("cell_size", 0.25, 0.05, 2.0, 0.05,
		"Cell Size", "Navigation mesh cell size (smaller = more precise, slower bake)"))
	add_parameter(GNParameter.create_float("cell_height", 0.25, 0.05, 2.0, 0.05,
		"Cell Height", "Navigation mesh cell height"))
	add_parameter(GNParameter.create_float("max_slope", 45.0, 0.0, 89.0, 1.0,
		"Max Slope", "Maximum walkable slope angle (degrees)"))
	add_parameter(GNParameter.create_float("max_climb", 0.3, 0.0, 5.0, 0.1,
		"Max Climb", "Maximum step height the agent can climb"))

	# Behavior
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable navigation"))
	add_parameter(GNParameter.create_bool("avoidance", true,
		"Avoidance", "Enable obstacle avoidance"))
	add_parameter(GNParameter.create_float("path_tolerance", 0.5, 0.1, 5.0, 0.1,
		"Path Tolerance", "Distance to target considered 'arrived'"))


func _cook(inputs: Array[GNData]) -> GNData:
	var agent_data = inputs[0] if inputs.size() > 0 else null
	var floor_data: GNGeoData = inputs[1] as GNGeoData if inputs.size() > 1 and inputs[1] is GNGeoData else null

	if agent_data == null:
		node_warning = "No agent COMP connected"
		return null

	_ensure_body()

	# If floor SOP provided, build navigation mesh
	if floor_data != null and floor_data.has_geometry():
		_update_nav_mesh(floor_data)
	elif _region != null and _nav_mesh == null:
		_build_default_nav_mesh()

	if not get_param_value("active"):
		node_warning = "Navigation paused"
		return agent_data

	# Set target
	var target := Vector3(
		get_param_value("target_x"),
		get_param_value("target_y"),
		get_param_value("target_z"))
	_agent.target_position = target

	# Move toward target
	if not _agent.is_navigation_finished():
		var next_pos := _agent.get_next_path_position()
		var direction := (_body.global_position.direction_to(next_pos)).normalized()
		var speed: float = get_param_value("speed")
		_body.velocity = direction * speed
		_body.move_and_slide()

		# Rotate to face movement direction
		if direction.length_squared() > 0.001:
			var look_dir := direction
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.001:
				_body.look_at(_body.global_position + look_dir, Vector3.UP)

	# Adopt upstream mesh for visual representation
	var upstream_node: Node3D = _get_upstream_scene_node(0)
	if upstream_node != null and upstream_node is MeshInstance3D:
		if upstream_node.get_parent() != _body:
			if upstream_node.get_parent() != null:
				upstream_node.get_parent().remove_child(upstream_node)
			_body.add_child(upstream_node)
		upstream_node.position = Vector3.ZERO

	node_warning = ""
	if _agent.is_navigation_finished():
		node_warning = "Arrived at target"
	return agent_data


func _ensure_body() -> void:
	if _body != null and is_instance_valid(_body):
		return

	# CharacterBody3D as the agent's physics body
	_body = CharacterBody3D.new()
	_body.name = id + "_nav_body"
	_body.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))

	# Collision shape for the agent
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = get_param_value("agent_radius")
	capsule.height = get_param_value("agent_height")
	col.shape = capsule
	_body.add_child(col)

	# Navigation agent
	_agent = NavigationAgent3D.new()
	_agent.name = id + "_agent"
	_agent.radius = get_param_value("agent_radius")
	_agent.path_desired_distance = get_param_value("path_tolerance")
	_agent.target_desired_distance = get_param_value("path_tolerance")
	_agent.avoidance_enabled = get_param_value("avoidance")
	_body.add_child(_agent)

	# Navigation region (will hold the nav mesh)
	_region = NavigationRegion3D.new()
	_region.name = id + "_region"
	_body.add_child(_region)

	_scene_node = _body


func _update_nav_mesh(floor_geo: GNGeoData) -> void:
	if floor_geo.mesh == _last_floor_mesh and _nav_mesh != null:
		return  # No change

	_nav_mesh = NavigationMesh.new()
	_nav_mesh.cell_size = get_param_value("cell_size")
	_nav_mesh.cell_height = get_param_value("cell_height")
	_nav_mesh.agent_radius = get_param_value("agent_radius")
	_nav_mesh.agent_height = get_param_value("agent_height")
	_nav_mesh.agent_max_slope = get_param_value("max_slope")
	_nav_mesh.agent_max_climb = get_param_value("max_climb")

	# Create a temporary MeshInstance3D for baking
	var temp_mesh := MeshInstance3D.new()
	temp_mesh.mesh = floor_geo.mesh
	_region.add_child(temp_mesh)

	_region.navigation_mesh = _nav_mesh
	_region.bake_navigation_mesh()

	temp_mesh.queue_free()
	_last_floor_mesh = floor_geo.mesh


func _build_default_nav_mesh() -> void:
	# Create a simple flat nav mesh when no SOP is provided
	_nav_mesh = NavigationMesh.new()
	_nav_mesh.cell_size = get_param_value("cell_size")
	_nav_mesh.cell_height = get_param_value("cell_height")
	_nav_mesh.agent_radius = get_param_value("agent_radius")
	_nav_mesh.agent_height = get_param_value("agent_height")

	# Simple flat plane vertices
	var verts := PackedVector3Array([
		Vector3(-20, 0, -20), Vector3(20, 0, -20),
		Vector3(20, 0, 20), Vector3(-20, 0, 20)
	])
	_nav_mesh.vertices = verts
	_nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	_nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))

	_region.navigation_mesh = _nav_mesh


func _get_upstream_scene_node(port: int) -> Node3D:
	var upstream := get_input_node(port)
	if upstream != null and upstream is GNCompBase:
		return (upstream as GNCompBase).get_scene_node()
	return null


func _on_node_removed() -> void:
	if _body != null and is_instance_valid(_body):
		if _body.get_parent() != null:
			_body.get_parent().remove_child(_body)
		_body.queue_free()
		_body = null
	_region = null
	_agent = null
