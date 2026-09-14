class_name GNAudioDevices
extends RefCounted
## Helpers for listing / selecting Godot AudioServer output (and input) devices.
##
## Godot keeps a single global output device. Hot-plugging speakers while the
## engine is running often leaves audio routed to a dead device until
## [method apply_output_device] is called again (or the editor is restarted).


## Returns output device names. Prepends "Default" for UI menus.
static func output_menu() -> PackedStringArray:
	var devices := AudioServer.get_output_device_list()
	var menu := PackedStringArray(["Default"])
	for d in devices:
		menu.append(d)
	return menu


## Returns input device names. Prepends "Default" for UI menus.
static func input_menu() -> PackedStringArray:
	var devices := AudioServer.get_input_device_list()
	var menu := PackedStringArray(["Default"])
	for d in devices:
		menu.append(d)
	return menu


static func _list_has(list: PackedStringArray, name: String) -> bool:
	return list.find(name) >= 0


## Apply an output device by menu index (0 = Default / OS preferred).
## Returns the device name that was selected (empty if none available).
static func apply_output_by_index(menu_index: int) -> String:
	var menu := output_menu()
	if menu.is_empty():
		return ""
	var idx: int = clampi(menu_index, 0, menu.size() - 1)
	return apply_output_device(menu[idx])


## Apply an output device by name. "Default" / empty picks a live device:
## prefers the current device if still listed, else the first hardware entry.
static func apply_output_device(device_name: String = "") -> String:
	var devices := AudioServer.get_output_device_list()
	if devices.is_empty():
		GNLogger.warn("Audio", "No audio output devices available")
		return ""

	var target: String = device_name.strip_edges()
	if target.is_empty() or target == "Default":
		# Prefer saved preference, then current, else first listed.
		var pref: String = str(GNSettings.get_value("audio_output_device", ""))
		if not pref.is_empty() and pref != "Default" and _list_has(devices, pref):
			target = pref
		elif _list_has(devices, AudioServer.output_device):
			target = AudioServer.output_device
		else:
			target = devices[0]

	if not _list_has(devices, target):
		GNLogger.warn("Audio", "Output device '%s' not found — falling back to '%s'" % [
			target, devices[0]])
		target = devices[0]

	if AudioServer.output_device != target:
		AudioServer.output_device = target
		GNLogger.info("Audio", "Output device → '%s'" % target)
	return target


## Persist + apply a preferred output device name for the editor session.
static func set_preferred_output(device_name: String) -> String:
	var applied: String = apply_output_device(device_name)
	if device_name.strip_edges().is_empty() or device_name == "Default":
		GNSettings.set_value("audio_output_device", "Default")
	elif not applied.is_empty():
		GNSettings.set_value("audio_output_device", applied)
	return applied
