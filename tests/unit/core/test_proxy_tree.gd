extends Node
## Unit tests for GNProxyTree — the proxy creation and sync system.
##
## Tests cover:
##   • Proxy creation for each visual node type
##   • Resource sharing (Mesh, Material stay shared, not duplicated)
##   • Transform and visibility sync
##   • Proxy caching and reuse across frames
##   • Stale proxy cleanup
##   • Recursive proxy tree for group nodes

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — MeshInstance3D
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_mesh_instance_created() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.mesh = BoxMesh.new()
	source.material_override = StandardMaterial3D.new()
	source.position = Vector3(1, 2, 3)

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_not_null(proxy, "proxy created")
	GNTestAssert.assert_true(proxy is MeshInstance3D, "proxy is MeshInstance3D")
	source.queue_free()


func test_proxy_mesh_shares_resources() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	source.mesh = mesh
	source.material_override = mat

	var proxy: Node3D = tree.get_or_create_proxy(source)
	var proxy_mesh: MeshInstance3D = proxy as MeshInstance3D
	GNTestAssert.assert_eq(proxy_mesh.mesh, mesh, "mesh shared (same resource)")
	GNTestAssert.assert_eq(proxy_mesh.material_override, mat, "material shared")
	source.queue_free()


func test_proxy_mesh_copies_transform() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.position = Vector3(5, 10, 15)
	source.rotation_degrees = Vector3(45, 90, 0)
	source.visible = false

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_vec3_approx(proxy.position, Vector3(5, 10, 15), 0.001, "position")
	GNTestAssert.assert_false(proxy.visible, "visibility copied")
	source.queue_free()


func test_proxy_mesh_copies_shadow_mode() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_eq(
		(proxy as MeshInstance3D).cast_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "shadow mode")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — Camera3D
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_camera_created() -> void:
	var tree := GNProxyTree.new()
	var source := Camera3D.new()
	source.fov = 90.0
	source.near = 0.5
	source.far = 500.0

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy is Camera3D, "proxy is Camera3D")
	GNTestAssert.assert_approx((proxy as Camera3D).fov, 90.0, 0.01, "fov")
	GNTestAssert.assert_approx((proxy as Camera3D).near, 0.5, 0.01, "near")
	GNTestAssert.assert_approx((proxy as Camera3D).far, 500.0, 0.01, "far")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — Lights
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_directional_light() -> void:
	var tree := GNProxyTree.new()
	var source := DirectionalLight3D.new()
	source.light_color = Color.RED
	source.light_energy = 2.5
	source.shadow_enabled = true

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy is DirectionalLight3D, "proxy is DirectionalLight3D")
	var pl: DirectionalLight3D = proxy as DirectionalLight3D
	GNTestAssert.assert_eq(pl.light_color, Color.RED, "color")
	GNTestAssert.assert_approx(pl.light_energy, 2.5, 0.01, "energy")
	GNTestAssert.assert_true(pl.shadow_enabled, "shadow")
	source.queue_free()


func test_proxy_omni_light() -> void:
	var tree := GNProxyTree.new()
	var source := OmniLight3D.new()
	source.omni_range = 20.0
	source.light_energy = 3.0

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy is OmniLight3D, "proxy is OmniLight3D")
	GNTestAssert.assert_approx((proxy as OmniLight3D).omni_range, 20.0, 0.01, "range")
	source.queue_free()


func test_proxy_spot_light() -> void:
	var tree := GNProxyTree.new()
	var source := SpotLight3D.new()
	source.spot_range = 15.0
	source.spot_angle = 30.0

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy is SpotLight3D, "proxy is SpotLight3D")
	GNTestAssert.assert_approx((proxy as SpotLight3D).spot_range, 15.0, 0.01, "range")
	GNTestAssert.assert_approx((proxy as SpotLight3D).spot_angle, 30.0, 0.01, "angle")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — MultiMeshInstance3D
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_multimesh_shares_resource() -> void:
	var tree := GNProxyTree.new()
	var source := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.mesh = BoxMesh.new()
	mm.instance_count = 10
	source.multimesh = mm

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy is MultiMeshInstance3D, "proxy type")
	GNTestAssert.assert_eq((proxy as MultiMeshInstance3D).multimesh, mm, "multimesh shared")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Creation — Recursive Group
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_group_recursive() -> void:
	var tree := GNProxyTree.new()
	var group := Node3D.new()
	group.position = Vector3(10, 0, 0)
	var child_mesh := MeshInstance3D.new()
	child_mesh.mesh = BoxMesh.new()
	group.add_child(child_mesh)
	var child_light := OmniLight3D.new()
	child_light.omni_range = 5.0
	group.add_child(child_light)

	var proxy: Node3D = tree.get_or_create_proxy(group)
	GNTestAssert.assert_vec3_approx(proxy.position, Vector3(10, 0, 0), 0.001, "group pos")
	GNTestAssert.assert_eq(proxy.get_child_count(), 2, "two children proxied")
	GNTestAssert.assert_true(proxy.get_child(0) is MeshInstance3D, "child 0 is mesh")
	GNTestAssert.assert_true(proxy.get_child(1) is OmniLight3D, "child 1 is light")
	GNTestAssert.assert_eq(
		(proxy.get_child(0) as MeshInstance3D).mesh,
		child_mesh.mesh, "child mesh shared")

	group.queue_free()


func test_proxy_physics_body_becomes_placeholder() -> void:
	var tree := GNProxyTree.new()
	var body := RigidBody3D.new()
	body.position = Vector3(0, 5, 0)
	var visual := MeshInstance3D.new()
	visual.mesh = SphereMesh.new()
	body.add_child(visual)

	var proxy: Node3D = tree.get_or_create_proxy(body)
	# PhysicsBody3D becomes a plain Node3D placeholder
	GNTestAssert.assert_false(proxy is RigidBody3D, "not a physics body")
	GNTestAssert.assert_true(proxy is Node3D, "is Node3D placeholder")
	GNTestAssert.assert_vec3_approx(proxy.position, Vector3(0, 5, 0), 0.001, "position kept")
	# But its MeshInstance3D child is properly proxied
	GNTestAssert.assert_eq(proxy.get_child_count(), 1, "one child")
	GNTestAssert.assert_true(proxy.get_child(0) is MeshInstance3D, "child is mesh")
	GNTestAssert.assert_eq(
		(proxy.get_child(0) as MeshInstance3D).mesh,
		visual.mesh, "mesh resource shared")

	body.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Proxy Caching & Reuse
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_reused_across_frames() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.mesh = BoxMesh.new()

	var proxy1: Node3D = tree.get_or_create_proxy(source)
	var proxy2: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_eq(proxy1, proxy2, "same proxy instance reused")
	source.queue_free()


func test_has_proxy_for() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	GNTestAssert.assert_false(tree.has_proxy_for(source), "no proxy yet")

	tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(tree.has_proxy_for(source), "proxy exists")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Sync
# ═══════════════════════════════════════════════════════════════════════════════

func test_sync_updates_transform() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.position = Vector3(1, 1, 1)
	source.mesh = BoxMesh.new()

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_vec3_approx(proxy.position, Vector3(1, 1, 1), 0.001, "initial pos")

	# Move source
	source.position = Vector3(10, 20, 30)
	tree.sync_all()
	GNTestAssert.assert_vec3_approx(proxy.position, Vector3(10, 20, 30), 0.001, "synced pos")
	source.queue_free()


func test_sync_updates_mesh_resource() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	var mesh1 := BoxMesh.new()
	source.mesh = mesh1

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_eq((proxy as MeshInstance3D).mesh, mesh1, "initial mesh")

	var mesh2 := SphereMesh.new()
	source.mesh = mesh2
	tree.sync_all()
	GNTestAssert.assert_eq((proxy as MeshInstance3D).mesh, mesh2, "synced mesh")
	source.queue_free()


func test_sync_updates_visibility() -> void:
	var tree := GNProxyTree.new()
	var source := MeshInstance3D.new()
	source.visible = true

	var proxy: Node3D = tree.get_or_create_proxy(source)
	GNTestAssert.assert_true(proxy.visible, "initially visible")

	source.visible = false
	tree.sync_all()
	GNTestAssert.assert_false(proxy.visible, "synced invisible")
	source.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Stale Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleanup_stale_removes_unused() -> void:
	var tree := GNProxyTree.new()
	var src1 := MeshInstance3D.new()
	var src2 := MeshInstance3D.new()
	src1.mesh = BoxMesh.new()
	src2.mesh = SphereMesh.new()

	tree.get_or_create_proxy(src1)
	var proxy2: Node3D = tree.get_or_create_proxy(src2)

	# Only src1 is still active
	var removed: Array[Node3D] = tree.cleanup_stale([src1])
	GNTestAssert.assert_eq(removed.size(), 1, "one stale removed")
	GNTestAssert.assert_false(tree.has_proxy_for(src2), "src2 proxy gone")
	GNTestAssert.assert_true(tree.has_proxy_for(src1), "src1 proxy kept")

	src1.queue_free()
	src2.queue_free()


func test_release_all() -> void:
	var tree := GNProxyTree.new()
	var src := MeshInstance3D.new()
	src.mesh = BoxMesh.new()

	tree.get_or_create_proxy(src)
	GNTestAssert.assert_true(tree.has_proxy_for(src), "before release")

	tree.release_all()
	GNTestAssert.assert_false(tree.has_proxy_for(src), "after release")
	src.queue_free()
