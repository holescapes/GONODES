class_name InterpolateCHOP
extends GNChopBase
## Interpolates between two CHOP inputs using a blend factor (0=A, 1=B).
## Supports linear, ease-in, ease-out, ease-in-out, and smooth-step curves.


func _init() -> void:
	node_type = "interpolate"


func _init_ports() -> void:
	add_input("a", GNFamily.Type.CHOP, false, "Channel set A", "A")
	add_input("b", GNFamily.Type.CHOP, false, "Channel set B", "B")
	add_output("out", GNFamily.Type.CHOP, "Blended channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blend", 0.5, 0.0, 1.0, 0.01,
		"Blend (0=A, 1=B)", "Interpolation factor"))
	add_parameter(GNParameter.create_enum("curve",
		PackedStringArray(["Linear", "Ease In", "Ease Out", "Ease In-Out", "Smooth Step"]),
		0, "", "Easing curve"))


func _cook(inputs: Array[GNData]) -> GNData:
	var data_a: GNChannelData = _get_input_chop(inputs, 0)
	var data_b: GNChannelData = _get_input_chop(inputs, 1)
	if data_a == null and data_b == null:
		return null

	var t: float = clampf(get_param_value("blend"), 0.0, 1.0)
	var curve: int = get_param_value("curve")

	# Apply easing curve
	var eased_t: float = _apply_easing(t, curve)

	var sr: float = 60.0
	if data_a != null:
		sr = data_a.sample_rate
	elif data_b != null:
		sr = data_b.sample_rate
	var out: GNChannelData = _prepare_output(sr)

	# Collect all channel names from both inputs
	var all_names: Dictionary = {}
	if data_a != null:
		for ch in data_a.channels:
			all_names[ch] = true
	if data_b != null:
		for ch in data_b.channels:
			all_names[ch] = true

	for ch_name in all_names:
		var val_a: float = 0.0
		var val_b: float = 0.0

		if data_a != null and data_a.channels.has(ch_name):
			var sa: PackedFloat32Array = data_a.channels[ch_name]
			if not sa.is_empty():
				val_a = sa[sa.size() - 1]

		if data_b != null and data_b.channels.has(ch_name):
			var sb: PackedFloat32Array = data_b.channels[ch_name]
			if not sb.is_empty():
				val_b = sb[sb.size() - 1]

		out.set_single_value(ch_name, lerpf(val_a, val_b, eased_t))

	return out


func _apply_easing(t: float, curve: int) -> float:
	match curve:
		0:  # Linear
			return t
		1:  # Ease In (quadratic)
			return t * t
		2:  # Ease Out (quadratic)
			return t * (2.0 - t)
		3:  # Ease In-Out (cubic)
			if t < 0.5:
				return 4.0 * t * t * t
			else:
				return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5
		4:  # Smooth Step (Hermite)
			return t * t * (3.0 - 2.0 * t)
		_:
			return t
