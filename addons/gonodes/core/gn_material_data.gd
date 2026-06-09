class_name GNMaterialData
extends GNData
## Output data type for MAT operators.
## Wraps Godot's Material base class — supports StandardMaterial3D, ShaderMaterial,
## ORMMaterial3D, and any other Material subclass.
## RefCounted (inherits from GNData) — transient compute result.

## The material resource.  Uses Godot's Material base class so any material type
## (StandardMaterial3D, ShaderMaterial, etc.) can flow through the graph.
var material: Material = null

## Human-readable label for UI preview (e.g., "PBR", "Shader: custom_toon").
var material_label: String = ""


func get_family() -> int:
	return GNFamily.Type.MAT


func get_preview_text() -> String:
	if material != null:
		return material_label
	return "no material"


func get_data_summary() -> String:
	return material_label if material != null else ""


func invalidate() -> void:
	super.invalidate()
	material = null
	material_label = ""


func duplicate_data() -> GNData:
	var copy := GNMaterialData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.metadata = metadata.duplicate(true)
	copy.material_label = material_label
	# Duplicate the material resource so downstream edits don't bleed back
	if material != null:
		copy.material = material.duplicate()
	return copy


func get_export_filters() -> Array[Dictionary]:
	return [
		{"filter": "*.tres", "description": "Godot Resource"},
	]


func export_to_file(path: String) -> Error:
	if material == null:
		return ERR_INVALID_DATA
	return ResourceSaver.save(material, path)


# ─── Expression Access ────────────────────────────────────────────────────────────────

func get_expression_value(key: String, _index: int = -1) -> Variant:
	match key:
		"label":
			return material_label
		"has_material":
			return 1.0 if material != null else 0.0
		"type":
			if material is StandardMaterial3D:
				return "standard"
			elif material is ShaderMaterial:
				return "shader"
			elif material != null:
				return "other"
			return ""
	# StandardMaterial3D property access
	if material is StandardMaterial3D:
		var std: StandardMaterial3D = material as StandardMaterial3D
		match key:
			"roughness":
				return std.roughness
			"metallic":
				return std.metallic
			"albedo_r":
				return std.albedo_color.r
			"albedo_g":
				return std.albedo_color.g
			"albedo_b":
				return std.albedo_color.b
			"albedo_a":
				return std.albedo_color.a
			"emission_energy":
				return std.emission_energy_multiplier
	return 0.0


func get_expression_info() -> Dictionary:
	var info := {
		"label": material_label,
		"has_material": material != null,
		"type": get_expression_value("type"),
	}
	if material is StandardMaterial3D:
		var std: StandardMaterial3D = material as StandardMaterial3D
		info["roughness"] = std.roughness
		info["metallic"] = std.metallic
		info["albedo_r"] = std.albedo_color.r
		info["albedo_g"] = std.albedo_color.g
		info["albedo_b"] = std.albedo_color.b
		info["albedo_a"] = std.albedo_color.a
		info["emission_energy"] = std.emission_energy_multiplier
	return info


func get_completions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["label", "has_material", "type"]:
		result.append({"label": key, "kind": "member"})
	if material is StandardMaterial3D:
		for key in ["roughness", "metallic",
				"albedo_r", "albedo_g", "albedo_b", "albedo_a",
				"emission_energy"]:
			result.append({"label": key, "kind": "member"})
	return result
