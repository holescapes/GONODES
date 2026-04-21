#include "gn_native_join_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
void GNNativeJoinChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "a", "b", "overlap"), &GNNativeJoinChop::process);
}
Dictionary GNNativeJoinChop::process(const Dictionary &a, const Dictionary &b, int overlap) {
    Dictionary out;
    Array keys_a = a.keys();
    for (int ki = 0; ki < keys_a.size(); ++ki) {
        String name = keys_a[ki];
        PackedFloat32Array da = a[name];
        PackedFloat32Array db = b.has(name) ? (PackedFloat32Array)b[name] : PackedFloat32Array();
        int sa = da.size(), sb = db.size();
        int ov = MIN(overlap, MIN(sa, sb));
        int total = sa + sb - ov;
        PackedFloat32Array result;
        result.resize(total);
        float *rp = result.ptrw();
        const float *ap = da.ptr();
        const float *bp = db.ptr();
        for (int i = 0; i < sa - ov; ++i) rp[i] = ap[i];
        for (int i = 0; i < ov; ++i) {
            float t = (float)(i + 1) / (float)(ov + 1);
            rp[sa - ov + i] = ap[sa - ov + i] * (1.0f - t) + bp[i] * t;
        }
        for (int i = ov; i < sb; ++i) rp[sa - ov + i] = bp[i];
        out[name] = result;
    }
    return out;
}
} // namespace godot
