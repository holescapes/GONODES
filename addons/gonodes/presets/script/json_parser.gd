# @param string json_text {"items":[1,2,3]} JSON string to parse
# @param bool flatten true Flatten nested keys with dot notation

func cook():
	var json := JSON.new()
	var err := json.parse(par("json_text"))
	if err != OK:
		op.set_headers(PackedStringArray(["error"]))
		op.append_row(PackedStringArray(["Parse error: " + json.get_error_message()]))
		return

	var data = json.data
	op.set_headers(PackedStringArray(["key", "value", "type"]))

	if data is Dictionary:
		_emit_dict(data, "")
	elif data is Array:
		for i in range(data.size()):
			op.append_row(PackedStringArray(["[%d]" % i, str(data[i]), _type_name(data[i])]))
	else:
		op.append_row(PackedStringArray(["root", str(data), _type_name(data)]))

func _emit_dict(d: Dictionary, prefix: String):
	for key in d:
		var full_key: String = (prefix + "." + str(key)) if not prefix.is_empty() else str(key)
		var val = d[key]
		if val is Dictionary and par("flatten"):
			_emit_dict(val, full_key)
		else:
			op.append_row(PackedStringArray([full_key, str(val), _type_name(val)]))

func _type_name(v) -> String:
	if v is float or v is int:
		return "number"
	if v is String:
		return "string"
	if v is bool:
		return "bool"
	if v is Array:
		return "array[%d]" % v.size()
	if v is Dictionary:
		return "dict[%d]" % v.size()
	return "null" if v == null else typeof(v)
