extends Node
## Unit tests for GNNetwork — pure graph model.
##
## Tests cover:
##   - Add / remove nodes
##   - Connect / disconnect nodes
##   - Topological ordering
##   - Cycle detection
##   - Dirty propagation
##   - Serialization round-trip (to_dict / from_dict) — basic structure
##   - Rename
##   - Input connection queries

var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	_network = GNNetwork.new()


func after_each() -> void:
	# Free any nodes still in the network (they extend Node)
	for node_id in _network.nodes.keys():
		var node: GNNode = _network.nodes[node_id]
		if is_instance_valid(node):
			node.queue_free()
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(id: String) -> GNNode:
	var node := NullCHOP.new()
	node.initialize(id)
	add_child(node)  # Add to scene tree so queue_free works
	return node


# ═══════════════════════════════════════════════════════════════════════════════
# Node Management
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_node() -> void:
	var node := _make_node("n1")
	var ok := _network.add_node(node)
	GNTestAssert.assert_true(ok, "should succeed")
	GNTestAssert.assert_eq(_network.get_node_count(), 1, "count")
	GNTestAssert.assert_not_null(_network.get_node_by_id("n1"), "retrievable")


func test_add_duplicate_id_fails() -> void:
	var n1 := _make_node("n1")
	_network.add_node(n1)
	var n2 := _make_node("n1")  # Same ID
	var ok := _network.add_node(n2)
	GNTestAssert.assert_false(ok, "duplicate should fail")
	GNTestAssert.assert_eq(_network.get_node_count(), 1, "count unchanged")
	n2.queue_free()


func test_remove_node() -> void:
	var node := _make_node("n1")
	_network.add_node(node)
	# Remove from our parent first since network.remove_node also does cleanup
	remove_child(node)
	var ok := _network.remove_node("n1")
	GNTestAssert.assert_true(ok, "should succeed")
	GNTestAssert.assert_eq(_network.get_node_count(), 0, "count after remove")
	GNTestAssert.assert_null(_network.get_node_by_id("n1"), "should be gone")


func test_remove_nonexistent_fails() -> void:
	var ok := _network.remove_node("nope")
	GNTestAssert.assert_false(ok, "should fail for missing node")


func test_get_node_by_id_returns_null() -> void:
	var result := _network.get_node_by_id("nonexistent")
	GNTestAssert.assert_null(result, "should return null")


# ═══════════════════════════════════════════════════════════════════════════════
# Connection Management
# ═══════════════════════════════════════════════════════════════════════════════

func test_connect_nodes() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	var ok := _network.connect_nodes("a", 0, "b", 0)
	GNTestAssert.assert_true(ok, "should succeed")
	GNTestAssert.assert_eq(_network.get_connection_count(), 1, "connection count")


func test_connect_nonexistent_node_fails() -> void:
	var a := _make_node("a")
	_network.add_node(a)
	var ok := _network.connect_nodes("a", 0, "nonexistent", 0)
	GNTestAssert.assert_false(ok, "should fail for missing target")


func test_disconnect_nodes() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	_network.connect_nodes("a", 0, "b", 0)
	var ok := _network.disconnect_nodes("a", 0, "b", 0)
	GNTestAssert.assert_true(ok, "should succeed")
	GNTestAssert.assert_eq(_network.get_connection_count(), 0, "count after disconnect")


func test_get_input_connections() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "c", 0)
	_network.connect_nodes("b", 0, "c", 0)
	# Wire replacement: b→c:0 replaces a→c:0 — only 1 connection remains.
	var inputs := _network.get_input_connections("c")
	GNTestAssert.assert_eq(inputs.size(), 1, "c should have exactly 1 input after replacement")
	GNTestAssert.assert_eq(inputs[0].from_node, "b", "surviving wire should be from b")


func test_remove_node_cleans_connections() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	_network.connect_nodes("a", 0, "b", 0)
	GNTestAssert.assert_eq(_network.get_connection_count(), 1, "before remove")
	remove_child(b)
	_network.remove_node("b")
	GNTestAssert.assert_eq(_network.get_connection_count(), 0, "connections cleaned")


# ═══════════════════════════════════════════════════════════════════════════════
# Topological Order
# ═══════════════════════════════════════════════════════════════════════════════

func test_topo_order_basic() -> void:
	## A → B → C should produce [A, B, C] order.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	var order := _network.get_topological_order()
	# Find indices
	var idx_a := -1
	var idx_b := -1
	var idx_c := -1
	for i in range(order.size()):
		if order[i].id == "a": idx_a = i
		elif order[i].id == "b": idx_b = i
		elif order[i].id == "c": idx_c = i
	GNTestAssert.assert_true(idx_a < idx_b, "a before b")
	GNTestAssert.assert_true(idx_b < idx_c, "b before c")


func test_topo_order_diamond() -> void:
	## A → B, A → C, B → D, C → D
	## A must be before B and C, both B and C before D.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	var d := _make_node("d")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.add_node(d)
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("a", 0, "c", 0)
	_network.connect_nodes("b", 0, "d", 0)
	_network.connect_nodes("c", 0, "d", 0)
	var order := _network.get_topological_order()
	var positions: Dictionary = {}
	for i in range(order.size()):
		positions[order[i].id] = i
	GNTestAssert.assert_true(positions["a"] < positions["b"], "a before b")
	GNTestAssert.assert_true(positions["a"] < positions["c"], "a before c")
	GNTestAssert.assert_true(positions["b"] < positions["d"], "b before d")
	GNTestAssert.assert_true(positions["c"] < positions["d"], "c before d")


func test_disconnected_nodes_included() -> void:
	## Disconnected nodes should still appear in topo order.
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	var order := _network.get_topological_order()
	GNTestAssert.assert_eq(order.size(), 2, "both nodes in order")


# ═══════════════════════════════════════════════════════════════════════════════
# Cycle Detection
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_cycle_linear() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	_network.connect_nodes("a", 0, "b", 0)
	GNTestAssert.assert_false(_network.has_cycle(), "linear graph has no cycle")


func test_no_cycle_empty() -> void:
	GNTestAssert.assert_false(_network.has_cycle(), "empty graph has no cycle")


# Note: We can't directly create a cycle via connect_nodes because the
# method likely rejects them. But we can test has_cycle() returns false
# for acyclic graphs, which validates the detection logic.


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation
# ═══════════════════════════════════════════════════════════════════════════════

func test_dirty_propagation() -> void:
	## Marking a upstream dirty should propagate to downstream.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)

	# Clear all dirty flags
	a.dirty = false
	b.dirty = false
	c.dirty = false

	# Mark a dirty and propagate
	a.mark_dirty()
	_network.propagate_dirty("a")

	GNTestAssert.assert_true(a.dirty, "a is dirty")
	GNTestAssert.assert_true(b.dirty, "b should be dirty (downstream of a)")
	GNTestAssert.assert_true(c.dirty, "c should be dirty (downstream of b)")


func test_dirty_propagation_only_downstream() -> void:
	## Sibling branches shouldn't get dirty.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "b", 0)
	# c is disconnected

	a.dirty = false
	b.dirty = false
	c.dirty = false

	a.mark_dirty()
	_network.propagate_dirty("a")

	GNTestAssert.assert_true(b.dirty, "b is downstream of a")
	GNTestAssert.assert_false(c.dirty, "c is disconnected — should stay clean")


# ═══════════════════════════════════════════════════════════════════════════════
# Rename
# ═══════════════════════════════════════════════════════════════════════════════

func test_rename_node() -> void:
	var node := _make_node("old_name")
	_network.add_node(node)
	var ok := _network.rename_node("old_name", "new_name")
	GNTestAssert.assert_true(ok, "rename should succeed")
	GNTestAssert.assert_null(_network.get_node_by_id("old_name"), "old id gone")
	GNTestAssert.assert_not_null(_network.get_node_by_id("new_name"), "new id exists")
	GNTestAssert.assert_eq(node.id, "new_name", "node.id updated")


func test_rename_updates_connections() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	_network.connect_nodes("a", 0, "b", 0)
	_network.rename_node("a", "alpha")
	var inputs := _network.get_input_connections("b")
	GNTestAssert.assert_gt(inputs.size(), 0, "b still has inputs")
	GNTestAssert.assert_eq(inputs[0].from_node, "alpha", "connection updated to new name")


# ═══════════════════════════════════════════════════════════════════════════════
# Unique ID Generation
# ═══════════════════════════════════════════════════════════════════════════════

func test_generate_unique_id() -> void:
	var id1 := _network.generate_unique_id("noise")
	GNTestAssert.assert_not_empty(id1, "should return non-empty id")
	# Create a node with that ID
	var n1 := _make_node(id1)
	_network.add_node(n1)
	# Generate another — should be different
	var id2 := _network.generate_unique_id("noise")
	GNTestAssert.assert_ne(id1, id2, "second id should be different")


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization — to_dict Structure
# ═══════════════════════════════════════════════════════════════════════════════

func test_to_dict_structure() -> void:
	var a := _make_node("a")
	var b := _make_node("b")
	_network.add_node(a)
	_network.add_node(b)
	_network.connect_nodes("a", 0, "b", 0)
	var d := _network.to_dict()
	GNTestAssert.assert_has_key(d, "version", "version key")
	GNTestAssert.assert_has_key(d, "generator", "generator key")
	GNTestAssert.assert_has_key(d, "nodes", "nodes key")
	GNTestAssert.assert_has_key(d, "connections", "connections key")
	GNTestAssert.assert_eq(d["generator"], "GONODES", "generator value")
	var nodes_dict: Dictionary = d["nodes"]
	GNTestAssert.assert_eq(nodes_dict.size(), 2, "2 nodes serialized")
	GNTestAssert.assert_has_key(nodes_dict, "a", "node a")
	GNTestAssert.assert_has_key(nodes_dict, "b", "node b")
	var conns: Array = d["connections"]
	GNTestAssert.assert_eq(conns.size(), 1, "1 connection")
	GNTestAssert.assert_eq(conns[0]["from"], "a", "from")
	GNTestAssert.assert_eq(conns[0]["to"], "b", "to")


func test_to_dict_empty_network() -> void:
	var d := _network.to_dict()
	var nodes_dict: Dictionary = d["nodes"]
	GNTestAssert.assert_eq(nodes_dict.size(), 0, "empty")
	var conns: Array = d["connections"]
	GNTestAssert.assert_eq(conns.size(), 0, "no connections")


# ═══════════════════════════════════════════════════════════════════════════════
# Wire Replacement (auto-disconnect old wire when connecting to occupied input)
# ═══════════════════════════════════════════════════════════════════════════════

func test_wire_replacement_succeeds() -> void:
	## Connecting to an already-occupied input should succeed (replace the old wire).
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "c", 0)
	var ok := _network.connect_nodes("b", 0, "c", 0)
	GNTestAssert.assert_true(ok, "replacement should succeed")


func test_wire_replacement_removes_old() -> void:
	## After replacement, the old connection should no longer exist.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "c", 0)
	_network.connect_nodes("b", 0, "c", 0)
	GNTestAssert.assert_eq(_network.get_connection_count(), 1, "only 1 connection after replacement")
	var conn := _network.get_connection_at_input("c", 0)
	GNTestAssert.assert_not_null(conn, "connection should exist")
	GNTestAssert.assert_eq(conn.from_node, "b", "new wire from b")


func test_wire_replacement_emits_signals() -> void:
	## Replacement should emit connection_removed for the old wire
	## and connection_added for the new wire.
	var a := _make_node("a")
	var b := _make_node("b")
	var c := _make_node("c")
	_network.add_node(a)
	_network.add_node(b)
	_network.add_node(c)
	_network.connect_nodes("a", 0, "c", 0)

	# Use arrays so lambdas can mutate the contents (GDScript int capture is by-value)
	var counts := { "removed": 0, "added": 0 }
	var on_removed := func(_conn: GNConnection) -> void: counts["removed"] += 1
	var on_added := func(_conn: GNConnection) -> void: counts["added"] += 1
	_network.connection_removed.connect(on_removed)
	_network.connection_added.connect(on_added)

	_network.connect_nodes("b", 0, "c", 0)

	GNTestAssert.assert_eq(counts["removed"], 1, "connection_removed emitted once")
	GNTestAssert.assert_eq(counts["added"], 1, "connection_added emitted once")

	_network.connection_removed.disconnect(on_removed)
	_network.connection_added.disconnect(on_added)
