extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Compact demoscene visual — "Creation" by Silexars (Danilo Guanabara).


func _init() -> void:
	node_type = "st_creation"
	time_dependent = true
	node_description = "Compact colour field demo effect. Shadertoy conversion."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_creation.gdshader"
	_shadertoy_url = "https://www.shadertoy.com/view/XsXXDn"
	_credits = "\"Creation\" by Danilo Guanabara (Silexars/Danguafer)"
	_is_generator = true
	_input_tex_count = 0
