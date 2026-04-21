class_name AreaCHOP
extends GNChopBase
## Calculates the area under channel curves via numerical integration.
## Supports trapezoidal, Simpson's, and rectangle rules.
## In cumulative mode, outputs running integral per sample.


func _init() -> void:
	node_type = "area"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to integrate")
	add_output("out", GNFamily.Type.CHOP, "Integrated area values")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Trapezoidal", "Simpson's", "Rectangle"]), 0,
		"Method", "Integration method"))
	add_parameter(GNParameter.create_bool("cumulative", false,
		"Cumulative", "Output running integral per sample instead of total area"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data := _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var method: int = get_param_value("method")
	var cumulative: bool = get_param_value("cumulative")
	var dt: float = 1.0 / maxf(in_data.sample_rate, 1.0)

	var out := _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var n: int = samples.size()
		if n < 2:
			out.channels[ch_name] = PackedFloat32Array([0.0])
			continue

		if cumulative:
			var cum := PackedFloat32Array()
			cum.resize(n)
			cum[0] = 0.0
			for i in range(1, n):
				cum[i] = cum[i - 1] + _segment_area(samples, i - 1, i, dt, method)
			out.channels[ch_name] = cum
		else:
			var area: float = 0.0
			if method == 1 and n >= 3 and (n - 1) % 2 == 0:
				# Simpson's rule for even number of intervals
				for i in range(0, n - 2, 2):
					area += (dt / 3.0) * (samples[i] + 4.0 * samples[i + 1] + samples[i + 2])
			else:
				for i in range(1, n):
					area += _segment_area(samples, i - 1, i, dt, method)
			out.channels[ch_name] = PackedFloat32Array([area])

	out.length = in_data.length if cumulative else 1
	return out


func _segment_area(samples: PackedFloat32Array, i0: int, i1: int, dt: float, method: int) -> float:
	match method:
		0: return 0.5 * (samples[i0] + samples[i1]) * dt  # Trapezoidal
		2: return samples[i0] * dt  # Rectangle (left)
		_: return 0.5 * (samples[i0] + samples[i1]) * dt  # Fallback trapezoidal
