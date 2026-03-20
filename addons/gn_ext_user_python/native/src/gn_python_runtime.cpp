#include "gn_python_runtime.h"

// numpy C API — must be included after Python.h
#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
#define PY_ARRAY_UNIQUE_SYMBOL GN_ARRAY_API
#include <numpy/arrayobject.h>

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/os.hpp>

#include <unordered_map>
#include <string>

using namespace godot;

namespace gn {

// ── Construction / Destruction ──────────────────────────────

GNPythonRuntime::GNPythonRuntime() {}

GNPythonRuntime::~GNPythonRuntime() {
    finalize();
}

// ── Interpreter lifecycle ───────────────────────────────────

bool GNPythonRuntime::initialize() {
    if (_initialized) return true;

    // Set Python home to our bundled embeddable package if present.
    // Discovery order:
    //   1. <extension_dir>/toolchain/python/   (bundled)
    //   2. GONODES_PYTHON_HOME env var
    //   3. System Python (whatever is on PATH)
    String ext_dir = ProjectSettings::get_singleton()->globalize_path(
        "res://addons/gn_ext_user_python/");
    String bundled = ext_dir + "toolchain/python";

    if (FileAccess::file_exists(String(bundled + "/python3.dll")) ||
        FileAccess::file_exists(String(bundled + "/libpython3.so")) ||
        FileAccess::file_exists(String(bundled + "/libpython3.dylib"))) {
        // Use bundled Python
        std::wstring whome(bundled.ptr(), bundled.ptr() + bundled.length());
        Py_SetPythonHome(whome.c_str());
    } else {
        // Check env var
        String env_home = OS::get_singleton()->get_environment("GONODES_PYTHON_HOME");
        if (!env_home.is_empty()) {
            std::wstring whome(env_home.ptr(), env_home.ptr() + env_home.length());
            Py_SetPythonHome(whome.c_str());
        }
        // else: fall back to system Python
    }

    Py_Initialize();
    if (!Py_IsInitialized()) {
        UtilityFunctions::push_warning("GNPythonRuntime: Py_Initialize failed.");
        return false;
    }

    // Import numpy C API
    if (_import_array() < 0) {
        UtilityFunctions::push_warning(
            "GNPythonRuntime: NumPy import failed. "
            "Install numpy: pip install numpy");
        PyErr_Clear();
        // Continue without numpy — pure-Python scripts still work
    }

    _setup_gonodes_sys_path();
    _initialized = true;

    UtilityFunctions::print("GNPythonRuntime: CPython ",
        PY_VERSION, " initialized.");
    return true;
}

void GNPythonRuntime::finalize() {
    if (!_initialized) return;

    // Release all module references
    PyGILState_STATE gstate = PyGILState_Ensure();
    for (auto &pair : _modules) {
        Py_XDECREF(pair.second);
    }
    _modules.clear();
    _path_to_handle.clear();
    PyGILState_Release(gstate);

    Py_FinalizeEx();
    _initialized = false;
}

bool GNPythonRuntime::is_initialized() const {
    return _initialized;
}

// ── Module loading ──────────────────────────────────────────

int64_t GNPythonRuntime::import_script(const String &path) {
    if (!_initialized) {
        UtilityFunctions::push_warning("GNPythonRuntime: Not initialized.");
        return -1;
    }

    // Globalize the path
    String abs_path = ProjectSettings::get_singleton()->globalize_path(path);
    std::string key(abs_path.utf8().get_data());

    // Check if already loaded
    auto it = _path_to_handle.find(key);
    if (it != _path_to_handle.end()) {
        return reload_script(it->second);
    }

    PyGILState_STATE gstate = PyGILState_Ensure();

    // Extract directory and module name from path
    String dir = abs_path.get_base_dir();
    String filename = abs_path.get_file();
    String module_name = filename.get_basename(); // strip .py

    // Add directory to sys.path temporarily
    PyObject *sys_path = PySys_GetObject("path");
    PyObject *py_dir = PyUnicode_FromString(dir.utf8().get_data());
    if (PySequence_Contains(sys_path, py_dir) == 0) {
        PyList_Insert(sys_path, 0, py_dir);
    }

    // Import the module
    PyObject *py_mod_name = PyUnicode_FromString(module_name.utf8().get_data());
    PyObject *module = PyImport_Import(py_mod_name);
    Py_DECREF(py_mod_name);
    Py_DECREF(py_dir);

    if (module == nullptr) {
        String err = _format_python_error();
        UtilityFunctions::push_warning("GNPythonRuntime: Import failed: ", err);
        PyGILState_Release(gstate);
        return -1;
    }

    int64_t handle = _next_handle++;
    _modules[handle] = module;
    _path_to_handle[key] = handle;

    PyGILState_Release(gstate);
    return handle;
}

int64_t GNPythonRuntime::reload_script(int64_t handle) {
    if (!_initialized) return -1;

    PyObject *old_module = _get_module(handle);
    if (old_module == nullptr) return -1;

    PyGILState_STATE gstate = PyGILState_Ensure();

    PyObject *new_module = PyImport_ReloadModule(old_module);
    if (new_module == nullptr) {
        String err = _format_python_error();
        UtilityFunctions::push_warning("GNPythonRuntime: Reload failed: ", err);
        PyGILState_Release(gstate);
        return -1;
    }

    Py_DECREF(old_module);
    _modules[handle] = new_module;

    PyGILState_Release(gstate);
    return handle;
}

void GNPythonRuntime::release_script(int64_t handle) {
    auto it = _modules.find(handle);
    if (it == _modules.end()) return;

    PyGILState_STATE gstate = PyGILState_Ensure();
    Py_XDECREF(it->second);
    PyGILState_Release(gstate);

    _modules.erase(it);

    // Remove from path map
    for (auto pit = _path_to_handle.begin(); pit != _path_to_handle.end(); ++pit) {
        if (pit->second == handle) {
            _path_to_handle.erase(pit);
            break;
        }
    }
}

// ── Calling user functions ──────────────────────────────────

Dictionary GNPythonRuntime::call_function(int64_t handle,
                                           const String &func_name,
                                           const Array &args) {
    if (!_initialized) return Dictionary();

    PyObject *module = _get_module(handle);
    if (module == nullptr) return Dictionary();

    PyGILState_STATE gstate = PyGILState_Ensure();

    PyObject *func = PyObject_GetAttrString(module, func_name.utf8().get_data());
    if (func == nullptr || !PyCallable_Check(func)) {
        Py_XDECREF(func);
        PyErr_Clear();
        PyGILState_Release(gstate);
        return Dictionary();
    }

    // Build args tuple
    PyObject *py_args = PyTuple_New(args.size());
    for (int i = 0; i < args.size(); i++) {
        Variant v = args[i];
        PyObject *py_val = nullptr;

        switch (v.get_type()) {
            case Variant::DICTIONARY:
                py_val = dict_to_pyobj(v);
                break;
            case Variant::ARRAY:
                py_val = array_to_pylist(v);
                break;
            case Variant::FLOAT:
                py_val = PyFloat_FromDouble((double)v);
                break;
            case Variant::INT:
                py_val = PyLong_FromLongLong((int64_t)v);
                break;
            case Variant::STRING:
                py_val = PyUnicode_FromString(String(v).utf8().get_data());
                break;
            case Variant::BOOL:
                py_val = PyBool_FromLong((bool)v ? 1 : 0);
                break;
            case Variant::PACKED_FLOAT32_ARRAY: {
                PackedFloat32Array pfa = v;
                py_val = packed_float_to_numpy(pfa);
                break;
            }
            case Variant::PACKED_BYTE_ARRAY: {
                PackedByteArray pba = v;
                py_val = packed_byte_to_numpy(pba);
                break;
            }
            default:
                // Fallback: convert to string
                py_val = PyUnicode_FromString(String(v).utf8().get_data());
                break;
        }

        if (py_val == nullptr) {
            py_val = Py_None;
            Py_INCREF(py_val);
        }
        PyTuple_SET_ITEM(py_args, i, py_val); // steals ref
    }

    // Call
    PyObject *result = PyObject_CallObject(func, py_args);
    Py_DECREF(py_args);
    Py_DECREF(func);

    if (result == nullptr) {
        String err = _format_python_error();
        Dictionary err_dict;
        err_dict["error"] = err;
        PyGILState_Release(gstate);
        return err_dict;
    }

    // Convert result to Dictionary
    Dictionary ret;
    if (PyDict_Check(result)) {
        ret = pyobj_to_dict(result);
    } else if (result == Py_None) {
        // empty dict = success with no output
    } else {
        ret["result"] = String(PyUnicode_AsUTF8(PyObject_Str(result)));
    }

    Py_DECREF(result);
    PyGILState_Release(gstate);
    return ret;
}

bool GNPythonRuntime::has_function(int64_t handle, const String &func_name) {
    PyObject *module = _get_module(handle);
    if (module == nullptr) return false;

    PyGILState_STATE gstate = PyGILState_Ensure();
    bool has = PyObject_HasAttrString(module, func_name.utf8().get_data());
    PyGILState_Release(gstate);
    return has;
}

// ── sys.path management ─────────────────────────────────────

void GNPythonRuntime::add_sys_path(const String &dir) {
    if (!_initialized) return;

    PyGILState_STATE gstate = PyGILState_Ensure();
    PyObject *sys_path = PySys_GetObject("path");
    PyObject *py_dir = PyUnicode_FromString(dir.utf8().get_data());
    if (PySequence_Contains(sys_path, py_dir) == 0) {
        PyList_Insert(sys_path, 0, py_dir);
    }
    Py_DECREF(py_dir);
    PyGILState_Release(gstate);
}

String GNPythonRuntime::get_last_error() {
    if (!_initialized) return "";
    PyGILState_STATE gstate = PyGILState_Ensure();
    String err = _format_python_error();
    PyGILState_Release(gstate);
    return err;
}

// ── Data bridge ─────────────────────────────────────────────

PyObject *GNPythonRuntime::dict_to_pyobj(const Dictionary &dict) {
    PyObject *py_dict = PyDict_New();
    Array keys = dict.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant val = dict[keys[i]];
        PyObject *py_key = PyUnicode_FromString(key.utf8().get_data());
        PyObject *py_val = nullptr;

        switch (val.get_type()) {
            case Variant::DICTIONARY:
                py_val = dict_to_pyobj(val);
                break;
            case Variant::ARRAY:
                py_val = array_to_pylist(val);
                break;
            case Variant::FLOAT:
                py_val = PyFloat_FromDouble((double)val);
                break;
            case Variant::INT:
                py_val = PyLong_FromLongLong((int64_t)val);
                break;
            case Variant::STRING:
                py_val = PyUnicode_FromString(String(val).utf8().get_data());
                break;
            case Variant::BOOL:
                py_val = PyBool_FromLong((bool)val ? 1 : 0);
                break;
            case Variant::PACKED_FLOAT32_ARRAY: {
                PackedFloat32Array pfa = val;
                py_val = packed_float_to_numpy(pfa);
                break;
            }
            case Variant::PACKED_BYTE_ARRAY: {
                PackedByteArray pba = val;
                py_val = packed_byte_to_numpy(pba);
                break;
            }
            default:
                py_val = PyUnicode_FromString(String(val).utf8().get_data());
                break;
        }

        if (py_val != nullptr) {
            PyDict_SetItem(py_dict, py_key, py_val);
            Py_DECREF(py_val);
        }
        Py_DECREF(py_key);
    }
    return py_dict;
}

Dictionary GNPythonRuntime::pyobj_to_dict(PyObject *obj) {
    Dictionary dict;
    if (obj == nullptr || !PyDict_Check(obj)) return dict;

    PyObject *key, *value;
    Py_ssize_t pos = 0;
    while (PyDict_Next(obj, &pos, &key, &value)) {
        String gd_key;
        if (PyUnicode_Check(key)) {
            gd_key = PyUnicode_AsUTF8(key);
        } else {
            gd_key = String::num_int64(PyLong_AsLongLong(key));
        }

        Variant gd_val;
        if (PyDict_Check(value)) {
            gd_val = pyobj_to_dict(value);
        } else if (PyList_Check(value) || PyTuple_Check(value)) {
            gd_val = pylist_to_array(value);
        } else if (PyFloat_Check(value)) {
            gd_val = PyFloat_AsDouble(value);
        } else if (PyLong_Check(value)) {
            gd_val = (int64_t)PyLong_AsLongLong(value);
        } else if (PyBool_Check(value)) {
            gd_val = (bool)(value == Py_True);
        } else if (PyUnicode_Check(value)) {
            gd_val = String(PyUnicode_AsUTF8(value));
        } else if (PyArray_Check(value)) {
            // numpy array -> PackedFloat32Array or PackedByteArray
            PyArrayObject *arr = (PyArrayObject *)value;
            int dtype = PyArray_TYPE(arr);
            if (dtype == NPY_FLOAT32) {
                gd_val = numpy_to_packed_float(value);
            } else if (dtype == NPY_UINT8) {
                gd_val = numpy_to_packed_byte(value);
            } else {
                // Cast to float32
                PyObject *cast = PyArray_Cast(arr, NPY_FLOAT32);
                if (cast != nullptr) {
                    gd_val = numpy_to_packed_float(cast);
                    Py_DECREF(cast);
                }
            }
        } else if (value == Py_None) {
            // Skip None values
            continue;
        } else {
            // Fallback: str()
            PyObject *str = PyObject_Str(value);
            if (str != nullptr) {
                gd_val = String(PyUnicode_AsUTF8(str));
                Py_DECREF(str);
            }
        }

        dict[gd_key] = gd_val;
    }
    return dict;
}

PyObject *GNPythonRuntime::array_to_pylist(const Array &arr) {
    PyObject *list = PyList_New(arr.size());
    for (int i = 0; i < arr.size(); i++) {
        Variant v = arr[i];
        PyObject *item = nullptr;
        switch (v.get_type()) {
            case Variant::DICTIONARY:
                item = dict_to_pyobj(v); break;
            case Variant::ARRAY:
                item = array_to_pylist(v); break;
            case Variant::FLOAT:
                item = PyFloat_FromDouble((double)v); break;
            case Variant::INT:
                item = PyLong_FromLongLong((int64_t)v); break;
            case Variant::STRING:
                item = PyUnicode_FromString(String(v).utf8().get_data()); break;
            case Variant::BOOL:
                item = PyBool_FromLong((bool)v ? 1 : 0); break;
            default:
                item = Py_None; Py_INCREF(item); break;
        }
        PyList_SET_ITEM(list, i, item); // steals ref
    }
    return list;
}

Array GNPythonRuntime::pylist_to_array(PyObject *obj) {
    Array arr;
    if (obj == nullptr) return arr;

    Py_ssize_t len = PySequence_Size(obj);
    for (Py_ssize_t i = 0; i < len; i++) {
        PyObject *item = PySequence_GetItem(obj, i);
        if (PyDict_Check(item)) {
            arr.push_back(pyobj_to_dict(item));
        } else if (PyList_Check(item) || PyTuple_Check(item)) {
            arr.push_back(pylist_to_array(item));
        } else if (PyFloat_Check(item)) {
            arr.push_back(PyFloat_AsDouble(item));
        } else if (PyLong_Check(item)) {
            arr.push_back((int64_t)PyLong_AsLongLong(item));
        } else if (PyBool_Check(item)) {
            arr.push_back((bool)(item == Py_True));
        } else if (PyUnicode_Check(item)) {
            arr.push_back(String(PyUnicode_AsUTF8(item)));
        } else {
            arr.push_back(Variant());
        }
        Py_DECREF(item);
    }
    return arr;
}

// ── Zero-copy numpy bridges ────────────────────────────────

PyObject *GNPythonRuntime::packed_float_to_numpy(PackedFloat32Array &arr) {
    npy_intp dims[1] = { (npy_intp)arr.size() };
    // Zero-copy: numpy wraps the existing Godot memory.
    // IMPORTANT: The PackedFloat32Array must outlive the numpy array.
    return PyArray_SimpleNewFromData(1, dims, NPY_FLOAT32, arr.ptrw());
}

PackedFloat32Array GNPythonRuntime::numpy_to_packed_float(PyObject *obj) {
    PackedFloat32Array result;
    if (obj == nullptr || !PyArray_Check(obj)) return result;

    PyArrayObject *arr = (PyArrayObject *)PyArray_GETCONTIGUOUS(
        (PyArrayObject *)obj);
    if (arr == nullptr) return result;

    npy_intp total = PyArray_SIZE(arr);
    result.resize(total);

    // Ensure float32
    if (PyArray_TYPE(arr) == NPY_FLOAT32) {
        memcpy(result.ptrw(), PyArray_DATA(arr), total * sizeof(float));
    } else {
        // Cast then copy
        PyObject *cast = PyArray_Cast(arr, NPY_FLOAT32);
        if (cast != nullptr) {
            memcpy(result.ptrw(), PyArray_DATA((PyArrayObject *)cast),
                   total * sizeof(float));
            Py_DECREF(cast);
        }
    }

    if ((PyObject *)arr != obj) Py_DECREF(arr);
    return result;
}

PyObject *GNPythonRuntime::packed_byte_to_numpy(PackedByteArray &arr) {
    npy_intp dims[1] = { (npy_intp)arr.size() };
    return PyArray_SimpleNewFromData(1, dims, NPY_UINT8, arr.ptrw());
}

PackedByteArray GNPythonRuntime::numpy_to_packed_byte(PyObject *obj) {
    PackedByteArray result;
    if (obj == nullptr || !PyArray_Check(obj)) return result;

    PyArrayObject *arr = (PyArrayObject *)PyArray_GETCONTIGUOUS(
        (PyArrayObject *)obj);
    if (arr == nullptr) return result;

    npy_intp total = PyArray_SIZE(arr);
    result.resize(total);

    if (PyArray_TYPE(arr) == NPY_UINT8) {
        memcpy(result.ptrw(), PyArray_DATA(arr), total);
    } else {
        PyObject *cast = PyArray_Cast(arr, NPY_UINT8);
        if (cast != nullptr) {
            memcpy(result.ptrw(), PyArray_DATA((PyArrayObject *)cast), total);
            Py_DECREF(cast);
        }
    }

    if ((PyObject *)arr != obj) Py_DECREF(arr);
    return result;
}

// ── Internal ────────────────────────────────────────────────

void GNPythonRuntime::_setup_gonodes_sys_path() {
    // Add the SDK directory so users can `import gonodes`
    String ext_dir = ProjectSettings::get_singleton()->globalize_path(
        "res://addons/gn_ext_user_python/");
    add_sys_path(ext_dir + "sdk");
}

PyObject *GNPythonRuntime::_get_module(int64_t handle) const {
    auto it = _modules.find(handle);
    if (it == _modules.end()) return nullptr;
    return it->second;
}

String GNPythonRuntime::_format_python_error() {
    if (!PyErr_Occurred()) return "";

    PyObject *type, *value, *traceback;
    PyErr_Fetch(&type, &value, &traceback);
    PyErr_NormalizeException(&type, &value, &traceback);

    String result;
    if (value != nullptr) {
        PyObject *str = PyObject_Str(value);
        if (str != nullptr) {
            result = PyUnicode_AsUTF8(str);
            Py_DECREF(str);
        }
    }

    // Try to get full traceback
    if (traceback != nullptr) {
        PyObject *tb_module = PyImport_ImportModule("traceback");
        if (tb_module != nullptr) {
            PyObject *format_func = PyObject_GetAttrString(
                tb_module, "format_exception");
            if (format_func != nullptr) {
                PyObject *args = PyTuple_Pack(3, type, value, traceback);
                PyObject *lines = PyObject_CallObject(format_func, args);
                if (lines != nullptr) {
                    result = "";
                    Py_ssize_t n = PyList_Size(lines);
                    for (Py_ssize_t i = 0; i < n; i++) {
                        result += PyUnicode_AsUTF8(PyList_GetItem(lines, i));
                    }
                    Py_DECREF(lines);
                }
                Py_DECREF(args);
                Py_DECREF(format_func);
            }
            Py_DECREF(tb_module);
        }
    }

    Py_XDECREF(type);
    Py_XDECREF(value);
    Py_XDECREF(traceback);
    return result;
}

// ── GDScript bindings ───────────────────────────────────────

void GNPythonRuntime::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize"), &GNPythonRuntime::initialize);
    ClassDB::bind_method(D_METHOD("finalize"), &GNPythonRuntime::finalize);
    ClassDB::bind_method(D_METHOD("is_initialized"),
                         &GNPythonRuntime::is_initialized);
    ClassDB::bind_method(D_METHOD("import_script", "path"),
                         &GNPythonRuntime::import_script);
    ClassDB::bind_method(D_METHOD("reload_script", "handle"),
                         &GNPythonRuntime::reload_script);
    ClassDB::bind_method(D_METHOD("release_script", "handle"),
                         &GNPythonRuntime::release_script);
    ClassDB::bind_method(D_METHOD("call_function", "handle", "func_name", "args"),
                         &GNPythonRuntime::call_function);
    ClassDB::bind_method(D_METHOD("has_function", "handle", "func_name"),
                         &GNPythonRuntime::has_function);
    ClassDB::bind_method(D_METHOD("add_sys_path", "dir"),
                         &GNPythonRuntime::add_sys_path);
    ClassDB::bind_method(D_METHOD("get_last_error"),
                         &GNPythonRuntime::get_last_error);
}

} // namespace gn
