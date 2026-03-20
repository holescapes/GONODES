#ifndef GN_PYTHON_PROCESSOR_H
#define GN_PYTHON_PROCESSOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace gn {

class GNPythonRuntime;

/// Per-node Python processor.
///
/// Each UserPython* wrapper creates one GNPythonProcessor via ClassDB.
/// This object holds the handle to the user's .py module and
/// translates between the Godot cook pipeline and Python functions.
///
/// User Python module is expected to define:
///   def get_port_definitions() -> list[dict]
///   def get_param_definitions() -> list[dict]
///   def setup(me, context: dict) -> None
///   def cook(me, params: dict, inputs: list, context: dict) -> dict
class GNPythonProcessor : public godot::RefCounted {
    GDCLASS(GNPythonProcessor, godot::RefCounted)

public:
    GNPythonProcessor();
    ~GNPythonProcessor();

    // ── Script management ──────────────────────────────────

    /// Load a Python script. Returns true on success.
    bool load_script(const godot::String &path);

    /// Reload the currently loaded script (hot-reload).
    bool reload_script();

    /// Whether a script is loaded.
    bool is_loaded() const;

    /// Path of the loaded script.
    godot::String get_script_path() const;

    // ── Lifecycle ──────────────────────────────────────────

    /// Call user's setup(me, context).
    void python_setup(const godot::Dictionary &context);

    /// Call user's cook(me, params, inputs, context).
    /// Returns the result dictionary.
    godot::Dictionary python_cook(const godot::Dictionary &params,
                                   const godot::Array &inputs,
                                   const godot::Dictionary &context);

    // ── Dynamic ports & params ─────────────────────────────

    /// Call user's get_port_definitions(). Returns Array of Dictionaries.
    godot::Array get_port_definitions();

    /// Call user's get_param_definitions(). Returns Array of Dictionaries.
    godot::Array get_param_definitions();

    // ── Error reporting ────────────────────────────────────

    godot::String get_last_error() const;

protected:
    static void _bind_methods();

private:
    int64_t _module_handle = -1;
    godot::String _script_path;
    godot::String _last_error;

    /// Lazily retrieve the singleton runtime.
    static GNPythonRuntime *_get_runtime();
};

} // namespace gn

#endif // GN_PYTHON_PROCESSOR_H
