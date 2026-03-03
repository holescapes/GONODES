extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Animated fire effect using Voronoi cells — "Combustible Voronoi" by Shane.


func _init() -> void:
	node_type = "st_voronoi_fire"
	time_dependent = true
	node_description = "Volumetric fire palette over 3D Voronoi noise. Shadertoy conversion."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_voronoi_fire.gdshader"
	_shadertoy_url = "https://www.shadertoy.com/view/4tlSzl"
	_credits = "\"Combustible Voronoi Layers\" by Shane"
	_is_generator = true
	_input_tex_count = 0
