class_name GNNativeFileWatch
extends RefCounted
## Polls a file path for modification time changes.
## Lightweight mtime-based watcher — no OS-level hooks required.

signal file_changed(path: String)

var _watch_path: String = ""
var _last_mtime: int = 0
var _poll_interval: float = 0.5
var _timer: float = 0.0


func watch(path: String) -> void:
	_watch_path = path
	_last_mtime = _get_mtime(path)
	_timer = 0.0


func stop() -> void:
	_watch_path = ""
	_last_mtime = 0


func poll(delta: float) -> void:
	if _watch_path.is_empty():
		return
	_timer += delta
	if _timer < _poll_interval:
		return
	_timer = 0.0
	var current_mtime := _get_mtime(_watch_path)
	if current_mtime != _last_mtime and current_mtime > 0:
		_last_mtime = current_mtime
		file_changed.emit(_watch_path)


func _get_mtime(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_modified_time(path)
