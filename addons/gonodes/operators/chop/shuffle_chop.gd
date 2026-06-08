class_name ShuffleCHOP
extends GNChopBase
## Reorders, reverses, or sorts channels by name or value.
## Also supports interleaving channels from multiple-channel inputs.


func _init() -> void:
	node_type = "shuffle"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Reordered channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Reverse", "Sort by Name", "Sort by Value", "Random"]),
		0, "", "Reorder method"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed",
		"Random seed (Random mode)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var method: int = get_param_value("method")
	var seed_val: int = get_param_value("seed")

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	var names: Array = []
	for ch in in_data.channels:
		names.append(ch)

	match method:
		0:  # Reverse
			names.reverse()
		1:  # Sort by Name
			names.sort()
		2:  # Sort by Value (ascending by last sample)
			names.sort_custom(func(a: String, b: String) -> bool:
				var va: float = in_data.get_value(a, -1)
				var vb: float = in_data.get_value(b, -1)
				return va < vb)
		3:  # Random (Fisher-Yates with seed)
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_val
			for i in range(names.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp = names[i]
				names[i] = names[j]
				names[j] = tmp

	for ch_name in names:
		out.set_channel(ch_name, in_data.channels[ch_name])

	return out
