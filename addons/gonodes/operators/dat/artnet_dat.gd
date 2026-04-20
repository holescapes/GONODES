class_name ArtnetDAT
extends GNDatBase
## Art-Net network discovery and status DAT.
##
## Listens for Art-Net ArtPoll / ArtPollReply packets to discover
## Art-Net nodes on the local network, and optionally broadcasts
## ArtPoll to trigger discovery.
##
## Outputs a table of discovered Art-Net nodes with their IP address,
## short name, long name, firmware version, universe configuration,
## and last-seen timestamp.
##
## For sending/receiving DMX channel data, use DmxOutCHOP / DmxInCHOP.
##
## TouchDesigner equivalent: Art-Net DAT.

const ARTNET_HEADER := "Art-Net"
const ARTNET_OPCODE_POLL := 0x2000
const ARTNET_OPCODE_POLL_REPLY := 0x2100

# ── State ──────────────────────────────────────────────────────────────────────
var _udp: PacketPeerUDP = null
var _bound_port: int = -1
## Dictionary of discovered nodes: ip_string → { short_name, long_name,
## firmware, universe_lo, universe_hi, port_count, last_seen_sec }
var _nodes: Dictionary = {}
var _poll_timer: float = 0.0


func _init() -> void:
	node_type = "artnet"
	time_dependent = true
	thread_safe = false  # PacketPeerUDP I/O


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Table of discovered Art-Net nodes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable Art-Net discovery listener"))
	add_parameter(GNParameter.create_int("port", 6454, 1, 65535,
		"Port", "Art-Net UDP port to listen on (default 6454)"))
	add_parameter(GNParameter.create_float("poll_interval", 10.0, 1.0, 120.0, 1.0,
		"Poll Interval", "Seconds between ArtPoll broadcast requests"))
	add_parameter(GNParameter.create_bool("auto_poll", true,
		"Auto Poll", "Periodically broadcast ArtPoll to discover nodes"))
	add_parameter(GNParameter.create_float("timeout", 30.0, 5.0, 300.0, 1.0,
		"Node Timeout", "Remove nodes not seen for this many seconds"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")

	if active:
		_ensure_bound()
		_poll_replies()
		_auto_poll_tick()
		_expire_stale_nodes()
	else:
		_close()

	# Build output table
	var out := _prepare_table()
	out.set_headers(PackedStringArray([
		"ip", "short_name", "long_name", "firmware",
		"universe_lo", "universe_hi", "port_count", "last_seen"
	]))

	for ip in _nodes:
		var n: Dictionary = _nodes[ip]
		out.append_row(PackedStringArray([
			ip,
			n.get("short_name", ""),
			n.get("long_name", ""),
			str(n.get("firmware", 0)),
			str(n.get("universe_lo", 0)),
			str(n.get("universe_hi", 0)),
			str(n.get("port_count", 0)),
			"%.1f" % n.get("last_seen", 0.0),
		]))

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Networking
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_bound() -> void:
	var port: int = get_param_value("port")
	if _udp != null and _bound_port == port:
		return
	_close()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(port)
	if err != OK:
		push_warning("ArtnetDAT: Could not bind to port %d (error %d)." % [port, err])
		_udp = null
		return
	_bound_port = port


func _poll_replies() -> void:
	if _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var sender_ip := _udp.get_packet_ip()
		_parse_packet(packet, sender_ip)


func _parse_packet(packet: PackedByteArray, sender_ip: String) -> void:
	if packet.size() < 10:
		return
	# Validate "Art-Net\0"
	if packet.slice(0, 7).get_string_from_ascii() != ARTNET_HEADER:
		return
	if packet[7] != 0:
		return

	var opcode: int = packet[8] | (packet[9] << 8)

	if opcode == ARTNET_OPCODE_POLL_REPLY:
		_parse_poll_reply(packet, sender_ip)


## Parses an ArtPollReply (opcode 0x2100) packet.
## See Art-Net 4 spec §6.2 for field offsets.
func _parse_poll_reply(packet: PackedByteArray, sender_ip: String) -> void:
	if packet.size() < 207:
		return

	# IP address from packet (bytes 10-13), but we prefer sender_ip
	# Short name: bytes 26-43 (18 chars, null-terminated)
	var short_name := _read_fixed_string(packet, 26, 18)
	# Long name: bytes 44-107 (64 chars, null-terminated)
	var long_name := _read_fixed_string(packet, 44, 64)
	# Firmware version: bytes 16-17 (big-endian)
	var firmware: int = (packet[16] << 8) | packet[17]
	# Number of ports: byte 173 (low byte of 2-byte field at 172-173)
	var port_count: int = packet[173]
	# Universe low: default subnet+universe from Net/SubUni fields
	# NetSwitch (byte 18), SubSwitch (byte 19)
	var net_switch: int = packet[18] if packet.size() > 18 else 0
	var sub_switch: int = packet[19] if packet.size() > 19 else 0
	var universe_lo: int = (net_switch << 8) | sub_switch
	var universe_hi: int = universe_lo + maxi(port_count - 1, 0)

	_nodes[sender_ip] = {
		"short_name": short_name,
		"long_name": long_name,
		"firmware": firmware,
		"universe_lo": universe_lo,
		"universe_hi": universe_hi,
		"port_count": port_count,
		"last_seen": Time.get_ticks_msec() / 1000.0,
	}


func _read_fixed_string(packet: PackedByteArray, offset: int, max_len: int) -> String:
	var end := mini(offset + max_len, packet.size())
	var bytes := packet.slice(offset, end)
	# Find null terminator
	var null_pos := -1
	for i in range(bytes.size()):
		if bytes[i] == 0:
			null_pos = i
			break
	if null_pos >= 0:
		bytes = bytes.slice(0, null_pos)
	return bytes.get_string_from_ascii()


# ═══════════════════════════════════════════════════════════════════════════════
# ArtPoll Broadcast
# ═══════════════════════════════════════════════════════════════════════════════

func _auto_poll_tick() -> void:
	if not get_param_value("auto_poll"):
		return
	var interval: float = get_param_value("poll_interval")
	_poll_timer += current_delta
	if _poll_timer >= interval:
		_poll_timer = 0.0
		_send_artpoll()


func _send_artpoll() -> void:
	if _udp == null:
		return
	var packet := PackedByteArray()
	# Header: "Art-Net\0"
	packet.append_array(ARTNET_HEADER.to_ascii_buffer())
	packet.append(0)
	# OpCode: ArtPoll (0x2000) little-endian
	packet.append(ARTNET_OPCODE_POLL & 0xFF)
	packet.append((ARTNET_OPCODE_POLL >> 8) & 0xFF)
	# Protocol version 14 (big-endian)
	packet.append(0)
	packet.append(14)
	# TalkToMe flags: 0x02 = send ArtPollReply on change
	packet.append(0x02)
	# Diagnostic priority: 0 (low)
	packet.append(0)

	var port: int = get_param_value("port")
	_udp.set_dest_address("255.255.255.255", port)
	_udp.put_packet(packet)


# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

func _expire_stale_nodes() -> void:
	var timeout: float = get_param_value("timeout")
	var now: float = Time.get_ticks_msec() / 1000.0
	var stale_keys: Array = []
	for ip in _nodes:
		if now - _nodes[ip].get("last_seen", 0.0) > timeout:
			stale_keys.append(ip)
	for ip in stale_keys:
		_nodes.erase(ip)


func _close() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
	_bound_port = -1
	_nodes.clear()
	_poll_timer = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close()
