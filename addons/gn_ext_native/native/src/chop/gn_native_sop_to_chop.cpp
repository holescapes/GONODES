#include "gn_native_sop_to_chop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeSopToChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process_positions", "positions", "max_points"),
                         &GNNativeSopToChop::process_positions);
    ClassDB::bind_method(D_METHOD("process_normals", "normals", "max_points"),
                         &GNNativeSopToChop::process_normals);
    ClassDB::bind_method(D_METHOD("process_uvs", "uvs_flat", "max_points"),
                         &GNNativeSopToChop::process_uvs);
}

Dictionary GNNativeSopToChop::process_positions(const PackedVector3Array &positions,
                                                 int max_points) {
    Dictionary out;
    int count = MIN((int)positions.size(), max_points);
    PackedFloat32Array px, py, pz;
    px.resize(count); py.resize(count); pz.resize(count);
    float *fpx = px.ptrw(), *fpy = py.ptrw(), *fpz = pz.ptrw();
    const Vector3 *pos = positions.ptr();

    for (int i = 0; i < count; ++i) {
        fpx[i] = (float)pos[i].x;
        fpy[i] = (float)pos[i].y;
        fpz[i] = (float)pos[i].z;
    }

    out["px"] = px;
    out["py"] = py;
    out["pz"] = pz;
    out["length"] = count;
    return out;
}

Dictionary GNNativeSopToChop::process_normals(const PackedVector3Array &normals,
                                               int max_points) {
    Dictionary out;
    int count = MIN((int)normals.size(), max_points);
    PackedFloat32Array nx, ny, nz;
    nx.resize(count); ny.resize(count); nz.resize(count);
    float *fnx = nx.ptrw(), *fny = ny.ptrw(), *fnz = nz.ptrw();
    const Vector3 *nrm = normals.ptr();

    for (int i = 0; i < count; ++i) {
        fnx[i] = (float)nrm[i].x;
        fny[i] = (float)nrm[i].y;
        fnz[i] = (float)nrm[i].z;
    }

    out["nx"] = nx;
    out["ny"] = ny;
    out["nz"] = nz;
    out["length"] = count;
    return out;
}

Dictionary GNNativeSopToChop::process_uvs(const PackedFloat32Array &uvs_flat,
                                           int max_points) {
    Dictionary out;
    int total = uvs_flat.size() / 2;
    int count = MIN(total, max_points);
    PackedFloat32Array u, v;
    u.resize(count); v.resize(count);
    float *fu = u.ptrw(), *fv = v.ptrw();
    const float *uv = uvs_flat.ptr();

    for (int i = 0; i < count; ++i) {
        fu[i] = uv[i * 2];
        fv[i] = uv[i * 2 + 1];
    }

    out["u"] = u;
    out["v"] = v;
    out["length"] = count;
    return out;
}

} // namespace godot
