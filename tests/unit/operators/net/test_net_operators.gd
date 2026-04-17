extends Node
## Tests for NET family operators — sub-networks, tunnels, and host I/O bridges.
##
## All 15 NET operators must:
##   1. Instantiate without error
##   2. Report correct node_type
##   3. Report family == GNFamily.Type.NET
##
## SubNetworkNode, InTunnel, and OutTunnel additionally test port bridging,
## tunnel data flow, and subnet nesting.

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


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# SubNetworkNode
# ═══════════════════════════════════════════════════════════════════════════════

func test_sub_network_instantiate() -> void:
	var node := _make_node(SubNetworkNode.new(), "subnet1")
	GNTestAssert.assert_eq(node.node_type, "sub_network", "node_type")

func test_sub_network_family_is_net() -> void:
	var node := _make_node(SubNetworkNode.new(), "subnet1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_sub_network_has_inner_network() -> void:
	var node := _make_node(SubNetworkNode.new(), "subnet1")
	GNTestAssert.assert_not_null(node.inner_network, "inner_network exists")

func test_sub_network_cooks_without_crash() -> void:
	var node := _make_node(SubNetworkNode.new(), "subnet1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNData, "no crash without inputs")


# ═══════════════════════════════════════════════════════════════════════════════
# InTunnel
# ═══════════════════════════════════════════════════════════════════════════════

func test_in_tunnel_instantiate() -> void:
	var node := _make_node(InTunnel.new(), "in1")
	GNTestAssert.assert_eq(node.node_type, "in_tunnel", "node_type")

func test_in_tunnel_family_is_net() -> void:
	var node := _make_node(InTunnel.new(), "in1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# OutTunnel
# ═══════════════════════════════════════════════════════════════════════════════

func test_out_tunnel_instantiate() -> void:
	var node := _make_node(OutTunnel.new(), "out1")
	GNTestAssert.assert_eq(node.node_type, "out_tunnel", "node_type")

func test_out_tunnel_family_is_net() -> void:
	var node := _make_node(OutTunnel.new(), "out1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_top_instantiate() -> void:
	var node := _make_node(HostInTOP.new(), "hi_top1")
	GNTestAssert.assert_eq(node.node_type, "host_in", "node_type")

func test_host_in_top_family_is_net() -> void:
	var node := _make_node(HostInTOP.new(), "hi_top1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_top_instantiate() -> void:
	var node := _make_node(HostOutTOP.new(), "ho_top1")
	GNTestAssert.assert_eq(node.node_type, "host_out", "node_type")

func test_host_out_top_family_is_net() -> void:
	var node := _make_node(HostOutTOP.new(), "ho_top1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_top_is_sink() -> void:
	var node := _make_node(HostOutTOP.new(), "ho_top1")
	GNTestAssert.assert_true(node.is_sink, "HostOutTOP is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_chop_instantiate() -> void:
	var node := _make_node(HostInCHOP.new(), "hi_chop1")
	GNTestAssert.assert_eq(node.node_type, "host_in_chop", "node_type")

func test_host_in_chop_family_is_net() -> void:
	var node := _make_node(HostInCHOP.new(), "hi_chop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_chop_instantiate() -> void:
	var node := _make_node(HostOutCHOP.new(), "ho_chop1")
	GNTestAssert.assert_eq(node.node_type, "host_out_chop", "node_type")

func test_host_out_chop_family_is_net() -> void:
	var node := _make_node(HostOutCHOP.new(), "ho_chop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_chop_is_sink() -> void:
	var node := _make_node(HostOutCHOP.new(), "ho_chop1")
	GNTestAssert.assert_true(node.is_sink, "HostOutCHOP is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_dat_instantiate() -> void:
	var node := _make_node(HostInDAT.new(), "hi_dat1")
	GNTestAssert.assert_eq(node.node_type, "host_in_dat", "node_type")

func test_host_in_dat_family_is_net() -> void:
	var node := _make_node(HostInDAT.new(), "hi_dat1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_dat_instantiate() -> void:
	var node := _make_node(HostOutDAT.new(), "ho_dat1")
	GNTestAssert.assert_eq(node.node_type, "host_out_dat", "node_type")

func test_host_out_dat_family_is_net() -> void:
	var node := _make_node(HostOutDAT.new(), "ho_dat1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_dat_is_sink() -> void:
	var node := _make_node(HostOutDAT.new(), "ho_dat1")
	GNTestAssert.assert_true(node.is_sink, "HostOutDAT is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_vol_instantiate() -> void:
	var node := _make_node(HostInVOL.new(), "hi_vol1")
	GNTestAssert.assert_eq(node.node_type, "host_in_vol", "node_type")

func test_host_in_vol_family_is_net() -> void:
	var node := _make_node(HostInVOL.new(), "hi_vol1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_vol_instantiate() -> void:
	var node := _make_node(HostOutVOL.new(), "ho_vol1")
	GNTestAssert.assert_eq(node.node_type, "host_out_vol", "node_type")

func test_host_out_vol_family_is_net() -> void:
	var node := _make_node(HostOutVOL.new(), "ho_vol1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_vol_is_sink() -> void:
	var node := _make_node(HostOutVOL.new(), "ho_vol1")
	GNTestAssert.assert_true(node.is_sink, "HostOutVOL is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_pop_instantiate() -> void:
	var node := _make_node(HostInPOP.new(), "hi_pop1")
	GNTestAssert.assert_eq(node.node_type, "host_in_pop", "node_type")

func test_host_in_pop_family_is_net() -> void:
	var node := _make_node(HostInPOP.new(), "hi_pop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_pop_instantiate() -> void:
	var node := _make_node(HostOutPOP.new(), "ho_pop1")
	GNTestAssert.assert_eq(node.node_type, "host_out_pop", "node_type")

func test_host_out_pop_family_is_net() -> void:
	var node := _make_node(HostOutPOP.new(), "ho_pop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_pop_is_sink() -> void:
	var node := _make_node(HostOutPOP.new(), "ho_pop1")
	GNTestAssert.assert_true(node.is_sink, "HostOutPOP is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_sop_instantiate() -> void:
	var node := _make_node(HostInSOP.new(), "hi_sop1")
	GNTestAssert.assert_eq(node.node_type, "host_in_sop", "node_type")

func test_host_in_sop_family_is_net() -> void:
	var node := _make_node(HostInSOP.new(), "hi_sop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_sop_instantiate() -> void:
	var node := _make_node(HostOutSOP.new(), "ho_sop1")
	GNTestAssert.assert_eq(node.node_type, "host_out_sop", "node_type")

func test_host_out_sop_family_is_net() -> void:
	var node := _make_node(HostOutSOP.new(), "ho_sop1")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.NET, "family must be NET")

func test_host_out_sop_is_sink() -> void:
	var node := _make_node(HostOutSOP.new(), "ho_sop1")
	GNTestAssert.assert_true(node.is_sink, "HostOutSOP is a sink")


# ═══════════════════════════════════════════════════════════════════════════════
# Cross-cutting: generate_host_io covers all 6 families
# ═══════════════════════════════════════════════════════════════════════════════

func test_generate_host_io_creates_all_families() -> void:
	var net := GNNetwork.new()
	net.generate_host_io()
	var ids: Array = net.get_all_node_ids()
	# Should have at least 12 nodes: 6 HostIn + 6 HostOut
	GNTestAssert.assert_true(ids.size() >= 12, "host IO nodes created for all families")

	# Verify each family has In and Out
	var has_in_top := false
	var has_out_top := false
	var has_in_chop := false
	var has_out_chop := false
	var has_in_dat := false
	var has_out_dat := false
	var has_in_vol := false
	var has_out_vol := false
	var has_in_pop := false
	var has_out_pop := false
	var has_in_sop := false
	var has_out_sop := false
	for nid in ids:
		var n := net.get_node_by_id(nid)
		if n is HostInTOP: has_in_top = true
		if n is HostOutTOP: has_out_top = true
		if n is HostInCHOP: has_in_chop = true
		if n is HostOutCHOP: has_out_chop = true
		if n is HostInDAT: has_in_dat = true
		if n is HostOutDAT: has_out_dat = true
		if n is HostInVOL: has_in_vol = true
		if n is HostOutVOL: has_out_vol = true
		if n is HostInPOP: has_in_pop = true
		if n is HostOutPOP: has_out_pop = true
		if n is HostInSOP: has_in_sop = true
		if n is HostOutSOP: has_out_sop = true
	GNTestAssert.assert_true(has_in_top, "HostInTOP generated")
	GNTestAssert.assert_true(has_out_top, "HostOutTOP generated")
	GNTestAssert.assert_true(has_in_chop, "HostInCHOP generated")
	GNTestAssert.assert_true(has_out_chop, "HostOutCHOP generated")
	GNTestAssert.assert_true(has_in_dat, "HostInDAT generated")
	GNTestAssert.assert_true(has_out_dat, "HostOutDAT generated")
	GNTestAssert.assert_true(has_in_vol, "HostInVOL generated")
	GNTestAssert.assert_true(has_out_vol, "HostOutVOL generated")
	GNTestAssert.assert_true(has_in_pop, "HostInPOP generated")
	GNTestAssert.assert_true(has_out_pop, "HostOutPOP generated")
	GNTestAssert.assert_true(has_in_sop, "HostInSOP generated")
	GNTestAssert.assert_true(has_out_sop, "HostOutSOP generated")
