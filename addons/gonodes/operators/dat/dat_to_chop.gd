class_name DATtoCHOP
extends GNChopBase
## Converts a DAT table into CHOP channel data.
## Each column (or row, depending on layout) becomes a channel.
## Bridge operator: DAT input → CHOP output.


func _init() -> void:
	node_type = "dat_to_chop"
	node_description = "Convert DAT table into CHOP channels."


func _init_ports() -> void:
	add_input("dat_in", GNFamily.Type.DAT, false, "DAT table input")
	add_output("out", GNFamily.Type.CHOP, "Channel data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("layout",
		PackedStringArray(["Columns as Channels", "Rows as Channels"]), 0, "Layout", "Read channels from columns or rows"))
	add_parameter(GNParameter.create_bool("first_is_name", true, "First Row/Col is Name", "Use first row/col as channel names"))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat_in: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if dat_in == null or not dat_in.is_table:
		return null

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	var layout: int = get_param_value("layout")
	var first_is_name: bool = get_param_value("first_is_name")

	if layout == 0:
		# Columns as channels
		var num_cols: int = dat_in.num_cols()
		var data_start: int = 1 if dat_in.has_header else 0
		var headers: PackedStringArray = dat_in.get_headers() if dat_in.has_header else PackedStringArray()

		for c in range(num_cols):
			var ch_name: String = headers[c] if c < headers.size() and first_is_name else "chan%d" % c
			var samples := PackedFloat32Array()
			for r in range(data_start, dat_in.table.size()):
				if c < dat_in.table[r].size():
					var val: String = dat_in.table[r][c]
					samples.append(val.to_float() if val.is_valid_float() else 0.0)
				else:
					samples.append(0.0)
			_cached_channel_data.set_channel(ch_name, samples)
	else:
		# Rows as channels
		var data_start: int = 1 if dat_in.has_header else 0
		for r in range(data_start, dat_in.table.size()):
			var row: PackedStringArray = dat_in.table[r]
			var ch_name: String = row[0] if first_is_name and not row.is_empty() else "chan%d" % (r - data_start)
			var samples := PackedFloat32Array()
			var s_start: int = 1 if first_is_name else 0
			for c in range(s_start, row.size()):
				samples.append(row[c].to_float() if row[c].is_valid_float() else 0.0)
			_cached_channel_data.set_channel(ch_name, samples)

	return _cached_channel_data
