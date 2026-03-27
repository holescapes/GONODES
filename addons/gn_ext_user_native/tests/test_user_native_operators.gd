extends Node
## Tests for gn_ext_user_native operators.

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


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


# ═══════════════════════════════════════════════════════════════════════════════
# NativeSCRIPT — consolidated Native C++ scripting node
# ═══════════════════════════════════════════════════════════════════════════════

func test_native_script_instantiate() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript1")
	GNTestAssert.assert_not_null(node, "NativeSCRIPT created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.SCRIPT, "NativeSCRIPT family is SCRIPT")


func test_native_script_template_chop() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_chop")
	node.set_param_value("template", NativeSCRIPT.Template.CHOP)
	GNTestAssert.assert_eq(node._current_template, NativeSCRIPT.Template.CHOP, "Template is CHOP")


func test_native_script_template_sop() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_sop")
	node._apply_template(NativeSCRIPT.Template.SOP)
	GNTestAssert.assert_eq(node._current_template, NativeSCRIPT.Template.SOP, "Template is SOP")


func test_native_script_template_dat() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_dat")
	node._apply_template(NativeSCRIPT.Template.DAT)
	GNTestAssert.assert_eq(node._current_template, NativeSCRIPT.Template.DAT, "Template is DAT")


func test_native_script_template_img() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_img")
	node._apply_template(NativeSCRIPT.Template.IMG)
	GNTestAssert.assert_eq(node._current_template, NativeSCRIPT.Template.IMG, "Template is IMG")


func test_native_script_template_top() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_top")
	node._apply_template(NativeSCRIPT.Template.TOP)
	GNTestAssert.assert_eq(node._current_template, NativeSCRIPT.Template.TOP, "Template is TOP")


func test_native_script_preview_default() -> void:
	var node := _make_node(NativeSCRIPT.new(), "nativescript_preview")
	var label := Label.new()
	node.update_preview_control(label)
	# No cook yet, preview should be empty
	GNTestAssert.assert_eq(label.text, "", "Preview empty before first cook")
	label.free()
