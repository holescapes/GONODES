class_name WebServerDAT
extends GNDatBase
## Minimal HTTP server — listens on a port and serves responses.
## Uses Godot's TCPServer + StreamPeerTCP to handle requests.
## Received requests are output as a table (method, path, headers, body).
## Connect a DAT input to provide response content.

var _server: TCPServer = null
var _requests: Array[Dictionary] = []
const MAX_REQUESTS := 100


func _init() -> void:
	node_type = "web_server"
	time_dependent = true


func _init_ports() -> void:
	add_input("response", GNFamily.Type.DAT, false, "Response body (text or table)", "Response")
	add_output("out", GNFamily.Type.DAT, "Request log table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("port", 8080, 1, 65535, "Port", "Listen port"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable/disable server"))
	add_parameter(GNParameter.create_string("content_type", "text/html", "Content Type",
		"Response Content-Type header"))
	add_parameter(GNParameter.create_int("max_requests", 50, 1, MAX_REQUESTS,
		"Max Rows", "Maximum request log rows"))
	add_parameter(GNParameter.create_bool("clear", false, "Clear", "Pulse to clear log"))


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var port: int = get_param_value("port")
	var do_clear: bool = get_param_value("clear")
	var max_rows: int = get_param_value("max_requests")
	var content_type: String = get_param_value("content_type")

	if do_clear:
		_requests.clear()

	if not active:
		_stop_server()
		return _build_output()

	_ensure_server(port)
	_poll_connections(inputs, content_type)

	# Trim buffer
	while _requests.size() > max_rows:
		_requests.pop_front()

	return _build_output()


func _ensure_server(port: int) -> void:
	if _server == null:
		_server = TCPServer.new()
	if not _server.is_listening():
		var err: int = _server.listen(port, "0.0.0.0")
		if err != OK:
			GNLogger.warn("WebServerDAT", "'%s' — failed to listen on port %d" % [id, port])


func _stop_server() -> void:
	if _server != null and _server.is_listening():
		_server.stop()


func _poll_connections(inputs: Array[GNData], content_type: String) -> void:
	if _server == null or not _server.is_listening():
		return

	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer == null:
			continue
		peer.poll()
		# Read request with a small timeout
		var request_text := ""
		var avail: int = peer.get_available_bytes()
		if avail > 0:
			var data: Array = peer.get_data(mini(avail, 8192))
			if data[0] == OK:
				request_text = (data[1] as PackedByteArray).get_string_from_utf8()

		# Parse request line
		var method := "GET"
		var path := "/"
		var lines: PackedStringArray = request_text.split("\r\n")
		if lines.size() > 0:
			var parts: PackedStringArray = lines[0].split(" ")
			if parts.size() >= 2:
				method = parts[0]
				path = parts[1]

		# Build response body from upstream DAT
		var body := "OK"
		if inputs.size() > 0 and inputs[0] is GNTableData:
			var tbl: GNTableData = inputs[0] as GNTableData
			body = tbl.text if not tbl.text.is_empty() else tbl.to_tsv()

		# Send HTTP response
		var response := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
			content_type, body.length(), body]
		peer.put_data(response.to_utf8_buffer())
		peer.disconnect_from_host()

		_requests.append({
			"method": method,
			"path": path,
			"time": Time.get_datetime_string_from_system(),
		})


func _build_output() -> GNData:
	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["method", "path", "time"]))
	for req in _requests:
		tbl.append_row(PackedStringArray([req.get("method", ""),
			req.get("path", ""), req.get("time", "")]))
	return tbl


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_server()
