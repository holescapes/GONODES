class_name CellularAutomataTOP
extends GNTopBase
## Cellular automata simulation (Game of Life, Brian's Brain, Seeds, Day & Night).
## Uses ping-pong feedback for state evolution.

var _feedback_texture: ImageTexture = null
var _frame_count: int = 0
var _last_reset: bool = false


func _init() -> void:
	node_type = "cellular_automata"
	time_dependent = true


func _init_ports() -> void:
	add_input("seed", GNFamily.Type.TOP, false, "Seed pattern (optional — uses noise if empty)")
	add_output("out", GNFamily.Type.TOP, "Automata state")


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
		_viewport.size = res
		_feedback_texture = null

	# Reset on toggle or first frame
	var needs_reset := do_reset or _feedback_texture == null
	if do_reset and not _last_reset:
		needs_reset = true
	_last_reset = do_reset

	_material.set_shader_parameter("reset", needs_reset)
	_material.set_shader_parameter("rule_set", get_param_value("rule_set"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	if seed_in != null:
		_material.set_shader_parameter("source_tex", seed_in.texture)

	if _feedback_texture != null and not needs_reset:
		_material.set_shader_parameter("prev_state", _feedback_texture)
	elif seed_in != null:
		_material.set_shader_parameter("prev_state", seed_in.texture)

	_frame_count += 1
	_capture_feedback.call_deferred()

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _capture_feedback() -> void:
	if _viewport == null:
		return
	var img: Image = _viewport.get_texture().get_image()
	if img == null:
		return
	if _feedback_texture == null:
		_feedback_texture = ImageTexture.create_from_image(img)
	else:
		_feedback_texture.update(img)
