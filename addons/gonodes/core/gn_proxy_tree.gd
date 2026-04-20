class_name GNProxyTree
extends RefCounted
## Manages visual proxy Node3D trees that mirror source scene hierarchies.
##
## Used by MergeCOMP and RenderTOP to solve the fan-out problem: when multiple
## consumers need the same scene node, each consumer beyond the first gets a
## lightweight proxy that shares GPU resources (Mesh, Material, MultiMesh) but
## has its own Node3D wrapper.
##
## Proxies sync their visual state from the source each frame via sync_all().
## Physics bodies are represented as plain Node3D placeholders — their
## visual children (MeshInstance3D) are proxied, but collision/simulation is
## not duplicated.

## Maps source Node3D instance ID → proxy Node3D.
var _proxies: Dictionary = {}

## Maps source Node3D instance ID → source Node3D (for sync lookups).
var _sources: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a proxy for the given source.  Reuses an existing proxy if one
## was created in a previous frame and is still valid.  The returned proxy
## is NOT parented — caller must add it to their tree.
func get_or_create_proxy(source: Node3D) -> Node3D:
	var key: int = source.get_instance_id()
	if _proxies.has(key):
		var existing: Node3D = _proxies[key]
		if is_instance_valid(existing):
			sync_pair(existing, source)
			return existing
	var proxy: Node3D = _create_proxy_tree(source)
	_proxies[key] = proxy
	_sources[key] = source
	return proxy


## Syncs all managed proxy trees from their sources.
## Call once per cook, after all proxies have been adopted.
func sync_all() -> void:
	var stale: Array[int] = []
	for key: int in _proxies:
		var proxy: Node3D = _proxies[key]
		var source: Node3D = _sources.get(key, null)
		if not is_instance_valid(proxy) or not is_instance_valid(source):
			stale.append(key)
			continue
		sync_pair(proxy, source)
	for key: int in stale:
		_remove_entry(key)


## Removes proxies whose source is no longer in the active set.
## Returns an array of proxy Node3D that should be removed from the tree.
func cleanup_stale(active_sources: Array[Node3D]) -> Array[Node3D]:
	var active_ids: Dictionary = {}
	for src: Node3D in active_sources:
		active_ids[src.get_instance_id()] = true

	var removed: Array[Node3D] = []
	var stale_keys: Array[int] = []
	for key: int in _proxies:
		if not active_ids.has(key):
			var proxy: Node3D = _proxies[key]
			if is_instance_valid(proxy):
				removed.append(proxy)
			stale_keys.append(key)
	for key: int in stale_keys:
		_remove_entry(key)
	return removed


## Frees all managed proxies.  Call during cleanup / destroy.
func release_all() -> void:
	for key: int in _proxies:
		var proxy: Node3D = _proxies[key]
		if is_instance_valid(proxy):
			if proxy.get_parent() != null:
				proxy.get_parent().remove_child(proxy)
			proxy.queue_free()
	_proxies.clear()
	_sources.clear()


## Returns true if this tree has a proxy for the given source.
func has_proxy_for(source: Node3D) -> bool:
	return _proxies.has(source.get_instance_id())


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — recursive tree builder
# ═══════════════════════════════════════════════════════════════════════════════

func _create_proxy_tree(source: Node3D) -> Node3D:
	var proxy: Node3D = _create_proxy_node(source)
	# Recursively proxy Node3D children (skip non-visual nodes like
	# CollisionShape3D which are Node but not Node3D).
	for child in source.get_children():
		if child is Node3D:
			var child_proxy: Node3D = _create_proxy_tree(child as Node3D)
			proxy.add_child(child_proxy)
	return proxy


## Creates a single proxy node matching the source's visual type.
## Physics bodies become plain Node3D placeholders so the hierarchy
## (and descendant meshes) is preserved without collision.
static func _create_proxy_node(source: Node3D) -> Node3D:
	var proxy: Node3D

	if source is MeshInstance3D:
		proxy = _proxy_mesh_instance(source as MeshInstance3D)
	elif source is MultiMeshInstance3D:
		proxy = _proxy_multimesh_instance(source as MultiMeshInstance3D)
	elif source is Camera3D:
		proxy = _proxy_camera(source as Camera3D)
	elif source is DirectionalLight3D:
		proxy = _proxy_directional_light(source as DirectionalLight3D)
	elif source is OmniLight3D:
		proxy = _proxy_omni_light(source as OmniLight3D)
	elif source is SpotLight3D:
		proxy = _proxy_spot_light(source as SpotLight3D)
	else:
		# Generic Node3D — covers MergeCOMP group nodes, physics body
		# placeholders, and any other Node3D subclass.
		proxy = Node3D.new()

	_sync_transform(proxy, source)
	return proxy


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Type Proxy Factories
# ═══════════════════════════════════════════════════════════════════════════════

static func _proxy_mesh_instance(source: MeshInstance3D) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.mesh = source.mesh
	proxy.material_override = source.material_override
	proxy.cast_shadow = source.cast_shadow
	proxy.gi_mode = source.gi_mode
	proxy.transparency = source.transparency
	proxy.layers = source.layers
	proxy.skeleton = NodePath()  # Proxied meshes don't bind to skeletons
	return proxy


static func _proxy_multimesh_instance(source: MultiMeshInstance3D) -> MultiMeshInstance3D:
	var proxy := MultiMeshInstance3D.new()
	proxy.multimesh = source.multimesh
	proxy.cast_shadow = source.cast_shadow
	proxy.gi_mode = source.gi_mode
	proxy.layers = source.layers
	return proxy


static func _proxy_camera(source: Camera3D) -> Camera3D:
	var proxy := Camera3D.new()
	proxy.projection = source.projection
	proxy.fov = source.fov
	proxy.near = source.near
	proxy.far = source.far
	proxy.size = source.size
	proxy.keep_aspect = source.keep_aspect
	if source.attributes != null:
		proxy.attributes = source.attributes
	return proxy


static func _proxy_directional_light(source: DirectionalLight3D) -> DirectionalLight3D:
	var proxy := DirectionalLight3D.new()
	_sync_light_common(proxy, source)
	proxy.directional_shadow_mode = source.directional_shadow_mode
	proxy.directional_shadow_max_distance = source.directional_shadow_max_distance
	return proxy


static func _proxy_omni_light(source: OmniLight3D) -> OmniLight3D:
	var proxy := OmniLight3D.new()
	_sync_light_common(proxy, source)
	proxy.omni_range = source.omni_range
	proxy.omni_attenuation = source.omni_attenuation
	proxy.omni_shadow_mode = source.omni_shadow_mode
	return proxy


static func _proxy_spot_light(source: SpotLight3D) -> SpotLight3D:
	var proxy := SpotLight3D.new()
	_sync_light_common(proxy, source)
	proxy.spot_range = source.spot_range
	proxy.spot_attenuation = source.spot_attenuation
	proxy.spot_angle = source.spot_angle
	proxy.spot_angle_attenuation = source.spot_angle_attenuation
	return proxy


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Frame Sync
# ═══════════════════════════════════════════════════════════════════════════════

## Syncs a proxy tree from its source tree.  Handles structural changes
## (children added/removed) by rebuilding the subtree when needed.
static func sync_pair(proxy: Node3D, source: Node3D) -> void:
	_sync_transform(proxy, source)
	_sync_visual_properties(proxy, source)


static func _sync_transform(proxy: Node3D, source: Node3D) -> void:
	proxy.transform = source.transform
	proxy.visible = source.visible


static func _sync_visual_properties(proxy: Node3D, source: Node3D) -> void:
	if proxy is MeshInstance3D and source is MeshInstance3D:
		var p: MeshInstance3D = proxy as MeshInstance3D
		var s: MeshInstance3D = source as MeshInstance3D
		p.mesh = s.mesh
		p.material_override = s.material_override
		p.cast_shadow = s.cast_shadow
		p.gi_mode = s.gi_mode
		p.transparency = s.transparency
		p.layers = s.layers

	elif proxy is MultiMeshInstance3D and source is MultiMeshInstance3D:
		(proxy as MultiMeshInstance3D).multimesh = (source as MultiMeshInstance3D).multimesh

	elif proxy is Camera3D and source is Camera3D:
		var p: Camera3D = proxy as Camera3D
		var s: Camera3D = source as Camera3D
		p.projection = s.projection
		p.fov = s.fov
		p.near = s.near
		p.far = s.far
		p.size = s.size
		p.keep_aspect = s.keep_aspect
		p.attributes = s.attributes

	elif proxy is DirectionalLight3D and source is DirectionalLight3D:
		_sync_light_common(proxy as Light3D, source as Light3D)
		(proxy as DirectionalLight3D).directional_shadow_mode = \
			(source as DirectionalLight3D).directional_shadow_mode
		(proxy as DirectionalLight3D).directional_shadow_max_distance = \
			(source as DirectionalLight3D).directional_shadow_max_distance

	elif proxy is OmniLight3D and source is OmniLight3D:
		_sync_light_common(proxy as Light3D, source as Light3D)
		(proxy as OmniLight3D).omni_range = (source as OmniLight3D).omni_range
		(proxy as OmniLight3D).omni_attenuation = (source as OmniLight3D).omni_attenuation

	elif proxy is SpotLight3D and source is SpotLight3D:
		_sync_light_common(proxy as Light3D, source as Light3D)
		var p: SpotLight3D = proxy as SpotLight3D
		var s: SpotLight3D = source as SpotLight3D
		p.spot_range = s.spot_range
		p.spot_attenuation = s.spot_attenuation
		p.spot_angle = s.spot_angle
		p.spot_angle_attenuation = s.spot_angle_attenuation

	# Recurse into children to sync nested proxy trees
	var proxy_children: Array[Node] = proxy.get_children()
	var source_children: Array[Node] = source.get_children()
	var pi: int = 0
	var si: int = 0
	while pi < proxy_children.size() and si < source_children.size():
		var pc: Node = proxy_children[pi]
		var sc: Node = source_children[si]
		if pc is Node3D and sc is Node3D:
			sync_pair(pc as Node3D, sc as Node3D)
			pi += 1
			si += 1
		elif not (sc is Node3D):
			si += 1  # Skip non-Node3D source children
		else:
			pi += 1  # Skip non-Node3D proxy children


static func _sync_light_common(proxy: Light3D, source: Light3D) -> void:
	proxy.light_color = source.light_color
	proxy.light_energy = source.light_energy
	proxy.light_indirect_energy = source.light_indirect_energy
	proxy.light_volumetric_fog_energy = source.light_volumetric_fog_energy
	proxy.shadow_enabled = source.shadow_enabled
	proxy.shadow_bias = source.shadow_bias
	proxy.shadow_normal_bias = source.shadow_normal_bias
	proxy.light_negative = source.light_negative
	proxy.light_specular = source.light_specular
	proxy.light_bake_mode = source.light_bake_mode
	proxy.layers = source.layers


# ═══════════════════════════════════════════════════════════════════════════════
# Internal Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _remove_entry(key: int) -> void:
	var proxy: Node3D = _proxies.get(key, null)
	if proxy != null and is_instance_valid(proxy):
		if proxy.get_parent() != null:
			proxy.get_parent().remove_child(proxy)
		proxy.queue_free()
	_proxies.erase(key)
	_sources.erase(key)
