#ifndef GN_PYTHON_RUNTIME_H
#define GN_PYTHON_RUNTIME_H

// Must be included before any standard headers per Python docs.
#include <Python.h>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace gn {

/// Singleton that manages the embedded CPython interpreter.
///
/// Lifecycle:
///   1. initialize() — called once at GDExtension load.
///      Sets up Py_Initialize, numpy import, sys.path.
///   2. import_script(path) — loads a user .py file as a module.
///   3. finalize() — called at GDExtension unload.
///
/// Thread safety:
///   All Python calls acquire the GIL. GONODES cooks operators
///   sequentially per-thread, matching TD's GIL constraint.
class GNPythonRuntime : public godot::RefCounted {
    GDCLASS(GNPythonRuntime, godot::RefCounted)

public:
    GNPythonRuntime();
    ~GNPythonRuntime();

    // ── Interpreter lifecycle ──────────────────────────────────

    /// Initialize CPython + numpy. Returns true on success.
    bool initialize();

    /// Shut down CPython. Safe to call multiple times.
    void finalize();

    /// Whether the interpreter is running.
    bool is_initialized() const;

    // ── Module loading ─────────────────────────────────────────

    /// Import/reload a .py file. Returns an opaque module handle
    /// (stored internally as PyObject*), or -1 on failure.
    /// The handle is valid until reload or finalize.
    int64_t import_script(const godot::String &path);

    /// Reload a previously imported script (for hot-reload).
    int64_t reload_script(int64_t handle);

    /// Release a module handle.
    void release_script(int64_t handle);

    // ── Calling user functions ─────────────────────────────────

    /// Call a named function on a loaded module.
    /// Returns the result as a Dictionary, or empty on failure.
    godot::Dictionary call_function(int64_t handle,
                                     const godot::String &func_name,
                                     const godot::Array &args);

    /// Check if a module has a named function.
    bool has_function(int64_t handle, const godot::String &func_name);

    // ── sys.path management ────────────────────────────────────

    /// Add a directory to Python's sys.path.
    void add_sys_path(const godot::String &dir);

    /// Get the last Python error as a string (clears it).
    godot::String get_last_error();

    // ── Data bridge (zero-copy where possible) ─────────────────

    /// Convert a Godot Dictionary to a Python dict (PyObject*).
    /// Used internally — not exposed to GDScript.
    static PyObject *dict_to_pyobj(const godot::Dictionary &dict);

    /// Convert a Python dict back to a Godot Dictionary.
    static godot::Dictionary pyobj_to_dict(PyObject *obj);

    /// Convert a Godot Array to a Python list.
    static PyObject *array_to_pylist(const godot::Array &arr);

    /// Convert a Python list back to a Godot Array.
    static godot::Array pylist_to_array(PyObject *obj);

    /// Wrap a PackedFloat32Array as a numpy ndarray (zero-copy).
    static PyObject *packed_float_to_numpy(godot::PackedFloat32Array &arr);

    /// Copy a numpy ndarray into a PackedFloat32Array.
    static godot::PackedFloat32Array numpy_to_packed_float(PyObject *arr);

    /// Wrap a PackedByteArray as a numpy uint8 ndarray (zero-copy).
    static PyObject *packed_byte_to_numpy(godot::PackedByteArray &arr);

    /// Copy a numpy uint8 ndarray into a PackedByteArray.
    static godot::PackedByteArray numpy_to_packed_byte(PyObject *arr);

protected:
    static void _bind_methods();

private:
    bool _initialized = false;
    // Module handle table: handle_id -> PyObject* module
    int64_t _next_handle = 1;
    std::unordered_map<int64_t, PyObject *> _modules;
    // Path -> handle for dedup
    std::unordered_map<std::string, int64_t> _path_to_handle;

    PyObject *_get_module(int64_t handle) const;
    void _setup_gonodes_sys_path();
    godot::String _format_python_error();
};

} // namespace gn

#endif // GN_PYTHON_RUNTIME_H
