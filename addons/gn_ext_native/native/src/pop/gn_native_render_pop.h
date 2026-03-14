#ifndef GN_NATIVE_RENDER_POP_H
#define GN_NATIVE_RENDER_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Sets MultiMesh instance transforms from particle positions + pscale.
class GNNativeRenderPop : public RefCounted {
    GDCLASS(GNNativeRenderPop, RefCounted)

protected:
    static void _bind_methods();

public:
    void process(const Ref<MultiMesh> &mm,
                 const PackedVector3Array &positions,
                 const PackedFloat32Array &pscales,
                 double base_size, bool use_pscale);
};

} // namespace godot

#endif
