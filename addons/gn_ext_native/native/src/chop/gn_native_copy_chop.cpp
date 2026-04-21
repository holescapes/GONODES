#include "gn_native_copy_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeCopyChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels_a", "channels_b", "operation"),
                         &GNNativeCopyChop::process);
}

static PackedFloat32Array combine_arrays(const PackedFloat32Array &a,
                                          const PackedFloat32Array &b, int op) {
    int len_a = a.size();
    int len_b = b.size();
    int len_out = len_a > len_b ? len_a : len_b;

    PackedFloat32Array result;
    result.resize(len_out);
    float *out = result.ptrw();
    const float *pa = a.ptr();
    const float *pb = b.ptr();

    for (int i = 0; i < len_out; ++i) {
        float va = (len_a > 0) ? pa[i < len_a ? i : len_a - 1] : 0.0f;
        float vb = (len_b > 0) ? pb[i < len_b ? i : len_b - 1] : 0.0f;
        switch (op) {
            case 1: out[i] = va + vb; break;
            case 2: out[i] = va - vb; break;
            case 3: out[i] = va * vb; break;
            default: out[i] = vb; break; // 0 = Overwrite
        }
    }
    return result;
}

Dictionary GNNativeCopyChop::process(const Dictionary &channels_a,
                                      const Dictionary &channels_b, int operation) {
    Dictionary out;

    // Process A channels — combine with B where matching
    if (!channels_a.is_empty()) {
        Array keys_a = channels_a.keys();
        for (int i = 0; i < keys_a.size(); ++i) {
            String name = keys_a[i];
            PackedFloat32Array sa = channels_a[name];
            if (channels_b.has(name)) {
                PackedFloat32Array sb = channels_b[name];
                out[name] = combine_arrays(sa, sb, operation);
            }
            // non-matching A channels are handled by wrapper (pass_non_matching param)
        }
    }

    // B-only channels are handled by wrapper (always passed through)
    return out;
}

} // namespace godot
