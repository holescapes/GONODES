class_name GNNativeCompiler
extends RefCounted
## Compiles user C++ source files into GDExtension shared libraries.
## Uses bundled godot-cpp headers and the platform compiler toolchain.
##
## Build flow:
##   1. Write user C++ source + register_types shim to a temp build directory
##   2. Generate a minimal SConstruct that links against godot-cpp
##   3. Invoke SCons (or fall back to direct compiler invocation)
##   4. Return the path to the compiled .dll/.so/.dylib
##
## The compiler looks for toolchains in this order:
##   1. Bundled: res://addons/gn_ext_user_native/toolchain/<platform>/
##   2. System PATH (g++, clang++, cl.exe)

signal compile_started(node_id: String)
signal compile_finished(node_id: String, success: bool, output: String, lib_path: String)

const _REGISTER_TYPES_TEMPLATE := """
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "{source_filename}"

using namespace godot;

void initialize_user_node(ModuleInitializationLevel p_level) {{
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	ClassDB::register_class<{class_name}>();
}}

void uninitialize_user_node(ModuleInitializationLevel p_level) {{
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
}}

extern "C" {{
GDExtensionBool GDE_EXPORT user_node_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {{
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_user_node);
	init_obj.register_terminator(uninitialize_user_node);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}}
}}
"""

const _SCONSTRUCT_TEMPLATE := """
#!/usr/bin/env python
import os, sys

# Find godot-cpp
godot_cpp_path = "{godot_cpp_path}"
if not os.path.isdir(godot_cpp_path):
    print("ERROR: godot-cpp not found at:", godot_cpp_path)
    sys.exit(1)

env = SConscript(os.path.join(godot_cpp_path, "SConstruct"))
env.Append(CPPPATH=["{sdk_path}"])

sources = Glob("*.cpp")
library = env.SharedLibrary(
    target="bin/{lib_name}" + env["suffix"] + env["SHLIBSUFFIX"],
    source=sources,
)
Default(library)
"""

const _GDEXTENSION_TEMPLATE := """
[configuration]
entry_symbol = "user_node_init"
compatibility_minimum = 4.1
reloadable = true

[libraries]
{lib_entries}
"""

var _ext_dir: String = ""
var _build_processes: Dictionary = {}  # node_id -> Thread


func _init() -> void:
	_ext_dir = "res://addons/gn_ext_user_native/"


## Compile a user C++ source file for a specific node.
## @param node_id       Unique node identifier
## @param source_code   The full C++ source text
## @param class_name_   The C++ class name to register
## @param callback      Callable(success: bool, output: String, lib_path: String)
func compile_async(node_id: String, source_code: String, class_name_: String,
		callback: Callable) -> void:
	compile_started.emit(node_id)
	# Run compilation on a background thread to avoid blocking the cook engine
	var thread := Thread.new()
	var ctx := {
		"node_id": node_id,
		"source": source_code,
		"class_name": class_name_,
		"callback": callback,
	}
	thread.start(_compile_thread.bind(ctx))
	_build_processes[node_id] = thread


func _compile_thread(ctx: Dictionary) -> void:
	var node_id: String = ctx["node_id"]
	var source: String = ctx["source"]
	var cls_name: String = ctx["class_name"]
	var callback: Callable = ctx["callback"]

	var build_dir := _get_build_dir(node_id)
	var result := _do_compile(node_id, source, cls_name, build_dir)

	# Must call back on main thread
	callback.call_deferred(result["success"], result["output"], result["lib_path"])
	compile_finished.emit.call_deferred(node_id, result["success"],
		result["output"], result["lib_path"])


func _do_compile(node_id: String, source: String, cls_name: String,
		build_dir: String) -> Dictionary:
	# Ensure build directory exists
	if not DirAccess.dir_exists_absolute(build_dir):
		DirAccess.make_dir_recursive_absolute(build_dir)

	var source_filename := cls_name.to_snake_case() + ".h"
	var platform := _get_platform()
	var lib_name := "libuser_%s" % node_id.replace("-", "_")

	# Write source file
	var src_path := build_dir.path_join(source_filename)
	var f := FileAccess.open(src_path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "output": "Failed to write source: %s" % src_path, "lib_path": ""}
	f.store_string(source)
	f.close()

	# Write register_types.cpp
	var reg_source := _REGISTER_TYPES_TEMPLATE.format({
		"source_filename": source_filename,
		"class_name": cls_name,
	})
	var reg_path := build_dir.path_join("register_types.cpp")
	f = FileAccess.open(reg_path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "output": "Failed to write register_types.cpp", "lib_path": ""}
	f.store_string(reg_source)
	f.close()

	# Write SConstruct
	var godot_cpp_path := _find_godot_cpp()
	var sdk_path := ProjectSettings.globalize_path(_ext_dir + "sdk")
	var sconstruct := _SCONSTRUCT_TEMPLATE.format({
		"godot_cpp_path": godot_cpp_path.replace("\\", "/"),
		"sdk_path": sdk_path.replace("\\", "/"),
		"lib_name": lib_name,
	})
	f = FileAccess.open(build_dir.path_join("SConstruct"), FileAccess.WRITE)
	if f == null:
		return {"success": false, "output": "Failed to write SConstruct", "lib_path": ""}
	f.store_string(sconstruct)
	f.close()

	# Run SCons
	var scons_path := _find_scons()
	if scons_path.is_empty():
		return {"success": false, "output": "SCons not found. Install SCons or check the bundled toolchain.", "lib_path": ""}

	var args := PackedStringArray([
		"-C", ProjectSettings.globalize_path(build_dir),
		"platform=%s" % platform,
		"target=template_release",
		"-j%d" % OS.get_processor_count(),
	])

	var output := []
	var exit_code := OS.execute(scons_path, args, output, true)
	var output_text := "\n".join(output)

	if exit_code != 0:
		return {"success": false, "output": output_text, "lib_path": ""}

	# Find the compiled library
	var lib_path := _find_compiled_lib(build_dir, lib_name, platform)
	if lib_path.is_empty():
		return {"success": false, "output": "Build succeeded but library not found.\n" + output_text, "lib_path": ""}

	# Write .gdextension file
	_write_gdextension(build_dir, lib_name, lib_path, platform)

	return {"success": true, "output": output_text, "lib_path": lib_path}


func _get_build_dir(node_id: String) -> String:
	# Build in user:// so we don't pollute the project directory
	return OS.get_user_data_dir().path_join("gonodes_native_build").path_join(node_id)


func _get_platform() -> String:
	var os_name := OS.get_name().to_lower()
	if os_name.begins_with("win"):
		return "windows"
	elif os_name == "macos" or os_name == "osx":
		return "macos"
	else:
		return "linux"


func _find_godot_cpp() -> String:
	# 1. Bundled with extension
	var bundled := ProjectSettings.globalize_path(
		_ext_dir + "toolchain/godot-cpp")
	if DirAccess.dir_exists_absolute(bundled):
		return bundled

	# 2. Project-level
	var project_level := ProjectSettings.globalize_path(
		"res://addons/gn_ext_user_native/toolchain/godot-cpp")
	if DirAccess.dir_exists_absolute(project_level):
		return project_level

	return ""


func _find_scons() -> String:
	# 1. Bundled Python + SCons
	var bundled_scons := ProjectSettings.globalize_path(
		_ext_dir + "toolchain/scons/scons.py")
	if FileAccess.file_exists(bundled_scons):
		return "python"  # assumes python can run the bundled scons.py

	# 2. System scons
	var output := []
	var code := OS.execute("scons", ["--version"], output, true)
	if code == 0:
		return "scons"

	return ""


func _find_compiled_lib(build_dir: String, lib_name: String, platform: String) -> String:
	var bin_dir := build_dir.path_join("bin")
	if not DirAccess.dir_exists_absolute(bin_dir):
		return ""
	var dir := DirAccess.open(bin_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.begins_with(lib_name):
			return bin_dir.path_join(fname)
		fname = dir.get_next()
	return ""


func _write_gdextension(build_dir: String, lib_name: String,
		lib_path: String, platform: String) -> void:
	var lib_entries := ""
	var relative_path := "bin/" + lib_path.get_file()
	lib_entries += '%s.debug.x86_64 = "%s"\n' % [platform, relative_path]
	lib_entries += '%s.release.x86_64 = "%s"\n' % [platform, relative_path]

	var content := _GDEXTENSION_TEMPLATE.format({"lib_entries": lib_entries}).strip_edges()
	var gde_path := build_dir.path_join(lib_name + ".gdextension")
	var f := FileAccess.open(gde_path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


## Check if a compiler is available on this system.
func is_toolchain_available() -> bool:
	if not _find_godot_cpp().is_empty() and not _find_scons().is_empty():
		return true
	return false


## Get human-readable toolchain status for display.
func get_toolchain_status() -> String:
	var status := ""
	var godot_cpp := _find_godot_cpp()
	var scons := _find_scons()

	if godot_cpp.is_empty():
		status += "⚠ godot-cpp not found. Place it in toolchain/godot-cpp/\n"
	else:
		status += "✓ godot-cpp: %s\n" % godot_cpp

	if scons.is_empty():
		status += "⚠ SCons not found. Install SCons: pip install scons\n"
	else:
		status += "✓ SCons: %s\n" % scons

	return status.strip_edges()


## Clean build artifacts for a node.
func clean_build(node_id: String) -> void:
	var build_dir := _get_build_dir(node_id)
	if DirAccess.dir_exists_absolute(build_dir):
		_remove_dir_recursive(build_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		var full_path := path.path_join(fname)
		if dir.current_is_dir():
			_remove_dir_recursive(full_path)
		else:
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_begin()  # reset
	DirAccess.remove_absolute(path)
