class_name WebSocketDAT
extends GNDatBase
## WebSocket client and server using Godot's WebSocketPeer / WebSocketMultiplayerPeer.
## Client mode connects to a remote WebSocket URL.
## Server mode listens for incoming connections.
## Messages are output as a text table (one row per message).

var _ws_client: WebSocketPeer = null
var _ws_server: TCPServer = null
var _ws_peers: Array[WebSocketPeer] = []
var _received_lines: PackedStringArray = PackedStringArray()
var _connected: bool = false
const MAX_BUFFER_LINES := 1000


func _init() -> void:
	node_type = "websocket"
	node_description = "WebSocket client/server communication."
	time_dependent = true


func _init_ports() -> void:
	add_input("send", GNFamily.Type.DAT, false, "Data to send as text message")
	add_output("out", GNFamily.Type.DAT, "Received messages table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Client", "Server"]), 0, "Mode",
		"Client connects to URL, Server listens on port"))
	add_parameter(GNParameter.create_string("url", "ws://127.0.0.1:9090", "URL",
		"WebSocket URL (client mode)"))
	add_parameter(GNParameter.create_int("port", 9090, 1, 65535, "Port",
		"Listen port (server mode)"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable/disable"))
	add_parameter(GNParameter.create_int("max_lines", 100, 1, MAX_BUFFER_LINES,
		"Max Lines", "Maximum received messages to buffer"))
	add_parameter(GNParameter.create_bool("clear", false, "Clear", "Pulse to clear buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var mode: int = get_param_value("mode")
	var active: bool = get_param_value("active")
	var max_lines: int = get_param_value("max_lines")
	var do_clear: bool = get_param_value("clear")

	if do_clear:
		_received_lines.clear()

	if not active:
		_disconnect_all()
		return _build_output()

	if mode == 0:  # Client
		_poll_client(max_lines)
		_send_client(inputs)
	else:  # Server
		_poll_server(max_lines)
		_send_server(inputs)

	return _build_output()


# ─── Client ──────────────────────────────────────────────────────────────────

func _poll_client(max_lines: int) -> void:
	var url: String = get_param_value("url").strip_edges()
	if url.is_empty():
		return

	if _ws_client == null:
		_ws_client = WebSocketPeer.new()
		var err: int = _ws_client.connect_to_url(url)
		if err != OK:
			GNLogger.warn("WebSocketDAT", "'%s' — failed to connect to '%s'" % [id, url])
			_ws_client = null
			return

	_ws_client.poll()
	var state: WebSocketPeer.State = _ws_client.get_ready_state()
	_connected = (state == WebSocketPeer.STATE_OPEN)

	while _ws_client.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _ws_client.get_packet()
		var text: String = pkt.get_string_from_utf8()
		_append_line(text, max_lines)

	if state == WebSocketPeer.STATE_CLOSED:
		_ws_client = null
		_connected = false


func _send_client(inputs: Array[GNData]) -> void:
	if _ws_client == null or not _connected:
		return
	var text: String = _get_send_text(inputs)
	if not text.is_empty():
		_ws_client.send_text(text)


# ─── Server ──────────────────────────────────────────────────────────────────

func _poll_server(max_lines: int) -> void:
	var port: int = get_param_value("port")

	if _ws_server == null:
		_ws_server = TCPServer.new()
		_ws_server.listen(port, "0.0.0.0")

	# Accept new TCP connections and upgrade to WebSocket
	while _ws_server.is_connection_available():
		var tcp_peer: StreamPeerTCP = _ws_server.take_connection()
		if tcp_peer != null:
			var ws_peer := WebSocketPeer.new()
			ws_peer.accept_stream(tcp_peer)
			_ws_peers.append(ws_peer)

	# Poll all connected peers
	var active_peers: Array[WebSocketPeer] = []
	for peer in _ws_peers:
		peer.poll()
		var state: WebSocketPeer.State = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				var pkt: PackedByteArray = peer.get_packet()
				_append_line(pkt.get_string_from_utf8(), max_lines)
			active_peers.append(peer)
		elif state == WebSocketPeer.STATE_CONNECTING:
			active_peers.append(peer)
		# else: closed — drop
	_ws_peers = active_peers


func _send_server(inputs: Array[GNData]) -> void:
	var text: String = _get_send_text(inputs)
	if text.is_empty():
		return
	for peer in _ws_peers:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send_text(text)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _get_send_text(inputs: Array[GNData]) -> String:
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var tbl: GNTableData = inputs[0] as GNTableData
		if not tbl.text.is_empty():
			return tbl.text
		return tbl.to_tsv()
	return ""


func _append_line(text: String, max_lines: int) -> void:
	for line in text.split("\n"):
		_received_lines.append(line)
	while _received_lines.size() > max_lines:
		_received_lines = _received_lines.slice(1)


func _disconnect_all() -> void:
	if _ws_client != null:
		_ws_client.close()
		_ws_client = null
	for peer in _ws_peers:
		peer.close()
	_ws_peers.clear()
	if _ws_server != null:
		_ws_server.stop()
		_ws_server = null
	_connected = false


func _build_output() -> GNData:
	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["message"]))
	for line in _received_lines:
		tbl.append_row(PackedStringArray([line]))
	return tbl


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_all()
