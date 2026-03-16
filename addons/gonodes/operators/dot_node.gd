class_name DotNode
extends GNNode
## Wire routing point — pure pass-through, any family.
##
## Dot nodes are visual-only helpers for organizing wires in complex
## networks.  They accept one connection and forward the data unchanged.
## The dot automatically adopts the family of whatever is connected to it.
##
## TouchDesigner equivalent: Dot / Wire Bend Point.


func _init() -> void:
	node_type = "dot"
	node_description = "Wire routing point — pass-through for any data type."
	# Dot adapts to connected family; default to CHOP
	family = GNFamily.Type.CHOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Any data input")
	add_output("out", GNFamily.Type.CHOP, "Same data (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] != null:
		return inputs[0]
	return null


## Override to accept connections from any family (not just the port's family).
func can_accept_connection(_from_family: GNFamily.Type, _to_port: int) -> bool:
	return true


## When a connection is made, adapt the dot's family and port types to match.
func adapt_to_family(new_family: GNFamily.Type) -> void:
	if family == new_family:
		return
	family = new_family
	if input_ports.size() > 0:
		input_ports[0].family = new_family
	if output_ports.size() > 0:
		output_ports[0].family = new_family
	ports_changed.emit(id)
