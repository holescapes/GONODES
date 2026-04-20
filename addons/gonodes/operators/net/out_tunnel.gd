class_name OutTunnel
extends GNNode
## Output tunnel — pseudo-node that lives inside a sub-network.
## Bridges data from the inner graph to the parent SubNetworkNode's output port.
##
## During a sub-network cook cycle, after the inner graph finishes cooking,
## the SubNetworkNode reads this tunnel's [member cached_output] and exposes
## it as one of its own output ports.
##
## Each OutTunnel maps to one output port on the parent SubNetworkNode.
## The [member tunnel_index] determines the port ordering (0-based).
## The [member tunnel_family] sets the data type for both the tunnel's input
## port and the corresponding parent output port.

## The output port index on the parent SubNetworkNode that this tunnel feeds.
## Must be unique among all OutTunnels in the same sub-network.
var tunnel_index: int = 0

## The data family this tunnel carries (TOP, CHOP, SOP, DAT, MAT, COMP, etc.).
## Used to configure the input port and the parent node's matching output port.
var tunnel_family: int = GNFamily.Type.TOP

## Label shown on the parent node's output port.
var tunnel_label: String = "out"

## Maps dropdown indices to family IDs (populated in _init_parameters).
var _family_ids: Array[int] = []


func _init() -> void:
	node_type = "out_tunnel"
	family = GNFamily.Type.NET  # Network infrastructure — sub-network data bridge
	time_dependent = false
	# OutTunnels default to structural sinks so the inner cook engine activates
	# their upstream chains.  SubNetworkNode._cook() toggles is_sink per-tunnel
	# based on external demand (is_output_demanded) for efficient pruning.
	is_sink = true


func _init_ports() -> void:
	# One input: receives data from an inner graph operator.
	add_input("in", tunnel_family, false, "Data to send to parent output %d" % tunnel_index)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", tunnel_index, 0, 32,
		"Index", "Output port index on the parent sub-network node"))
	# Build family dropdown dynamically — only data-carrying families (port types)
	var fam_data: Array = GNFamily.get_data_families()
	_family_ids = fam_data[0]
	var fam_names: PackedStringArray = fam_data[1]
	var default_idx: int = _family_ids.find(tunnel_family)
	if default_idx < 0:
		default_idx = 0
	add_parameter(GNParameter.create_enum("family", fam_names, default_idx,
		"Family", "Data type this tunnel carries"))
	add_parameter(GNParameter.create_string("label", tunnel_label,
		"Label", "Port label shown on the parent sub-network node"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Pass through the connected input data — this becomes the parent node's
	# output on the corresponding port index.
	if inputs.size() > 0 and inputs[0] != null:
		return inputs[0]
	return null


## Rebuilds the input port to match [member tunnel_family].
## Called when the user changes the family parameter.
func _rebuild_input_port() -> void:
	input_ports.clear()
	add_input("in", tunnel_family, false, "Data to send to parent output %d" % tunnel_index)
	ports_changed.emit(id)


## Applies parameter changes — updates [member tunnel_index], [member tunnel_family],
## and [member tunnel_label], and rebuilds the input port if the family changed.
func _on_parameter_changed(param_name: String, new_value: Variant) -> void:
	super._on_parameter_changed(param_name, new_value)
	match param_name:
		"index":
			tunnel_index = int(new_value)
		"family":
			var idx := int(new_value)
			var new_family: int = _family_ids[idx] if idx >= 0 and idx < _family_ids.size() else GNFamily.Type.TOP
			if new_family != tunnel_family:
				tunnel_family = new_family
				_rebuild_input_port()
		"label":
			tunnel_label = str(new_value)


## Serialization — include tunnel metadata.
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tunnel_index"] = tunnel_index
	d["tunnel_family"] = int(tunnel_family)
	d["tunnel_label"] = tunnel_label
	return d


## Deserialization — restore tunnel metadata.
func from_dict(d: Dictionary) -> void:
	if d.has("tunnel_index"):
		tunnel_index = int(d["tunnel_index"])
	if d.has("tunnel_family"):
		tunnel_family = int(d["tunnel_family"]) as GNFamily.Type
	if d.has("tunnel_label"):
		tunnel_label = str(d["tunnel_label"])
	# Rebuild input port to match restored family before super restores params
	input_ports.clear()
	add_input("in", tunnel_family, false, "Data to send to parent output %d" % tunnel_index)
	super.from_dict(d)


## Preview: show tunnel direction and index.
func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = "OUT [%d] %s" % [
			tunnel_index, GNFamily.get_family_name(tunnel_family)]
