class_name GNNativeReloader
extends RefCounted
## Manages hot-reloading of user-compiled GDExtension libraries.
##
## Flow:
##   1. GNNativeCompiler produces a .dll/.so + .gdextension
##   2. GNNativeReloader loads it via GDExtension API
##   3. Node's _processor is replaced with the new class instance
##   4. On recompile: unload old -> load new -> re-instantiate

## Maps node_id -> {"lib_path": String, "gdext_path": String, "class_name": String}
var _loaded_libs: Dictionary = {}

## Maps node_id -> RefCounted (the live processor instance)
var _processors: Dictionary = {}


## Load a compiled user native library and instantiate the processor class.
## @param node_id      Unique node identifier
## @param gdext_path   Path to the .gdextension file
## @param class_name_  The C++ class name to instantiate
## @return             The processor instance, or null on failure
func load_and_instantiate(node_id: String, gdext_path: String,
		class_name_: String) -> RefCounted:
	# Unload previous version if exists
	if _loaded_libs.has(node_id):
		unload(node_id)

	# Godot 4.2+ will automatically detect reloadable = true in .gdextension
	# and handle the low-level reload. We just need to ensure the .gdextension
	# is registered with the project.
	#
	# For runtime loading, we use ProjectSettings to register the extension,
	# then instantiate via ClassDB.
	if not FileAccess.file_exists(gdext_path):
		push_warning("GNNativeReloader: .gdextension not found: %s" % gdext_path)
		return null

	# Check if class is already registered (previous compile in same session)
	# The GDExtension runtime loading uses GDExtensionManager
	var mgr = Engine.get_singleton("GDExtensionManager")
	if mgr == null:
		push_warning("GNNativeReloader: GDExtensionManager not available.")
		return null

	# Convert to a res:// or user:// path that Godot can load
	var loadable_path := _to_loadable_path(gdext_path)

	# Load the extension
	var status = mgr.load_extension(loadable_path)
	if status != OK and status != ERR_ALREADY_EXISTS:
		push_warning("GNNativeReloader: Failed to load extension: %s (status=%d)" % [loadable_path, status])
		return null

	# Record the load
	_loaded_libs[node_id] = {
		"lib_path": loadable_path,
		"gdext_path": gdext_path,
		"class_name": class_name_,
	}

	# Instantiate the class
	if not ClassDB.class_exists(class_name_):
		push_warning("GNNativeReloader: Class '%s' not found after loading extension." % class_name_)
		return null

	var instance: RefCounted = ClassDB.instantiate(class_name_)
	if instance == null:
		push_warning("GNNativeReloader: Failed to instantiate '%s'." % class_name_)
		return null

	_processors[node_id] = instance
	return instance


## Reload a library (unload old, compile is assumed done, load new).
func reload(node_id: String) -> RefCounted:
	if not _loaded_libs.has(node_id):
		return null

	var info: Dictionary = _loaded_libs[node_id]
	return load_and_instantiate(node_id, info["gdext_path"], info["class_name"])


## Unload a previously loaded library.
func unload(node_id: String) -> void:
	if not _loaded_libs.has(node_id):
		return

	var info: Dictionary = _loaded_libs[node_id]

	# Remove processor reference
	if _processors.has(node_id):
		_processors.erase(node_id)

	# Unload extension
	var mgr = Engine.get_singleton("GDExtensionManager")
	if mgr != null:
		mgr.unload_extension(info["lib_path"])

	_loaded_libs.erase(node_id)


## Get the processor instance for a node (or null).
func get_processor(node_id: String) -> RefCounted:
	return _processors.get(node_id, null)


## Check if a node has a loaded native processor.
func has_processor(node_id: String) -> bool:
	return _processors.has(node_id)


## Clean up all loaded libraries.
func unload_all() -> void:
	for node_id in _loaded_libs.keys():
		unload(node_id)


func _to_loadable_path(absolute_path: String) -> String:
	# Try to make it relative to user data dir
	var user_dir := OS.get_user_data_dir()
	if absolute_path.begins_with(user_dir):
		var relative := absolute_path.substr(user_dir.length())
		return "user://" + relative.lstrip("/\\")
	# Otherwise try res://
	var project_dir := ProjectSettings.globalize_path("res://")
	if absolute_path.begins_with(project_dir):
		var relative := absolute_path.substr(project_dir.length())
		return "res://" + relative.lstrip("/\\")
	# Fallback: use absolute path (may not work on all platforms)
	return absolute_path
