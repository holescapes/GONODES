class_name GNSettings
extends RefCounted
## Centralized key-value store for user preferences.
##
## All settings are persisted to user://gonodes_settings.cfg under the
## [preferences] section.  Editor-internal layout state (split offsets,
## recent patches) keeps the existing [editor] section untouched.
##
## Usage:
##   GNSettings.set_value("preview_max_height", 120.0)
##   var h: float = GNSettings.get_value("preview_max_height", 120.0)
##
## The first call to get_value/set_value lazily loads the ConfigFile.

const _PATH := "user://gonodes_settings.cfg"
const _SECTION := "preferences"

static var _cfg: ConfigFile = null
static var _loaded: bool = false

## Emitted when any setting changes (key, new_value).
## Connect from UI controls that need live updates.
static var changed: Signal  # Can't use static signals in 4.x — use a callable approach instead.

## Registered listeners: Array of Callable(key, value).
static var _listeners: Array[Callable] = []


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(_PATH):
		_cfg.load(_PATH)
	_loaded = true


## Returns the value for a key, or the default if not set.
static func get_value(key: String, default: Variant = null) -> Variant:
	_ensure_loaded()
	return _cfg.get_value(_SECTION, key, default)


## Sets a value and persists to disk.
static func set_value(key: String, value: Variant) -> void:
	_ensure_loaded()
	_cfg.set_value(_SECTION, key, value)
	_cfg.save(_PATH)
	_notify_listeners(key, value)


## Returns true if a key has been explicitly set.
static func has_key(key: String) -> bool:
	_ensure_loaded()
	return _cfg.has_section_key(_SECTION, key)


## Registers a callable to be notified when any setting changes.
## The callable receives (key: String, value: Variant).
static func add_listener(cb: Callable) -> void:
	if cb not in _listeners:
		_listeners.append(cb)


## Removes a previously registered listener.
static func remove_listener(cb: Callable) -> void:
	var idx := _listeners.find(cb)
	if idx >= 0:
		_listeners.remove_at(idx)


static func _notify_listeners(key: String, value: Variant) -> void:
	for cb in _listeners:
		cb.call(key, value)


# ═══════════════════════════════════════════════════════════════════════════════
# Well-Known Defaults
# ═══════════════════════════════════════════════════════════════════════════════

## Default settings and their values.  Used by the preferences dialog
## to populate controls and by callers to provide defaults.
const DEFAULTS: Dictionary = {
	"preview_max_height": 80.0,
	"preview_enabled_on_create": true,
	"graph_snap_distance": 20,
	"perf_overlay_enabled": false,
	"log_level": 1,  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
	"log_to_file": false,  # Player export. Editor uses log_file_name.
	"log_file_name": "",  # Editor: file name beside the patch. Empty = no file.
	"log_panel_lines": 50,
	"parallel_cook_enabled": false,
	"wire_style": 0,  # 0=Curved, 1=Straight, 2=Right-Angle
	"viewer_bg_color": Color(0.06, 0.06, 0.08),
	"max_cooks_per_frame": 0,  # 0=unlimited
	"recent_patches_count": 10,
	"confirm_on_delete": false,
	"auto_save_interval": 0,  # seconds, 0=disabled
	"default_resolution_x": 512,
	"default_resolution_y": 512,
	"audio_output_device": "Default",
	"ffmpeg_path": "",
	# Graph reference overlay (reads / writes / wireless)
	"graph_ref_reads_visible": true,
	"graph_ref_writes_visible": true,
	"graph_ref_runtime_writes_visible": true,
	"graph_ref_wireless_hover_visible": true,
	"graph_ref_read_color": Color(0.2, 0.85, 0.95, 0.55),
	"graph_ref_write_color": Color(1.0, 0.55, 0.15, 0.55),
	"graph_ref_runtime_color": Color(1.0, 0.35, 0.2, 0.65),
	"graph_ref_wireless_color": Color(1.0, 0.65, 0.1, 0.45),
	"graph_inspector_deps_visible": true,
}
