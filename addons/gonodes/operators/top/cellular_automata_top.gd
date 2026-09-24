class_name CellularAutomataTOP
extends GNTopBase
## Cellular automata simulation (Game of Life, Brian's Brain, Seeds, Day & Night).
## Uses ping-pong feedback for state evolution.

var _blit: Dictionary = {}
var _frame_count: int = 0
var _last_reset: bool = false


func _init() -> void:
	node_type = "cellular_automata"
	time_dependent = true


func _init_ports() -> void:
	add_input("seed", GNFamily.Type.TOP, false, "Seed pattern (optional — uses noise if empty)", "Seed")
	add_output("out", GNFamily.Type.TOP, "Automata state", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(256, 256),
		"Resolution", "Simulation grid size"))
	add_parameter(GNParameter.create_enum("rule_set",
		PackedStringArray(["Game of Life", "Brian's Brain", "Seeds", "Day & Night"]), 0,
		"Rule Set", "Cellular automata rule"))
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01,
		"Threshold", "Seed brightness threshold for alive cells"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Re-seed the simulation from input"))


func _cook(inputs: Array[GNData]) -> GNData:
	var seed_in: GNTextureData = _get_input_top(inputs, 0)
	var res: Vector2i = get_param_value("resolution")
	var do_reset: bool = get_param_value("reset")

	_init_shader_viewport("res://addons/gonodes/shaders/top/cellular_automata.gdshader", true, false, res)

	if _viewport.size != res:
		_ensure_viewport_size(res)
		_destroy_blit()

	# Reset on toggle or first frame
	var needs_reset := do_reset or _frame_count == 0
	if do_reset and not _last_reset:
		needs_reset = true
		_frame_count = 0
	_last_reset = do_reset

	_ensure_blit(res)

	_material.set_shader_parameter("reset", needs_reset)
	_material.set_shader_parameter("rule_set", get_param_value("rule_set"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	if seed_in != null:
		_material.set_shader_parameter("source_tex", seed_in.texture)

	if _frame_count > 0 and not needs_reset:
		_material.set_shader_parameter("prev_state", (_blit.viewport as SubViewport).get_texture())
	elif seed_in != null:
		_material.set_shader_parameter("prev_state", seed_in.texture)

	# Point blit viewport at main viewport output for GPU-side capture
	(_blit.canvas as TextureRect).texture = _viewport.get_texture()
	_frame_count += 1

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_blit(res: Vector2i) -> void:
	if not _blit.is_empty() and (_blit.viewport as SubViewport).size == res:
		return
	_destroy_blit()
	_blit = GNTopBase._create_blit_viewport(self, "CellularBlit", res, true)


func _destroy_blit() -> void:
	if _blit.has("viewport") and is_instance_valid(_blit.viewport):
		(_blit.viewport as SubViewport).queue_free()
	_blit = {}
