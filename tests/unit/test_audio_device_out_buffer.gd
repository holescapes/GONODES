extends Node
## Unit tests for AudioDeviceOUT buffer sample-count enum and migration.


func _make_node() -> AudioDeviceOUT:
	var node := AudioDeviceOUT.new()
	node.initialize("audio1")
	return node


func test_buffer_length_seconds_migration_to_4096() -> void:
	var node := _make_node()
	node.from_dict({
		"parameters": {
			"mix_rate": {"value": 44100.0},
			"buffer_length": {"value": 0.1},
		},
	})
	GNTestAssert.assert_eq(node.get_param_value("buffer_length"), 3,
		"0.1 s at 44100 Hz migrates to 4096 samples (index 3)")


func test_buffer_seconds_512_at_44100() -> void:
	var node := _make_node()
	node.set_param_value("buffer_length", 0)
	node.set_param_value("mix_rate", 44100.0)
	GNTestAssert.assert_approx(node._get_buffer_seconds(), 512.0 / 44100.0, 0.0001,
		"512 samples at 44100 Hz is about 0.0116 s")


func test_buffer_seconds_512_at_96000_clamps_to_floor() -> void:
	var node := _make_node()
	node.set_param_value("buffer_length", 0)
	node.set_param_value("mix_rate", 96000.0)
	GNTestAssert.assert_approx(node._get_buffer_seconds(), 0.01, 0.0001,
		"512 samples at 96000 Hz clamps to Godot 10 ms floor")
