class_name GroupSOP
extends GNSopBase
## Creates and manages point and primitive groups on geometry.
## Groups are stored as point_attribs on GNGeoData (1.0 = in group, 0.0 = not).
## Supports selection by bounding box, normal direction, or expression-like range.

func _init() -> void:
	node_type = "group"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Geometry with updated groups", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("group_name", "group1", "Group Name",
		"Name of the group to create / modify"))
	add_parameter(GNParameter.create_enum("entity",
		PackedStringArray(["Points", "Primitives"]), 0, "Entity",
		"Select points or primitives"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Bounding Box", "Normal Direction", "Range Pattern", "All"]),
		0, "Method", "Selection criterion"))
	# Bounding box params
	add_parameter(GNParameter.create_float("bb_min_x", -0.5, null, null, 0.01, "BB Min X", "Bounding box minimum X"))
	add_parameter(GNParameter.create_float("bb_min_y", -0.5, null, null, 0.01, "BB Min Y", "Bounding box minimum Y"))
	add_parameter(GNParameter.create_float("bb_min_z", -0.5, null, null, 0.01, "BB Min Z", "Bounding box minimum Z"))
	add_parameter(GNParameter.create_float("bb_max_x", 0.5, null, null, 0.01, "BB Max X", "Bounding box maximum X"))
	add_parameter(GNParameter.create_float("bb_max_y", 0.5, null, null, 0.01, "BB Max Y", "Bounding box maximum Y"))
	add_parameter(GNParameter.create_float("bb_max_z", 0.5, null, null, 0.01, "BB Max Z", "Bounding box maximum Z"))
	# Normal direction params
	add_parameter(GNParameter.create_float("dir_x", 0.0, -1.0, 1.0, 0.01, "Direction X", "Normal direction X"))
	add_parameter(GNParameter.create_float("dir_y", 1.0, -1.0, 1.0, 0.01, "Direction Y", "Normal direction Y"))
	add_parameter(GNParameter.create_float("dir_z", 0.0, -1.0, 1.0, 0.01, "Direction Z", "Normal direction Z"))
	add_parameter(GNParameter.create_float("spread_angle", 45.0, 0.0, 180.0, 1.0,
		"Spread Angle", "Cone half-angle in degrees"))
	# Range pattern
	add_parameter(GNParameter.create_string("range_pattern", "0-9", "Range",
		"Point/prim index range (e.g. 0-9, 20, 30-40)"))
	# Operation
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Set", "Add", "Remove"]), 0, "Operation",
		"Set replaces, Add merges, Remove subtracts"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return _prepare_geo()

	# Duplicate so we don't modify upstream
	var geo: GNGeoData = in_geo.duplicate_data() as GNGeoData
	var group_name: String = get_param_value("group_name").strip_edges()
	if group_name.is_empty():
		return geo

	var entity: int = get_param_value("entity")
	var method: int = get_param_value("method")
	var operation: int = get_param_value("operation")

	# Only point groups are fully supported via point_attribs
	# Primitive groups use "prim_<name>" prefix
	var attrib_key: String = group_name if entity == 0 else ("prim_" + group_name)
	var count: int = _get_entity_count(geo, entity)

	# Get or create membership array
	var membership: PackedFloat32Array
	if operation == 0:  # Set — start fresh
		membership = PackedFloat32Array()
		membership.resize(count)
		membership.fill(0.0)
	else:
		membership = geo.get_point_attrib(attrib_key)
		if membership.size() != count:
			membership = PackedFloat32Array()
			membership.resize(count)
			membership.fill(0.0)

	# Build selection mask
	var selected: PackedFloat32Array = PackedFloat32Array()
	selected.resize(count)
	selected.fill(0.0)

	match method:
		0: _select_bounding_box(geo, entity, selected)
		1: _select_normal_direction(geo, entity, selected)
		2: _select_range(count, selected)
		3: selected.fill(1.0)

	# Apply operation
	for i in range(count):
		match operation:
			0: membership[i] = selected[i]              # Set
			1: membership[i] = maxf(membership[i], selected[i])  # Add
			2:  # Remove
				if selected[i] > 0.5:
					membership[i] = 0.0

	geo.set_point_attrib(attrib_key, membership)
	return geo


func _get_entity_count(geo: GNGeoData, entity: int) -> int:
	if geo.mesh == null:
		return 0
	if entity == 0:  # Points
		return geo.vertex_count
	else:  # Primitives (triangles)
		var total := 0
		for s in range(geo.mesh.get_surface_count()):
			var arrays: Array = geo.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_INDEX] != null:
				total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif arrays[Mesh.ARRAY_VERTEX] != null:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		return total


func _select_bounding_box(geo: GNGeoData, entity: int, selected: PackedFloat32Array) -> void:
	var bb_min := Vector3(get_param_value("bb_min_x"), get_param_value("bb_min_y"), get_param_value("bb_min_z"))
	var bb_max := Vector3(get_param_value("bb_max_x"), get_param_value("bb_max_y"), get_param_value("bb_max_z"))
	var aabb := AABB(bb_min, bb_max - bb_min)

	if entity == 0:  # Points
		var idx := 0
		for s in range(geo.mesh.get_surface_count()):
			var verts: PackedVector3Array = geo.get_positions(s)
			for v in verts:
				if idx < selected.size() and aabb.has_point(v):
					selected[idx] = 1.0
				idx += 1
	else:  # Primitives — select if centroid is inside
		var prim_idx := 0
		for s in range(geo.mesh.get_surface_count()):
			var arrays: Array = geo.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in range(0, verts.size(), 3):
					var c: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
					if prim_idx < selected.size() and aabb.has_point(c):
						selected[prim_idx] = 1.0
					prim_idx += 1
			else:
				for i in range(0, indices.size(), 3):
					var c: Vector3 = (verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]]) / 3.0
					if prim_idx < selected.size() and aabb.has_point(c):
						selected[prim_idx] = 1.0
					prim_idx += 1


func _select_normal_direction(geo: GNGeoData, entity: int, selected: PackedFloat32Array) -> void:
	var direction := Vector3(get_param_value("dir_x"), get_param_value("dir_y"), get_param_value("dir_z")).normalized()
	var spread_cos: float = cos(deg_to_rad(get_param_value("spread_angle")))

	if entity == 0:  # Points
		var idx := 0
		for s in range(geo.mesh.get_surface_count()):
			var normals: PackedVector3Array = geo.get_normals(s)
			for i in range(normals.size()):
				if idx < selected.size() and normals[i].dot(direction) >= spread_cos:
					selected[idx] = 1.0
				idx += 1
	else:  # Primitives
		var prim_idx := 0
		for s in range(geo.mesh.get_surface_count()):
			var arrays: Array = geo.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in range(0, verts.size(), 3):
					var face_n: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).normalized()
					if prim_idx < selected.size() and face_n.dot(direction) >= spread_cos:
						selected[prim_idx] = 1.0
					prim_idx += 1
			else:
				for i in range(0, indices.size(), 3):
					var a: Vector3 = verts[indices[i]]
					var b: Vector3 = verts[indices[i + 1]]
					var c: Vector3 = verts[indices[i + 2]]
					var face_n: Vector3 = (b - a).cross(c - a).normalized()
					if prim_idx < selected.size() and face_n.dot(direction) >= spread_cos:
						selected[prim_idx] = 1.0
					prim_idx += 1


func _select_range(count: int, selected: PackedFloat32Array) -> void:
	var pattern: String = get_param_value("range_pattern").strip_edges()
	if pattern.is_empty():
		return

	for part in pattern.split(","):
		part = part.strip_edges()
		if part.contains("-"):
			var range_parts: PackedStringArray = part.split("-")
			if range_parts.size() == 2:
				var from_idx: int = maxi(0, range_parts[0].to_int())
				var to_idx: int = mini(count - 1, range_parts[1].to_int())
				for i in range(from_idx, to_idx + 1):
					if i < selected.size():
						selected[i] = 1.0
		else:
			var idx: int = part.to_int()
			if idx >= 0 and idx < count:
				selected[idx] = 1.0
