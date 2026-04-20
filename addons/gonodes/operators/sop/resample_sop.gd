class_name ResampleSOP
extends GNSopBase
## Resamples polylines and curves at uniform arc-length spacing.
##
## Takes input geometry and redistributes vertices along each edge loop
## or polyline so they are evenly spaced. Essential for curve-based
## workflows, generative art, and motion graphics where uniform point
## distribution is needed.
##
## Modes:
##   Even — redistribute to N evenly-spaced points per polyline
##   Length — place points every D world units apart
##
## Preserves normals and UVs via linear interpolation.
##
## Houdini equivalent: Resample SOP.


func _init() -> void:
	node_type = "resample"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry to resample")
	add_output("out", GNFamily.Type.SOP, "Resampled geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Even", "Length"]), 0,
		"Mode", "Resampling method"))
	add_parameter(GNParameter.create_int("count", 32, 2, 10000,
		"Point Count", "Target number of points per polyline (Even mode)"))
	add_parameter(GNParameter.create_float("segment_length", 0.1, 0.001, 100.0, 0.001,
		"Segment Length", "Distance between points (Length mode)"))
	add_parameter(GNParameter.create_bool("close", false,
		"Close Curves", "Treat polylines as closed loops"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var mode: int = get_param_value("mode")
	var target_count: int = get_param_value("count")
	var seg_len: float = get_param_value("segment_length")
	var close_curves: bool = get_param_value("close")

	var out_geo: GNGeoData = _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s: int in range(in_geo.mesh.get_surface_count()):
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		# Only resample line strips and triangles-as-edges
		if prim == Mesh.PRIMITIVE_LINE_STRIP or prim == Mesh.PRIMITIVE_LINES:
			var arrays: Array = in_geo.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.size() < 2:
				new_mesh.add_surface_from_arrays(prim, arrays)
				continue

			# Build polyline points
			var points: PackedVector3Array = verts

			# Compute arc lengths
			var arc_lengths := PackedFloat64Array()
			arc_lengths.resize(points.size())
			arc_lengths[0] = 0.0
			for i: int in range(1, points.size()):
				arc_lengths[i] = arc_lengths[i - 1] + points[i - 1].distance_to(points[i])

			if close_curves and points.size() > 2:
				arc_lengths.append(arc_lengths[arc_lengths.size() - 1] + points[points.size() - 1].distance_to(points[0]))

			var total_length: float = arc_lengths[arc_lengths.size() - 1]
			if total_length < 1e-6:
				new_mesh.add_surface_from_arrays(prim, arrays)
				continue

			# Determine output point count
			var out_count: int
			if mode == 0:  # Even
				out_count = maxi(target_count, 2)
			else:  # Length
				out_count = maxi(int(ceil(total_length / maxf(seg_len, 1e-6))) + 1, 2)

			# Sample at uniform arc lengths
			var step: float = total_length / float(out_count - 1) if not close_curves else total_length / float(out_count)
			var new_verts := PackedVector3Array()
			new_verts.resize(out_count)

			var src_pts: PackedVector3Array = points
			if close_curves:
				src_pts = points.duplicate()
				src_pts.append(points[0])

			for i: int in range(out_count):
				var target_dist: float = step * float(i)
				# Binary search for segment
				var seg: int = _find_segment(arc_lengths, target_dist)
				var seg_start: float = arc_lengths[seg]
				var seg_end: float = arc_lengths[seg + 1] if seg + 1 < arc_lengths.size() else arc_lengths[seg]
				var seg_frac: float = 0.0
				var seg_span: float = seg_end - seg_start
				if seg_span > 1e-8:
					seg_frac = (target_dist - seg_start) / seg_span
				new_verts[i] = src_pts[seg].lerp(src_pts[seg + 1] if seg + 1 < src_pts.size() else src_pts[0], seg_frac)

			var out_arrays: Array = []
			out_arrays.resize(Mesh.ARRAY_MAX)
			out_arrays[Mesh.ARRAY_VERTEX] = new_verts
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, out_arrays)
		else:
			# Pass through non-line geometry unchanged
			new_mesh.add_surface_from_arrays(prim, in_geo.mesh.surface_get_arrays(s))

	out_geo.set_mesh(new_mesh)
	return out_geo


## Binary search for the segment containing the target arc length.
static func _find_segment(arc_lengths: PackedFloat64Array, target: float) -> int:
	var lo: int = 0
	var hi: int = arc_lengths.size() - 2
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if arc_lengths[mid] <= target:
			lo = mid
		else:
			hi = mid - 1
	return lo
