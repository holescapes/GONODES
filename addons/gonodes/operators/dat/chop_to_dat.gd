class_name CHOPDAT
extends GNDatBase
## Converts CHOP channel data into a DAT table.
## Each channel becomes a column; each sample becomes a row.
## Bridge operator: CHOP input → DAT output.


func _init() -> void:
	node_type = "chop_to_dat"


func _init_ports() -> void:
	add_input("chop_in", GNFamily.Type.CHOP, false, "CHOP channel input", "CHOP")
	add_output("out", GNFamily.Type.DAT, "Table output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("layout",
		PackedStringArray(["Channels as Columns", "Channels as Rows"]), 0, "Layout", "Table orientation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_in: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if chop_in == null:
		return null

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()
	_cached_table.is_table = true
	_cached_table.has_header = true

	var ch_names: PackedStringArray = chop_in.get_channel_names()
	var layout: int = get_param_value("layout")

	if layout == 0:
		# Channels as columns: header = channel names, rows = samples
		_cached_table.set_headers(ch_names)

		var max_len: int = 0
		for ch_name in ch_names:
			var ch: PackedFloat32Array = chop_in.get_channel(ch_name)
			max_len = maxi(max_len, ch.size())

		for s in range(max_len):
			var row := PackedStringArray()
			for ch_name in ch_names:
				var ch: PackedFloat32Array = chop_in.get_channel(ch_name)
				if s < ch.size():
					row.append("%.6f" % ch[s])
				else:
					row.append("0")
			_cached_table.append_row(row)
	else:
		# Channels as rows: header = ["channel", "sample0", "sample1", ...]
		var max_len: int = 0
		for ch_name in ch_names:
			var ch: PackedFloat32Array = chop_in.get_channel(ch_name)
			max_len = maxi(max_len, ch.size())

		var headers := PackedStringArray(["channel"])
		for s in range(max_len):
			headers.append("s%d" % s)
		_cached_table.set_headers(headers)

		for ch_name in ch_names:
			var row := PackedStringArray([ch_name])
			var ch: PackedFloat32Array = chop_in.get_channel(ch_name)
			for s in range(max_len):
				if s < ch.size():
					row.append("%.6f" % ch[s])
				else:
					row.append("0")
			_cached_table.append_row(row)

	return _cached_table
