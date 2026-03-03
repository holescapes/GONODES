extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Procedural ocean surface — "Seascape" by TDM (Alexander Alekseev).


func _init() -> void:
	node_type = "st_seascape"
	time_dependent = true
	node_description = "Procedural ocean with waves, lighting and sky. Shadertoy conversion."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_seascape.gdshader"
	_shadertoy_url = "https://www.shadertoy.com/view/Ms2SD1"
	_credits = "\"Seascape\" by TDM (Alexander Alekseev) — CC BY-NC-SA 3.0"
	_is_generator = true
	_input_tex_count = 0
