class_name GNUiPrefs
extends RefCounted
## Editor UI preferences stored separately from patch data and GNSettings.
##
## Persisted to user://gn_ui_prefs.cfg.  Used for interface scale and other
## purely visual editor settings that should not live in gonodes_settings.cfg.

const _PATH := "user://gn_ui_prefs.cfg"
const _SECTION := "interface"
const DEFAULT_SCALE_PERCENT := 100
const DEFAULT_SIDE_PANEL_MIN_WIDTH := 260
const SIDE_PANEL_MIN_WIDTH_MIN := 120
const SIDE_PANEL_MIN_WIDTH_MAX := 800

static var _cfg: ConfigFile = null
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(_PATH):
		_cfg.load(_PATH)
	_loaded = true


static func get_interface_scale_percent() -> int:
	_ensure_loaded()
	return int(_cfg.get_value(_SECTION, "scale_percent", DEFAULT_SCALE_PERCENT))


static func set_interface_scale_percent(percent: int) -> void:
	_ensure_loaded()
	_cfg.set_value(_SECTION, "scale_percent", percent)
	_cfg.save(_PATH)


static func get_side_panel_min_width() -> int:
	_ensure_loaded()
	return clampi(int(_cfg.get_value(_SECTION, "side_panel_min_width", DEFAULT_SIDE_PANEL_MIN_WIDTH)),
		SIDE_PANEL_MIN_WIDTH_MIN, SIDE_PANEL_MIN_WIDTH_MAX)


static func set_side_panel_min_width(width: int) -> void:
	_ensure_loaded()
	_cfg.set_value(_SECTION, "side_panel_min_width",
		clampi(width, SIDE_PANEL_MIN_WIDTH_MIN, SIDE_PANEL_MIN_WIDTH_MAX))
	_cfg.save(_PATH)


static func get_wrap_sticky_notes() -> bool:
	_ensure_loaded()
	return bool(_cfg.get_value(_SECTION, "wrap_sticky_notes", true))


static func set_wrap_sticky_notes(enabled: bool) -> void:
	_ensure_loaded()
	_cfg.set_value(_SECTION, "wrap_sticky_notes", enabled)
	_cfg.save(_PATH)


static func scale_percent_to_factor(percent: int) -> float:
	return float(percent) / 100.0


## Applies the saved interface scale to the running scene window root.
static func apply_interface_scale(tree: SceneTree = null) -> void:
	var scene_tree: SceneTree = tree if tree else Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return
	scene_tree.root.content_scale_factor = scale_percent_to_factor(get_interface_scale_percent())
