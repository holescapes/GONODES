class_name GNPort
extends Resource
## Defines a typed input or output port on a GNNode.
## Ports enforce family-based type checking for connections.

## Human-readable name for this port (e.g., "texture_in", "channel_out").
@export var port_name: String = ""

## The operator family this port accepts or produces.
@export var family: GNFamily.Type = GNFamily.Type.TOP

## Port index on the node (0-based, within input or output group).
@export var index: int = 0

## True for input ports, false for output ports.
@export var is_input: bool = true

## If true, this input port accepts multiple incoming connections (e.g., Composite TOP).
## Output ports always support fan-out regardless of this setting.
@export var multi_input: bool = false


## Creates a new port with the given configuration.
static func create(p_name: String, p_family: GNFamily.Type, p_index: int,
		p_is_input: bool, p_multi_input: bool = false) -> GNPort:
	var port := GNPort.new()
	port.port_name = p_name
	port.family = p_family
	port.index = p_index
	port.is_input = p_is_input
	port.multi_input = p_multi_input
	return port


## Returns the UI color for this port based on its family.
func get_color() -> Color:
	return GNFamily.get_color(family)


## Checks whether a connection from [param source_port] to this port is type-compatible.
func can_connect_from(source_port: GNPort) -> bool:
	if source_port == null:
		return false
	# Must be connecting an output to an input
	if source_port.is_input or not is_input:
		return false
	# Must match family (bridge operators have mixed ports, which is fine — their ports
	# are declared with the correct families on each side)
	if source_port.family != family:
		return false
	return true
