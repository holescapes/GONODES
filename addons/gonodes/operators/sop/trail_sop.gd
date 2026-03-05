class_name TrailSOP
extends GNSopBase
## Records the centroid of input geometry over time and outputs
## the trail as a line-strip mesh. Useful for motion trails and
## trajectory visualization.

var _trail_points: PackedVector3Array = PackedVector3Array()
var _write_idx: int = 0
var _filled: bool = false


func _init() -> void:
	node_type = "trail"
	time_dependent = true
	node_description = "Record input centroid as a line trail over time."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Trail line mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 60, 2, 3600,
		"Trail Length", "Number of frames to record"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable recording of new trail points"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var trail_len: int = get_param_value("length")
	var active: bool = get_param_value("active")

	# Resize ring buffer if length changed
	if _trail_points.size() != trail_len:
		_trail_points.resize(trail_len)
		_write_idx = 0
		_filled = false

	# Compute centroid of input
	if active:
		var positions: PackedVector3Array = in_geo.get_positions()
		if positions.size() > 0:
			var centroid := Vector3.ZERO
			for p in positions:
				centroid += p
			centroid /= float(positions.size())
			_trail_points[_write_idx] = centroid
			_write_idx = (_write_idx + 1) % trail_len
			if _write_idx == 0:
				_filled = true

	# Determine how many valid points we have
	var count: int = trail_len if _filled else _write_idx
	if count < 2:
		return out

	# Build line strip from ring buffer in chronological order
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)

	var start_idx: int = _write_idx if _filled else 0
	for i in range(count):
		var idx: int = (start_idx + i) % trail_len
		var t: float = float(i) / float(count - 1)
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(_trail_points[idx])

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	out.set_mesh(arr_mesh)
	return out
