class_name OscInCHOP
extends GNChopBase
## Receives OSC messages on a UDP port and maps address/argument values to
## CHOP channels.  Each unique OSC address becomes a channel (or multiple
## channels if the message carries more than one numeric argument).
##
## Channel naming: "/foo" with one float → channel "foo".
## "/bar" with 3 floats → channels "bar:0", "bar:1", "bar:2".
##
## Non-numeric arguments are silently ignored (use OscInDAT for raw messages).
## The node is time-dependent and polls the UDP socket every frame.

# ─── Networking ────────────────────────────────────────────────────────────────

var _udp: PacketPeerUDP = null
var _bound_port: int = -1

## Latest value per channel.  Accumulates across frames; cleared only on reset.
var _channel_values: Dictionary = {}  # channel_name → float


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "osc_in"
	time_dependent = true
	node_description = "Receive OSC messages as CHOP channels via UDP."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Latest OSC values as channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("port", 9000, 1, 65535, "Port",
		"UDP port to listen on"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable the OSC listener"))
	add_parameter(GNParameter.create_string("address_filter", "", "Filter",
		"Only accept addresses matching this prefix (empty = all)"))
	add_parameter(GNParameter.create_bool("normalize_names", true, "Clean Names",
		"Strip leading '/' from channel names"))
	add_parameter(GNParameter.create_int("max_channels", 128, 1, 1024, "Max Channels",
		"Maximum number of channels to track"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Pulse: clear all stored channels"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var port: int = get_param_value("port")
	var addr_filter: String = get_param_value("address_filter")
	var normalize: bool = get_param_value("normalize_names")
	var max_ch: int = get_param_value("max_channels")

	# Handle reset pulse
	if get_param_value("reset"):
		_channel_values.clear()
		set_param_value("reset", false)

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
			var messages: Array[GNOscParser.OscMessage] = GNOscParser.decode_all(pkt)
			for msg in messages:
				_process_osc_message(msg, addr_filter, normalize, max_ch)

	# Build output
	var out: GNChannelData = _prepare_output(60.0)
	for ch_name in _channel_values:
		out.set_single_value(ch_name, _channel_values[ch_name])
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# OSC Processing
# ═══════════════════════════════════════════════════════════════════════════════

func _process_osc_message(msg: GNOscParser.OscMessage, addr_filter: String,
		normalize: bool, max_ch: int) -> void:
	# Address filter
	if not addr_filter.is_empty() and not msg.address.begins_with(addr_filter):
		return

	# Extract numeric args
	var nums: PackedFloat32Array = PackedFloat32Array()
	for arg in msg.args:
		if arg is int or arg is float:
			nums.append(float(arg))
		elif arg is bool:
			nums.append(1.0 if arg else 0.0)

	if nums.is_empty():
		return

	# Build channel name
	var base_name: String = msg.address
	if normalize and base_name.begins_with("/"):
		base_name = base_name.substr(1)
	# Replace remaining '/' with ':' for flat channel namespace
	base_name = base_name.replace("/", ":")

	if nums.size() == 1:
		if _channel_values.size() < max_ch or _channel_values.has(base_name):
			_channel_values[base_name] = nums[0]
	else:
		for i in range(nums.size()):
			var ch_name: String = "%s:%d" % [base_name, i]
			if _channel_values.size() < max_ch or _channel_values.has(ch_name):
				_channel_values[ch_name] = nums[i]


# ═══════════════════════════════════════════════════════════════════════════════
# UDP Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_udp(port: int) -> void:
	if _udp != null and _bound_port == port:
		return  # Already bound to correct port
	_close_udp()
	_udp = PacketPeerUDP.new()
	var err: Error = _udp.bind(port)
	if err != OK:
		push_warning("OscInCHOP: failed to bind UDP port %d — error %s" % [port, error_string(err)])
		_udp = null
		_bound_port = -1
		return
	_bound_port = port
	GNLogger.info("OscInCHOP", "Listening on UDP port %d" % port)


func _close_udp() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
		_bound_port = -1


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_udp()
