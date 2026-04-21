class_name GNPdEngine
extends RefCounted
## Singleton-like wrapper around libpd native library.
## Manages Pd instance lifecycle, patch loading, and audio I/O.

var _lib: Object = null
var _initialized: bool = false
var _sample_rate: float = 44100.0
var _block_size: int = 64  # Pd's native block size
var _patches: Dictionary = {}  # path → patch_handle
var _receive_values: Dictionary = {}  # name → float


func _init() -> void:
	_try_load_library()


func _try_load_library() -> void:
	if ClassDB.class_exists("GNNativeLibPd"):
		_lib = ClassDB.instantiate("GNNativeLibPd")
		_initialized = true


func is_available() -> bool:
	return _initialized and _lib != null


func init_audio(sr: float, in_channels: int, out_channels: int) -> bool:
	if not is_available():
		return false
	_sample_rate = sr
	return _lib.init_audio(int(sr), in_channels, out_channels)


func open_patch(path: String) -> int:
	if not is_available():
		return -1
	if _patches.has(path):
		return _patches[path]
	var handle: int = _lib.open_patch(path)
	if handle >= 0:
		_patches[path] = handle
	return handle


func close_patch(path: String) -> void:
	if not is_available():
		return
	if _patches.has(path):
		_lib.close_patch(_patches[path])
		_patches.erase(path)


func process_audio(input: PackedFloat32Array, ticks: int) -> PackedFloat32Array:
	if not is_available():
		return PackedFloat32Array()
	return _lib.process_float(ticks, input)


func send_float(receiver: String, value: float) -> void:
	if is_available():
		_lib.send_float(receiver, value)


func send_bang(receiver: String) -> void:
	if is_available():
		_lib.send_bang(receiver)


func send_symbol(receiver: String, symbol: String) -> void:
	if is_available():
		_lib.send_symbol(receiver, symbol)


func send_note(channel: int, pitch: int, velocity: int) -> void:
	if is_available():
		_lib.send_noteon(channel, pitch, velocity)


func get_block_size() -> int:
	return _block_size


func get_received_value(name: String) -> float:
	return _receive_values.get(name, 0.0)


func set_received_value(name: String, value: float) -> void:
	_receive_values[name] = value


func get_all_received() -> Dictionary:
	return _receive_values.duplicate()


func cleanup() -> void:
	for path in _patches:
		if is_available():
			_lib.close_patch(_patches[path])
	_patches.clear()
	_receive_values.clear()
