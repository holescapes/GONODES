class_name InTunnel
extends GNNode
## Input tunnel — pseudo-node that lives inside a sub-network.
## Bridges data from the parent SubNetworkNode's input port into the inner graph.
##
## During a sub-network cook cycle, the SubNetworkNode injects the upstream
## data into this tunnel's [member cached_output] before the inner graph cooks.
## Inner operators connected to this tunnel's output see it as a normal upstream
## node with valid cached data.
##
## Each InTunnel maps to one input port on the parent SubNetworkNode.
## The [member tunnel_index] determines the port ordering (0-based).
## The [member tunnel_family] sets the data type for both the tunnel's output
## port and the corresponding parent port.

## The input port index on the parent SubNetworkNode that feeds this tunnel.
## Must be unique among all InTunnels in the same sub-network.
var tunnel_index: int = 0

## The data family this tunnel carries (TOP, CHOP, SOP, DAT, MAT, COMP, etc.).
## Used to configure the output port and the parent node's matching input port.
var tunnel_family: int = GNFamily.Type.TOP

## Label shown on the parent node's input port.
var tunnel_label: String = "in"

## Maps dropdown indices to family IDs (populated in _init_parameters).
var _family_ids: Array[int] = []


func _init() -> void:
	node_type = "in_tunnel"
	family = GNFamily.Type.COMP  # Tunnels are structural — live in COMP family
	# Tunnels are never time-dependent on their own; they are written to externally.
	time_dependent = false


func _init_ports() -> void:
	# One output: provides injected data to inner graph operators.
	add_output("out", tunnel_family, "Data from parent input %d" % tunnel_index)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", tunnel_index, 0, 32,
		"Index", "Input port index on the parent sub-network node"))
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


func _cook(_inputs: Array[GNData]) -> GNData:
	# The SubNetworkNode injects data into cached_output before cooking the
	# inner graph.  _cook() simply returns whatever was injected.
	# If nothing was injected, cached_output is already null from the last cycle.
	return cached_output


## Rebuilds the output port to match [member tunnel_family].
## Called when the user changes the family parameter.
func _rebuild_output_port() -> void:
	output_ports.clear()
	add_output("out", tunnel_family, "Data from parent input %d" % tunnel_index)
	ports_changed.emit(id)


## Applies parameter changes — updates [member tunnel_index], [member tunnel_family],
## and [member tunnel_label], and rebuilds the output port if the family changed.
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
				_rebuild_output_port()
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
	# Rebuild output port to match restored family before super restores params
	output_ports.clear()
	add_output("out", tunnel_family, "Data from parent input %d" % tunnel_index)
	super.from_dict(d)


## Preview: show tunnel direction and index.
func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = "IN [%d] %s" % [
			tunnel_index, GNFamily.get_family_name(tunnel_family)]
