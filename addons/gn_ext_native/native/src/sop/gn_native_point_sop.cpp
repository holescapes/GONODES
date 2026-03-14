#include "gn_native_point_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/expression.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

void GNNativePointSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "expr_x", "expr_y", "expr_z", "time_val"),
                         &GNNativePointSop::process);
}

Dictionary GNNativePointSop::process(const PackedVector3Array &verts,
                                      const PackedVector3Array &normals,
                                      const PackedVector2Array &uvs,
                                      const String &expr_x_str,
                                      const String &expr_y_str,
                                      const String &expr_z_str,
                                      double time_val) {
    Dictionary result;
    int count = verts.size();
    if (count == 0) {
        result["positions"] = PackedVector3Array();
        return result;
    }

    PackedStringArray var_names;
    var_names.push_back("px"); var_names.push_back("py"); var_names.push_back("pz");
    var_names.push_back("nx"); var_names.push_back("ny"); var_names.push_back("nz");
    var_names.push_back("u");  var_names.push_back("v");
    var_names.push_back("i");  var_names.push_back("n");  var_names.push_back("t");

    Ref<Expression> ex, ey, ez;
    ex.instantiate(); ey.instantiate(); ez.instantiate();

    if (ex->parse(expr_x_str, var_names) != OK ||
        ey->parse(expr_y_str, var_names) != OK ||
        ez->parse(expr_z_str, var_names) != OK) {
        result["positions"] = verts;
        result["error"] = true;
        return result;
    }

    const Vector3 *vp = verts.ptr();
    const Vector3 *np = normals.ptr();
    const Vector2 *up = uvs.ptr();
    bool has_n = (int)normals.size() == count;
    bool has_uv = (int)uvs.size() == count;

    PackedVector3Array out;
    out.resize(count);
    Vector3 *op = out.ptrw();

    Array vals;
    vals.resize(11);

    for (int i = 0; i < count; ++i) {
        Vector3 p = vp[i];
        Vector3 nm = has_n ? np[i] : Vector3(0, 1, 0);
        Vector2 uv = has_uv ? up[i] : Vector2(0, 0);

        vals[0] = p.x; vals[1] = p.y; vals[2] = p.z;
        vals[3] = nm.x; vals[4] = nm.y; vals[5] = nm.z;
        vals[6] = uv.x; vals[7] = uv.y;
        vals[8] = (double)i; vals[9] = (double)count; vals[10] = time_val;

        Variant rx = ex->execute(vals, nullptr, false);
        Variant ry = ey->execute(vals, nullptr, false);
        Variant rz = ez->execute(vals, nullptr, false);

        float ox = (rx.get_type() == Variant::FLOAT) ? (float)(double)rx :
                   (rx.get_type() == Variant::INT) ? (float)(int64_t)rx : p.x;
        float oy = (ry.get_type() == Variant::FLOAT) ? (float)(double)ry :
                   (ry.get_type() == Variant::INT) ? (float)(int64_t)ry : p.y;
        float oz = (rz.get_type() == Variant::FLOAT) ? (float)(double)rz :
                   (rz.get_type() == Variant::INT) ? (float)(int64_t)rz : p.z;

        op[i] = Vector3(ox, oy, oz);
    }

    result["positions"] = out;
    return result;
}

} // namespace godot
