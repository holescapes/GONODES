extends Node
## Tests for GNData subclass fundamentals: construction, fields, duplicate, summaries.
## Covers GNTextureData, GNChannelData, GNGeoData, GNVolumeData, GNParticleData.


# ═══════════════════════════════════════════════════════════════════════════════
# GNTextureData
# ═══════════════════════════════════════════════════════════════════════════════

func test_texture_data_defaults() -> void:
	var td := GNTextureData.new()
	GNTestAssert.assert_eq(td.get_family(), GNFamily.Type.TOP, "family should be TOP")
	GNTestAssert.assert_eq(td.resolution, Vector2i(512, 512), "default resolution 512x512")
	GNTestAssert.assert_null(td.texture, "texture starts null")
	GNTestAssert.assert_false(td.valid, "not valid by default")


func test_texture_data_aspect_ratio() -> void:
	var td := GNTextureData.new()
	td.resolution = Vector2i(1920, 1080)
	var aspect := td.get_aspect()
	GNTestAssert.assert_approx(aspect, 1920.0 / 1080.0, 0.01, "16:9 aspect")


func test_texture_data_aspect_zero_height() -> void:
	var td := GNTextureData.new()
	td.resolution = Vector2i(100, 0)
	GNTestAssert.assert_approx(td.get_aspect(), 1.0, 0.001, "zero-height returns 1.0")


func test_texture_data_duplicate() -> void:
	var td := GNTextureData.new()
	td.resolution = Vector2i(800, 600)
	td.valid = true
	var copy := td.duplicate_data()
	GNTestAssert.assert_true(copy is GNTextureData, "copy is GNTextureData")
	GNTestAssert.assert_eq((copy as GNTextureData).resolution, Vector2i(800, 600), "resolution preserved")
	GNTestAssert.assert_true(copy.valid, "valid flag preserved")


func test_texture_data_invalidate() -> void:
	var td := GNTextureData.new()
	td.valid = true
	td.invalidate()
	GNTestAssert.assert_null(td.texture, "texture cleared on invalidate")


func test_texture_data_expression_values() -> void:
	var td := GNTextureData.new()
	td.resolution = Vector2i(1920, 1080)
	GNTestAssert.assert_eq(td.get_expression_value("width"), 1920, "width expression")
	GNTestAssert.assert_eq(td.get_expression_value("height"), 1080, "height expression")
	GNTestAssert.assert_approx(td.get_expression_value("aspect"), 1920.0 / 1080.0, 0.01, "aspect expression")


func test_texture_data_export_filters() -> void:
	var td := GNTextureData.new()
	var filters := td.get_export_filters()
	GNTestAssert.assert_true(filters.size() >= 2, "at least PNG and WebP export filters")


func test_texture_data_summary_no_texture() -> void:
	var td := GNTextureData.new()
	td.resolution = Vector2i(256, 256)
	GNTestAssert.assert_eq(td.get_preview_text(), "", "no texture = empty text")


# ═══════════════════════════════════════════════════════════════════════════════
# GNChannelData
# ═══════════════════════════════════════════════════════════════════════════════

func test_channel_data_defaults() -> void:
	var cd := GNChannelData.new()
	GNTestAssert.assert_eq(cd.get_family(), GNFamily.Type.CHOP, "family should be CHOP")
	GNTestAssert.assert_eq(cd.channels.size(), 0, "starts with 0 channels")


func test_channel_data_set_get() -> void:
	var cd := GNChannelData.new()
	var samples := PackedFloat32Array([1.0, 2.0, 3.0])
	cd.set_channel("tx", samples)
	GNTestAssert.assert_eq(cd.channels.size(), 1, "1 channel")
	GNTestAssert.assert_true("tx" in cd.channels, "has tx")
	var out := cd.get_channel("tx")
	GNTestAssert.assert_eq(out.size(), 3, "3 samples")
	GNTestAssert.assert_approx(out[0], 1.0, 0.001, "first sample")
	GNTestAssert.assert_approx(out[2], 3.0, 0.001, "third sample")


func test_channel_data_multiple_channels() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("tx", PackedFloat32Array([1.0]))
	cd.set_channel("ty", PackedFloat32Array([2.0]))
	cd.set_channel("tz", PackedFloat32Array([3.0]))
	GNTestAssert.assert_eq(cd.channels.size(), 3, "3 channels")
	var names := cd.get_channel_names()
	GNTestAssert.assert_true("tx" in names, "has tx")
	GNTestAssert.assert_true("tz" in names, "has tz")


func test_channel_data_missing_channel() -> void:
	var cd := GNChannelData.new()
	var out := cd.get_channel("nonexistent")
	GNTestAssert.assert_eq(out.size(), 0, "missing channel returns empty array")


func test_channel_data_duplicate() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("lfo", PackedFloat32Array([0.5, 0.7]))
	cd.valid = true
	var copy := cd.duplicate_data()
	GNTestAssert.assert_true(copy is GNChannelData, "copy is GNChannelData")
	GNTestAssert.assert_eq((copy as GNChannelData).channels.size(), 1, "channel preserved")
	GNTestAssert.assert_true(copy.valid, "valid preserved")


func test_channel_data_get_value() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("x", PackedFloat32Array([42.0]))
	var val := cd.get_value("x")
	GNTestAssert.assert_approx(val, 42.0, 0.001, "get_value returns last sample")


func test_channel_data_set_single_value() -> void:
	var cd := GNChannelData.new()
	cd.set_single_value("gain", 0.75)
	var out := cd.get_channel("gain")
	GNTestAssert.assert_eq(out.size(), 1, "single sample")
	GNTestAssert.assert_approx(out[0], 0.75, 0.001, "value matches")


func test_channel_data_save_restore() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("a", PackedFloat32Array([1.0, 2.0]))
	cd.set_channel("b", PackedFloat32Array([3.0]))
	var state := cd.save_state()
	var cd2 := GNChannelData.new()
	cd2.restore_state(state)
	GNTestAssert.assert_eq(cd2.channels.size(), 2, "2 channels restored")
	GNTestAssert.assert_approx(cd2.get_value("a"), 2.0, 0.001, "a value restored")
	GNTestAssert.assert_approx(cd2.get_value("b"), 3.0, 0.001, "b value restored")


# ═══════════════════════════════════════════════════════════════════════════════
# GNGeoData
# ═══════════════════════════════════════════════════════════════════════════════

func test_geo_data_defaults() -> void:
	var gd := GNGeoData.new()
	GNTestAssert.assert_eq(gd.get_family(), GNFamily.Type.SOP, "family should be SOP")
	GNTestAssert.assert_eq(gd.vertex_count, 0, "starts with 0 vertices")


func test_geo_data_set_surface_arrays() -> void:
	var gd := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	gd.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	GNTestAssert.assert_true(gd.has_geometry(), "has geometry after set")
	GNTestAssert.assert_true(gd.vertex_count > 0, "vertex count updated")


func test_geo_data_clear() -> void:
	var gd := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO])
	gd.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	gd.clear()
	GNTestAssert.assert_eq(gd.vertex_count, 0, "clear resets vertices")
	GNTestAssert.assert_false(gd.has_geometry(), "no geometry after clear")


func test_geo_data_duplicate() -> void:
	var gd := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(1, 2, 3)])
	gd.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	gd.valid = true
	var copy := gd.duplicate_data()
	GNTestAssert.assert_true(copy is GNGeoData, "copy is GNGeoData")
	GNTestAssert.assert_true(copy.valid, "valid preserved")


func test_geo_data_positions() -> void:
	var gd := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array([Vector3(-1, -2, -3), Vector3(4, 5, 6)])
	arrays[Mesh.ARRAY_VERTEX] = verts
	gd.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var positions := gd.get_positions()
	GNTestAssert.assert_eq(positions.size(), 2, "2 vertices")
	GNTestAssert.assert_vec3_approx(positions[0], Vector3(-1, -2, -3), 0.01, "first vertex")
	GNTestAssert.assert_vec3_approx(positions[1], Vector3(4, 5, 6), 0.01, "second vertex")


func test_geo_data_point_attribs() -> void:
	var gd := GNGeoData.new()
	gd.set_point_attrib("density", PackedFloat32Array([0.5, 0.8, 1.0]))
	var out := gd.get_point_attrib("density")
	GNTestAssert.assert_eq(out.size(), 3, "3 values")
	GNTestAssert.assert_approx(out[1], 0.8, 0.001, "second attrib value")


func test_geo_data_expression_vertex_count() -> void:
	var gd := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	gd.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var val = gd.get_expression_value("vertex_count")
	GNTestAssert.assert_true(val >= 2, "vertex_count expression >= 2")


# ═══════════════════════════════════════════════════════════════════════════════
# GNVolumeData
# ═══════════════════════════════════════════════════════════════════════════════

func test_volume_data_defaults() -> void:
	var vd := GNVolumeData.new()
	GNTestAssert.assert_eq(vd.get_family(), GNFamily.Type.VOL, "family should be VOL")
	GNTestAssert.assert_eq(vd.resolution, Vector3i(64, 64, 64), "default resolution 64^3")
	GNTestAssert.assert_eq(vd.channel_count, 1, "default 1 channel")
	GNTestAssert.assert_eq(vd.field_name, "density", "default field name")


func test_volume_data_cpu_path() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(4, 4, 4)
	vd.channel_count = 1
	var data := PackedFloat32Array()
	data.resize(64)
	data.fill(0.5)
	vd.cpu_data = data
	vd.is_cpu = true
	vd.valid = true
	GNTestAssert.assert_eq(vd.cpu_data.size(), 64, "CPU data size matches")
	GNTestAssert.assert_approx(vd.cpu_data[0], 0.5, 0.001, "CPU data value")


func test_volume_data_voxel_count() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(8, 8, 8)
	GNTestAssert.assert_eq(vd.voxel_count(), 512, "8^3 = 512 voxels")


func test_volume_data_has_volume() -> void:
	var vd := GNVolumeData.new()
	vd.is_cpu = true
	vd.cpu_data = PackedFloat32Array()
	GNTestAssert.assert_false(vd.has_volume(), "empty CPU data = no volume")
	vd.cpu_data.resize(64)
	vd.cpu_data.fill(1.0)
	vd.resolution = Vector3i(4, 4, 4)
	GNTestAssert.assert_true(vd.has_volume(), "populated CPU data = has volume")


func test_volume_data_expression_value() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(32, 64, 16)
	GNTestAssert.assert_eq(vd.get_expression_value("res_x"), 32, "res_x expression")
	GNTestAssert.assert_eq(vd.get_expression_value("res_y"), 64, "res_y expression")
	GNTestAssert.assert_eq(vd.get_expression_value("res_z"), 16, "res_z expression")
	GNTestAssert.assert_eq(vd.get_expression_value("voxels"), 32 * 64 * 16, "voxel_count expression")


func test_volume_data_duplicate() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(8, 8, 8)
	vd.field_name = "temperature"
	vd.is_cpu = true
	vd.valid = true
	var data := PackedFloat32Array()
	data.resize(512)
	data.fill(0.3)
	vd.cpu_data = data
	var copy := vd.duplicate_data()
	GNTestAssert.assert_true(copy is GNVolumeData, "copy is GNVolumeData")
	var vc := copy as GNVolumeData
	GNTestAssert.assert_eq(vc.resolution, Vector3i(8, 8, 8), "resolution preserved")
	GNTestAssert.assert_eq(vc.field_name, "temperature", "field_name preserved")


func test_volume_data_preview_text() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(32, 16, 8)
	vd.field_name = "velocity"
	var text := vd.get_preview_text()
	GNTestAssert.assert_true(text.contains("32"), "preview contains X res")
	GNTestAssert.assert_true(text.contains("velocity"), "preview contains field name")


# ═══════════════════════════════════════════════════════════════════════════════
# GNParticleData
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_data_defaults() -> void:
	var pd := GNParticleData.new()
	GNTestAssert.assert_eq(pd.get_family(), GNFamily.Type.POP, "family should be POP")
	GNTestAssert.assert_eq(pd.particle_count, 0, "0 particles by default")
	GNTestAssert.assert_eq(pd.max_particles, 0, "0 max by default")


func test_particle_data_cpu_properties() -> void:
	var pd := GNParticleData.new()
	pd.particle_count = 100
	pd.max_particles = 1000
	pd.is_cpu = true
	pd.stride = 64
	GNTestAssert.assert_eq(pd.particle_count, 100, "count set")
	GNTestAssert.assert_eq(pd.max_particles, 1000, "max set")
	GNTestAssert.assert_eq(pd.stride, 64, "stride is 64")
	GNTestAssert.assert_true(pd.is_cpu, "is CPU")


func test_particle_data_has_particles_cpu() -> void:
	var pd := GNParticleData.new()
	pd.is_cpu = true
	pd.particle_count = 2
	pd.cpu_positions = PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	GNTestAssert.assert_true(pd.has_particles(), "has particles with CPU data")


func test_particle_data_has_particles_empty() -> void:
	var pd := GNParticleData.new()
	pd.is_cpu = true
	pd.particle_count = 0
	GNTestAssert.assert_false(pd.has_particles(), "no particles when count=0")


func test_particle_data_duplicate_cpu() -> void:
	var pd := GNParticleData.new()
	pd.particle_count = 3
	pd.max_particles = 100
	pd.is_cpu = true
	pd.stride = 64
	pd.cpu_positions = PackedVector3Array([Vector3(1,0,0), Vector3(2,0,0), Vector3(3,0,0)])
	pd.cpu_velocities = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	pd.valid = true
	var copy := pd.duplicate_data()
	GNTestAssert.assert_true(copy is GNParticleData, "copy is GNParticleData")
	var pc := copy as GNParticleData
	GNTestAssert.assert_eq(pc.particle_count, 3, "count preserved")
	GNTestAssert.assert_true(pc.is_cpu, "CPU flag preserved")
	GNTestAssert.assert_true(pc.valid, "valid preserved")


func test_particle_data_invalidate() -> void:
	var pd := GNParticleData.new()
	pd.particle_count = 50
	pd.valid = true
	pd.invalidate()
	GNTestAssert.assert_eq(pd.particle_count, 0, "particle count zeroed on invalidate")


func test_particle_data_preview_text() -> void:
	var pd := GNParticleData.new()
	pd.particle_count = 500
	var text := pd.get_preview_text()
	GNTestAssert.assert_true(text.contains("500"), "preview shows count")
