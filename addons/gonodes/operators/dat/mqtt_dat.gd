class_name MqttDAT
extends GNDatBase
## MQTT 3.1.1 client DAT — publish and subscribe to IoT topics.
##
## Pure GDScript implementation using Godot's StreamPeerTCP.  No external
## libraries required.  Supports QoS 0 (fire-and-forget) which covers the
## vast majority of real-time art/installation use cases.
##
## Subscribe to topics in the "subscribe" parameter (comma-separated).
## Incoming messages appear in the output table.  Connect a DAT input
## to publish its text content to the "publish_topic".
##
## MQTT brokers: Mosquitto, HiveMQ, EMQX, etc.

# ─── MQTT Protocol Constants ──────────────────────────────────────────────────

const MQTT_CONNECT     := 1
const MQTT_CONNACK     := 2
const MQTT_PUBLISH     := 3
const MQTT_SUBSCRIBE   := 8
const MQTT_SUBACK      := 9
const MQTT_PINGREQ     := 12
const MQTT_PINGRESP    := 13
const MQTT_DISCONNECT  := 14

# ─── State ─────────────────────────────────────────────────────────────────────

var _tcp: StreamPeerTCP = null
var _connected: bool = false
var _subscribed: bool = false
var _received: PackedStringArray = PackedStringArray()
var _last_ping: float = 0.0
var _last_sub_topics: String = ""
var _packet_id: int = 1
const MAX_BUFFER := 500
const PING_INTERVAL := 30.0  # seconds


func _init() -> void:
	node_type = "mqtt"
	time_dependent = true
	thread_safe = false  # StreamPeerTCP I/O


func _init_ports() -> void:
	add_input("publish", GNFamily.Type.DAT, false, "Text to publish")
	add_output("out", GNFamily.Type.DAT, "Received messages table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("broker", "127.0.0.1",
		"Broker", "MQTT broker hostname or IP"))
	add_parameter(GNParameter.create_int("port", 1883, 1, 65535,
		"Port", "MQTT broker port (default 1883)"))
	add_parameter(GNParameter.create_string("client_id", "gonodes",
		"Client ID", "MQTT client identifier"))
	add_parameter(GNParameter.create_string("username", "",
		"Username", "Broker username (leave empty for anonymous)"))
	add_parameter(GNParameter.create_string("password", "",
		"Password", "Broker password"))
	add_parameter(GNParameter.create_string("subscribe", "gonodes/#",
		"Subscribe", "Comma-separated topic filters to subscribe"))
	add_parameter(GNParameter.create_string("publish_topic", "gonodes/out",
		"Publish Topic", "Topic for outgoing messages"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable MQTT connection"))
	add_parameter(GNParameter.create_int("max_messages", 100, 1, MAX_BUFFER,
		"Max Messages", "Maximum buffered received messages"))
	add_parameter(GNParameter.create_bool("clear", false,
		"Clear", "Pulse to clear receive buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var do_clear: bool = get_param_value("clear")
	var max_msg: int = get_param_value("max_messages")

	if do_clear:
		_received.clear()

	if not active:
		_disconnect()
		return _build_output()

	# Connect if needed
	_ensure_connected()

	if _tcp != null:
		_tcp.poll()

	# Subscribe if topics changed or not yet subscribed
	if _connected:
		var sub_topics: String = get_param_value("subscribe")
		if sub_topics != _last_sub_topics or not _subscribed:
			_send_subscribe(sub_topics)
			_last_sub_topics = sub_topics

		# Publish input DAT text
		_publish_input(inputs)

		# Read incoming data
		_poll_incoming(max_msg)

		# Keep-alive ping
		_last_ping += current_delta
		if _last_ping >= PING_INTERVAL:
			_send_pingreq()
			_last_ping = 0.0

	return _build_output()


# ═══════════════════════════════════════════════════════════════════════════════
# Connection
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_connected() -> void:
	if _tcp == null:
		_tcp = StreamPeerTCP.new()

	var status: StreamPeerTCP.Status = _tcp.get_status()

	if status == StreamPeerTCP.STATUS_NONE:
		var broker: String = get_param_value("broker")
		var port: int = get_param_value("port")
		_tcp.connect_to_host(broker, port)
		_connected = false
		_subscribed = false

	elif status == StreamPeerTCP.STATUS_CONNECTED and not _connected:
		_send_connect_packet()
		_connected = true
		_last_ping = 0.0

	elif status == StreamPeerTCP.STATUS_ERROR:
		GNLogger.warn("MqttDAT", "'%s' — TCP connection error, reconnecting" % id)
		_tcp.disconnect_from_host()
		_connected = false
		_subscribed = false


func _disconnect() -> void:
	if _tcp != null:
		if _connected:
			# Send DISCONNECT
			var pkt := PackedByteArray()
			pkt.append((MQTT_DISCONNECT << 4) | 0)
			pkt.append(0)
			_tcp.put_data(pkt)
		_tcp.disconnect_from_host()
	_tcp = null
	_connected = false
	_subscribed = false


# ═══════════════════════════════════════════════════════════════════════════════
# MQTT Packet Building
# ═══════════════════════════════════════════════════════════════════════════════

func _send_connect_packet() -> void:
	var client_id: String = get_param_value("client_id")
	var username: String = get_param_value("username")
	var password: String = get_param_value("password")

	var payload := PackedByteArray()

	# Variable header: Protocol Name "MQTT"
	_append_utf8(payload, "MQTT")
	# Protocol Level: 4 (MQTT 3.1.1)
	payload.append(4)
	# Connect Flags
	var flags: int = 0x02  # Clean Session
	if not username.is_empty():
		flags |= 0x80  # Username flag
	if not password.is_empty():
		flags |= 0x40  # Password flag
	payload.append(flags)
	# Keep Alive (seconds)
	payload.append(0)
	payload.append(60)

	# Payload: Client ID
	_append_utf8(payload, client_id)
	if not username.is_empty():
		_append_utf8(payload, username)
	if not password.is_empty():
		_append_utf8(payload, password)

	_send_packet(MQTT_CONNECT, payload)


func _send_subscribe(topics_str: String) -> void:
	if not _connected:
		return
	var topics: PackedStringArray = topics_str.split(",")
	if topics.is_empty():
		return

	var payload := PackedByteArray()
	# Packet Identifier
	payload.append((_packet_id >> 8) & 0xFF)
	payload.append(_packet_id & 0xFF)
	_packet_id = (_packet_id % 65535) + 1

	for topic in topics:
		var t: String = topic.strip_edges()
		if t.is_empty():
			continue
		_append_utf8(payload, t)
		payload.append(0)  # QoS 0

	# SUBSCRIBE has fixed header flag 0x02
	var header := PackedByteArray()
	header.append((MQTT_SUBSCRIBE << 4) | 0x02)
	_encode_remaining_length(header, payload.size())
	header.append_array(payload)
	_tcp.put_data(header)

	_subscribed = true
	GNLogger.info("MqttDAT", "'%s' subscribed to: %s" % [id, topics_str])


func _publish_input(inputs: Array[GNData]) -> void:
	var dat: GNTableData = _get_input_dat(inputs, 0)
	if dat == null:
		return
	var text: String = dat.text if not dat.text.is_empty() else dat.to_tsv() if dat.is_table else ""
	if text.is_empty():
		return

	var topic: String = get_param_value("publish_topic")
	if topic.is_empty():
		return

	var payload := PackedByteArray()
	_append_utf8(payload, topic)
	payload.append_array(text.to_utf8_buffer())

	_send_packet(MQTT_PUBLISH, payload)


func _send_pingreq() -> void:
	var pkt := PackedByteArray()
	pkt.append((MQTT_PINGREQ << 4) | 0)
	pkt.append(0)
	if _tcp != null:
		_tcp.put_data(pkt)


func _send_packet(ptype: int, payload: PackedByteArray) -> void:
	if _tcp == null:
		return
	var header := PackedByteArray()
	header.append((ptype << 4) | 0)
	_encode_remaining_length(header, payload.size())
	header.append_array(payload)
	_tcp.put_data(header)


# ═══════════════════════════════════════════════════════════════════════════════
# Incoming
# ═══════════════════════════════════════════════════════════════════════════════

func _poll_incoming(max_msg: int) -> void:
	if _tcp == null:
		return
	while _tcp.get_available_bytes() > 0:
		# Read fixed header byte
		var hdr_result: Array = _tcp.get_data(1)
		if hdr_result[0] != OK or (hdr_result[1] as PackedByteArray).size() == 0:
			break
		var hdr_byte: int = (hdr_result[1] as PackedByteArray)[0]
		var ptype: int = (hdr_byte >> 4) & 0x0F

		# Read remaining length
		var rem_len: int = _read_remaining_length()
		if rem_len < 0:
			break

		if rem_len == 0:
			continue

		# Read payload
		var data_result: Array = _tcp.get_data(rem_len)
		if data_result[0] != OK:
			break
		var data: PackedByteArray = data_result[1] as PackedByteArray

		if ptype == MQTT_PUBLISH:
			_handle_publish(data)
		# CONNACK, SUBACK, PINGRESP — acknowledged silently

	# Trim buffer
	while _received.size() > max_msg:
		_received = _received.slice(1)


func _handle_publish(data: PackedByteArray) -> void:
	if data.size() < 2:
		return
	# Topic length (2 bytes big-endian)
	var topic_len: int = (data[0] << 8) | data[1]
	if 2 + topic_len > data.size():
		return
	var topic: String = data.slice(2, 2 + topic_len).get_string_from_utf8()
	var payload_start: int = 2 + topic_len
	var msg: String = ""
	if payload_start < data.size():
		msg = data.slice(payload_start).get_string_from_utf8()
	_received.append("%s\t%s" % [topic, msg])


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _append_utf8(buf: PackedByteArray, text: String) -> void:
	var encoded: PackedByteArray = text.to_utf8_buffer()
	buf.append((encoded.size() >> 8) & 0xFF)
	buf.append(encoded.size() & 0xFF)
	buf.append_array(encoded)


func _encode_remaining_length(buf: PackedByteArray, length: int) -> void:
	var val: int = length
	for _i in range(4):
		var byte: int = val & 0x7F
		val >>= 7
		if val > 0:
			byte |= 0x80
		buf.append(byte)
		if val == 0:
			break


func _read_remaining_length() -> int:
	var result: int = 0
	var shift: int = 0
	for _i in range(4):
		if _tcp.get_available_bytes() == 0:
			return -1
		var byte_result: Array = _tcp.get_data(1)
		if byte_result[0] != OK or (byte_result[1] as PackedByteArray).size() == 0:
			return -1
		var byte: int = (byte_result[1] as PackedByteArray)[0]
		result |= (byte & 0x7F) << shift
		shift += 7
		if (byte & 0x80) == 0:
			return result
	return -1


func _build_output() -> GNData:
	var tbl: GNTableData = _prepare_table()
	tbl.has_header = true
	tbl.is_table = true
	tbl.table.append(PackedStringArray(["topic", "message"]))
	for line in _received:
		var parts: PackedStringArray = line.split("\t", true, 1)
		if parts.size() == 2:
			tbl.table.append(PackedStringArray([parts[0], parts[1]]))
		else:
			tbl.table.append(PackedStringArray(["", line]))
	return tbl


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect()
