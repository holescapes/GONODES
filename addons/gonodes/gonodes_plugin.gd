@tool
extends EditorPlugin
## GONODES editor plugin entry point.
## Registers the GONODES editor UI, custom types, and autoloads.


func _enter_tree() -> void:
	# TODO: Register custom node types, dock panels, autoloads
	print("GONODES plugin loaded (v0.1.0)")


func _exit_tree() -> void:
	# TODO: Unregister everything added in _enter_tree
	print("GONODES plugin unloaded")
