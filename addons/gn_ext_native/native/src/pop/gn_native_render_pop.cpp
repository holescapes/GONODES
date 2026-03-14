#include "gn_native_render_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

void GNNativeRenderPop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "mm", "positions", "pscales",
                                  "base_size", "use_pscale"),
                         &GNNativeRenderPop::process);
}

void GNNativeRenderPop::process(const Ref<MultiMesh> &mm,
                                 const PackedVector3Array &positions,
                                 const PackedFloat32Array &pscales,
                                 double base_size, bool use_pscale) {
    if (mm.is_null()) return;

    int count = positions.size();
    if (count <= 0) return;

    mm->set_instance_count(count);
    const Vector3 *pp = positions.ptr();
    const float *ps = pscales.ptr();
    bool has_ps = use_pscale && (int)pscales.size() >= count;
    float bs = (float)base_size;

    for (int i = 0; i < count; ++i) {
        Transform3D xf;
        xf.origin = pp[i];
        if (has_ps) {
            float s = ps[i] * bs;
            xf.basis.scale(Vector3(s, s, s));
        } else {
            xf.basis.scale(Vector3(bs, bs, bs));
        }
        mm->set_instance_transform(i, xf);
    }
}

} // namespace godot
