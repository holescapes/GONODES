class_name OscInDAT
extends GNDatBase
## Receives OSC messages on a UDP port and logs them as table rows.
## Each incoming message becomes a row with columns:
##   address | type_tags | arg0 | arg1 | arg2 | arg3 | timestamp
##
## This is the raw-message companion to OscInCHOP (which maps values to channels).
## Useful for debugging, triggering logic, or reading string/blob arguments.

# ─── Networking ────────────────────────────────────────────────────────────────

var _udp: PacketPeerUDP = null
var _bound_port: int = -1

## Ring buffer of received messages as table rows.
var _messages: Array[PackedStringArray] = []
var _max_messages: int = 100


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "osc_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "OSC messages table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("port", 9000, 1, 65535, "Port",
		"UDP port to listen on"))
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000, "Max Rows",
		"Maximum stored messages (ring buffer)"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable the OSC listener"))
	add_parameter(GNParameter.create_string("address_filter", "", "Filter",
		"Only accept addresses matching this prefix (empty = all)"))
	add_parameter(GNParameter.create_bool("clear", false, "Clear",
		"Pulse: clear all stored messages"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var port: int = get_param_value("port")
	var addr_filter: String = get_param_value("address_filter")
	_max_messages = get_param_value("max_rows")

	# Handle clear pulse
	if get_param_value("clear"):
		_messages.clear()
		set_param_value("clear", false)

	# Bind / rebind UDP socket
	if active:
		_ensure_udp(port)
	else:
		_close_udp()

	# Poll incoming packets
	if _udp != null:
		var packets_read: int = 0
		while _udp.get_available_packet_count() > 0 and packets_read < 256:
			var pkt: PackedByteArray = _udp.get_packet()
			packets_read += 1
			var osc_messages: Array[GNOscParser.OscMessage] = GNOscParser.decode_all(pkt)
			for msg in osc_messages:
				if not addr_filter.is_empty() and not msg.address.begins_with(addr_filter):
					continue
				_push_message(msg)

	# Build output table
	var out: GNTableData = _prepare_table()
	out.is_table = true
	out.has_header = true
	out.set_headers(PackedStringArray(["address", "types", "arg0", "arg1", "arg2", "arg3", "timestamp"]))

	for row in _messages:
		out.append_row(row)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Message Processing
# ═══════════════════════════════════════════════════════════════════════════════

func _push_message(msg: GNOscParser.OscMessage) -> void:
	var row := PackedStringArray()
	row.append(msg.address)
	row.append(msg.type_tags)
	# Up to 4 argument columns
	for i in range(4):
		if i < msg.args.size():
			row.append(str(msg.args[i]))
		else:
			row.append("")
	row.append("%.3f" % elapsed_time)
	_messages.append(row)
	# Ring buffer trim
	while _messages.size() > _max_messages:
		_messages.pop_front()
	mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# UDP Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_udp(port: int) -> void:
	if _udp != null and _bound_port == port:
		return
	_close_udp()
	_udp = PacketPeerUDP.new()
	var err: Error = _udp.bind(port)
	if err != OK:
		push_warning("OscInDAT: failed to bind UDP port %d — error %s" % [port, error_string(err)])
		_udp = null
		_bound_port = -1
		return
	_bound_port = port
	GNLogger.info("OscInDAT", "Listening on UDP port %d" % port)


func _close_udp() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
		_bound_port = -1


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_udp()
