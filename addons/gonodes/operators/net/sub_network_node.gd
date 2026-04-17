class_name SubNetworkNode
extends GNNode
## A sub-network operator — contains a nested GNNetwork with its own nodes
## and connections.  The inner graph is isolated from the parent graph; data
## flows in/out through InTunnel and OutTunnel pseudo-nodes.
##
## Port Synchronization:
##   The SubNetworkNode's external ports are derived from the InTunnel and
##   OutTunnel nodes inside its [member inner_network].  Whenever tunnels are
##   added, removed, or reconfigured, [method sync_ports_from_tunnels] rebuilds
##   the external port list.
##
## Cooking:
##   When the parent cook engine reaches this node, [method _cook] is called.
##   It injects upstream data into InTunnels, runs a full inner cook cycle
##   (using the [member _inner_cook_engine]), and reads OutTunnel results
##   as this node's output.
##
## Serialization:
##   [method to_dict] embeds the entire inner network as a nested dict.
##   [method from_dict] restores it, including all inner nodes and connections.

# ─── Inner Network ─────────────────────────────────────────────────────────────

## The nested graph model owned by this sub-network.
var inner_network: GNNetwork = null

## Cook engine for the inner graph.  Lives as a child Node of this
## SubNetworkNode, so inner TOP viewports are in the scene tree.
var _inner_cook_engine: GNCookEngine = null

## Cached sorted InTunnel references (by tunnel_index) for fast injection.
var _in_tunnels: Array[InTunnel] = []

## Cached sorted OutTunnel references (by tunnel_index) for fast extraction.
var _out_tunnels: Array[OutTunnel] = []

## When true, the external ports need to be rebuilt from tunnel state.
var _ports_dirty: bool = true


func _init() -> void:
	node_type = "sub_network"
	family = GNFamily.Type.NET


func _init_ports() -> void:
	# Ports are built dynamically from inner tunnels.
	# Start with no ports — sync_ports_from_tunnels() will add them.
	pass


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Subnet",
		"Label", "Display label for this sub-network"))


## Override initialize to also set up the inner network and cook engine.
func initialize(p_id: String) -> void:
	super.initialize(p_id)
	_ensure_inner_network()


# ═══════════════════════════════════════════════════════════════════════════════
# Inner Network Management
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the inner network and cook engine if they don't exist yet.
func _ensure_inner_network() -> void:
	if inner_network == null:
		inner_network = GNNetwork.new()
		inner_network.host_node = self
	if _inner_cook_engine == null:
		_inner_cook_engine = GNCookEngine.new()
		_inner_cook_engine.name = "InnerCookEngine"
		_inner_cook_engine.network = inner_network
		_inner_cook_engine.cooking_enabled = false  # Only cook when parent triggers
		add_child(_inner_cook_engine)
	# Wire inner network signals so we know when tunnels change
	if not inner_network.node_added.is_connected(_on_inner_node_added):
		inner_network.node_added.connect(_on_inner_node_added)
	if not inner_network.node_removed.is_connected(_on_inner_node_removed):
		inner_network.node_removed.connect(_on_inner_node_removed)
	if not inner_network.graph_changed.is_connected(_on_inner_graph_changed):
		inner_network.graph_changed.connect(_on_inner_graph_changed)


## Returns all InTunnel nodes in the inner network, sorted by tunnel_index.
func get_in_tunnels() -> Array[InTunnel]:
	var tunnels: Array[InTunnel] = []
	for node_id in inner_network.nodes:
		var node: GNNode = inner_network.nodes[node_id]
		if node is InTunnel:
			tunnels.append(node as InTunnel)
	tunnels.sort_custom(func(a: InTunnel, b: InTunnel) -> bool:
		return a.tunnel_index < b.tunnel_index)
	return tunnels


## Returns all OutTunnel nodes in the inner network, sorted by tunnel_index.
func get_out_tunnels() -> Array[OutTunnel]:
	var tunnels: Array[OutTunnel] = []
	for node_id in inner_network.nodes:
		var node: GNNode = inner_network.nodes[node_id]
		if node is OutTunnel:
			tunnels.append(node as OutTunnel)
	tunnels.sort_custom(func(a: OutTunnel, b: OutTunnel) -> bool:
		return a.tunnel_index < b.tunnel_index)
	return tunnels


## Rebuilds external input/output ports from InTunnel and OutTunnel nodes.
## Called when tunnels are added, removed, or reconfigured.
func sync_ports_from_tunnels() -> void:
	_in_tunnels = get_in_tunnels()
	_out_tunnels = get_out_tunnels()

	# Rebuild input ports from InTunnels
	input_ports.clear()
	for tunnel in _in_tunnels:
		add_input(tunnel.tunnel_label, tunnel.tunnel_family, false,
			"Sub-network input %d (%s)" % [tunnel.tunnel_index,
				GNFamily.get_family_name(tunnel.tunnel_family)])

	# Rebuild output ports from OutTunnels
	output_ports.clear()
	for tunnel in _out_tunnels:
		add_output(tunnel.tunnel_label, tunnel.tunnel_family,
			"Sub-network output %d (%s)" % [tunnel.tunnel_index,
				GNFamily.get_family_name(tunnel.tunnel_family)])

	_ports_dirty = false
	ports_changed.emit(id)
	GNLogger.info("SubNetwork", "'%s' ports synced: %d in, %d out" % [
		id, input_ports.size(), output_ports.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	if inner_network == null or _inner_cook_engine == null:
		return null

	# Rebuild ports / tunnel caches if needed
	if _ports_dirty:
		sync_ports_from_tunnels()

	# Step 1: Inject upstream data into InTunnels
	for i in range(_in_tunnels.size()):
		var tunnel: InTunnel = _in_tunnels[i]
		if i < inputs.size():
			tunnel.cached_output = inputs[i]
		else:
			tunnel.cached_output = null
		tunnel.cook_valid = tunnel.cached_output != null
		tunnel.clear_dirty()

	# Step 2: Mark all inner nodes that depend on InTunnels as dirty
	for tunnel in _in_tunnels:
		tunnel.mark_dirty()

	# Step 3: Propagate timing context to inner cook engine
	_inner_cook_engine.elapsed_time = elapsed_time
	_inner_cook_engine.current_delta = current_delta
	_inner_cook_engine.frame_count = current_frame
	# Ensure NRT mode matches parent
	_inner_cook_engine.non_realtime = false  # Parent handles timing

	# Step 3b: Wire parent engine for hierarchical op() resolution
	#   The parent cook engine is our own parent in the scene tree.
	if _inner_cook_engine.parent_engine == null:
		var parent_ce := _find_parent_cook_engine()
		if parent_ce:
			_inner_cook_engine.parent_engine = parent_ce

	# Step 4: Cook the inner graph (one cycle)
	_inner_cook_engine.cook_frame(current_delta)

	# Step 5: Read results from OutTunnels
	#   If there's exactly one OutTunnel, return its data directly.
	#   If there are multiple, return the first OutTunnel's data.
	#   (Multi-output sub-networks are handled by the gather_inputs override
	#    in the cook engine — we store all outputs and the engine reads them.)
	if _out_tunnels.is_empty():
		return null

	# Store all outputs for multi-output access
	# The primary output is the first OutTunnel's data
	var primary_output: GNData = null
	for tunnel in _out_tunnels:
		if tunnel.cached_output != null:
			if primary_output == null:
				primary_output = tunnel.cached_output
	return primary_output


## Override base class multi-output routing.  The cook engine calls this
## instead of reading cached_output directly, allowing each output port
## to carry data from a different OutTunnel.
func get_output_data(port_index: int) -> GNData:
	if port_index < 0 or port_index >= _out_tunnels.size():
		return cached_output  # Fallback to primary
	return _out_tunnels[port_index].cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# Hierarchy Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Walks up the scene tree to find the CookEngine that owns *this* SubNetworkNode.
## SubNetworkNode is adopted as a child of its parent CookEngine, so we look for
## the nearest GNCookEngine ancestor (skipping _inner_cook_engine since that's our child).
func _find_parent_cook_engine() -> GNCookEngine:
	var p: Node = get_parent()
	while p != null:
		if p is GNCookEngine and p != _inner_cook_engine:
			return p as GNCookEngine
		p = p.get_parent()
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Inner Network Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_inner_node_added(node_id: String) -> void:
	var node: GNNode = inner_network.nodes.get(node_id, null)
	if node == null:
		return
	# Propagate inner node dirtiness to the SubNetworkNode so the outer
	# cook engine re-cooks us when inner UI widgets (drag pads, sliders)
	# are interacted with at runtime.
	if not node.node_dirty.is_connected(_on_inner_node_dirty):
		node.node_dirty.connect(_on_inner_node_dirty)
	if node is InTunnel or node is OutTunnel:
		# Listen for tunnel parameter changes (family, index, label)
		if not node.parameter_changed.is_connected(_on_tunnel_param_changed):
			node.parameter_changed.connect(_on_tunnel_param_changed)
		# Eagerly rebuild external ports so they are current before any
		# view rebuild (e.g. when diving back out).
		sync_ports_from_tunnels()
		mark_dirty()


func _on_inner_node_removed(node_id: String) -> void:
	# Can't check type since the node is already removed — just rebuild ports.
	sync_ports_from_tunnels()
	mark_dirty()


func _on_inner_graph_changed() -> void:
	mark_dirty()


func _on_tunnel_param_changed(_node_id: String, param_name: String) -> void:
	if param_name in ["index", "family", "label"]:
		sync_ports_from_tunnels()
		mark_dirty()


## Propagates inner node dirtiness outward — when an inner widget is
## interacted with (drag pad, slider), the SubNetworkNode must re-cook
## so the inner cook engine runs and the outputs update.
func _on_inner_node_dirty(_inner_node_id: String) -> void:
	if not dirty:
		GNLogger.debug("SubNetwork", "'%s' inner node '%s' dirty → marking self dirty" % [id, _inner_node_id])
	mark_dirty()


## Connects node_dirty signals for all existing inner nodes.
## Called after from_dict() restores a saved inner network.
func _connect_inner_dirty_signals() -> void:
	if inner_network == null:
		return
	var count := 0
	for node_id in inner_network.nodes:
		var node: GNNode = inner_network.nodes[node_id]
		if not node.node_dirty.is_connected(_on_inner_node_dirty):
			node.node_dirty.connect(_on_inner_node_dirty)
			count += 1
	GNLogger.info("SubNetwork", "'%s' connected dirty signals for %d inner nodes" % [id, count])


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var d := super.to_dict()
	# Embed the inner network as a nested dictionary
	if inner_network != null:
		d["inner_network"] = inner_network.to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	# Restore inner network from nested dictionary
	if d.has("inner_network"):
		_ensure_inner_network()
		inner_network.from_dict(d["inner_network"])
		_ports_dirty = true
		sync_ports_from_tunnels()
		# Connect dirty-propagation for all inner nodes loaded from the patch.
		# _on_inner_node_added only fires for nodes added at runtime,
		# so deserialized nodes need explicit hookup.
		_connect_inner_dirty_signals()


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

func update_preview_control(control: Control) -> void:
	if control is Label:
		var inner_count: int = inner_network.get_node_count() if inner_network else 0
		var lbl: String = get_param_value("label")
		(control as Label).text = "%s\n%d nodes" % [lbl, inner_count]
