#include "gn_native_composite_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeCompositeChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "inputs", "weights", "op"),
                         &GNNativeCompositeChop::process);
}

Dictionary GNNativeCompositeChop::process(const Array &inputs,
                                           const PackedFloat32Array &weights,
                                           int op) {
    Dictionary out;
    int num_inputs = inputs.size();
    if (num_inputs == 0) return out;

    const float *w = weights.ptr();
    int w_count = weights.size();

    // Collect all channel names
    HashMap<String, bool> all_names;
    for (int i = 0; i < num_inputs; ++i) {
        Dictionary ch = inputs[i];
        Array keys = ch.keys();
        for (int k = 0; k < keys.size(); ++k) {
            all_names[keys[k]] = true;
        }
    }

    for (auto it = all_names.begin(); it != all_names.end(); ++it) {
        String ch_name = it->key;
        std::vector<float> values;
        std::vector<float> w_list;

        for (int i = 0; i < num_inputs; ++i) {
            Dictionary ch = inputs[i];
            if (!ch.has(ch_name)) continue;
            PackedFloat32Array samples = ch[ch_name];
            if (samples.size() == 0) continue;
            float val = samples.ptr()[samples.size() - 1];
            float wi = (i < w_count) ? w[i] : 1.0f;
            values.push_back(val);
            w_list.push_back(wi);
        }

        if (values.empty()) continue;

        float result = 0.0f;
        switch (op) {
            case 0: { // Weighted Average
                float total_w = 0.0f;
                for (size_t i = 0; i < values.size(); ++i) {
                    result += values[i] * w_list[i];
                    total_w += w_list[i];
                }
                result = (total_w > 0.0001f) ? result / total_w : 0.0f;
                break;
            }
            case 1: // Add
                for (size_t i = 0; i < values.size(); ++i)
                    result += values[i] * w_list[i];
                break;
            case 2: // Max
                result = values[0];
                for (size_t i = 1; i < values.size(); ++i)
                    result = (values[i] > result) ? values[i] : result;
                break;
            case 3: // Min
                result = values[0];
                for (size_t i = 1; i < values.size(); ++i)
                    result = (values[i] < result) ? values[i] : result;
                break;
        }

        PackedFloat32Array ch_out;
        ch_out.resize(1);
        ch_out.ptrw()[0] = result;
        out[ch_name] = ch_out;
    }

    return out;
}

} // namespace godot
