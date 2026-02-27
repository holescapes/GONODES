class_name GNOscParser
extends RefCounted
## Lightweight OSC 1.0 message parser/builder.
## Handles the binary wire format: 4-byte aligned strings, type tags, and
## the common argument types (int32, float32, string, blob).
##
## Reference: https://opensoundcontrol.stanford.edu/spec-1_0.html

# ─── Data types ────────────────────────────────────────────────────────────────

## Parsed OSC message.
class OscMessage:
	var address: String = ""
	var args: Array = []           # Array of Variant (int, float, String, PackedByteArray)
	var type_tags: String = ""     # e.g. "ifs" for int, float, string


# ─── Encoding ─────────────────────────────────────────────────────────────────

## Encode an OSC message to a PackedByteArray ready for UDP transmission.
static func encode(address: String, args: Array = []) -> PackedByteArray:
	var buf := PackedByteArray()

	# Address pattern (must start with '/')
	_write_osc_string(buf, address)

	# Type tag string: starts with ','
	var tags := ","
	for arg in args:
		if arg is int:
			tags += "i"
		elif arg is float:
			tags += "f"
		elif arg is String:
			tags += "s"
		elif arg is PackedByteArray:
			tags += "b"
		else:
			tags += "s"  # Fallback: convert to string
	_write_osc_string(buf, tags)

	# Arguments
	for i in range(args.size()):
		var arg = args[i]
		var tag: String = tags[i + 1]  # Skip leading ','
		match tag:
			"i":
				_write_int32(buf, int(arg))
			"f":
				_write_float32(buf, float(arg))
			"s":
				_write_osc_string(buf, str(arg))
			"b":
				_write_blob(buf, arg as PackedByteArray)

	return buf


## Encode an OSC bundle (timetag + array of messages).
## [param timetag] is NTP timestamp as 64-bit int (0 = immediately).
static func encode_bundle(messages: Array[PackedByteArray], timetag: int = 1) -> PackedByteArray:
	var buf := PackedByteArray()
	_write_osc_string(buf, "#bundle")
	_write_int64(buf, timetag)
	for msg in messages:
		_write_int32(buf, msg.size())
		buf.append_array(msg)
	return buf


# ─── Decoding ─────────────────────────────────────────────────────────────────

## Decode a single OSC message from raw bytes.
## Returns null if the data is not a valid OSC message.
static func decode(data: PackedByteArray) -> OscMessage:
	if data.size() < 4:
		return null

	var offset: int = 0

	# Check for bundle
	if data[0] == 0x23:  # '#'
		return _decode_first_bundle_message(data)

	# Address pattern
	var addr_result: Array = _read_osc_string(data, offset)
	if addr_result.is_empty():
		return null
	var address: String = addr_result[0]
	offset = addr_result[1]

	if not address.begins_with("/"):
		return null

	# Type tag string (optional — some OSC sources omit it)
	var type_tags: String = ""
	var args: Array = []

	if offset < data.size() and data[offset] == 0x2C:  # ','
		var tag_result: Array = _read_osc_string(data, offset)
		if tag_result.is_empty():
			return null
		type_tags = (tag_result[0] as String).substr(1)  # Strip leading ','
		offset = tag_result[1]

		# Parse arguments based on type tags
		for tag_char in type_tags:
			match tag_char:
				"i":
					if offset + 4 > data.size():
						break
					args.append(_read_int32(data, offset))
					offset += 4
				"f":
					if offset + 4 > data.size():
						break
					args.append(_read_float32(data, offset))
					offset += 4
				"s":
					var s_result: Array = _read_osc_string(data, offset)
					if s_result.is_empty():
						break
					args.append(s_result[0])
					offset = s_result[1]
				"b":
					if offset + 4 > data.size():
						break
					var blob_len: int = _read_int32(data, offset)
					offset += 4
					if offset + blob_len > data.size():
						break
					args.append(data.slice(offset, offset + blob_len))
					offset += blob_len
					offset = _pad4(offset)
				"T":
					args.append(true)
				"F":
					args.append(false)
				"N":
					args.append(null)
				_:
					pass  # Unknown type tag — skip

	var msg := OscMessage.new()
	msg.address = address
	msg.args = args
	msg.type_tags = type_tags
	return msg


## Decode all messages from data (handles both single messages and bundles).
static func decode_all(data: PackedByteArray) -> Array[OscMessage]:
	var result: Array[OscMessage] = []
	if data.size() < 4:
		return result

	if data[0] == 0x23:  # '#' — bundle
		var msgs: Array[OscMessage] = _decode_bundle(data)
		result.append_array(msgs)
	else:
		var msg: OscMessage = decode(data)
		if msg != null:
			result.append(msg)
	return result


# ─── Bundle decoding ──────────────────────────────────────────────────────────

static func _decode_first_bundle_message(data: PackedByteArray) -> OscMessage:
	var msgs: Array[OscMessage] = _decode_bundle(data)
	if msgs.is_empty():
		return null
	return msgs[0]


static func _decode_bundle(data: PackedByteArray) -> Array[OscMessage]:
	var result: Array[OscMessage] = []
	# Skip "#bundle\0" (8 bytes) + timetag (8 bytes) = 16 bytes header
	if data.size() < 16:
		return result

	var offset: int = 16
	while offset + 4 <= data.size():
		var elem_size: int = _read_int32(data, offset)
		offset += 4
		if elem_size <= 0 or offset + elem_size > data.size():
			break
		var elem_data: PackedByteArray = data.slice(offset, offset + elem_size)
		var msgs: Array[OscMessage] = decode_all(elem_data)
		result.append_array(msgs)
		offset += elem_size
	return result


# ─── Wire format helpers ──────────────────────────────────────────────────────

## Round up to next 4-byte boundary.
static func _pad4(n: int) -> int:
	return (n + 3) & ~3


## Write a null-terminated, 4-byte-aligned OSC string.
static func _write_osc_string(buf: PackedByteArray, s: String) -> void:
	var bytes: PackedByteArray = s.to_utf8_buffer()
	buf.append_array(bytes)
	# Null terminator + padding to 4-byte boundary
	var padded_len: int = _pad4(bytes.size() + 1)
	var pad_count: int = padded_len - bytes.size()
	for _i in range(pad_count):
		buf.append(0)


## Write a big-endian int32.
static func _write_int32(buf: PackedByteArray, value: int) -> void:
	buf.append((value >> 24) & 0xFF)
	buf.append((value >> 16) & 0xFF)
	buf.append((value >> 8) & 0xFF)
	buf.append(value & 0xFF)


## Write a big-endian int64 (for NTP timetag).
static func _write_int64(buf: PackedByteArray, value: int) -> void:
	_write_int32(buf, (value >> 32) & 0xFFFFFFFF)
	_write_int32(buf, value & 0xFFFFFFFF)


## Write a big-endian IEEE 754 float32.
static func _write_float32(buf: PackedByteArray, value: float) -> void:
	var tmp := PackedFloat32Array([value])
	var raw: PackedByteArray = tmp.to_byte_array()
	# Godot stores little-endian — reverse to big-endian for OSC
	buf.append(raw[3])
	buf.append(raw[2])
	buf.append(raw[1])
	buf.append(raw[0])


## Write a blob (int32 size + data + padding).
static func _write_blob(buf: PackedByteArray, data: PackedByteArray) -> void:
	_write_int32(buf, data.size())
	buf.append_array(data)
	var pad_count: int = _pad4(data.size()) - data.size()
	for _i in range(pad_count):
		buf.append(0)


## Read a null-terminated, 4-byte-aligned OSC string.
## Returns [string, new_offset] or empty array on failure.
static func _read_osc_string(data: PackedByteArray, offset: int) -> Array:
	var end: int = offset
	while end < data.size() and data[end] != 0:
		end += 1
	if end >= data.size():
		return []
	var s: String = data.slice(offset, end).get_string_from_utf8()
	var new_offset: int = _pad4(end + 1)
	return [s, new_offset]


## Read a big-endian int32.
static func _read_int32(data: PackedByteArray, offset: int) -> int:
	var value: int = (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]
	# Handle sign bit for int32
	if value >= 0x80000000:
		value -= 0x100000000
	return value


## Read a big-endian IEEE 754 float32.
static func _read_float32(data: PackedByteArray, offset: int) -> float:
	# Reverse big-endian to little-endian for Godot
	var raw := PackedByteArray([data[offset + 3], data[offset + 2], data[offset + 1], data[offset]])
	var tmp: PackedFloat32Array = raw.to_float32_array()
	return tmp[0]
