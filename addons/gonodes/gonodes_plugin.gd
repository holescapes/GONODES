@tool
extends EditorPlugin
## GONODES editor plugin entry point.
## Registers the GONODES editor UI, custom types, and autoloads.


func _enter_tree() -> void:
	# Ensure OpenGL fallback is enabled so Compatibility renderer works on old GPUs/WebGL2.
	# Godot strips this from project.godot when it matches the default, so we enforce it here.
	ProjectSettings.set_setting("rendering/rendering_device/fallback_to_opengl3", true)
	ProjectSettings.save()

	# Deactivate .gdextension files whose native binaries aren't compiled yet.
	# Changes take effect on the next Godot restart (GDExtensions load before plugins).
	GNExtensionRegistry.sync_native_extensions()

	print("GONODES plugin loaded (v0.1.0)")


func _exit_tree() -> void:
	# TODO: Unregister everything added in _enter_tree
	print("GONODES plugin unloaded")
