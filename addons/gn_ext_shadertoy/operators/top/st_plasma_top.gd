extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Retro plasma globe effect — original GONODES shader.


func _init() -> void:
	node_type = "st_plasma"
	time_dependent = true
	node_description = "Classic plasma colour effect. Original GONODES shader."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_plasma.gdshader"
	_shadertoy_url = ""
	_credits = "Original GONODES — inspired by classic Shadertoy plasma effects"
	_is_generator = true
	_input_tex_count = 0
