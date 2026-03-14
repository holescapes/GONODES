#include "gn_native_attribute_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/expression.hpp>
#include <godot_cpp/variant/array.hpp>



namespace godot {

void GNNativeAttributeSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "source", "const_val", "expression",
                                  "time_val", "seed", "rand_min", "rand_max"),
                         &GNNativeAttributeSop::process);
}

PackedFloat32Array GNNativeAttributeSop::process(const PackedVector3Array &verts,
                                                  const PackedVector3Array &normals,
                                                  const PackedVector2Array &uvs,
                                                  int source, double const_val,
                                                  const String &expression,
                                                  double time_val,
                                                  int seed, double rand_min,
                                                  double rand_max) {
    int n = verts.size();
    PackedFloat32Array out;
    out.resize(n);
    float *op = out.ptrw();

    const Vector3 *vp = verts.ptr();
    const Vector3 *np = (int)normals.size() == n ? normals.ptr() : nullptr;
    const Vector2 *up = (int)uvs.size() == n ? uvs.ptr() : nullptr;

    switch (source) {
        case 0: // Constant
            for (int i = 0; i < n; ++i) op[i] = (float)const_val;
            break;

        case 1: { // Expression
            PackedStringArray var_names;
            var_names.push_back("px"); var_names.push_back("py");
            var_names.push_back("pz");
            var_names.push_back("nx"); var_names.push_back("ny");
            var_names.push_back("nz");
            var_names.push_back("u");  var_names.push_back("v");
            var_names.push_back("i");  var_names.push_back("n");
            var_names.push_back("t");

            Ref<Expression> expr;
            expr.instantiate();
            if (expr->parse(expression, var_names) != OK) {
                for (int i = 0; i < n; ++i) op[i] = 0.0f;
                break;
            }

            Array vals;
            vals.resize(11);
            for (int i = 0; i < n; ++i) {
                Vector3 p = vp[i];
                Vector3 nm = np ? np[i] : Vector3(0, 1, 0);
                Vector2 uv = up ? up[i] : Vector2(0, 0);

                vals[0] = p.x; vals[1] = p.y; vals[2] = p.z;
                vals[3] = nm.x; vals[4] = nm.y; vals[5] = nm.z;
                vals[6] = uv.x; vals[7] = uv.y;
                vals[8] = (double)i; vals[9] = (double)n; vals[10] = time_val;

                Variant r = expr->execute(vals, nullptr, false);
                if (r.get_type() == Variant::FLOAT) op[i] = (float)(double)r;
                else if (r.get_type() == Variant::INT) op[i] = (float)(int64_t)r;
                else op[i] = 0.0f;
            }
            break;
        }

        case 2: // px
            for (int i = 0; i < n; ++i) op[i] = vp[i].x;
            break;
        case 3: // py
            for (int i = 0; i < n; ++i) op[i] = vp[i].y;
            break;
        case 4: // pz
            for (int i = 0; i < n; ++i) op[i] = vp[i].z;
            break;
        case 5: // ny
            for (int i = 0; i < n; ++i) op[i] = np ? np[i].y : 0.0f;
            break;
        case 6: // uv_u
            for (int i = 0; i < n; ++i) op[i] = up ? up[i].x : 0.0f;
            break;
        case 7: { // random
            srand(seed);
            float rmin = (float)rand_min, rmax = (float)rand_max;
            float rng = rmax - rmin;
            for (int i = 0; i < n; ++i) {
                op[i] = rmin + ((float)rand() / (float)RAND_MAX) * rng;
            }
            break;
        }
        default:
            for (int i = 0; i < n; ++i) op[i] = 0.0f;
    }

    return out;
}

} // namespace godot
