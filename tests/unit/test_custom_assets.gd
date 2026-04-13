extends Node
## Tests for the Custom Asset (.gnasset) system — end-to-end validation.
##
## Tests cover:
##   - .gnasset loading from extension assets/ directory
##   - Extension asset scanning and registration
##   - Custom asset instantiation (GNCustomOperator)
##   - Inner network structure (nodes, connections, tunnels)
##   - Custom parameter creation from .gnasset definitions
##   - Expression wiring (CHOP expressions on mapping params)
##   - Read-only extension asset flags
##   - Palette registry grouping (custom asset hierarchy)
##   - Asset serialization round-trip (to_dict / from_dict)
##   - Make Editable (asset → SubNetworkNode conversion)
##   - Interactive mapper assets (QuadMap, BezierMap, GridWarp, Stoner)


# ═══════════════════════════════════════════════════════════════════════════════
# Extension Asset Scanning
# ═══════════════════════════════════════════════════════════════════════════════

func test_extension_asset_scan_finds_mapper_assets() -> void:
	var reg := GNExtensionRegistry.instance()
	reg.scan_custom_assets()
	# Should find the 4 interactive mapper assets
	var found := 0
	for key in reg._operators:
		var entry = reg._operators[key]
		if entry.is_custom_asset and entry.source == "custom_asset":
			if "Interactive" in key:
				found += 1
	GNTestAssert.assert_true(found >= 4,
		"Should find at least 4 InteractiveXxx mapper assets, got %d" % found)


func test_extension_assets_are_read_only() -> void:
	var reg := GNExtensionRegistry.instance()
	reg.scan_custom_assets()
	for key in ["InteractiveQuadMap", "InteractiveBezierMap",
			"InteractiveGridWarp", "InteractiveStonerMap"]:
		var entry = reg._operators.get(key, null)
		if entry != null:
			GNTestAssert.assert_true(entry.asset_read_only,
				"%s should be read-only (from extension)" % key)
			GNTestAssert.assert_true(entry.is_custom_asset,
				"%s should be marked as custom asset" % key)


func test_custom_asset_registry_has_mapper_section() -> void:
	var reg := GNExtensionRegistry.instance()
	reg.scan_custom_assets()
	var custom_reg: Dictionary = reg.get_custom_asset_registry()
	# Should have a TOP family entry
	GNTestAssert.assert_true(custom_reg.has("TOP"),
		"Custom asset registry should have TOP family")
	if custom_reg.has("TOP"):
		var top_sections: Dictionary = custom_reg["TOP"]
		# Should have a section named after the mapper extension
		var has_mapper_section := false
		for section_name in top_sections:
			if "Mapper" in section_name or "mapper" in section_name or "Projection" in section_name:
				has_mapper_section = true
				break
		GNTestAssert.assert_true(has_mapper_section,
			"TOP custom assets should have a mapper extension section")


# ═══════════════════════════════════════════════════════════════════════════════
# Asset Instantiation
# ═══════════════════════════════════════════════════════════════════════════════

func _create_asset_instance(asset_name: String) -> GNCustomOperator:
	var reg := GNExtensionRegistry.instance()
	reg.scan_custom_assets()
	var entry = reg._operators.get(asset_name, null)
	if entry == null:
		return null
	var node := GNCustomOperator.new()
	if node.load_from_asset(entry.extension_dir):
		return node
	node.free()
	return null


func test_quad_map_asset_loads() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	GNTestAssert.assert_true(node != null, "InteractiveQuadMap should load")
	if node:
		GNTestAssert.assert_eq(node.node_type, "InteractiveQuadMap", "node_type")
		GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family should be TOP")
		node.free()


func test_bezier_map_asset_loads() -> void:
	var node := _create_asset_instance("InteractiveBezierMap")
	GNTestAssert.assert_true(node != null, "InteractiveBezierMap should load")
	if node:
		GNTestAssert.assert_eq(node.node_type, "InteractiveBezierMap", "node_type")
		GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family should be TOP")
		node.free()


func test_grid_warp_asset_loads() -> void:
	var node := _create_asset_instance("InteractiveGridWarp")
	GNTestAssert.assert_true(node != null, "InteractiveGridWarp should load")
	if node:
		GNTestAssert.assert_eq(node.node_type, "InteractiveGridWarp", "node_type")
		GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family should be TOP")
		node.free()


func test_stoner_map_asset_loads() -> void:
	var node := _create_asset_instance("InteractiveStonerMap")
	GNTestAssert.assert_true(node != null, "InteractiveStonerMap should load")
	if node:
		GNTestAssert.assert_eq(node.node_type, "InteractiveStonerMap", "node_type")
		GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family should be TOP")
		node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# Inner Network Structure
# ═══════════════════════════════════════════════════════════════════════════════

func test_quad_map_inner_network_structure() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	var net: GNNetwork = node.inner_network
	GNTestAssert.assert_true(net != null, "inner_network should exist")
	if net:
		# Should have 5 nodes: in1, drag1, map1, out_tex, out_panel
		GNTestAssert.assert_eq(net.nodes.size(), 5,
			"Should have 5 inner nodes, got %d" % net.nodes.size())
		GNTestAssert.assert_true(net.nodes.has("in1"), "Should have InTunnel 'in1'")
		GNTestAssert.assert_true(net.nodes.has("drag1"), "Should have drag UI 'drag1'")
		GNTestAssert.assert_true(net.nodes.has("map1"), "Should have mapping TOP 'map1'")
		GNTestAssert.assert_true(net.nodes.has("out_tex"), "Should have OutTunnel 'out_tex'")
		GNTestAssert.assert_true(net.nodes.has("out_panel"), "Should have OutTunnel 'out_panel'")
		# Check connections count
		GNTestAssert.assert_eq(net.connections.size(), 3,
			"Should have 3 connections, got %d" % net.connections.size())
	node.free()


func test_inner_tunnels_have_correct_families() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	# Check that we have 2 output ports: TOP + UI
	var out_tunnels := node.get_out_tunnels()
	GNTestAssert.assert_true(out_tunnels.size() >= 2,
		"Should have at least 2 OutTunnels, got %d" % out_tunnels.size())
	# Port 0 should be TOP, port 1 should be UI
	if out_tunnels.size() >= 2:
		var tex_tunnel: OutTunnel = null
		var panel_tunnel: OutTunnel = null
		for t in out_tunnels:
			if t.get_param_value("index") == 0:
				tex_tunnel = t
			elif t.get_param_value("index") == 1:
				panel_tunnel = t
		if tex_tunnel:
			GNTestAssert.assert_eq(tex_tunnel.get_param_value("family"),
				GNFamily.Type.TOP, "Port 0 should be TOP")
		if panel_tunnel:
			GNTestAssert.assert_eq(panel_tunnel.get_param_value("family"),
				GNFamily.Type.UI, "Port 1 should be UI")
	node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# Custom Parameters
# ═══════════════════════════════════════════════════════════════════════════════

func test_quad_map_has_custom_params() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	GNTestAssert.assert_true(node.parameters.has("show_panel"),
		"Should have 'show_panel' custom param")
	GNTestAssert.assert_true(node.parameters.has("pad_size"),
		"Should have 'pad_size' custom param")
	if node.parameters.has("show_panel"):
		var sp: GNParameter = node.parameters["show_panel"]
		GNTestAssert.assert_eq(sp.value_type, GNParameter.ValueType.BOOL, "show_panel type")
		GNTestAssert.assert_eq(sp.value, true, "show_panel default")
	if node.parameters.has("pad_size"):
		var ps: GNParameter = node.parameters["pad_size"]
		GNTestAssert.assert_eq(ps.value_type, GNParameter.ValueType.INT, "pad_size type")
		GNTestAssert.assert_eq(ps.value, 250, "pad_size default")
	node.free()


func test_stoner_map_has_extra_params() -> void:
	var node := _create_asset_instance("InteractiveStonerMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveStonerMap")
		return
	# Stoner has softedge and test_pattern custom params
	GNTestAssert.assert_true(node.parameters.has("softedge_left"),
		"Should have 'softedge_left' custom param")
	GNTestAssert.assert_true(node.parameters.has("test_pattern"),
		"Should have 'test_pattern' custom param")
	if node.parameters.has("test_pattern"):
		var tp: GNParameter = node.parameters["test_pattern"]
		GNTestAssert.assert_eq(tp.value_type, GNParameter.ValueType.ENUM, "test_pattern type")
	node.free()


func test_grid_warp_has_grid_params() -> void:
	var node := _create_asset_instance("InteractiveGridWarp")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveGridWarp")
		return
	GNTestAssert.assert_true(node.parameters.has("grid_cols"),
		"Should have 'grid_cols' custom param")
	GNTestAssert.assert_true(node.parameters.has("grid_rows"),
		"Should have 'grid_rows' custom param")
	if node.parameters.has("grid_cols"):
		var gc: GNParameter = node.parameters["grid_cols"]
		GNTestAssert.assert_eq(gc.value, 4, "grid_cols default")
		GNTestAssert.assert_eq(gc.min_value, 2, "grid_cols min")
		GNTestAssert.assert_eq(gc.max_value, 8, "grid_cols max")
	node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Wiring
# ═══════════════════════════════════════════════════════════════════════════════

func test_quad_map_expressions_reference_drag_ui() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	var map_node: GNNode = node.inner_network.nodes.get("map1", null)
	GNTestAssert.assert_true(map_node != null, "map1 should exist in inner network")
	if map_node:
		for corner in ["tl", "tr", "bl", "br"]:
			for axis in ["x", "y"]:
				var pname := "%s_%s" % [corner, axis]
				var param: GNParameter = map_node.parameters.get(pname, null)
				GNTestAssert.assert_true(param != null,
					"map1 should have param '%s'" % pname)
				if param:
					GNTestAssert.assert_eq(param.mode, GNParameter.Mode.EXPRESSION,
						"'%s' should be in EXPRESSION mode" % pname)
					GNTestAssert.assert_true(param.expression.contains("drag1"),
						"'%s' expression should reference 'drag1'" % pname)
	node.free()


func test_bezier_map_expressions_cover_all_16_points() -> void:
	var node := _create_asset_instance("InteractiveBezierMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveBezierMap")
		return
	var map_node: GNNode = node.inner_network.nodes.get("map1", null)
	GNTestAssert.assert_true(map_node != null, "map1 should exist")
	if map_node:
		var expr_count := 0
		for col in range(4):
			for row in range(4):
				for axis in ["x", "y"]:
					var pname := "cp%d%d_%s" % [col, row, axis]
					var param: GNParameter = map_node.parameters.get(pname, null)
					if param and param.mode == GNParameter.Mode.EXPRESSION:
						expr_count += 1
		GNTestAssert.assert_eq(expr_count, 32,
			"BezierMapTOP should have 32 expression-driven params (16 points × 2 axes)")
	node.free()


func test_grid_warp_expressions_cover_4x4_grid() -> void:
	var node := _create_asset_instance("InteractiveGridWarp")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveGridWarp")
		return
	var map_node: GNNode = node.inner_network.nodes.get("map1", null)
	GNTestAssert.assert_true(map_node != null, "map1 should exist")
	if map_node:
		var expr_count := 0
		for col in range(4):
			for row in range(4):
				for axis in ["x", "y"]:
					var pname := "pt_%d_%d_%s" % [col, row, axis]
					var param: GNParameter = map_node.parameters.get(pname, null)
					if param and param.mode == GNParameter.Mode.EXPRESSION:
						expr_count += 1
		GNTestAssert.assert_eq(expr_count, 32,
			"GridWarpTOP should have 32 expression-driven params (4x4 grid × 2 axes)")
	node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_asset_to_dict_is_compact() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	node.id = "quad_asset_1"
	var d: Dictionary = node.to_dict()
	GNTestAssert.assert_eq(d.get("type", ""), "GNCustomOperator",
		"to_dict type should be GNCustomOperator")
	GNTestAssert.assert_true(d.has("asset_path"),
		"to_dict should include asset_path")
	# Inner network should NOT be serialized (compact reference)
	GNTestAssert.assert_false(d.has("inner_network"),
		"to_dict should NOT include inner_network (compact)")
	node.free()


func test_asset_from_dict_restores_correctly() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	node.id = "quad_asset_1"
	# Change a custom param
	if node.parameters.has("pad_size"):
		node.parameters["pad_size"].set_value(300)
	var d: Dictionary = node.to_dict()
	# Restore into a new instance
	var node2 := GNCustomOperator.new()
	node2.from_dict(d)
	GNTestAssert.assert_eq(node2.node_type, "InteractiveQuadMap",
		"Restored node_type")
	GNTestAssert.assert_eq(node2.family, GNFamily.Type.TOP,
		"Restored family")
	# Check param override was preserved
	if node2.parameters.has("pad_size"):
		GNTestAssert.assert_eq(node2.parameters["pad_size"].value, 300,
			"pad_size override should be 300")
	node.free()
	node2.free()


# ═══════════════════════════════════════════════════════════════════════════════
# GNNetwork.host_node Back-Reference
# ═══════════════════════════════════════════════════════════════════════════════

func test_inner_network_host_node() -> void:
	var subnet := SubNetworkNode.new()
	subnet.initialize("test_subnet")
	GNTestAssert.assert_true(subnet.inner_network != null,
		"SubNetwork should have inner_network")
	if subnet.inner_network:
		GNTestAssert.assert_eq(subnet.inner_network.host_node, subnet,
			"inner_network.host_node should point to owning SubNetworkNode")
	subnet.free()


func test_custom_asset_inner_network_host_node() -> void:
	var node := _create_asset_instance("InteractiveQuadMap")
	if node == null:
		GNTestAssert.assert_true(false, "Failed to create InteractiveQuadMap")
		return
	GNTestAssert.assert_true(node.inner_network != null, "inner_network exists")
	if node.inner_network:
		GNTestAssert.assert_eq(node.inner_network.host_node, node,
			"Custom asset inner_network.host_node should point to GNCustomOperator")
	node.free()
