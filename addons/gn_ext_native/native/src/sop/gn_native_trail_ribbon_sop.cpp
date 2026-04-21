#include "gn_native_trail_ribbon_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <cmath>
namespace godot {
void GNNativeTrailRibbonSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "current_pos", "width", "max_frames", "up_vector"),
                         &GNNativeTrailRibbonSop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeTrailRibbonSop::reset);
}
void GNNativeTrailRibbonSop::reset() { _history.clear(); }
Dictionary GNNativeTrailRibbonSop::process(const Vector3 &current_pos, double width,
        int max_frames, const Vector3 &up_vector) {
    _max_frames = max_frames > 2 ? max_frames : 2;
    // Add current position
    _history.push_back(current_pos);
    if ((int)_history.size() > _max_frames)
        _history.erase(_history.begin());
    Dictionary result;
    int n = (int)_history.size();
    if (n < 2) {
        result["vertices"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        result["indices"] = PackedInt32Array();
        return result;
    }
    // Build ribbon: 2 vertices per point (left/right offset)
    int vert_count = n * 2;
    int tri_count = (n - 1) * 2;
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;
    vertices.resize(vert_count);
    normals.resize(vert_count);
    uvs.resize(vert_count);
    indices.resize(tri_count * 3);
    Vector3 *vp = vertices.ptrw();
    Vector3 *np = normals.ptrw();
    Vector2 *up_arr = uvs.ptrw();
    int *ip = indices.ptrw();
    float half_w = (float)(width * 0.5);
    for (int i = 0; i < n; ++i) {
        Vector3 fwd;
        if (i < n - 1) fwd = (_history[i+1] - _history[i]).normalized();
        else fwd = (_history[i] - _history[i-1]).normalized();
        if (fwd.length_squared() < 1e-8) fwd = Vector3(0, 0, 1);
        Vector3 right = fwd.cross(up_vector).normalized();
        if (right.length_squared() < 1e-8) {
            right = fwd.cross(Vector3(1, 0, 0)).normalized();
        }
        Vector3 norm = right.cross(fwd).normalized();
        float t = (float)i / (float)(n - 1);
        vp[i * 2] = _history[i] - right * half_w;
        vp[i * 2 + 1] = _history[i] + right * half_w;
        np[i * 2] = norm;
        np[i * 2 + 1] = norm;
        up_arr[i * 2] = Vector2(0.0f, t);
        up_arr[i * 2 + 1] = Vector2(1.0f, t);
    }
    int ii = 0;
    for (int i = 0; i < n - 1; ++i) {
        int bl = i * 2, br = i * 2 + 1;
        int tl = (i + 1) * 2, tr = (i + 1) * 2 + 1;
        ip[ii++] = bl; ip[ii++] = tl; ip[ii++] = br;
        ip[ii++] = br; ip[ii++] = tl; ip[ii++] = tr;
    }
    result["vertices"] = vertices;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
} // namespace godot
