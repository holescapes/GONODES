#ifndef GN_NATIVE_POLYREDUCE_H
#define GN_NATIVE_POLYREDUCE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

/// QEM-based mesh decimation processor.
/// Iterative edge-collapse using quadric error metrics —
/// same algorithm as the GDScript PolyReduceSOP but in C++ for speed.
class GNNativePolyReduce : public RefCounted {
    GDCLASS(GNNativePolyReduce, RefCounted);

protected:
    static void _bind_methods();

public:
    GNNativePolyReduce() = default;
    ~GNNativePolyReduce() = default;

    /// Returns Dictionary { "positions": PV3A, "normals": PV3A, "indices": PI32A }
    Dictionary process(const PackedVector3Array &positions,
                       const PackedInt32Array &indices,
                       double target_percent,
                       bool preserve_boundary,
                       double boundary_weight);

private:
    // Symmetric 4×4 quadric stored as 10 doubles (upper triangle row-major)
    struct Quadric {
        double q[10] = {};
        void add(const Quadric &o) {
            for (int i = 0; i < 10; ++i) q[i] += o.q[i];
        }
        double eval(const Vector3 &v) const {
            double x = v.x, y = v.y, z = v.z;
            return q[0]*x*x + 2.0*q[1]*x*y + 2.0*q[2]*x*z + 2.0*q[3]*x
                 + q[4]*y*y + 2.0*q[5]*y*z + 2.0*q[6]*y
                 + q[7]*z*z + 2.0*q[8]*z + q[9];
        }
        static Quadric from_plane(double a, double b, double c, double d) {
            Quadric qr;
            qr.q[0] = a*a; qr.q[1] = a*b; qr.q[2] = a*c; qr.q[3] = a*d;
            qr.q[4] = b*b; qr.q[5] = b*c; qr.q[6] = b*d;
            qr.q[7] = c*c; qr.q[8] = c*d; qr.q[9] = d*d;
            return qr;
        }
    };

    static int _resolve(int v, int *remap);
    static uint64_t _edge_key(int a, int b);
};

#endif // GN_NATIVE_POLYREDUCE_H
