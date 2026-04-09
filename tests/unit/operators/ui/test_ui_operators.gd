extends Node
## Correctness tests for UI operators.
##
## UI operators create Control nodes. We test instantiation.

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


func test_button_ui_instantiate() -> void:
	var node := _make_node(ButtonUI.new(), "btn1")
	GNTestAssert.assert_eq(node.node_type, "button", "node_type")

func test_check_box_ui_instantiate() -> void:
	var node := _make_node(CheckBoxUI.new(), "cb1")
	GNTestAssert.assert_eq(node.node_type, "check_box", "node_type")

func test_color_picker_ui_instantiate() -> void:
	var node := _make_node(ColorPickerUI.new(), "cp1")
	GNTestAssert.assert_eq(node.node_type, "color_picker", "node_type")

func test_color_rect_ui_instantiate() -> void:
	var node := _make_node(ColorRectUI.new(), "cr1")
	GNTestAssert.assert_eq(node.node_type, "color_rect", "node_type")

func test_container_ui_instantiate() -> void:
	var node := _make_node(ContainerUI.new(), "cont1")
	GNTestAssert.assert_eq(node.node_type, "container", "node_type")

func test_dropdown_ui_instantiate() -> void:
	var node := _make_node(DropdownUI.new(), "dd1")
	GNTestAssert.assert_eq(node.node_type, "dropdown", "node_type")

func test_item_list_ui_instantiate() -> void:
	var node := _make_node(ItemListUI.new(), "il1")
	GNTestAssert.assert_eq(node.node_type, "item_list", "node_type")

func test_knob_ui_instantiate() -> void:
	var node := _make_node(KnobUI.new(), "knob1")
	GNTestAssert.assert_eq(node.node_type, "knob", "node_type")

func test_label_ui_instantiate() -> void:
	var node := _make_node(LabelUI.new(), "lbl1")
	GNTestAssert.assert_eq(node.node_type, "label", "node_type")

func test_line_edit_ui_instantiate() -> void:
	var node := _make_node(LineEditUI.new(), "le1")
	GNTestAssert.assert_eq(node.node_type, "line_edit", "node_type")

func test_link_button_ui_instantiate() -> void:
	var node := _make_node(LinkButtonUI.new(), "lb1")
	GNTestAssert.assert_eq(node.node_type, "link_button", "node_type")

func test_margin_container_ui_instantiate() -> void:
	var node := _make_node(MarginContainerUI.new(), "mc1")
	GNTestAssert.assert_eq(node.node_type, "margin_container", "node_type")

func test_menu_button_ui_instantiate() -> void:
	var node := _make_node(MenuButtonUI.new(), "mb1")
	GNTestAssert.assert_eq(node.node_type, "menu_button", "node_type")

func test_nine_patch_rect_ui_instantiate() -> void:
	var node := _make_node(NinePatchRectUI.new(), "np1")
	GNTestAssert.assert_eq(node.node_type, "nine_patch_rect", "node_type")

func test_panel_container_ui_instantiate() -> void:
	var node := _make_node(PanelContainerUI.new(), "pc1")
	GNTestAssert.assert_eq(node.node_type, "panel_container", "node_type")

func test_progress_bar_ui_instantiate() -> void:
	var node := _make_node(ProgressBarUI.new(), "pb1")
	GNTestAssert.assert_eq(node.node_type, "progress_bar", "node_type")

func test_rich_text_label_ui_instantiate() -> void:
	var node := _make_node(RichTextLabelUI.new(), "rtl1")
	GNTestAssert.assert_eq(node.node_type, "rich_text_label", "node_type")

func test_scroll_container_ui_instantiate() -> void:
	var node := _make_node(ScrollContainerUI.new(), "sc1")
	GNTestAssert.assert_eq(node.node_type, "scroll_container", "node_type")

func test_separator_ui_instantiate() -> void:
	var node := _make_node(SeparatorUI.new(), "sep1")
	GNTestAssert.assert_eq(node.node_type, "separator", "node_type")

func test_slider_ui_instantiate() -> void:
	var node := _make_node(SliderUI.new(), "sl1")
	GNTestAssert.assert_eq(node.node_type, "slider", "node_type")

func test_spin_box_ui_instantiate() -> void:
	var node := _make_node(SpinBoxUI.new(), "sb1")
	GNTestAssert.assert_eq(node.node_type, "spin_box", "node_type")

func test_split_container_ui_instantiate() -> void:
	var node := _make_node(SplitContainerUI.new(), "split1")
	GNTestAssert.assert_eq(node.node_type, "split_container", "node_type")

func test_tab_bar_ui_instantiate() -> void:
	var node := _make_node(TabBarUI.new(), "tb1")
	GNTestAssert.assert_eq(node.node_type, "tab_bar", "node_type")

func test_tab_container_ui_instantiate() -> void:
	var node := _make_node(TabContainerUI.new(), "tc1")
	GNTestAssert.assert_eq(node.node_type, "tab_container", "node_type")

func test_text_edit_ui_instantiate() -> void:
	var node := _make_node(TextEditUI.new(), "te1")
	GNTestAssert.assert_eq(node.node_type, "text_edit", "node_type")

func test_texture_button_ui_instantiate() -> void:
	var node := _make_node(TextureButtonUI.new(), "txb1")
	GNTestAssert.assert_eq(node.node_type, "texture_button", "node_type")

func test_texture_progress_bar_ui_instantiate() -> void:
	var node := _make_node(TextureProgressBarUI.new(), "tpb1")
	GNTestAssert.assert_eq(node.node_type, "texture_progress_bar", "node_type")

func test_texture_rect_ui_instantiate() -> void:
	var node := _make_node(TextureRectUI.new(), "txr1")
	GNTestAssert.assert_eq(node.node_type, "texture_rect", "node_type")

func test_toggle_ui_instantiate() -> void:
	var node := _make_node(ToggleUI.new(), "tog1")
	GNTestAssert.assert_eq(node.node_type, "toggle", "node_type")

func test_tree_ui_instantiate() -> void:
	var node := _make_node(TreeUI.new(), "tree1")
	GNTestAssert.assert_eq(node.node_type, "tree", "node_type")

func test_xy_pad_ui_instantiate() -> void:
	var node := _make_node(XYPadUI.new(), "xyp1")
	GNTestAssert.assert_eq(node.node_type, "xy_pad", "node_type")
