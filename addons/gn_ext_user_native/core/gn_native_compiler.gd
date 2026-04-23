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

godot_cpp_path = "{godot_cpp_path}"
if not os.path.isdir(godot_cpp_path):
    print("ERROR: godot-cpp not found at:", godot_cpp_path)
    sys.exit(1)

# Import the godotcpp tool from toolchain/tools/ to set up compiler flags,
# but do NOT run godot-cpp's own SConstruct (which tries to build godot-cpp from
# source).  Instead we configure the environment manually and link against the
# pre-built static library.
sys.path.insert(0, godot_cpp_path)

EnsureSConsVersion(4, 0)

platform = ARGUMENTS.get("platform", "")
target   = ARGUMENTS.get("target", "template_release")
arch     = ARGUMENTS.get("arch", "x86_64")

env = Environment(tools=["default"], PLATFORM="")
env.PrependENVPath("PATH", os.getenv("PATH"))

opts = Variables([], ARGUMENTS)
cpp_tool = Tool("godotcpp", toolpath=[os.path.join(godot_cpp_path, "tools")])
cpp_tool.options(opts, env)
opts.Update(env)
cpp_tool.generate(env)

# Headers
env.Append(CPPPATH=[
    os.path.join(godot_cpp_path, "include"),
    os.path.join(godot_cpp_path, "gen", "include"),
    os.path.join(godot_cpp_path, "gdextension"),
    "{sdk_path}",
])

# Link against pre-built godot-cpp static library
lib_dir = os.path.join(godot_cpp_path, "bin")
env.Append(LIBPATH=[lib_dir])
# Find the matching lib file
import glob
libs = glob.glob(os.path.join(lib_dir, "libgodot-cpp.*" + target + "*"))
if libs:
    lib_name_full = os.path.splitext(os.path.basename(libs[0]))[0]
    if lib_name_full.startswith("lib"):
        lib_name_full = lib_name_full[3:]  # strip "lib" prefix for linker
    env.Append(LIBS=[lib_name_full])
else:
    print("ERROR: No pre-built godot-cpp library found in", lib_dir)
    sys.exit(1)

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


## Remove build artifacts for a specific node.
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
		var full := path.path_join(fname)
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


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


## Syntax-check only — compile without linking. Faster than a full build.
## @param node_id       Unique node identifier
## @param source_code   The full C++ source text
## @param callback      Callable(success: bool, output: String)
func syntax_check_async(node_id: String, source_code: String,
		callback: Callable) -> void:
	var thread := Thread.new()
	var ctx := {
		"node_id": node_id,
		"source": source_code,
		"callback": callback,
	}
	thread.start(_check_thread.bind(ctx))


func _check_thread(ctx: Dictionary) -> void:
	var node_id: String = ctx["node_id"]
	var source: String = ctx["source"]
	var callback: Callable = ctx["callback"]
	var result := _do_syntax_check(node_id, source)
	callback.call_deferred(result["success"], result["output"])


func _do_syntax_check(node_id: String, source: String) -> Dictionary:
	var build_dir := _get_build_dir(node_id)
	if not DirAccess.dir_exists_absolute(build_dir):
		DirAccess.make_dir_recursive_absolute(build_dir)

	# Write source to temp file
	var src_path := build_dir.path_join("_check_tmp.h")
	var f := FileAccess.open(src_path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "output": "Failed to write temp source file."}
	f.store_string(source)
	f.close()

	var compiler := _find_system_compiler()
	if compiler.is_empty():
		return {"success": false, "output": "No C++ compiler found."}

	var godot_cpp_path := _find_godot_cpp()
	if godot_cpp_path.is_empty():
		return {"success": false, "output": "godot-cpp not found."}

	var sdk_path := ProjectSettings.globalize_path(_ext_dir + "sdk")
	var global_src := ProjectSettings.globalize_path(src_path)
	var includes := [
		godot_cpp_path.path_join("include"),
		godot_cpp_path.path_join("gen/include"),
		godot_cpp_path.path_join("gdextension"),
		sdk_path,
	]

	var output := []
	var exit_code: int
	var platform := _get_platform()

	if platform == "windows" and compiler == "cl":
		var args := PackedStringArray([
			"/Zs", "/std:c++17", "/EHsc", "/utf-8",
			"/DWINDOWS_ENABLED", "/DTYPED_METHOD_BIND", "/DNOMINMAX",
			"/DWIN32", "/D_WIN32",
		])
		for inc in includes:
			args.append("/I%s" % inc)
		args.append(global_src)
		exit_code = OS.execute("cl", args, output, true)
	else:
		var args := PackedStringArray([
			"-fsyntax-only", "-std=c++17", "-DTYPED_METHOD_BIND",
		])
		if platform == "linux":
			args.append("-DLINUX_ENABLED")
		elif platform == "macos":
			args.append("-DMACOS_ENABLED")
		else:
			args.append("-DWINDOWS_ENABLED")
		for inc in includes:
			args.append("-I%s" % inc)
		args.append(global_src)
		exit_code = OS.execute(compiler, args, output, true)

	return {"success": exit_code == 0, "output": "\n".join(output)}


func _do_compile(node_id: String, source: String, cls_name: String,
		build_dir: String) -> Dictionary:
	# Ensure build directory exists
	if not DirAccess.dir_exists_absolute(build_dir):
		DirAccess.make_dir_recursive_absolute(build_dir)

	var source_filename := cls_name.to_snake_case() + ".h"
	var platform := _get_platform()
	var arch := _get_arch()
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

	# Write SConstruct (for advanced users who prefer SCons)
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

	# Prefer direct compiler (fast, no SCons dependency), fall back to SCons
	var output_text := ""
	var exit_code := -1
	var direct_compiler := _find_system_compiler()

	if not direct_compiler.is_empty():
		var direct_result := _compile_direct(build_dir, source_filename, lib_name,
			platform, arch, godot_cpp_path, sdk_path)
		exit_code = direct_result["exit_code"]
		output_text = direct_result["output"]
	else:
		var scons_path := _find_scons()
		if not scons_path.is_empty():
			var args := PackedStringArray([
				"-C", ProjectSettings.globalize_path(build_dir),
				"platform=%s" % platform,
				"arch=%s" % arch,
				"target=template_release",
				"-j%d" % OS.get_processor_count(),
			])
			var output := []
			exit_code = OS.execute(scons_path, args, output, true)
			output_text = "\n".join(output)
		else:
			return {"success": false, "output": "No C++ compiler found.\nInstall Visual Studio Build Tools (cl.exe), g++, or clang++.", "lib_path": ""}

	if exit_code != 0:
		return {"success": false, "output": output_text, "lib_path": ""}

	# Find the compiled library
	var lib_path := _find_compiled_lib(build_dir, lib_name, platform)
	if lib_path.is_empty():
		return {"success": false, "output": "Build succeeded but library not found.\n" + output_text, "lib_path": ""}

	# Write .gdextension file
	_write_gdextension(build_dir, lib_name, lib_path, platform, arch)

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


func _get_arch() -> String:
	var features := OS.get_processor_name().to_lower()
	if features.contains("arm") or features.contains("aarch64"):
		return "arm64"
	return "x86_64"


func _find_godot_cpp() -> String:
	# 1. Extension's bundled toolchain
	var bundled := ProjectSettings.globalize_path(
		_ext_dir + "toolchain/godot-cpp")
	if DirAccess.dir_exists_absolute(bundled):
		return bundled

	# 2. GODOT_CPP_PATH environment variable
	var env_path := OS.get_environment("GODOT_CPP_PATH")
	if not env_path.is_empty() and DirAccess.dir_exists_absolute(env_path):
		return env_path

	# 3. Project's gn_ext_native bundled godot-cpp (shared by all extensions)
	var project_native := ProjectSettings.globalize_path(
		"res://addons/gn_ext_native/native/godot-cpp")
	if DirAccess.dir_exists_absolute(project_native):
		return project_native

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
		lib_path: String, platform: String, arch: String = "x86_64") -> void:
	var lib_entries := ""
	var relative_path := "bin/" + lib_path.get_file()

	if platform == "macos":
		# macOS uses universal/bare keys without explicit arch
		lib_entries += 'macos.debug = "%s"\n' % relative_path
		lib_entries += 'macos.release = "%s"\n' % relative_path
	else:
		lib_entries += '%s.debug.%s = "%s"\n' % [platform, arch, relative_path]
		lib_entries += '%s.release.%s = "%s"\n' % [platform, arch, relative_path]

	var content := _GDEXTENSION_TEMPLATE.format({"lib_entries": lib_entries}).strip_edges()
	var gde_path := build_dir.path_join(lib_name + ".gdextension")
	var f := FileAccess.open(gde_path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


## Check if a compiler is available on this system.
## Returns true if godot-cpp is found and a C++ compiler (direct or SCons) exists.
func is_toolchain_available() -> bool:
	if _find_godot_cpp().is_empty():
		return false
	if not _find_system_compiler().is_empty():
		return true
	if not _find_scons().is_empty():
		return true
	return false


## Get human-readable toolchain status for display.
func get_toolchain_status() -> String:
	var status := ""
	var godot_cpp := _find_godot_cpp()
	var compiler := _find_system_compiler()
	var scons := _find_scons()

	if godot_cpp.is_empty():
		status += "⚠ godot-cpp not found.\n"
		status += "  Place it in toolchain/godot-cpp/, set GODOT_CPP_PATH,\n"
		status += "  or ensure gn_ext_native/native/godot-cpp/ exists.\n"
	else:
		status += "✓ godot-cpp: %s\n" % godot_cpp

	if not compiler.is_empty():
		status += "✓ Compiler: %s (direct build)\n" % compiler
	elif not scons.is_empty():
		status += "✓ SCons: %s (SCons build)\n" % scons
	else:
		status += "⚠ No C++ compiler or SCons found.\n"
		status += "  Install Visual Studio Build Tools, g++, or clang++.\n"

	status += "✓ Platform: %s  Arch: %s\n" % [_get_platform(), _get_arch()]
	return status


# ── Direct compiler fallback ──────────────────────────────────────────────────


## Find a usable C++ compiler on the system.
func _find_system_compiler() -> String:
	var platform := _get_platform()
	var candidates: PackedStringArray
	if platform == "windows":
		candidates = PackedStringArray(["cl", "g++", "clang++"])
	else:
		candidates = PackedStringArray(["g++", "clang++"])

	for cmd in candidates:
		var output := []
		var args := PackedStringArray(["--version"]) if cmd != "cl" else PackedStringArray()
		var code := OS.execute(cmd, args, output, true)
		if code == 0 or (cmd == "cl" and code != -1):
			return cmd
	return ""


## Compile using direct compiler invocation when SCons is not available.
## Requires godot-cpp to be already built (pre-built static lib must exist).
func _compile_direct(build_dir: String, source_filename: String,
		lib_name: String, platform: String, arch: String,
		godot_cpp_path: String, sdk_path: String) -> Dictionary:
	var compiler := _find_system_compiler()
	if compiler.is_empty():
		return {"exit_code": 1, "output": "No compiler found. Install a C++ compiler or SCons."}

	var global_build_dir := ProjectSettings.globalize_path(build_dir)
	var bin_dir := global_build_dir.path_join("bin")
	if not DirAccess.dir_exists_absolute(bin_dir):
		DirAccess.make_dir_recursive_absolute(bin_dir)

	var suffix := ".%s.template_release.%s" % [platform, arch]
	var includes := [
		godot_cpp_path.path_join("include"),
		godot_cpp_path.path_join("gen/include"),
		godot_cpp_path.path_join("gdextension"),
		sdk_path,
	]

	# Find the pre-built godot-cpp library
	var godotcpp_lib := ""
	if platform == "windows":
		godotcpp_lib = godot_cpp_path.path_join(
			"bin/libgodot-cpp%s.lib" % suffix)
	else:
		godotcpp_lib = godot_cpp_path.path_join(
			"bin/libgodot-cpp%s.a" % suffix)

	if not FileAccess.file_exists(godotcpp_lib):
		return {"exit_code": 1, "output": "godot-cpp pre-built library not found at: %s\nBuild godot-cpp first with SCons, then retry." % godotcpp_lib}

	var source_cpp := global_build_dir.path_join("register_types.cpp")
	var output := []
	var exit_code := 0

	# On Linux ARM64, prefer aarch64-linux-gnu-g++ for cross-compilation
	if platform == "linux" and arch == "arm64" and compiler == "g++":
		var cross_output := []
		var cross_code := OS.execute("aarch64-linux-gnu-g++", PackedStringArray(["--version"]), cross_output, true)
		if cross_code == 0:
			compiler = "aarch64-linux-gnu-g++"

	if platform == "windows" and compiler == "cl":
		exit_code = _compile_direct_msvc(global_build_dir, bin_dir,
			source_cpp, lib_name, suffix, includes, godotcpp_lib, output, arch)
	else:
		exit_code = _compile_direct_gcc(compiler, global_build_dir, bin_dir,
			source_cpp, lib_name, suffix, platform, includes, godotcpp_lib, output, arch)

	return {"exit_code": exit_code, "output": "\n".join(output)}


func _compile_direct_msvc(build_dir: String, bin_dir: String,
		source_cpp: String, lib_name: String, suffix: String,
		includes: Array, godotcpp_lib: String,
		output: Array, arch: String = "x86_64") -> int:
	var obj_path := build_dir.path_join("register_types.obj")
	var dll_path := bin_dir.path_join("%s%s.dll" % [lib_name, suffix])

	# Compile
	var compile_args := PackedStringArray([
		"/c", "/std:c++17", "/EHsc", "/utf-8",
		"/O2", "/MT", "/DNDEBUG",
		"/DWINDOWS_ENABLED", "/DTYPED_METHOD_BIND", "/DNOMINMAX",
		"/DWIN32", "/D_WIN32",
	])
	if arch == "arm64":
		compile_args.append("/arch:ARM64")
	for inc in includes:
		compile_args.append("/I%s" % inc)
	compile_args.append_array(PackedStringArray(["/Fo%s" % obj_path, source_cpp]))

	var code := OS.execute("cl", compile_args, output, true)
	if code != 0:
		return code

	# Link
	var link_args := PackedStringArray([
		"/DLL", "/OUT:%s" % dll_path,
		obj_path, godotcpp_lib,
	])
	code = OS.execute("link", link_args, output, true)
	return code


func _compile_direct_gcc(compiler: String, build_dir: String, bin_dir: String,
		source_cpp: String, lib_name: String, suffix: String,
		platform: String, includes: Array, godotcpp_lib: String,
		output: Array, arch: String = "x86_64") -> int:
	var lib_ext := ".so" if platform == "linux" else ".dylib"
	var lib_path := bin_dir.path_join("%s%s%s" % [lib_name, suffix, lib_ext])

	var args := PackedStringArray([
		"-std=c++17", "-fPIC", "-O2", "-DNDEBUG",
		"-DTYPED_METHOD_BIND",
	])

	if platform == "linux":
		args.append("-DLINUX_ENABLED")
		args.append_array(PackedStringArray(["-shared", "-o", lib_path]))
	else:  # macOS
		args.append("-DMACOS_ENABLED")
		args.append_array(PackedStringArray(["-arch", arch]))
		args.append_array(PackedStringArray(["-dynamiclib", "-o", lib_path]))

	for inc in includes:
		args.append("-I%s" % inc)
	args.append(source_cpp)
	args.append(godotcpp_lib)

	var code := OS.execute(compiler, args, output, true)
	return code
