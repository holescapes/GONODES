class_name OscInDAT
extends GNDatBase
## Receives OSC messages and stores them in a table.
## Stub for future OSC integration — currently generates placeholder data.
## When OSC is implemented, this will use Godot's UDP networking.

var _messages: Array[PackedStringArray] = []
var _max_messages: int = 100


func _init() -> void:
	node_type = "oscin"
	time_dependent = true
	node_description = "Receive OSC messages into a table (stub)."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "OSC messages table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("port", 9000, 1, 65535, "Port", "UDP listen port"))
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000, "Max Rows", "Maximum stored messages"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable OSC listener"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()
	_cached_table.is_table = true
	_cached_table.has_header = true
	_cached_table.set_headers(PackedStringArray(["address", "arg0", "arg1", "arg2", "timestamp"]))

	_max_messages = get_param_value("max_rows")

	# TODO: Replace with actual UDP/OSC listener when networking is implemented.
	# For now, output the stored messages buffer (populated externally or by future OSC code).
	for msg in _messages:
		_cached_table.append_row(msg)

	return _cached_table


## Public API for pushing OSC messages (called by future OSC integration).
func push_message(address: String, args: Array) -> void:
	var row := PackedStringArray([address])
	for i in range(3):
		row.append(str(args[i]) if i < args.size() else "")
	row.append("%.3f" % elapsed_time)
	_messages.append(row)
	if _messages.size() > _max_messages:
		_messages.pop_front()
	mark_dirty()
