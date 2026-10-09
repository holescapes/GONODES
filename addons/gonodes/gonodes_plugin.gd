@tool
extends EditorPlugin
## GONODES editor plugin entry point.
## Registers the GONODES editor UI, custom types, and autoloads.


func _enter_tree() -> void:
	# Before extension scan prints. Godot's own boot lines already happened.
	GNLogger.install_godot_bridge()

	# Ensure OpenGL fallback is enabled so Compatibility renderer works on old GPUs/WebGL2.
	# Godot strips this from project.godot when it matches the default, so we enforce it here.
	ProjectSettings.set_setting("rendering/rendering_device/fallback_to_opengl3", true)
	ProjectSettings.save()

	# Deactivate .gdextension files whose native binaries aren't compiled yet.
	# Changes take effect on the next Godot restart (GDExtensions load before plugins).
	GNExtensionRegistry.sync_native_extensions()

	var ver: String = ProjectSettings.get_setting("application/config/version", "dev")
	print("GONODES plugin loaded (v%s)" % ver)


func _exit_tree() -> void:
	# Nothing to undo: the ProjectSettings change is intentionally persistent
	# and GNExtensionRegistry.sync_native_extensions() only toggles .gdextension
	# files on disk (takes effect on next Godot restart, not at runtime).
	print("GONODES plugin unloaded")
