#include "gn_native_boolean_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>
#include <memory>

namespace godot {

// ---------------------------------------------------------------------------
// BSP-tree CSG algorithm (based on the binary space partitioning approach)
// ---------------------------------------------------------------------------

static constexpr double BSP_EPSILON = 1e-5;

enum SplitClass { COPLANAR = 0, FRONT = 1, BACK = 2, SPANNING = 3 };

struct CSGVertex {
    Vector3 pos;
    Vector3 normal;
};

struct CSGPlane {
    Vector3 normal;
    double d;

    CSGPlane() : normal(0, 1, 0), d(0) {}
    CSGPlane(const Vector3 &n, double dist) : normal(n), d(dist) {}

    static CSGPlane from_points(const Vector3 &a, const Vector3 &b, const Vector3 &c) {
        Vector3 n = (b - a).cross(c - a).normalized();
        return CSGPlane(n, n.dot(a));
    }
};

struct CSGPolygon {
    std::vector<CSGVertex> vertices;
    CSGPlane plane;

    void calc_plane() {
        if (vertices.size() >= 3) {
            plane = CSGPlane::from_points(vertices[0].pos, vertices[1].pos, vertices[2].pos);
        }
    }

    void flip() {
        for (int i = 0; i < (int)vertices.size(); ++i) {
            vertices[i].normal = -vertices[i].normal;
        }
        std::reverse(vertices.begin(), vertices.end());
        plane.normal = -plane.normal;
        plane.d = -plane.d;
    }
};

struct BSPNode {
    CSGPlane plane;
    std::unique_ptr<BSPNode> front;
    std::unique_ptr<BSPNode> back;
    std::vector<CSGPolygon> polygons;

    BSPNode() {}
    explicit BSPNode(const std::vector<CSGPolygon> &polys) {
        build(polys);
    }

    // Invert all polygons and the BSP tree structure.
    void invert() {
        for (auto &p : polygons) {
            p.flip();
        }
        plane.normal = -plane.normal;
        plane.d = -plane.d;
        if (front) front->invert();
        if (back) back->invert();
        std::swap(front, back);
    }

    // Collect all polygons from this BSP tree.
    std::vector<CSGPolygon> all_polygons() const {
        std::vector<CSGPolygon> result = polygons;
        if (front) {
            auto fp = front->all_polygons();
            result.insert(result.end(), fp.begin(), fp.end());
        }
        if (back) {
            auto bp = back->all_polygons();
            result.insert(result.end(), bp.begin(), bp.end());
        }
        return result;
    }

    // Remove polygons from this BSP that are inside the other BSP.
    void clip_to(const BSPNode &other) {
        polygons = other.clip_polygons(polygons);
        if (front) front->clip_to(other);
        if (back) back->clip_to(other);
    }

    // Return a list of polygons that are not inside this BSP tree.
    std::vector<CSGPolygon> clip_polygons(const std::vector<CSGPolygon> &polys) const {
        if (polygons.empty() && !front && !back) {
            // Empty tree → nothing clipped.
            return polys;
        }

        std::vector<CSGPolygon> front_polys, back_polys;

        for (const auto &poly : polys) {
            split_polygon(poly, front_polys, back_polys, front_polys, back_polys);
        }

        if (front) {
            front_polys = front->clip_polygons(front_polys);
        }

        if (back) {
            back_polys = back->clip_polygons(back_polys);
        } else {
            // No back node → discard back polygons (they're inside).
            back_polys.clear();
        }

        front_polys.insert(front_polys.end(), back_polys.begin(), back_polys.end());
        return front_polys;
    }

    // Build this BSP tree from a list of polygons.
    void build(const std::vector<CSGPolygon> &polys) {
        if (polys.empty()) return;

        if (polygons.empty() && !front && !back) {
            plane = polys[0].plane;
        }

        std::vector<CSGPolygon> front_polys, back_polys;

        for (const auto &poly : polys) {
            split_polygon(poly, polygons, polygons, front_polys, back_polys);
        }

        if (!front_polys.empty()) {
            if (!front) front = std::make_unique<BSPNode>();
            front->build(front_polys);
        }

        if (!back_polys.empty()) {
            if (!back) back = std::make_unique<BSPNode>();
            back->build(back_polys);
        }
    }

private:
    // Classify and split a polygon against this node's plane.
    void split_polygon(
            const CSGPolygon &poly,
            std::vector<CSGPolygon> &coplanar_front,
            std::vector<CSGPolygon> &coplanar_back,
            std::vector<CSGPolygon> &out_front,
            std::vector<CSGPolygon> &out_back) const {

        int ptype = 0;
        int vcount = (int)poly.vertices.size();
        std::vector<int> types(vcount);

        for (int i = 0; i < vcount; ++i) {
            double t = plane.normal.dot(poly.vertices[i].pos) - plane.d;
            int type = (t < -BSP_EPSILON) ? BACK : (t > BSP_EPSILON) ? FRONT
                                                                      : COPLANAR;
            ptype |= type;
            types[i] = type;
        }

        switch (ptype) {
            case COPLANAR:
                if (plane.normal.dot(poly.plane.normal) > 0)
                    coplanar_front.push_back(poly);
                else
                    coplanar_back.push_back(poly);
                break;

            case FRONT:
                out_front.push_back(poly);
                break;

            case BACK:
                out_back.push_back(poly);
                break;

            case SPANNING: {
                std::vector<CSGVertex> f_verts, b_verts;

                for (int i = 0; i < vcount; ++i) {
                    int j = (i + 1) % vcount;
                    int ti = types[i];
                    int tj = types[j];
                    const CSGVertex &vi = poly.vertices[i];
                    const CSGVertex &vj = poly.vertices[j];

                    if (ti != BACK) f_verts.push_back(vi);
                    if (ti != FRONT) b_verts.push_back(vi);

                    if ((ti | tj) == SPANNING) {
                        double di = plane.normal.dot(vi.pos) - plane.d;
                        double dj = plane.normal.dot(vj.pos) - plane.d;
                        double t = di / (di - dj);
                        CSGVertex interp;
                        interp.pos = vi.pos.lerp(vj.pos, t);
                        interp.normal = vi.normal.lerp(vj.normal, t).normalized();
                        f_verts.push_back(interp);
                        b_verts.push_back(interp);
                    }
                }

                if (f_verts.size() >= 3) {
                    CSGPolygon fp;
                    fp.vertices = std::move(f_verts);
                    fp.plane = poly.plane;
                    out_front.push_back(std::move(fp));
                }
                if (b_verts.size() >= 3) {
                    CSGPolygon bp;
                    bp.vertices = std::move(b_verts);
                    bp.plane = poly.plane;
                    out_back.push_back(std::move(bp));
                }
                break;
            }
        }
    }
};

// ---------------------------------------------------------------------------
// Helper: convert indexed triangle mesh to CSG polygons
// ---------------------------------------------------------------------------
static std::vector<CSGPolygon> mesh_to_polygons(
        const PackedVector3Array &positions,
        const PackedInt32Array &indices) {
    const Vector3 *pos = positions.ptr();
    const int *idx = indices.ptr();
    int tri_count = indices.size() / 3;

    std::vector<CSGPolygon> polys;
    polys.reserve(tri_count);

    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3];
        int i1 = idx[t * 3 + 1];
        int i2 = idx[t * 3 + 2];

        // Skip degenerate triangles.
        Vector3 edge1 = pos[i1] - pos[i0];
        Vector3 edge2 = pos[i2] - pos[i0];
        Vector3 fn = edge1.cross(edge2);
        if (fn.length_squared() < 1e-12) continue;

        fn = fn.normalized();

        CSGPolygon poly;
        poly.vertices.resize(3);
        poly.vertices[0] = { pos[i0], fn };
        poly.vertices[1] = { pos[i1], fn };
        poly.vertices[2] = { pos[i2], fn };
        poly.plane = CSGPlane::from_points(pos[i0], pos[i1], pos[i2]);
        polys.push_back(std::move(poly));
    }

    return polys;
}

// ---------------------------------------------------------------------------
// Helper: convert CSG polygons back to indexed triangle mesh
// ---------------------------------------------------------------------------
static void polygons_to_mesh(
        const std::vector<CSGPolygon> &polys,
        PackedVector3Array &out_positions,
        PackedInt32Array &out_indices,
        PackedVector3Array &out_normals) {

    // Fan-triangulate each polygon (they may have 3+ vertices after splits).
    int total_verts = 0;
    int total_tris = 0;
    for (const auto &p : polys) {
        int vc = (int)p.vertices.size();
        if (vc < 3) continue;
        total_verts += vc;
        total_tris += vc - 2;
    }

    out_positions.resize(total_verts);
    out_normals.resize(total_verts);
    out_indices.resize(total_tris * 3);

    Vector3 *pos_w = out_positions.ptrw();
    Vector3 *nrm_w = out_normals.ptrw();
    int *idx_w = out_indices.ptrw();

    int vi = 0;
    int ii = 0;
    for (const auto &p : polys) {
        int vc = (int)p.vertices.size();
        if (vc < 3) continue;

        int base = vi;
        for (int v = 0; v < vc; ++v) {
            pos_w[vi] = p.vertices[v].pos;
            nrm_w[vi] = p.vertices[v].normal;
            ++vi;
        }

        // Fan triangulation from vertex 0.
        for (int t = 1; t < vc - 1; ++t) {
            idx_w[ii++] = base;
            idx_w[ii++] = base + t;
            idx_w[ii++] = base + t + 1;
        }
    }
}

// ---------------------------------------------------------------------------
// GDExtension binding
// ---------------------------------------------------------------------------

void GNNativeBooleanSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process",
                                  "positions_a", "indices_a",
                                  "positions_b", "indices_b",
                                  "operation"),
                         &GNNativeBooleanSop::process);
}

Dictionary GNNativeBooleanSop::process(
        const PackedVector3Array &positions_a,
        const PackedInt32Array &indices_a,
        const PackedVector3Array &positions_b,
        const PackedInt32Array &indices_b,
        int operation) {
    Dictionary result;

    if (positions_a.size() < 3 || indices_a.size() < 3 ||
        positions_b.size() < 3 || indices_b.size() < 3) {
        result["positions"] = positions_a;
        result["indices"] = indices_a;
        result["normals"] = PackedVector3Array();
        return result;
    }

    auto polys_a = mesh_to_polygons(positions_a, indices_a);
    auto polys_b = mesh_to_polygons(positions_b, indices_b);

    if (polys_a.empty() || polys_b.empty()) {
        result["positions"] = positions_a;
        result["indices"] = indices_a;
        result["normals"] = PackedVector3Array();
        return result;
    }

    BSPNode a(polys_a);
    BSPNode b(polys_b);

    switch (operation) {
        case 0: {
            // Union: A + B - intersection volume
            a.clip_to(b);
            b.clip_to(a);
            b.invert();
            b.clip_to(a);
            b.invert();
            a.build(b.all_polygons());
            break;
        }
        case 1: {
            // Intersection: keep only the shared volume
            a.invert();
            b.clip_to(a);
            b.invert();
            a.clip_to(b);
            b.clip_to(a);
            a.build(b.all_polygons());
            a.invert();
            break;
        }
        case 2:
        default: {
            // Subtraction: A - B
            a.invert();
            a.clip_to(b);
            b.clip_to(a);
            b.invert();
            b.clip_to(a);
            b.invert();
            a.build(b.all_polygons());
            a.invert();
            break;
        }
    }

    auto result_polys = a.all_polygons();

    PackedVector3Array out_pos;
    PackedInt32Array out_idx;
    PackedVector3Array out_nrm;
    polygons_to_mesh(result_polys, out_pos, out_idx, out_nrm);

    result["positions"] = out_pos;
    result["indices"] = out_idx;
    result["normals"] = out_nrm;
    return result;
}

} // namespace godot
