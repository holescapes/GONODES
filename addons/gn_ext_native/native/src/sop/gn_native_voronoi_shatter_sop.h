#ifndef GN_NATIVE_VORONOI_SHATTER_SOP_H
#define GN_NATIVE_VORONOI_SHATTER_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeVoronoiShatterSop : public RefCounted {
    GDCLASS(GNNativeVoronoiShatterSop, RefCounted)
public:
    // Returns Array of Dictionaries, each with "vertices" and "indices" for a fragment
    TypedArray<Dictionary> process(const PackedVector3Array &mesh_verts,
                                    const PackedInt32Array &mesh_indices,
                                    const PackedVector3Array &scatter_points,
                                    int seed);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
