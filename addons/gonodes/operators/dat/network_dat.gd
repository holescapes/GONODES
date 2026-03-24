class_name NetworkDAT
extends GNDatBase
## Combined TCP/UDP network communication operator.
##
## Uses Godot's native StreamPeerTCP / PacketPeerUDP for network I/O.
## Supports both client mode (connect to remote) and listen mode (accept connections).
## Received data is output as a text DAT (one row per message) or as a table.

enum Protocol { TCP, UDP }
enum Mode { CLIENT, LISTEN }

var _tcp_client: StreamPeerTCP = null
var _tcp_server: TCPServer = null
var _tcp_peer: StreamPeerTCP = null  # Accepted client connection
var _udp: PacketPeerUDP = null

var _received_lines: PackedStringArray = PackedStringArray()
var _connected: bool = false
const MAX_BUFFER_LINES := 1000


func _init() -> void:
	node_type = "network"


func _init_ports() -> void:
	add_input("send", GNFamily.Type.DAT, false, "Data to send (text or table)")
	add_output("out", GNFamily.Type.DAT, "Received data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("protocol",
		PackedStringArray(["TCP", "UDP"]), 0, "Protocol", "Network protocol"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Client", "Listen"]), 0, "Mode", "Client (connect) or Listen (server)"))
	add_parameter(GNParameter.create_string("address", "127.0.0.1", "Address", "Remote address (client) or bind address (listen)"))
	add_parameter(GNParameter.create_int("port", 7000, 1, 65535, "Port", "Network port"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable/disable network activity"))
	add_parameter(GNParameter.create_int("max_lines", 100, 1, MAX_BUFFER_LINES, "Max Lines", "Maximum received lines to buffer"))
	add_parameter(GNParameter.create_bool("clear_buffer", false, "Clear", "Pulse to clear receive buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var proto: int = get_param_value("protocol")
	var net_mode: int = get_param_value("mode")
	var address: String = get_param_value("address")
	var net_port: int = get_param_value("port")
	var active: bool = get_param_value("active")
	var max_lines: int = get_param_value("max_lines")
	var do_clear: bool = get_param_value("clear_buffer")

	if do_clear:
		_received_lines.clear()

	if not active:
		_disconnect_all()
		return _build_output()

	# ── TCP ──────────────────────────────────────────────────────────────────
	if proto == Protocol.TCP:
		if net_mode == Mode.CLIENT:
			_ensure_tcp_client(address, net_port)
			_poll_tcp_client(max_lines)
			_send_tcp_client(inputs)
		else:
			_ensure_tcp_server(address, net_port)
			_poll_tcp_server(max_lines)
			_send_tcp_peer(inputs)
	# ── UDP ──────────────────────────────────────────────────────────────────
	else:
		_ensure_udp(address, net_port, net_mode)
		_poll_udp(max_lines)
		_send_udp(inputs, address, net_port)

	return _build_output()


# ─── TCP Client ──────────────────────────────────────────────────────────────

func _ensure_tcp_client(address: String, net_port: int) -> void:
	if _tcp_client == null:
		_tcp_client = StreamPeerTCP.new()
	if _tcp_client.get_status() == StreamPeerTCP.STATUS_NONE:
		_tcp_client.connect_to_host(address, net_port)
		_connected = false


func _poll_tcp_client(max_lines: int) -> void:
	if _tcp_client == null:
		return
	_tcp_client.poll()
	var status: StreamPeerTCP.Status = _tcp_client.get_status()
	_connected = (status == StreamPeerTCP.STATUS_CONNECTED)
	if _connected:
		var avail: int = _tcp_client.get_available_bytes()
		if avail > 0:
			var data: Array = _tcp_client.get_data(avail)
			if data[0] == OK:
				var text: String = (data[1] as PackedByteArray).get_string_from_utf8()
				_append_lines(text, max_lines)


func _send_tcp_client(inputs: Array[GNData]) -> void:
	if _tcp_client == null or not _connected:
		return
	var text: String = _get_send_text(inputs)
	if not text.is_empty():
		_tcp_client.put_data(text.to_utf8_buffer())


# ─── TCP Server ──────────────────────────────────────────────────────────────

func _ensure_tcp_server(address: String, net_port: int) -> void:
	if _tcp_server == null:
		_tcp_server = TCPServer.new()
	if not _tcp_server.is_listening():
		_tcp_server.listen(net_port, address)


func _poll_tcp_server(max_lines: int) -> void:
	if _tcp_server == null:
		return
	if _tcp_server.is_connection_available():
		if _tcp_peer != null:
			_tcp_peer.disconnect_from_host()
		_tcp_peer = _tcp_server.take_connection()
	if _tcp_peer != null:
		_tcp_peer.poll()
		if _tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var avail: int = _tcp_peer.get_available_bytes()
			if avail > 0:
				var data: Array = _tcp_peer.get_data(avail)
				if data[0] == OK:
					var text: String = (data[1] as PackedByteArray).get_string_from_utf8()
					_append_lines(text, max_lines)


func _send_tcp_peer(inputs: Array[GNData]) -> void:
	if _tcp_peer == null or _tcp_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var text: String = _get_send_text(inputs)
	if not text.is_empty():
		_tcp_peer.put_data(text.to_utf8_buffer())


# ─── UDP ─────────────────────────────────────────────────────────────────────

func _ensure_udp(address: String, net_port: int, net_mode: int) -> void:
	if _udp == null:
		_udp = PacketPeerUDP.new()
	if net_mode == Mode.LISTEN:
		if not _udp.is_bound():
			_udp.bind(net_port, address)
	else:
		if not _udp.is_bound():
			_udp.connect_to_host(address, net_port)


func _poll_udp(max_lines: int) -> void:
	if _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _udp.get_packet()
		var text: String = pkt.get_string_from_utf8()
		_append_lines(text, max_lines)


func _send_udp(inputs: Array[GNData], address: String, net_port: int) -> void:
	if _udp == null:
		return
	var text: String = _get_send_text(inputs)
	if not text.is_empty():
		_udp.put_packet(text.to_utf8_buffer())


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _get_send_text(inputs: Array[GNData]) -> String:
	var dat: GNTableData = _get_input_dat(inputs, 0)
	if dat == null:
		return ""
	if dat.is_table:
		var lines := PackedStringArray()
		for row: PackedStringArray in dat.table:
			lines.append(",".join(row))
		return "\n".join(lines)
	return dat.text


func _append_lines(text: String, max_lines: int) -> void:
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.is_empty():
			_received_lines.append(stripped)
	# Trim buffer
	while _received_lines.size() > max_lines:
		_received_lines.remove_at(0)


func _build_output() -> GNTableData:
	var output: GNTableData = _prepare_table()
	output.has_header = true
	output.is_table = true
	output.table.append(PackedStringArray(["line", "data"]))
	for i in range(_received_lines.size()):
		output.table.append(PackedStringArray([str(i), _received_lines[i]]))
	return output


func _disconnect_all() -> void:
	if _tcp_client != null:
		_tcp_client.disconnect_from_host()
		_connected = false
	if _tcp_peer != null:
		_tcp_peer.disconnect_from_host()
		_tcp_peer = null
	if _tcp_server != null:
		_tcp_server.stop()
	if _udp != null:
		_udp.close()
		_udp = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_all()
