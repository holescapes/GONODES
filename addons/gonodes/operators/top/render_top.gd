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

var _environment: Environment = null
var _world_env: WorldEnvironment = null

## External EnvironmentCOMP (when connected) — overrides the fallback env.
var _env_comp: EnvironmentCOMP = null

## Track which scene nodes are currently in the viewport
var _managed_children: Array[Node3D] = []

## Previous frame's managed children — used for stable diff so physics
## bodies stay in the scene tree between frames.
var _prev_managed: Array[Node3D] = []

## Set to true when _adopt_scene_node actually adds a new child this frame.
## Used to gate the physics-body registration walk so it costs zero on
## steady-state frames where the scene composition hasn't changed.
var _new_nodes_adopted: bool = false


## Override execute_cook: for 3D viewports the render mode must stay at
## UPDATE_ALWAYS when cooking every frame, so the physics simulation is
## captured.  When cook_every_frame is off, uses UPDATE_ONCE (default TOP
## behavior) to avoid wasted GPU work.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	if _viewport != null and get_param_value("cook_every_frame"):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return result


func _init() -> void:
	node_type = "render"
	time_dependent = true


## Respect the cook_every_frame toggle.
func _pre_cook(_delta: float) -> void:
	time_dependent = get_param_value("cook_every_frame")
	if time_dependent:
		mark_dirty()


func _init_ports() -> void:
	# Dynamic-input COMP — accepts geometry, camera, lights on numbered ports
	_enable_dynamic_inputs(GNFamily.Type.COMP, "comp", "COMP Input")
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
	# Shadow quality
	add_parameter(GNParameter.create_enum("shadow_atlas_size",
		PackedStringArray(["1024", "2048", "4096", "8192"]), 2,
		"Shadow Atlas", "Positional shadow atlas resolution (Omni/Spot)"))
	add_parameter(GNParameter.create_enum("dir_shadow_size",
		PackedStringArray(["1024", "2048", "4096", "8192"]), 2,
		"Dir Shadow Size", "Directional shadow map resolution"))
	add_parameter(GNParameter.create_enum("shadow_filter",
		PackedStringArray(["Hard", "Soft Low", "Soft Medium", "Soft High", "Soft Ultra"]), 2,
		"Shadow Filter", "Shadow filter quality (PCF)"))

	# ── Depth of Field (camera attribute, stays on RenderTOP) ───────────
	add_parameter(GNParameter.create_bool("dof_far_enabled", false,
		"DOF Far", "Enable far depth-of-field blur"))
	add_parameter(GNParameter.create_float("dof_far_distance", 10.0, 0.1, 200.0, 0.5,
		"Far Distance", "Focus distance for far DOF"))
	add_parameter(GNParameter.create_float("dof_far_transition", 5.0, 0.1, 50.0, 0.5,
		"Far Transition", "Transition region width for far DOF"))
	add_parameter(GNParameter.create_bool("dof_near_enabled", false,
		"DOF Near", "Enable near depth-of-field blur"))
	add_parameter(GNParameter.create_float("dof_near_distance", 2.0, 0.1, 50.0, 0.1,
		"Near Distance", "Focus distance for near DOF"))
	add_parameter(GNParameter.create_float("dof_near_transition", 1.0, 0.1, 20.0, 0.1,
		"Near Transition", "Transition region width for near DOF"))
	add_parameter(GNParameter.create_float("dof_bokeh_size", 4.0, 0.5, 10.0, 0.1,
		"Bokeh Size", "Blur disc radius for DOF"))
	add_parameter(GNParameter.create_enum("dof_bokeh_shape",
		PackedStringArray(["Box", "Hexagon", "Circle"]), 2,
		"Bokeh Shape", "Shape of the depth-of-field bokeh"))

	# Cook behavior
	add_parameter(GNParameter.create_bool("cook_every_frame", true,
		"Cook Every Frame", "When off, only re-renders when inputs or parameters change"))


func _cook(inputs: Array[GNData]) -> GNData:
	_setup_viewport()

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

	# Shadow atlas (positional lights: Omni/Spot)
	var atlas_idx: int = get_param_value("shadow_atlas_size")
	var atlas_sizes: Array[int] = [1024, 2048, 4096, 8192]
	_viewport.positional_shadow_atlas_size = atlas_sizes[atlas_idx]

	# Directional shadow size
	var dir_idx: int = get_param_value("dir_shadow_size")
	_viewport.set_meta("directional_shadow_size", atlas_sizes[dir_idx])

	# Shadow filter quality
	var filter_idx: int = get_param_value("shadow_filter")
	match filter_idx:
		0: _viewport.positional_shadow_atlas_16_bits = false
		1: _viewport.positional_shadow_atlas_16_bits = true

	# ── Environment: EnvironmentCOMP or fallback ───────────────────────────
	_env_comp = null  # Reset each cook; _populate_scene_from_network sets it

	# Stable scene population — nodes that haven't changed stay in the
	# viewport so physics bodies keep simulating between frames.
	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_new_nodes_adopted = false

	# Scan inputs for COMP nodes and add their 3D nodes to the viewport
	# The cook engine passes upstream cached_output via inputs, but we need
	# to access the actual COMP nodes to get their MeshInstance3D/Camera3D/Light3D.
	_populate_scene_from_network()

	# Remove any previously managed nodes that were not re-adopted this frame
	_remove_stale_children()

	# Safety net: force-register any physics bodies that ended up with
	# space=RID(0) — only runs when new nodes were adopted this frame,
	# so steady-state frames pay zero cost.
	if _new_nodes_adopted:
		_force_register_physics_bodies()

	# Apply environment — prefer EnvironmentCOMP, fall back to built-in params
	_apply_environment(bg_color, use_env)

	# Apply DOF after scene population so we target the active camera
	_apply_dof_to_active_camera()

	# Update output
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Lazily creates the 3D SubViewport and environment.
## IMPORTANT: The SubViewport is fully configured with its own World3D BEFORE
## being added to the tree.  This ensures that any CollisionObject3D or
## SoftBody3D nodes added later receive the correct physics space in their
## NOTIFICATION_ENTER_WORLD.
func _setup_viewport() -> void:
	if _viewport != null:
		return

	# Build the SubViewport manually instead of _create_viewport() so we can
	# assign a dedicated World3D BEFORE the viewport enters the tree.
	# _create_viewport() calls add_child() immediately, which means
	# world_3d would be set AFTER the viewport is in the tree,
	# and descendant physics nodes would not register with the
	# correct physics space on ENTER_WORLD.
	var res: Vector2i = get_param_value("resolution")
	_viewport = SubViewport.new()
	_viewport.name = "VP3D_%s" % id
	_viewport.size = res
	_viewport.transparent_bg = false
	_viewport.disable_3d = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Set an explicit World3D BEFORE entering tree.  Do NOT set
	# own_world_3d = true — that causes Godot to create a DUPLICATE
	# World3D internally, so child nodes see a different World3D (and
	# different physics space) than the one we activate below.  By
	# setting world_3d directly, find_world_3d() returns the same
	# World3D we reference here, and all physics bodies register with
	# the activated space.
	_viewport.world_3d = World3D.new()

	# NOW add to tree — world is fully configured
	add_child(_viewport)

	# Activate the physics space so Jolt steps it each physics frame
	var space_rid: RID = _viewport.world_3d.space
	PhysicsServer3D.space_set_active(space_rid, true)

	# Create a lightweight fallback environment (bg + ambient only).
	# If an EnvironmentCOMP is connected later, it will replace this.
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


## Populates the 3D viewport with scene nodes from connected COMPs.
## Iterates connections sorted by input port index for deterministic ordering.
func _populate_scene_from_network() -> void:
	if _viewport == null:
		return

	var cook_engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	var net: GNNetwork = cook_engine.network if cook_engine != null else null
	var has_camera: bool = false

	for upstream_node in get_input_nodes_sorted():
		if upstream_node is EnvironmentCOMP:
			_env_comp = upstream_node as EnvironmentCOMP
			continue

		# Resolve the scene node — walks through pass-through COMPs and
		# data-path fallback for SubNetworkNode/GNCustomOperator.
		var scene_nd: Node3D = GNCompBase.resolve_scene_node_upstream(
			upstream_node, net) if net != null else null
		if scene_nd == null:
			# Direct fallback when no network context
			var comp_data := upstream_node.cached_output as GNCompData
			if comp_data != null:
				scene_nd = comp_data.scene_node
		if scene_nd == null:
			continue

		_adopt_scene_node(scene_nd)

		# Camera bookkeeping — activate any camera found
		if scene_nd is Camera3D:
			(scene_nd as Camera3D).current = true
			has_camera = true
		elif upstream_node is MergeCOMP and not has_camera:
			has_camera = _activate_camera_in_subtree(scene_nd)

	# If no camera COMP is connected, create a default camera
	if not has_camera:
		_ensure_default_camera()
	elif _default_camera != null:
		_default_camera.current = false


## Recursively searches a subtree for Camera3D nodes and activates the first
## one found.  Returns true if a camera was found, false otherwise.
## This is needed when CameraCOMP goes through MergeCOMP — the camera ends
## up as a child of the merge group node rather than being a direct input.
func _activate_camera_in_subtree(root: Node3D) -> bool:
	for child in root.get_children():
		if child is Camera3D:
			(child as Camera3D).current = true
			return true
		if child is Node3D and child.get_child_count() > 0:
			if _activate_camera_in_subtree(child as Node3D):
				return true
	return false


## Adds a 3D node to the viewport if not already there.
## Always tracks the node in _managed_children for stable diff.
func _adopt_scene_node(node_3d: Node3D) -> void:
	if node_3d.get_parent() != _viewport:
		if node_3d.get_parent() != null:
			node_3d.get_parent().remove_child(node_3d)
		_viewport.add_child(node_3d)
		_new_nodes_adopted = true
	_managed_children.append(node_3d)


## Force-register any physics bodies not yet in the viewport's physics space.
## Godot normally handles this via NOTIFICATION_ENTER_WORLD, but SubViewport
## + custom World3D can miss bodies depending on add_child ordering.  This
## walk runs once per cook after scene population as a safety net.
func _force_register_physics_bodies() -> void:
	if _viewport == null or _viewport.world_3d == null:
		return
	var target_space: RID = _viewport.world_3d.space
	if not target_space.is_valid():
		return
	_recursive_register_bodies(_viewport, target_space)


func _recursive_register_bodies(parent: Node, target_space: RID) -> void:
	for child in parent.get_children():
		if child is PhysicsBody3D:
			var body_rid: RID = child.get_rid()
			if body_rid.is_valid():
				var current_space: RID = PhysicsServer3D.body_get_space(body_rid)
				if current_space != target_space:
					PhysicsServer3D.body_set_space(body_rid, target_space)
		elif child is SoftBody3D:
			# SoftBody3D extends MeshInstance3D (NOT PhysicsBody3D) and uses
			# a separate soft_body_* API on PhysicsServer3D.
			var soft_rid: RID = child.get_physics_rid()
			if soft_rid.is_valid():
				var current_space: RID = PhysicsServer3D.soft_body_get_space(soft_rid)
				if current_space != target_space:
					PhysicsServer3D.soft_body_set_space(soft_rid, target_space)
		if child.get_child_count() > 0:
			_recursive_register_bodies(child, target_space)


## Removes previously managed children that were NOT re-adopted this frame.
## Nodes that are still in _managed_children stay in the viewport — this is
## essential for physics bodies that must remain in the scene tree.
func _remove_stale_children() -> void:
	for child in _prev_managed:
		if child != null and is_instance_valid(child) and not _managed_children.has(child):
			if child.get_parent() == _viewport:
				_viewport.remove_child(child)
	_prev_managed.clear()


## Removes all managed children from the viewport (used during cleanup).
func _clear_managed_children() -> void:
	for child in _managed_children:
		if child != null and is_instance_valid(child) and child.get_parent() == _viewport:
			_viewport.remove_child(child)
	_managed_children.clear()


## Resets the viewport tracking state so the next cook adopts all COMP scene
## nodes fresh.  Called by the editor Stop button after all COMPs have
## destroyed their scene nodes.
func reset_viewport() -> void:
	_clear_managed_children()
	_prev_managed.clear()
	_new_nodes_adopted = false


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


# ═══════════════════════════════════════════════════════════════════════════════
# Environment
# ═══════════════════════════════════════════════════════════════════════════════

## Applies the connected EnvironmentCOMP or the lightweight fallback env.
## Called after _populate_scene_from_network so _env_comp is resolved.
func _apply_environment(bg_color: Color, use_env: bool) -> void:
	if _env_comp != null:
		# Use the EnvironmentCOMP's fully configured Environment resource
		var ext_env: Environment = _env_comp.get_environment()
		if ext_env != null and _world_env != null:
			_world_env.environment = ext_env
			_environment = ext_env
		return

	# Fallback: apply bg/ambient from RenderTOP's own params
	if _environment == null:
		return
	# Ensure WorldEnvironment points to our fallback
	if _world_env != null and _world_env.environment != _environment:
		_world_env.environment = _environment
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = bg_color
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if use_env else Environment.AMBIENT_SOURCE_DISABLED
	_environment.ambient_light_color = get_param_value("ambient_color")
	_environment.ambient_light_energy = get_param_value("ambient_energy")
	# Reset post-processing on fallback (no EnvironmentCOMP = no effects)
	_environment.tonemap_mode = 0
	_environment.glow_enabled = false
	_environment.ssao_enabled = false
	_environment.ssil_enabled = false
	_environment.ssr_enabled = false
	_environment.adjustment_enabled = false
	_environment.volumetric_fog_enabled = false


## Applies DOF parameters to whatever camera is currently active in the viewport.
## Called after _populate_scene_from_network so the active camera is known.
## Early-exits when both DOF toggles are off.
func _apply_dof_to_active_camera() -> void:
	var dof_far: bool = get_param_value("dof_far_enabled")
	var dof_near: bool = get_param_value("dof_near_enabled")

	# Fast path: no DOF requested — skip camera lookup entirely.
	if not dof_far and not dof_near:
		return

	var active_cam: Camera3D = _find_active_camera()
	if active_cam == null:
		return

	# Ensure camera has CameraAttributesPractical for DOF
	if active_cam.attributes == null or not (active_cam.attributes is CameraAttributesPractical):
		active_cam.attributes = CameraAttributesPractical.new()

	var attrs: CameraAttributesPractical = active_cam.attributes as CameraAttributesPractical

	# ── DOF Far ──────────────────────────────────────────────────────────
	attrs.dof_blur_far_enabled = dof_far
	if dof_far:
		attrs.dof_blur_far_distance = get_param_value("dof_far_distance")
		attrs.dof_blur_far_transition = get_param_value("dof_far_transition")

	# ── DOF Near ─────────────────────────────────────────────────────────
	attrs.dof_blur_near_enabled = dof_near
	if dof_near:
		attrs.dof_blur_near_distance = get_param_value("dof_near_distance")
		attrs.dof_blur_near_transition = get_param_value("dof_near_transition")

	# ── DOF shared ───────────────────────────────────────────────────────
	if dof_far or dof_near:
		attrs.dof_blur_amount = get_param_value("dof_bokeh_size")
		var bokeh_shape: int = get_param_value("dof_bokeh_shape")
		match bokeh_shape:
			0: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_BOX)
			1: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_HEXAGON)
			2: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)


## Finds the active Camera3D in the viewport (from CameraCOMP or the default).
func _find_active_camera() -> Camera3D:
	if _viewport == null:
		return null
	for child in _viewport.get_children():
		if child is Camera3D and (child as Camera3D).current:
			return child as Camera3D
	return null
