extends Node
## Unit tests for GNTopInteractiveBase panel visibility lifecycle.
##
## Panels stay hidden on the operator node and become visible only when a
## viewer overlay, panel-port preview, or WindowOUT adopts them.

const _TopStub := preload("res://tests/unit/fixtures/interactive_top_stub.gd")

var _network: GNNetwork
var _engine: GNCookEngine


class _ViewerHostStub:
	extends RefCounted
	var overlay: GNInteractivePanel = null
	var control: Control = null

	func set_texture(_tex: Texture2D, _info: String = "") -> void:
		pass

	func set_interactive_texture_overlay(panel: GNInteractivePanel) -> void:
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		if panel is GNInteractivePanel:
			panel.show_for_host()
		else:
			panel.visible = true
		overlay = panel

	func set_control(ctrl: Control, _info: String = "") -> void:
		ctrl.visible = true
		control = ctrl

	func set_info(_text: String, _info: String = "") -> void:
		pass


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


func _make_top(id: String) -> GNTopInteractiveBase:
	var node: GNTopInteractiveBase = _TopStub.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _make_window(id: String) -> WindowOUT:
	var node := WindowOUT.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func test_interactive_panel_vis_spawned_hidden_on_operator() -> void:
	var top := _make_top("map1")
	var viewer_panel := top._ensure_viewer_panel()
	var export_panel := top._ensure_export_panel()
	GNTestAssert.assert_not_null(viewer_panel, "viewer panel created")
	GNTestAssert.assert_not_null(export_panel, "export panel created")
	GNTestAssert.assert_false(viewer_panel.visible, "viewer panel hidden on node")
	GNTestAssert.assert_false(export_panel.visible, "export panel hidden on node")
	GNTestAssert.assert_eq(viewer_panel.get_parent(), top, "viewer panel parent is operator")
	GNTestAssert.assert_eq(export_panel.get_parent(), top, "export panel parent is operator")


func test_interactive_panel_vis_viewer_overlay_shows() -> void:
	var top := _make_top("map2")
	var panel := top._ensure_viewer_panel()
	var host := _ViewerHostStub.new()
	panel.show_for_host()
	host.set_interactive_texture_overlay(panel)
	GNTestAssert.assert_true(panel.visible, "overlay visible when hosted")
	GNTestAssert.assert_eq(host.overlay, panel, "host holds overlay ref")

	panel.return_to_storage()
	GNTestAssert.assert_false(panel.visible, "overlay hidden after return_to_storage")
	GNTestAssert.assert_eq(panel.get_parent(), top, "overlay returned to operator node")


func test_interactive_panel_vis_panel_port_preview() -> void:
	var top := _make_top("map3")
	var host := _ViewerHostStub.new()
	top._render_panel_port_in_viewer(host)
	GNTestAssert.assert_not_null(host.control, "panel preview mounted")
	GNTestAssert.assert_true(host.control.visible, "panel preview visible")
	GNTestAssert.assert_false(
		(host.control as GNInteractivePanel).is_storage_managed(),
		"preview duplicate is not storage-managed")


func test_interactive_panel_vis_window_adopt_and_release() -> void:
	var top := _make_top("map4")
	var win := _make_window("win1")
	win.set_param_value("open", true)
	var panel := top._ensure_export_panel()

	win._ensure_window()
	win._adopt_control(panel)
	GNTestAssert.assert_true(panel.visible, "export panel visible in WindowOUT")
	GNTestAssert.assert_eq(panel.get_parent(), win._panel_ui_root, "panel parent is window ui root")

	win._clear_managed_controls()
	GNTestAssert.assert_false(panel.visible, "export panel hidden after release")
	GNTestAssert.assert_eq(panel.get_parent(), top, "export panel rehomed on operator")
