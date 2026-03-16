class_name InstancePOP
extends GNPopBase
## Copies SOP geometry onto each particle position.
## Bridge operator: reads POP SSBO → outputs GNGeoData (SOP) via CPU readback.

func _init() -> void:
	super._init()
	node_type = "instance"
	node_description = "Copy SOP geometry onto each particle. Outputs SOP geometry."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_input("geo_in", GNFamily.Type.SOP, false, "Instance geometry")
	add_output("out", GNFamily.Type.SOP, "Instanced geometry output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_instances", 10000,
		1, 100000, "Max Instances", "Maximum instances to generate (limits CPU load)"))
	add_parameter(GNParameter.create_bool("use_pscale", true, "Use pscale",
		"Scale instances by the particle pscale attribute"))
	add_parameter(GNParameter.create_bool("use_color", true, "Use Color",
		"Apply particle color attribute to instance vertex colors"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var geo: GNGeoData = null
	if inputs.size() > 1 and inputs[1] is GNGeoData:
		geo = inputs[1] as GNGeoData
	if geo == null or not geo.has_geometry():
		return null

	# CPU readback — positions + pscale
	var positions: PackedVector3Array = pd.read_positions()
	var pscales: PackedFloat32Array = pd.read_float_attrib("pscale") if get_param_value("use_pscale") else PackedFloat32Array()

	var max_inst: int = mini(get_param_value("max_instances"), positions.size())
	if max_inst <= 0:
		return null

	# Build instanced mesh — transform source geometry by each particle's position
	var source_mesh: Mesh = geo.mesh
	if source_mesh.get_surface_count() == 0:
		return null

	var src_arrays: Array = source_mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = src_arrays[Mesh.ARRAY_NORMAL] if src_arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
	var has_normals: bool = src_normals.size() == src_verts.size()
	var src_indices: PackedInt32Array = src_arrays[Mesh.ARRAY_INDEX] if src_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
	var src_vert_count: int = src_verts.size()

	var all_verts := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_indices := PackedInt32Array()
	all_verts.resize(src_vert_count * max_inst)
	if has_normals:
		all_normals.resize(src_vert_count * max_inst)
	var has_indices: bool = src_indices.size() > 0
	if has_indices:
		all_indices.resize(src_indices.size() * max_inst)

	var use_color: bool = get_param_value("use_color")
	var colors: PackedFloat32Array = pd.read_float_attrib("color") if use_color else PackedFloat32Array()
	var all_colors := PackedColorArray()
	if use_color:
		all_colors.resize(src_vert_count * max_inst)

	for i in range(max_inst):
		var xform := Transform3D.IDENTITY
		xform.origin = positions[i]
		if pscales.size() > i:
			var s: float = pscales[i]
			xform.basis = xform.basis.scaled(Vector3(s, s, s))

		var base_v: int = i * src_vert_count
		for v in range(src_vert_count):
			all_verts[base_v + v] = xform * src_verts[v]
		if has_normals:
			var basis := xform.basis
			for v in range(src_vert_count):
				all_normals[base_v + v] = (basis * src_normals[v]).normalized()
		if has_indices:
			var base_i: int = i * src_indices.size()
			for idx in range(src_indices.size()):
				all_indices[base_i + idx] = src_indices[idx] + base_v
		if use_color and colors.size() >= (i + 1) * 4:
			var c := Color(colors[i * 4], colors[i * 4 + 1], colors[i * 4 + 2], colors[i * 4 + 3])
			for v in range(src_vert_count):
				all_colors[base_v + v] = c

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_verts
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = all_normals
	if has_indices:
		arrays[Mesh.ARRAY_INDEX] = all_indices
	if use_color and all_colors.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = all_colors

	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var out := GNGeoData.new()
	out.set_mesh(out_mesh)
	return out


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	# CPU fallback — identical logic but reads from CPU arrays directly
	var pd := _get_input_pop_cpu(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var geo: GNGeoData = null
	if inputs.size() > 1 and inputs[1] is GNGeoData:
		geo = inputs[1] as GNGeoData
	if geo == null or not geo.has_geometry():
		return null

	var positions: PackedVector3Array = pd.cpu_positions.slice(0, pd.particle_count)
	var pscales: PackedFloat32Array = pd.cpu_pscales.slice(0, pd.particle_count) if get_param_value("use_pscale") else PackedFloat32Array()

	var max_inst: int = mini(get_param_value("max_instances"), positions.size())
	if max_inst <= 0:
		return null

	var source_mesh: Mesh = geo.mesh
	if source_mesh.get_surface_count() == 0:
		return null

	var src_arrays: Array = source_mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = src_arrays[Mesh.ARRAY_NORMAL] if src_arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
	var has_normals: bool = src_normals.size() == src_verts.size()
	var src_indices: PackedInt32Array = src_arrays[Mesh.ARRAY_INDEX] if src_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
	var src_vert_count: int = src_verts.size()

	var all_verts := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_indices := PackedInt32Array()
	all_verts.resize(src_vert_count * max_inst)
	if has_normals:
		all_normals.resize(src_vert_count * max_inst)
	var has_indices: bool = src_indices.size() > 0
	if has_indices:
		all_indices.resize(src_indices.size() * max_inst)

	var use_color: bool = get_param_value("use_color")
	var all_colors := PackedColorArray()
	if use_color:
		all_colors.resize(src_vert_count * max_inst)

	for i in range(max_inst):
		var xform := Transform3D.IDENTITY
		xform.origin = positions[i]
		if pscales.size() > i:
			var s: float = pscales[i]
			xform.basis = xform.basis.scaled(Vector3(s, s, s))
		var base_v: int = i * src_vert_count
		for v in range(src_vert_count):
			all_verts[base_v + v] = xform * src_verts[v]
		if has_normals:
			var basis := xform.basis
			for v in range(src_vert_count):
				all_normals[base_v + v] = (basis * src_normals[v]).normalized()
		if has_indices:
			var base_i: int = i * src_indices.size()
			for idx in range(src_indices.size()):
				all_indices[base_i + idx] = src_indices[idx] + base_v
		if use_color and i < pd.particle_count:
			var c: Color = pd.cpu_colors[i]
			for v in range(src_vert_count):
				all_colors[base_v + v] = c

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_verts
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = all_normals
	if has_indices:
		arrays[Mesh.ARRAY_INDEX] = all_indices
	if use_color and all_colors.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = all_colors

	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var out := GNGeoData.new()
	out.set_mesh(out_mesh)
	return out
