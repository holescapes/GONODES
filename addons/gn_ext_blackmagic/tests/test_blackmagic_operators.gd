extends Node
## Tests for gn_ext_blackmagic operators.

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
# BlackmagicInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_in_top_instantiate() -> void:
	var node := _make_node(BlackmagicInTOP.new(), "bmin1")
	GNTestAssert.assert_not_null(node, "BlackmagicInTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# BlackmagicOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_out_top_instantiate() -> void:
	var node := _make_node(BlackmagicOutTOP.new(), "bmout1")
	GNTestAssert.assert_not_null(node, "BlackmagicOutTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# BlackmagicDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_dat_instantiate() -> void:
	var node := _make_node(BlackmagicDAT.new(), "bm1")
	GNTestAssert.assert_not_null(node, "BlackmagicDAT created")
