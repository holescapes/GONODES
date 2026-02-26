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


func get_family() -> GNFamily.Type:
	return GNFamily.Type.MAT


func invalidate() -> void:
	super.invalidate()
	material = null
	material_label = ""


func duplicate_data() -> GNData:
	var copy := GNMaterialData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.material_label = material_label
	# Duplicate the material resource so downstream edits don't bleed back
	if material != null:
		copy.material = material.duplicate()
	return copy
