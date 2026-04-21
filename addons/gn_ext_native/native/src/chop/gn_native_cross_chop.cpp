#include "gn_native_cross_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
void GNNativeCrossChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "a", "b", "cross"), &GNNativeCrossChop::process);
}
Dictionary GNNativeCrossChop::process(const Dictionary &a, const Dictionary &b, double cross) {
    Dictionary out;
    Array keys_a = a.keys();
    for (int ki = 0; ki < keys_a.size(); ++ki) {
        String name = keys_a[ki];
        PackedFloat32Array da = a[name];
        PackedFloat32Array db = b.has(name) ? (PackedFloat32Array)b[name] : PackedFloat32Array();
        int max_len = MAX(da.size(), db.size());
        PackedFloat32Array result;
        result.resize(max_len);
        float *rp = result.ptrw();
        const float *ap = da.ptr();
        const float *bp = db.ptr();
        int as = da.size(), bs = db.size();
        float cf = (float)cross;
        for (int i = 0; i < max_len; ++i) {
            float va = i < as ? ap[i] : (as > 0 ? ap[as - 1] : 0.0f);
            float vb = i < bs ? bp[i] : (bs > 0 ? bp[bs - 1] : 0.0f);
            rp[i] = va + cf * (vb - va);
        }
        out[name] = result;
    }
    // Include channels only in b
    Array keys_b = b.keys();
    for (int ki = 0; ki < keys_b.size(); ++ki) {
        String name = keys_b[ki];
        if (!out.has(name)) {
            PackedFloat32Array db = b[name];
            PackedFloat32Array result;
            result.resize(db.size());
            float *rp = result.ptrw();
            const float *bp = db.ptr();
            float cf = (float)cross;
            for (int i = 0; i < db.size(); ++i) rp[i] = cf * bp[i];
            out[name] = result;
        }
    }
    return out;
}
} // namespace godot
