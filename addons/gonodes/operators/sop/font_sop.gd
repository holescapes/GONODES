class_name FontSOP
extends GNSopBase
## Generates 3D text mesh using Godot's TextMesh.
## No input geometry required — acts as a generator SOP.


func _init() -> void:
	node_type = "font"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Text mesh geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Hello",
		"Text", "Text string to generate"))
	add_parameter(GNParameter.create_float("font_size", 1.0, 0.1, 100.0, 0.1,
		"Font Size", "Size of the text"))
	add_parameter(GNParameter.create_float("depth", 0.1, 0.0, 10.0, 0.01,
		"Depth", "Extrusion depth of the text"))
	add_parameter(GNParameter.create_enum("horizontal_align",
		PackedStringArray(["Left", "Center", "Right"]), 1,
		"Horizontal Align", "Horizontal text alignment"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_geo()
	var text_val: String = get_param_value("text")
	if text_val.is_empty():
		return out

	var text_mesh := TextMesh.new()
	text_mesh.text = text_val
	text_mesh.font_size = int(get_param_value("font_size") * 16.0)
	text_mesh.depth = get_param_value("depth")
	match get_param_value("horizontal_align"):
		0: text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		1: text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2: text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Convert TextMesh surfaces to ArrayMesh
	var arr_mesh := ArrayMesh.new()
	for s in range(text_mesh.get_surface_count()):
		var arrays: Array = text_mesh.surface_get_arrays(s)
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	out.set_mesh(arr_mesh)
	return out
