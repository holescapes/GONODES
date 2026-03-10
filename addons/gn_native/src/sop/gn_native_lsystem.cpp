#include "gn_native_lsystem.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <cmath>
#include <string>
#include <vector>
#include <unordered_map>

namespace godot {

void GNNativeLSystem::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "axiom", "rules_str", "iterations",
                                  "step_size", "angle_deg", "step_scale",
                                  "angle_rand", "seed", "tube_radius",
                                  "tube_sides", "taper", "gravity"),
                         &GNNativeLSystem::process);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal helpers
// ═══════════════════════════════════════════════════════════════════════════════

struct TurtleState {
    Vector3 position;
    Vector3 heading;   // forward
    Vector3 left;
    Vector3 up;
    float step;
    float radius_scale;
};

static void _parse_rules(const String &rules_str,
                          std::unordered_map<char32_t, std::vector<char32_t>> &rules) {
    PackedStringArray parts = rules_str.split(";", false);
    for (int i = 0; i < parts.size(); ++i) {
        String rule = parts[i].strip_edges();
        if (rule.length() < 3) continue;
        int eq = rule.find("=");
        if (eq < 1) continue;
        char32_t pred = rule[0];
        std::vector<char32_t> succ;
        for (int j = eq + 1; j < rule.length(); ++j) {
            succ.push_back(rule[j]);
        }
        rules[pred] = succ;
    }
}

static std::vector<char32_t> _rewrite(const String &axiom,
                                        const std::unordered_map<char32_t, std::vector<char32_t>> &rules,
                                        int iterations) {
    std::vector<char32_t> current;
    for (int i = 0; i < axiom.length(); ++i) current.push_back(axiom[i]);

    for (int iter = 0; iter < iterations; ++iter) {
        std::vector<char32_t> next;
        next.reserve(current.size() * 2);
        for (char32_t c : current) {
            auto it = rules.find(c);
            if (it != rules.end()) {
                next.insert(next.end(), it->second.begin(), it->second.end());
            } else {
                next.push_back(c);
            }
        }
        current = std::move(next);
        if (current.size() > 1000000) break; // safety limit
    }
    return current;
}

static Basis _rotate_heading(const Basis &b, float angle_rad, int axis) {
    switch (axis) {
        case 0: return b.rotated(b.get_column(2), angle_rad); // yaw (around up)
        case 1: return b.rotated(b.get_column(0), angle_rad); // pitch (around left)
        case 2: return b.rotated(b.get_column(1), angle_rad); // roll (around heading)
        default: return b;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main process
// ═══════════════════════════════════════════════════════════════════════════════

Dictionary GNNativeLSystem::process(const String &axiom, const String &rules_str,
                                     int iterations, double step_size, double angle_deg,
                                     double step_scale, double angle_rand, int seed,
                                     double tube_radius, int tube_sides, double taper,
                                     double gravity) {
    // Parse rules
    std::unordered_map<char32_t, std::vector<char32_t>> rules;
    _parse_rules(rules_str, rules);

    // Rewrite
    iterations = CLAMP(iterations, 0, 10);
    std::vector<char32_t> result_str = _rewrite(axiom, rules, iterations);

    // Turtle interpretation
    float angle_rad = (float)(angle_deg * Math_PI / 180.0);
    float step = (float)step_size;
    float grav = (float)gravity;

    TurtleState turtle;
    turtle.position = Vector3(0, 0, 0);
    turtle.heading = Vector3(0, 1, 0);
    turtle.left = Vector3(-1, 0, 0);
    turtle.up = Vector3(0, 0, 1);
    turtle.step = step;
    turtle.radius_scale = 1.0f;

    std::vector<TurtleState> stack;
    std::vector<Vector3> segments_start;
    std::vector<Vector3> segments_end;
    std::vector<float> seg_radius_start;
    std::vector<float> seg_radius_end;

    // Simple LCG for angle randomization
    uint32_t rng = (uint32_t)seed;
    auto rand_float = [&rng]() -> float {
        rng = rng * 1103515245u + 12345u;
        return (float)(rng & 0x7FFFFFFF) / (float)0x7FFFFFFF;
    };

    int depth = 0;
    for (char32_t c : result_str) {
        Basis basis(turtle.left, turtle.heading, turtle.up);

        float rand_offset = (float)angle_rand * (rand_float() * 2.0f - 1.0f) * (float)(Math_PI / 180.0);

        switch (c) {
            case 'F':
            case 'G': {
                Vector3 start = turtle.position;
                float r_start = turtle.radius_scale;
                turtle.position += turtle.heading * turtle.step;
                turtle.position.y += grav * turtle.step * 0.01f; // slight gravity
                turtle.step *= (float)step_scale;
                turtle.radius_scale *= (float)taper;
                segments_start.push_back(start);
                segments_end.push_back(turtle.position);
                seg_radius_start.push_back(r_start);
                seg_radius_end.push_back(turtle.radius_scale);
                break;
            }
            case '+': { // yaw right
                basis = _rotate_heading(basis, angle_rad + rand_offset, 0);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '-': { // yaw left
                basis = _rotate_heading(basis, -(angle_rad + rand_offset), 0);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '&': { // pitch down
                basis = _rotate_heading(basis, angle_rad + rand_offset, 1);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '^': { // pitch up
                basis = _rotate_heading(basis, -(angle_rad + rand_offset), 1);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '\\': { // roll CW
                basis = _rotate_heading(basis, angle_rad + rand_offset, 2);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '/': { // roll CCW
                basis = _rotate_heading(basis, -(angle_rad + rand_offset), 2);
                turtle.heading = basis.get_column(1);
                turtle.left = basis.get_column(0);
                turtle.up = basis.get_column(2);
                break;
            }
            case '[':
                stack.push_back(turtle);
                ++depth;
                break;
            case ']':
                if (!stack.empty()) {
                    turtle = stack.back();
                    stack.pop_back();
                    --depth;
                }
                break;
            default:
                break;
        }
    }

    // Build geometry
    Dictionary out;
    PackedVector3Array out_positions;
    PackedVector3Array out_normals;

    if (segments_start.empty()) {
        out["positions"] = out_positions;
        out["normals"] = out_normals;
        return out;
    }

    bool tube_mode = tube_radius > 0.001 && tube_sides >= 3;

    if (!tube_mode) {
        // Line pairs
        out_positions.resize(segments_start.size() * 2);
        out_normals.resize(segments_start.size() * 2);
        Vector3 *pp = out_positions.ptrw();
        Vector3 *np = out_normals.ptrw();
        for (size_t i = 0; i < segments_start.size(); ++i) {
            pp[i * 2] = segments_start[i];
            pp[i * 2 + 1] = segments_end[i];
            Vector3 dir = (segments_end[i] - segments_start[i]).normalized();
            np[i * 2] = dir;
            np[i * 2 + 1] = dir;
        }
    } else {
        // Tube mesh: for each segment, generate start and end rings, connect with triangles
        float base_r = (float)tube_radius;
        int sides = CLAMP(tube_sides, 3, 32);

        // Pre-compute unit circle
        std::vector<float> circle_x(sides), circle_z(sides);
        for (int i = 0; i < sides; ++i) {
            float a = (float)i / (float)sides * (float)(Math_PI * 2.0);
            circle_x[i] = std::cos(a);
            circle_z[i] = std::sin(a);
        }

        // Reserve: each segment = sides * 2 triangles = sides * 6 vertices
        int total_verts = (int)segments_start.size() * sides * 6;
        out_positions.resize(total_verts);
        out_normals.resize(total_verts);
        Vector3 *pp = out_positions.ptrw();
        Vector3 *np = out_normals.ptrw();

        int vi = 0;
        for (size_t si = 0; si < segments_start.size(); ++si) {
            Vector3 p0 = segments_start[si];
            Vector3 p1 = segments_end[si];
            Vector3 dir = (p1 - p0);
            float seg_len = dir.length();
            if (seg_len < 1e-6f) continue;
            dir /= seg_len;

            // Build local frame
            Vector3 perp;
            if (std::fabs(dir.dot(Vector3(0, 1, 0))) > 0.999f)
                perp = Vector3(1, 0, 0);
            else
                perp = dir.cross(Vector3(0, 1, 0)).normalized();
            Vector3 perp2 = perp.cross(dir).normalized();

            float r0 = base_r * seg_radius_start[si];
            float r1 = base_r * seg_radius_end[si];

            for (int i = 0; i < sides; ++i) {
                int j = (i + 1) % sides;

                Vector3 n0_i = (perp * circle_x[i] + perp2 * circle_z[i]);
                Vector3 n0_j = (perp * circle_x[j] + perp2 * circle_z[j]);

                Vector3 v00 = p0 + n0_i * r0;
                Vector3 v01 = p0 + n0_j * r0;
                Vector3 v10 = p1 + n0_i * r1;
                Vector3 v11 = p1 + n0_j * r1;

                // Triangle 1
                pp[vi] = v00; np[vi] = n0_i.normalized(); ++vi;
                pp[vi] = v10; np[vi] = n0_i.normalized(); ++vi;
                pp[vi] = v01; np[vi] = n0_j.normalized(); ++vi;

                // Triangle 2
                pp[vi] = v01; np[vi] = n0_j.normalized(); ++vi;
                pp[vi] = v10; np[vi] = n0_i.normalized(); ++vi;
                pp[vi] = v11; np[vi] = n0_j.normalized(); ++vi;
            }
        }

        // Trim if some segments were skipped
        if (vi < total_verts) {
            out_positions.resize(vi);
            out_normals.resize(vi);
        }
    }

    out["positions"] = out_positions;
    out["normals"] = out_normals;
    return out;
}

} // namespace godot
