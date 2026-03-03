extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Volumetric star-field fractal — "Star Nest" by Kali.


func _init() -> void:
	node_type = "st_star_nest"
	time_dependent = true
	node_description = "Animated volumetric space fractal. Shadertoy conversion."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_star_nest.gdshader"
	_shadertoy_url = "https://www.shadertoy.com/view/XlfGRj"
	_credits = "\"Star Nest\" by Pablo Roman Andrioli (Kali) — MIT License"
	_is_generator = true
	_input_tex_count = 0
