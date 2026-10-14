#include "gn_onnx_inference.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// ONNX Runtime C++ API
#include <onnxruntime_cxx_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

using namespace godot;

// ── Internal state ───────────────────────────────────────────────────────────

static Ort::Env &shared_env() {
    static std::unique_ptr<Ort::Env> env;
    if (!env) {
        env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "GNOnnxInference");
    }
    return *env;
}

struct GNOnnxInference::OrtState {
    std::unique_ptr<Ort::Session> session;
    Ort::MemoryInfo mem_info = Ort::MemoryInfo::CreateCpu(
            OrtArenaAllocator, OrtMemTypeDefault);

    // Input staging
    struct InputTensor {
        std::vector<float> data;
        std::vector<int64_t> shape;
    };
    std::unordered_map<std::string, InputTensor> inputs;

    // Output cache (populated after run())
    struct OutputTensor {
        std::vector<float> float_data;
        std::vector<int64_t> int_data;
        std::vector<int64_t> shape;
        ONNXTensorElementDataType dtype = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
    };
    std::unordered_map<std::string, OutputTensor> outputs;

    // Model metadata
    std::vector<std::string> input_names;
    std::vector<std::string> output_names;
};

// ── Binding ──────────────────────────────────────────────────────────────────

void GNOnnxInference::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_model", "path"), &GNOnnxInference::load_model);
    ClassDB::bind_method(D_METHOD("set_project_dir", "dir"), &GNOnnxInference::set_project_dir);
    ClassDB::bind_method(D_METHOD("get_last_error"), &GNOnnxInference::get_last_error);
    ClassDB::bind_method(D_METHOD("release"), &GNOnnxInference::release);
    ClassDB::bind_method(D_METHOD("is_loaded"), &GNOnnxInference::is_loaded);

    ClassDB::bind_method(D_METHOD("set_execution_provider", "provider"),
            &GNOnnxInference::set_execution_provider);
    ClassDB::bind_method(D_METHOD("get_execution_provider"),
            &GNOnnxInference::get_execution_provider);

    ClassDB::bind_method(D_METHOD("set_input_float", "name", "data", "shape"),
            &GNOnnxInference::set_input_float);
    ClassDB::bind_method(D_METHOD("set_input_from_image", "name", "image", "target_w", "target_h"),
            &GNOnnxInference::set_input_from_image);
    ClassDB::bind_method(D_METHOD("set_input_from_image_normalized", "name", "image",
                                 "target_w", "target_h", "mean", "std"),
            &GNOnnxInference::set_input_from_image_normalized);

    ClassDB::bind_method(D_METHOD("run"), &GNOnnxInference::run);

    ClassDB::bind_method(D_METHOD("get_output_float", "name"),
            &GNOnnxInference::get_output_float);
    ClassDB::bind_method(D_METHOD("get_output_int", "name"),
            &GNOnnxInference::get_output_int);
    ClassDB::bind_method(D_METHOD("get_output_shape", "name"),
            &GNOnnxInference::get_output_shape);

    ClassDB::bind_method(D_METHOD("get_input_names"), &GNOnnxInference::get_input_names);
    ClassDB::bind_method(D_METHOD("get_output_names"), &GNOnnxInference::get_output_names);
    ClassDB::bind_method(D_METHOD("get_model_info"), &GNOnnxInference::get_model_info);
}

// ── Constructor / Destructor ─────────────────────────────────────────────────

GNOnnxInference::GNOnnxInference() {
}

GNOnnxInference::~GNOnnxInference() {
    release();
}

// ── Model Lifecycle ──────────────────────────────────────────────────────────

void GNOnnxInference::set_project_dir(const String &p_dir) {
    _project_dir = p_dir;
}

String GNOnnxInference::get_last_error() const {
    return _last_error;
}

String GNOnnxInference::_resolve_model_path(const String &p_path) {
    if (p_path.is_empty()) {
        _last_error = "No model path";
        return String();
    }
    if (p_path.begins_with("res://") || p_path.begins_with("user://")) {
        ProjectSettings *settings = ProjectSettings::get_singleton();
        if (settings == nullptr) {
            _last_error = "ProjectSettings is not available";
            return String();
        }
        return settings->globalize_path(p_path);
    }
    if (p_path.begins_with("project://")) {
        if (_project_dir.is_empty()) {
            _last_error = "Cannot resolve project:// without a project directory";
            return String();
        }
        return _project_dir.path_join(p_path.trim_prefix("project://"));
    }
    return p_path;
}

bool GNOnnxInference::_attach_provider(Ort::SessionOptions &p_options) {
    if (_provider == "cpu" || _provider.is_empty()) {
        return true;
    }
    try {
        if (_provider == "directml") {
#ifdef _WIN32
            p_options.AppendExecutionProvider("DML");
            return true;
#else
            _last_error = "DirectML is only available on Windows";
            return false;
#endif
        }
        if (_provider == "cuda") {
            OrtCUDAProviderOptions cuda_opts{};
            p_options.AppendExecutionProvider_CUDA(cuda_opts);
            return true;
        }
        if (_provider == "coreml") {
#ifdef __APPLE__
            p_options.AppendExecutionProvider("CoreML");
            return true;
#else
            _last_error = "CoreML is only available on macOS";
            return false;
#endif
        }
        _last_error = "Unknown execution provider: " + _provider;
        return false;
    } catch (const Ort::Exception &e) {
        _last_error = String(e.what());
        return false;
    }
}

bool GNOnnxInference::load_model(const String &p_path) {
    _last_error = String();
    String resolved = _resolve_model_path(p_path);
    if (resolved.is_empty()) {
        return false;
    }
    if (!FileAccess::file_exists(p_path) && !FileAccess::file_exists(resolved)) {
        _last_error = "Model file not found: " + p_path;
        return false;
    }
    release();

    try {
        _state = new OrtState();

        Ort::SessionOptions opts;
        opts.SetIntraOpNumThreads(2);
        opts.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);

        if (!_attach_provider(opts)) {
            release();
            return false;
        }

#ifdef _WIN32
        Char16String utf16 = resolved.utf16();
        _state->session = std::make_unique<Ort::Session>(
                shared_env(), (const wchar_t *)utf16.get_data(), opts);
#else
        CharString utf8 = resolved.utf8();
        std::string model_path(utf8.get_data(), utf8.length());
        _state->session = std::make_unique<Ort::Session>(shared_env(), model_path.c_str(), opts);
#endif

        // Cache input / output names
        Ort::AllocatorWithDefaultOptions alloc;
        size_t num_in = _state->session->GetInputCount();
        for (size_t i = 0; i < num_in; i++) {
            auto name = _state->session->GetInputNameAllocated(i, alloc);
            _state->input_names.push_back(name.get());
        }
        size_t num_out = _state->session->GetOutputCount();
        for (size_t i = 0; i < num_out; i++) {
            auto name = _state->session->GetOutputNameAllocated(i, alloc);
            _state->output_names.push_back(name.get());
        }

        return true;
    } catch (const Ort::Exception &e) {
        _last_error = String(e.what());
        UtilityFunctions::printerr(String("GNOnnxInference: ONNX error: ") + _last_error);
        release();
        return false;
    } catch (const std::exception &e) {
        _last_error = String(e.what());
        UtilityFunctions::printerr(String("GNOnnxInference: ") + _last_error);
        release();
        return false;
    }
}

void GNOnnxInference::release() {
    if (_state) {
        delete _state;
        _state = nullptr;
    }
}

bool GNOnnxInference::is_loaded() const {
    return _state != nullptr && _state->session != nullptr;
}

// ── Execution Provider ───────────────────────────────────────────────────────

void GNOnnxInference::set_execution_provider(const String &p_provider) {
    _provider = p_provider.to_lower();
}

String GNOnnxInference::get_execution_provider() const {
    return _provider;
}

// ── Input Setup ──────────────────────────────────────────────────────────────

void GNOnnxInference::set_input_float(const String &p_name,
                                       const PackedFloat32Array &p_data,
                                       const PackedInt32Array &p_shape) {
    if (!_state) return;

    std::string name(p_name.utf8().get_data());
    auto &tensor = _state->inputs[name];
    tensor.data.resize(p_data.size());
    memcpy(tensor.data.data(), p_data.ptr(), p_data.size() * sizeof(float));
    tensor.shape.resize(p_shape.size());
    for (int i = 0; i < p_shape.size(); i++) {
        tensor.shape[i] = p_shape[i];
    }
}

void GNOnnxInference::set_input_from_image(const String &p_name,
                                            const Ref<Image> &p_image,
                                            int p_target_w, int p_target_h) {
    // Default: normalize to [0, 1] with no mean/std adjustment
    PackedFloat32Array mean, std;
    mean.resize(3); std.resize(3);
    mean[0] = 0.0f; mean[1] = 0.0f; mean[2] = 0.0f;
    std[0] = 1.0f;  std[1] = 1.0f;  std[2] = 1.0f;
    set_input_from_image_normalized(p_name, p_image, p_target_w, p_target_h, mean, std);
}

void GNOnnxInference::set_input_from_image_normalized(const String &p_name,
                                                       const Ref<Image> &p_image,
                                                       int p_target_w, int p_target_h,
                                                       const PackedFloat32Array &p_mean,
                                                       const PackedFloat32Array &p_std) {
    if (!_state || p_image.is_null()) return;
    if (p_mean.size() < 3 || p_std.size() < 3) return;

    // Resize and convert to RGB8
    Ref<Image> img = p_image->duplicate();
    if (img->get_width() != p_target_w || img->get_height() != p_target_h) {
        img->resize(p_target_w, p_target_h, Image::INTERPOLATE_BILINEAR);
    }
    if (img->get_format() != Image::FORMAT_RGB8) {
        img->convert(Image::FORMAT_RGB8);
    }

    PackedByteArray pixels = img->get_data();
    int num_pixels = p_target_w * p_target_h;

    // Convert to NCHW float32 with normalization: (pixel/255 - mean) / std
    std::string name(p_name.utf8().get_data());
    auto &tensor = _state->inputs[name];
    tensor.shape = {1, 3, p_target_h, p_target_w};
    tensor.data.resize(3 * num_pixels);

    const uint8_t *px = pixels.ptr();
    float m[3] = {p_mean[0], p_mean[1], p_mean[2]};
    float s[3] = {p_std[0], p_std[1], p_std[2]};

    for (int c = 0; c < 3; c++) {
        float *dst = tensor.data.data() + c * num_pixels;
        float mc = m[c], sc = s[c];
        for (int i = 0; i < num_pixels; i++) {
            dst[i] = (static_cast<float>(px[i * 3 + c]) / 255.0f - mc) / sc;
        }
    }
}

// ── Inference ────────────────────────────────────────────────────────────────

bool GNOnnxInference::run() {
    _last_error = String();
    if (!is_loaded()) {
        _last_error = "Model is not loaded";
        return false;
    }

    try {
        _state->outputs.clear();

        // Build input tensors
        std::vector<const char *> in_names;
        std::vector<Ort::Value> in_tensors;
        for (auto &name : _state->input_names) {
            auto it = _state->inputs.find(name);
            if (it == _state->inputs.end()) {
                _last_error = String("Missing input '") + name.c_str() + "'";
                UtilityFunctions::printerr(String("GNOnnxInference: ") + _last_error);
                return false;
            }
            in_names.push_back(name.c_str());
            auto &t = it->second;
            in_tensors.push_back(Ort::Value::CreateTensor<float>(
                    _state->mem_info, t.data.data(), t.data.size(),
                    t.shape.data(), t.shape.size()));
        }

        // Build output name list
        std::vector<const char *> out_names;
        for (auto &name : _state->output_names) {
            out_names.push_back(name.c_str());
        }

        // Run
        auto results = _state->session->Run(Ort::RunOptions{nullptr},
                in_names.data(), in_tensors.data(), in_names.size(),
                out_names.data(), out_names.size());

        // Cache outputs
        for (size_t i = 0; i < results.size(); i++) {
            auto &val = results[i];
            auto info = val.GetTensorTypeAndShapeInfo();
            auto shape = info.GetShape();
            auto dtype = info.GetElementType();

            OrtState::OutputTensor ot;
            ot.shape.assign(shape.begin(), shape.end());
            ot.dtype = dtype;

            size_t count = info.GetElementCount();
            if (dtype == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) {
                const float *data = val.GetTensorData<float>();
                ot.float_data.assign(data, data + count);
            } else if (dtype == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64) {
                const int64_t *data = val.GetTensorData<int64_t>();
                ot.int_data.assign(data, data + count);
            } else if (dtype == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32) {
                const int32_t *data = val.GetTensorData<int32_t>();
                ot.int_data.resize(count);
                for (size_t j = 0; j < count; j++) {
                    ot.int_data[j] = data[j];
                }
            }

            _state->outputs[_state->output_names[i]] = std::move(ot);
        }

        return true;
    } catch (const Ort::Exception &e) {
        _last_error = String(e.what());
        UtilityFunctions::printerr(String("GNOnnxInference: run error: ") + _last_error);
        return false;
    } catch (const std::exception &e) {
        _last_error = String(e.what());
        UtilityFunctions::printerr(String("GNOnnxInference: run error: ") + _last_error);
        return false;
    }
}

// ── Output Access ────────────────────────────────────────────────────────────

PackedFloat32Array GNOnnxInference::get_output_float(const String &p_name) const {
    PackedFloat32Array result;
    if (!_state) return result;

    std::string name(p_name.utf8().get_data());
    auto it = _state->outputs.find(name);
    if (it == _state->outputs.end()) return result;

    result.resize(it->second.float_data.size());
    if (!it->second.float_data.empty()) {
        memcpy(result.ptrw(), it->second.float_data.data(),
               it->second.float_data.size() * sizeof(float));
    }
    return result;
}

PackedInt32Array GNOnnxInference::get_output_int(const String &p_name) const {
    PackedInt32Array result;
    if (!_state) return result;

    std::string name(p_name.utf8().get_data());
    auto it = _state->outputs.find(name);
    if (it == _state->outputs.end()) return result;

    result.resize(it->second.int_data.size());
    for (size_t i = 0; i < it->second.int_data.size(); i++) {
        result[i] = static_cast<int32_t>(it->second.int_data[i]);
    }
    return result;
}

PackedInt32Array GNOnnxInference::get_output_shape(const String &p_name) const {
    PackedInt32Array result;
    if (!_state) return result;

    std::string name(p_name.utf8().get_data());
    auto it = _state->outputs.find(name);
    if (it == _state->outputs.end()) return result;

    result.resize(it->second.shape.size());
    for (size_t i = 0; i < it->second.shape.size(); i++) {
        result[i] = static_cast<int32_t>(it->second.shape[i]);
    }
    return result;
}

// ── Introspection ────────────────────────────────────────────────────────────

PackedStringArray GNOnnxInference::get_input_names() const {
    PackedStringArray result;
    if (!_state) return result;
    for (auto &n : _state->input_names) {
        result.push_back(String(n.c_str()));
    }
    return result;
}

PackedStringArray GNOnnxInference::get_output_names() const {
    PackedStringArray result;
    if (!_state) return result;
    for (auto &n : _state->output_names) {
        result.push_back(String(n.c_str()));
    }
    return result;
}

Dictionary GNOnnxInference::get_model_info() const {
    Dictionary info;
    if (!_state || !_state->session) return info;

    info["num_inputs"] = (int)_state->input_names.size();
    info["num_outputs"] = (int)_state->output_names.size();
    info["provider"] = _provider;

    // Input details
    Array in_arr;
    Ort::AllocatorWithDefaultOptions alloc;
    for (size_t i = 0; i < _state->input_names.size(); i++) {
        Dictionary d;
        d["name"] = String(_state->input_names[i].c_str());
        auto type_info = _state->session->GetInputTypeInfo(i);
        auto tensor_info = type_info.GetTensorTypeAndShapeInfo();
        auto shape = tensor_info.GetShape();
        PackedInt32Array s;
        for (auto dim : shape) s.push_back(static_cast<int32_t>(dim));
        d["shape"] = s;
        in_arr.push_back(d);
    }
    info["inputs"] = in_arr;

    // Output details
    Array out_arr;
    for (size_t i = 0; i < _state->output_names.size(); i++) {
        Dictionary d;
        d["name"] = String(_state->output_names[i].c_str());
        auto type_info = _state->session->GetOutputTypeInfo(i);
        auto tensor_info = type_info.GetTensorTypeAndShapeInfo();
        auto shape = tensor_info.GetShape();
        PackedInt32Array s;
        for (auto dim : shape) s.push_back(static_cast<int32_t>(dim));
        d["shape"] = s;
        out_arr.push_back(d);
    }
    info["outputs"] = out_arr;

    return info;
}
