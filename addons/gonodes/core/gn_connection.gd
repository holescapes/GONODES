class_name GNConnection
extends Resource
## Represents a wire between two operator ports in the node graph.
## Connections carry data from an output port to an input port.

## ID of the source GNNode.
@export var from_node: String = ""

## Output port index on the source node.
@export var from_port: int = 0

## ID of the destination GNNode.
@export var to_node: String = ""

## Input port index on the destination node.
@export var to_port: int = 0


## Creates a new connection between two node ports.
static func create(p_from_node: String, p_from_port: int,
		p_to_node: String, p_to_port: int) -> GNConnection:
	var conn := GNConnection.new()
	conn.from_node = p_from_node
	conn.from_port = p_from_port
	conn.to_node = p_to_node
	conn.to_port = p_to_port
	return conn


## Returns true if this connection matches the given endpoints.
func matches(p_from_node: String, p_from_port: int,
		p_to_node: String, p_to_port: int) -> bool:
	return (from_node == p_from_node and from_port == p_from_port
			and to_node == p_to_node and to_port == p_to_port)


## Returns a human-readable string for debugging.
func _to_string() -> String:
	return "%s[%d] → %s[%d]" % [from_node, from_port, to_node, to_port]
