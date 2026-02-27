class_name OscOutCHOP
extends GNChopBase
## Sends CHOP channel values as OSC messages over UDP.
##
## Each channel becomes an OSC message:
##   address = prefix + "/" + channel_name  (e.g. "/gonodes/tx")
##   args    = [float value]
##
## Alternatively, set "bundle" mode to send all channels in a single OSC bundle.
## The node is a sink (is_sink = true) — it keeps its upstream chain alive.

# ─── Networking ────────────────────────────────────────────────────────────────

var _udp: PacketPeerUDP = null
var _current_host: String = ""
var _current_port: int = -1

## Send mode: individual messages per channel vs. one bundle.
enum SendMode { INDIVIDUAL, BUNDLE }


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "oscout"
	time_dependent = true
	is_sink = true
	node_description = "Send CHOP channels as OSC messages over UDP."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Channel data to send")
	add_output("out", GNFamily.Type.CHOP, "Pass-through of input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("host", "127.0.0.1", "Host",
		"Target host address (IP or hostname)"))
	add_parameter(GNParameter.create_int("port", 9001, 1, 65535, "Port",
		"Target UDP port"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable sending"))
	add_parameter(GNParameter.create_string("prefix", "/gonodes", "Prefix",
		"OSC address prefix (prepended to channel name)"))
	add_parameter(GNParameter.create_enum("send_mode",
		PackedStringArray(["Individual", "Bundle"]), 0, "Mode",
		"Send each channel as a separate message, or all in one bundle"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var chop: GNChannelData = _get_input_chop(inputs, 0)
	if chop == null:
		_close_udp()
		return _prepare_output()

	var active: bool = get_param_value("active")
	if not active:
		_close_udp()
		# Pass through input even when inactive
		_cached_channel_data = chop
		return chop

	var host: String = get_param_value("host")
	var port: int = get_param_value("port")
	var prefix: String = get_param_value("prefix")
	var mode: int = get_param_value("send_mode")

	_ensure_udp(host, port)

	if _udp != null:
		var names: PackedStringArray = chop.get_channel_names()

		if mode == SendMode.BUNDLE:
			_send_bundle(chop, names, prefix)
		else:
			_send_individual(chop, names, prefix)

	# Pass through input
	_cached_channel_data = chop
	return chop


# ═══════════════════════════════════════════════════════════════════════════════
# Sending
# ═══════════════════════════════════════════════════════════════════════════════

func _send_individual(chop: GNChannelData, names: PackedStringArray, prefix: String) -> void:
	for ch_name in names:
		var addr: String = prefix + "/" + ch_name
		var value: float = chop.get_value(ch_name, -1)
		var pkt: PackedByteArray = GNOscParser.encode(addr, [value])
		_udp.put_packet(pkt)


func _send_bundle(chop: GNChannelData, names: PackedStringArray, prefix: String) -> void:
	var messages: Array[PackedByteArray] = []
	for ch_name in names:
		var addr: String = prefix + "/" + ch_name
		var value: float = chop.get_value(ch_name, -1)
		messages.append(GNOscParser.encode(addr, [value]))
	var bundle: PackedByteArray = GNOscParser.encode_bundle(messages)
	_udp.put_packet(bundle)


# ═══════════════════════════════════════════════════════════════════════════════
# UDP Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_udp(host: String, port: int) -> void:
	if _udp != null and _current_host == host and _current_port == port:
		return
	_close_udp()
	_udp = PacketPeerUDP.new()
	_udp.set_dest_address(host, port)
	_current_host = host
	_current_port = port
	GNLogger.info("OscOutCHOP", "Sending to %s:%d" % [host, port])


func _close_udp() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
		_current_host = ""
		_current_port = -1


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_udp()
