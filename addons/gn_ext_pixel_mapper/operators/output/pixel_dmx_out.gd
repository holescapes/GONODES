class_name PixelDmxOUT
extends GNOutBase
## Sends pixel-mapped fixture data as multi-universe DMX-512 via Art-Net (UDP).
##
## Reads CHOP input (0-1 float values) from FixtureSamplerTOP and uses the
## dmx_routing metadata to route each channel to its declared (universe, slot)
## address. Scales values from 0-1 to 0-255 for DMX. Sends one Art-Net OpDmx
## packet per active universe each frame.
##
## This is a terminal sink (no output ports) -- display and send only.

const DMX_CHANNELS := 512
const ARTNET_HEADER := "Art-Net"
const ARTNET_OPCODE_DMX := 0x5000

var _udp: PacketPeerUDP = null
var _artnet_sequence: int = 0
var _bound_address: String = ""


func _init() -> void:
	node_type = "pixel_dmx_out"
	node_description = "Multi-universe Art-Net output for pixel-mapped fixtures."
	time_dependent = true
	thread_safe = false


func _init_ports() -> void:
	add_input("values", GNFamily.Type.CHOP, false,
		"Fixture CHOP from FixtureSamplerTOP (0-1 values with dmx_routing metadata)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("ip", "255.255.255.255",
		"IP Address", "Destination IP for Art-Net broadcast"))
	add_parameter(GNParameter.create_int("port", 6454, 1, 65535,
		"Port", "Art-Net UDP port (default 6454)"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable Art-Net sending"))
	add_parameter(GNParameter.create_string("bind_address", "",
		"Bind Address", "Local interface IP to send from (e.g. 10.201.6.111). Leave empty to let OS choose."))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_chop := _get_input_chop(inputs, 0)
	if in_chop == null:
		node_warning = "No CHOP input."
		return null

	var active: bool = get_param_value("active")
	if not active:
		node_warning = "Inactive"
		return null

	var routing: Variant = in_chop.metadata.get("dmx_routing", null)
	if not (routing is Array) or routing.is_empty():
		node_warning = "No dmx_routing metadata on input."
		return null

	_send_routed(in_chop, routing)
	return null


func _send_routed(in_chop: GNChannelData, routing: Array) -> void:
	var universes: Dictionary = {}

	for entry in routing:
		var ch_name: String = entry.get("channel", "")
		var uni: int = int(entry.get("universe", 0))
		var slot: int = int(entry.get("slot", 1))
		if ch_name.is_empty() or slot < 1 or slot > 512:
			continue

		if not universes.has(uni):
			var buf := PackedByteArray()
			buf.resize(512)
			universes[uni] = buf

		# Scale 0-1 float to 0-255 DMX byte
		var value: float = in_chop.get_value(ch_name)
		universes[uni][slot - 1] = clampi(int(value * 255.0), 0, 255)

	var uni_keys: Array = universes.keys()
	uni_keys.sort()
	for uni in uni_keys:
		var buf: PackedByteArray = universes[uni]
		# Send the full 512-byte universe -- never trim. Art-Net receivers often
		# hold the last value when they receive a shorter packet, causing lights
		# to stay on when all channels go to zero.
		_send_artnet(buf, uni)

	node_warning = ""


func _send_artnet(values: PackedByteArray, universe: int) -> void:
	var ip: String = get_param_value("ip")
	var port_num: int = get_param_value("port")

	_artnet_sequence = (_artnet_sequence + 1) % 256
	if _artnet_sequence == 0:
		_artnet_sequence = 1

	var packet := PackedByteArray()
	packet.append_array(ARTNET_HEADER.to_ascii_buffer())
	packet.append(0)
	packet.append(ARTNET_OPCODE_DMX & 0xFF)
	packet.append((ARTNET_OPCODE_DMX >> 8) & 0xFF)
	packet.append(0)
	packet.append(14)
	packet.append(_artnet_sequence)
	packet.append(0)
	packet.append(universe & 0xFF)
	packet.append((universe >> 8) & 0xFF)
	var data_len := values.size()
	if data_len % 2 != 0:
		data_len += 1
	packet.append((data_len >> 8) & 0xFF)
	packet.append(data_len & 0xFF)
	packet.append_array(values)
	if values.size() % 2 != 0:
		packet.append(0)

	if _udp == null:
		_udp = PacketPeerUDP.new()
	var bind_addr: String = get_param_value("bind_address")
	if bind_addr != _bound_address:
		_udp.close()
		_udp = PacketPeerUDP.new()
		if bind_addr != "":
			_udp.bind(0, bind_addr)
		else:
			_udp.bind(0)
		_bound_address = bind_addr
	_udp.set_dest_address(ip, port_num)
	_udp.put_packet(packet)
