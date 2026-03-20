#include "gn_python_processor.h"
#include "gn_python_runtime.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace gn {

// ── Singleton accessor ──────────────────────────────────────

static GNPythonRuntime *s_runtime = nullptr;

GNPythonRuntime *GNPythonProcessor::_get_runtime() {
    if (s_runtime == nullptr) {
        s_runtime = memnew(GNPythonRuntime);
        if (!s_runtime->is_initialized()) {
            s_runtime->initialize();
        }
    }
    return s_runtime;
}

// ── Construction ────────────────────────────────────────────

GNPythonProcessor::GNPythonProcessor() {}

GNPythonProcessor::~GNPythonProcessor() {
    if (_module_handle >= 0) {
        auto *rt = _get_runtime();
        if (rt != nullptr && rt->is_initialized()) {
            rt->release_script(_module_handle);
        }
    }
}

// ── Script management ───────────────────────────────────────

bool GNPythonProcessor::load_script(const String &path) {
    auto *rt = _get_runtime();
    if (rt == nullptr) {
        _last_error = "Python runtime not available.";
        return false;
    }

    int64_t handle = rt->import_script(path);
    if (handle < 0) {
        _last_error = rt->get_last_error();
        return false;
    }

    _module_handle = handle;
    _script_path = path;
    _last_error = "";
    return true;
}

bool GNPythonProcessor::reload_script() {
    if (_module_handle < 0) return false;

    auto *rt = _get_runtime();
    if (rt == nullptr) return false;

    int64_t new_handle = rt->reload_script(_module_handle);
    if (new_handle < 0) {
        _last_error = rt->get_last_error();
        return false;
    }

    _module_handle = new_handle;
    _last_error = "";
    return true;
}

bool GNPythonProcessor::is_loaded() const {
    return _module_handle >= 0;
}

String GNPythonProcessor::get_script_path() const {
    return _script_path;
}

// ── Lifecycle ───────────────────────────────────────────────

void GNPythonProcessor::python_setup(const Dictionary &context) {
    if (_module_handle < 0) return;

    auto *rt = _get_runtime();
    if (rt == nullptr || !rt->has_function(_module_handle, "setup")) return;

    // Build me dict (operator identity info)
    Dictionary me;
    me["name"] = context.get("node_name", "");
    me["path"] = _script_path;
    me["time"] = context.get("elapsed", 0.0);
    me["frame"] = context.get("frame", 0);

    Array args;
    args.push_back(me);
    args.push_back(context);

    Dictionary result = rt->call_function(_module_handle, "setup", args);
    if (result.has("error")) {
        _last_error = result["error"];
        UtilityFunctions::push_warning("GNPythonProcessor setup error: ",
                                        _last_error);
    }
}

Dictionary GNPythonProcessor::python_cook(const Dictionary &params,
                                           const Array &inputs,
                                           const Dictionary &context) {
    if (_module_handle < 0) return Dictionary();

    auto *rt = _get_runtime();
    if (rt == nullptr || !rt->has_function(_module_handle, "cook")) {
        return Dictionary();
    }

    // Build me dict
    Dictionary me;
    me["name"] = context.get("node_name", "");
    me["path"] = _script_path;
    me["time"] = context.get("elapsed", 0.0);
    me["frame"] = context.get("frame", 0);
    me["delta"] = context.get("delta", 0.0);

    Array args;
    args.push_back(me);
    args.push_back(params);
    args.push_back(inputs);
    args.push_back(context);

    Dictionary result = rt->call_function(_module_handle, "cook", args);
    if (result.has("error")) {
        _last_error = result["error"];
    } else {
        _last_error = "";
    }
    return result;
}

// ── Dynamic ports & params ──────────────────────────────────

Array GNPythonProcessor::get_port_definitions() {
    if (_module_handle < 0) return Array();

    auto *rt = _get_runtime();
    if (rt == nullptr || !rt->has_function(_module_handle, "get_port_definitions")) {
        return Array();
    }

    Array args;
    Dictionary result = rt->call_function(_module_handle,
                                          "get_port_definitions", args);

    // The function should return a list → we get it via "result" key or
    // the function itself may return a list which comes as Array in result.
    if (result.has("ports")) {
        return result["ports"];
    }

    // If the Python function returned a list directly, it lands in "result"
    if (result.has("result")) {
        Variant r = result["result"];
        if (r.get_type() == Variant::ARRAY) return r;
    }

    // Fallback: the result dict may contain the list entries directly
    // if the function returned a dict with port entries
    return Array();
}

Array GNPythonProcessor::get_param_definitions() {
    if (_module_handle < 0) return Array();

    auto *rt = _get_runtime();
    if (rt == nullptr || !rt->has_function(_module_handle, "get_param_definitions")) {
        return Array();
    }

    Array args;
    Dictionary result = rt->call_function(_module_handle,
                                          "get_param_definitions", args);

    if (result.has("params")) {
        return result["params"];
    }
    if (result.has("result")) {
        Variant r = result["result"];
        if (r.get_type() == Variant::ARRAY) return r;
    }
    return Array();
}

// ── Error ───────────────────────────────────────────────────

String GNPythonProcessor::get_last_error() const {
    return _last_error;
}

// ── GDScript bindings ───────────────────────────────────────

void GNPythonProcessor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_script", "path"),
                         &GNPythonProcessor::load_script);
    ClassDB::bind_method(D_METHOD("reload_script"),
                         &GNPythonProcessor::reload_script);
    ClassDB::bind_method(D_METHOD("is_loaded"),
                         &GNPythonProcessor::is_loaded);
    ClassDB::bind_method(D_METHOD("get_script_path"),
                         &GNPythonProcessor::get_script_path);
    ClassDB::bind_method(D_METHOD("python_setup", "context"),
                         &GNPythonProcessor::python_setup);
    ClassDB::bind_method(D_METHOD("python_cook", "params", "inputs", "context"),
                         &GNPythonProcessor::python_cook);
    ClassDB::bind_method(D_METHOD("get_port_definitions"),
                         &GNPythonProcessor::get_port_definitions);
    ClassDB::bind_method(D_METHOD("get_param_definitions"),
                         &GNPythonProcessor::get_param_definitions);
    ClassDB::bind_method(D_METHOD("get_last_error"),
                         &GNPythonProcessor::get_last_error);
}

} // namespace gn
