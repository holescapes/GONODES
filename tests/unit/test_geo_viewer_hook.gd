extends Node
## Tests for GNViewerRenderHelpers geo viewer provider hook.
##
## Verifies headless no-op behaviour and stub registration. Saves and restores
## the live provider so later tests in the same process keep geo viewer access.


class _GeoViewerStub extends RefCounted:
	var _mesh := MeshInstance3D.new()

	func ensure_scene() -> void:
		pass

	func reparent_scene(_vp: SubViewport) -> void:
		pass

	func shared_mesh() -> MeshInstance3D:
		return _mesh

	func shared_camera() -> Camera3D:
		return Camera3D.new()

	func shared_gizmo() -> Node3D:
		return Node3D.new()


var _saved_provider: Object = null


func before_each() -> void:
	_saved_provider = GNViewerRenderHelpers.geo_viewer_provider()


func after_each() -> void:
	GNViewerRenderHelpers.register_geo_viewer(_saved_provider)


func test_shared_geo_viewer_no_provider() -> void:
	GNViewerRenderHelpers.register_geo_viewer(null)
	GNTestAssert.assert_null(GNViewerRenderHelpers.shared_geo_mesh(),
		"no provider → null mesh")
	GNViewerRenderHelpers.ensure_shared_geo_viewer()


func test_shared_geo_viewer_with_stub() -> void:
	var stub := _GeoViewerStub.new()
	GNViewerRenderHelpers.register_geo_viewer(stub)
	GNViewerRenderHelpers.ensure_shared_geo_viewer()
	var mesh := GNViewerRenderHelpers.shared_geo_mesh()
	GNTestAssert.assert_not_null(mesh, "stub provider returns mesh")
	GNTestAssert.assert_eq(mesh, stub.shared_mesh(), "mesh is stub instance")
