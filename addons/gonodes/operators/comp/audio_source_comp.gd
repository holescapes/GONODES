class_name AudioSourceCOMP
extends GNCompBase
## Wraps Godot's AudioStreamPlayer3D for positional audio in 3D scenes.
## Plays audio streams with 3D spatialization (distance attenuation, panning).
## Pairs with AudioListenerCOMP for full 3D audio.

var _player: AudioStreamPlayer3D = null
var _last_file: String = ""
var _stream_loaded: bool = false


func _init() -> void:
	node_type = "audiosource"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Audio source component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01,
		"Translate X", "Source X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01,
		"Translate Y", "Source Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01,
		"Translate Z", "Source Z position"))
	add_parameter(GNParameter.create_string("file", "",
		"File", "Path to audio file (res:// or user://)"))
	add_parameter(GNParameter.create_float("volume_db", 0.0, -80.0, 24.0, 0.1,
		"Volume (dB)", "Playback volume in decibels"))
	add_parameter(GNParameter.create_float("max_distance", 10.0, 0.1, 1000.0, 0.1,
		"Max Distance", "Maximum audible distance"))
	add_parameter(GNParameter.create_float("unit_size", 1.0, 0.1, 100.0, 0.1,
		"Unit Size", "Distance at which stream is at full volume"))
	add_parameter(GNParameter.create_enum("attenuation",
		PackedStringArray(["Inverse Distance", "Inverse Square", "Logarithmic", "Disabled"]), 0,
		"Attenuation", "Distance attenuation model"))
	add_parameter(GNParameter.create_bool("autoplay", true,
		"Autoplay", "Start playing automatically"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop audio playback"))
	add_parameter(GNParameter.create_bool("playing", true,
		"Playing", "Play/pause toggle"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.name = id + "_source"
		_scene_node = _player

	_player.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))

	_player.volume_db = get_param_value("volume_db")
	_player.max_distance = get_param_value("max_distance")
	_player.unit_size = get_param_value("unit_size")

	var atten: int = get_param_value("attenuation")
	match atten:
		0: _player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		1: _player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		2: _player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		3: _player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED

	# Load audio file
	var file_path: String = get_param_value("file")
	if file_path != _last_file and not file_path.is_empty():
		_last_file = file_path
		_stream_loaded = false
		if ResourceLoader.exists(file_path):
			var stream: AudioStream = load(file_path)
			if stream != null:
				_player.stream = stream
				_stream_loaded = true

	var should_play: bool = get_param_value("playing")
	if _stream_loaded:
		if should_play and not _player.playing:
			_player.play()
		elif not should_play and _player.playing:
			_player.stop()

	return _build_comp_data()


func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_player = null
	_last_file = ""
	_stream_loaded = false
