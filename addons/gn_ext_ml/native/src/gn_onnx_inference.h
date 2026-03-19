#ifndef GN_ONNX_INFERENCE_H
#define GN_ONNX_INFERENCE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

// Forward-declare ONNX Runtime types to avoid requiring the header at parse time.
// The actual ORT header is included only in the .cpp file.
namespace Ort {
class Env;
class Session;
class SessionOptions;
class MemoryInfo;
class Value;
} // namespace Ort

using namespace godot;

/// Generic ONNX Runtime inference wrapper for GDScript.
///
/// Loads any ONNX model, accepts typed input tensors, runs inference,
/// and returns output tensors.  Model-specific pre/post processing
/// is handled in GDScript operators.
///
/// GDScript usage:
///   var onnx = ClassDB.instantiate("GNOnnxInference")
///   onnx.load_model("res://addons/gn_ext_ml/models/pose_landmark.onnx")
///   onnx.set_input_from_image("input", image, 256, 256)
///   onnx.run()
///   var landmarks = onnx.get_output_float("landmarks")
///   onnx.release()
class GNOnnxInference : public RefCounted {
    GDCLASS(GNOnnxInference, RefCounted);

protected:
    static void _bind_methods();

public:
    GNOnnxInference();
    ~GNOnnxInference();

    // ── Model Lifecycle ──────────────────────────────────────────────

    /// Load an ONNX model from the given file path.
    /// Returns true on success.
    bool load_model(const String &p_path);

    /// Release the loaded model and free memory.
    void release();

    /// Returns true if a model is currently loaded.
    bool is_loaded() const;

    // ── Execution Provider ───────────────────────────────────────────

    /// Set the execution provider before loading a model.
    /// Supported: "cpu", "cuda", "directml", "coreml"
    void set_execution_provider(const String &p_provider);

    /// Get the current execution provider name.
    String get_execution_provider() const;

    // ── Input Setup ──────────────────────────────────────────────────

    /// Set raw float tensor data for the named input.
    /// [param shape]: dimension array, e.g. [1, 3, 256, 256]
    void set_input_float(const String &p_name,
                         const PackedFloat32Array &p_data,
                         const PackedInt32Array &p_shape);

    /// Set input from a Godot Image, auto-converting to the
    /// NCHW float32 tensor format expected by most vision models.
    /// Resizes to target_w × target_h, normalizes to [0, 1].
    void set_input_from_image(const String &p_name,
                              const Ref<Image> &p_image,
                              int p_target_w, int p_target_h);

    /// Set input from a Godot Image, with custom mean/std
    /// normalization per channel (ImageNet-style).
    /// mean/std arrays must have 3 elements (R, G, B).
    void set_input_from_image_normalized(const String &p_name,
                                         const Ref<Image> &p_image,
                                         int p_target_w, int p_target_h,
                                         const PackedFloat32Array &p_mean,
                                         const PackedFloat32Array &p_std);

    // ── Inference ────────────────────────────────────────────────────

    /// Run inference.  Returns true on success.
    bool run();

    // ── Output Access ────────────────────────────────────────────────

    /// Get float output tensor by name.
    PackedFloat32Array get_output_float(const String &p_name) const;

    /// Get int64 output tensor cast to int32 by name.
    PackedInt32Array get_output_int(const String &p_name) const;

    /// Get the shape of an output tensor.
    PackedInt32Array get_output_shape(const String &p_name) const;

    // ── Introspection ────────────────────────────────────────────────

    /// Get the names of all model inputs.
    PackedStringArray get_input_names() const;

    /// Get the names of all model outputs.
    PackedStringArray get_output_names() const;

    /// Get a dictionary of model metadata.
    Dictionary get_model_info() const;

private:
    // Opaque pointers — actual ONNX Runtime types.
    // Defined in .cpp to avoid header dependency.
    struct OrtState;
    OrtState *_state = nullptr;
    String _provider = "cpu";
};

#endif // GN_ONNX_INFERENCE_H
