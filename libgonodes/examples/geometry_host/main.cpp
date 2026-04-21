/*
 * GONODES Geometry Host Example
 *
 * Demonstrates the v2.0 geometry/SOP exchange API:
 *   • Pushing vertex data into a HostInSOP node
 *   • Reading cooked geometry from SOP/COMP output nodes
 *   • Texture info query for output TOPs
 *   • Geometry data inspection (positions, normals, UVs, indices)
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target geometry_host
 *
 * Run:
 *   ./geometry_host path/to/gonodes_project path/to/geometry_demo.gnpatch
 */

#include <gonodes_host.h>

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Helpers                                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void print_geometry(const char* label, const gonodes_geometry_data_t* geo) {
    if (!geo) {
        printf("  %s: (null — no geometry available)\n", label);
        return;
    }
    const char* prim_names[] = {"triangles", "lines", "points"};
    const char* prim = (geo->primitive_type >= 0 && geo->primitive_type <= 2)
                       ? prim_names[geo->primitive_type] : "unknown";

    printf("  %s: %d vertices, %d indices, primitive=%s\n",
           label, geo->vertex_count, geo->index_count, prim);

    /* Print first few vertices. */
    int n = geo->vertex_count < 4 ? geo->vertex_count : 4;
    for (int i = 0; i < n; ++i) {
        printf("    v[%d] pos=(%.3f, %.3f, %.3f)",
               i, geo->positions[i*3], geo->positions[i*3+1], geo->positions[i*3+2]);
        if (geo->normals)
            printf("  nrm=(%.3f, %.3f, %.3f)",
                   geo->normals[i*3], geo->normals[i*3+1], geo->normals[i*3+2]);
        if (geo->uvs)
            printf("  uv=(%.3f, %.3f)", geo->uvs[i*2], geo->uvs[i*2+1]);
        printf("\n");
    }
    if (geo->vertex_count > 4) printf("    ... (%d more)\n", geo->vertex_count - 4);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Generate a procedural grid and push it                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_push_geometry(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Push Geometry into HostInSOP ═══\n");

    /* Generate a 4×4 grid. */
    const int GRID = 4;
    const int VERTS = (GRID + 1) * (GRID + 1);
    const int TRIS  = GRID * GRID * 2;

    float positions[VERTS * 3];
    float normals[VERTS * 3];
    float uvs[VERTS * 2];
    uint32_t indices[TRIS * 3];

    /* Fill vertices. */
    for (int y = 0; y <= GRID; ++y) {
        for (int x = 0; x <= GRID; ++x) {
            int i = y * (GRID + 1) + x;
            float fx = (float)x / (float)GRID;
            float fy = (float)y / (float)GRID;

            positions[i*3 + 0] = fx - 0.5f;
            positions[i*3 + 1] = 0.0f;
            positions[i*3 + 2] = fy - 0.5f;

            normals[i*3 + 0] = 0.0f;
            normals[i*3 + 1] = 1.0f;
            normals[i*3 + 2] = 0.0f;

            uvs[i*2 + 0] = fx;
            uvs[i*2 + 1] = fy;
        }
    }

    /* Fill indices (two triangles per cell). */
    int idx = 0;
    for (int y = 0; y < GRID; ++y) {
        for (int x = 0; x < GRID; ++x) {
            int tl = y * (GRID + 1) + x;
            int tr = tl + 1;
            int bl = (y + 1) * (GRID + 1) + x;
            int br = bl + 1;

            indices[idx++] = tl;
            indices[idx++] = bl;
            indices[idx++] = tr;

            indices[idx++] = tr;
            indices[idx++] = bl;
            indices[idx++] = br;
        }
    }

    printf("  Generated %dx%d grid: %d vertices, %d indices\n",
           GRID, GRID, VERTS, TRIS * 3);

    /* v2.0: Use gonodes_set_input_geometry_direct() for zero-copy
     * pointer lending instead of the temp-file path.  The arrays stay
     * valid for the frame's lifetime (until next gonodes_cook_frame). */
    int err = gonodes_set_input_geometry_direct(gn, p, "host_geo_in",
                                          positions, normals, uvs, nullptr,
                                          VERTS, indices, TRIS * 3);
    if (err == GONODES_OK)
        printf("  Successfully pushed geometry (direct/zero-copy).\n");
    else
        printf("  Push failed: %d — %s\n", err, gonodes_get_last_error(gn));

    /* Cook to process the geometry. */
    gonodes_cook_frame(gn, 1.0 / 60.0);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Read geometry output                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_read_geometry(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Read Geometry from SOP Output ═══\n");

    const gonodes_geometry_data_t* geo = gonodes_get_output_geometry(gn, p, "sop_out");
    print_geometry("sop_out", geo);

    /* Also try reading from a second output if it exists. */
    geo = gonodes_get_output_geometry(gn, p, "host_geo_out");
    print_geometry("host_geo_out", geo);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Texture info query                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_texture_info(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Texture Info Query ═══\n");

    gonodes_texture_info_t info;
    memset(&info, 0, sizeof(info));

    int err = gonodes_get_texture_info(gn, p, "vis_out", &info);
    if (err == GONODES_OK) {
        const char* fmt_names[] = {
            "RGBA8", "RGBA16F", "RGBA32F", "R8", "RG8", "BGRA8", "R16F", "RG16F"
        };
        const char* fmt = (info.format >= 0 && info.format <= 7)
                          ? fmt_names[info.format] : "unknown";
        printf("  vis_out: %dx%d, format=%s, channels=%d, handle=0x%llx\n",
               info.width, info.height, fmt, info.channels,
               (unsigned long long)info.native_handle);
    } else {
        printf("  vis_out: texture info not available (%d)\n", err);
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Animated geometry (morph the grid over time)                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_animated_geometry(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Animated Geometry (20 frames) ═══\n");

    const int GRID = 8;
    const int VERTS = (GRID + 1) * (GRID + 1);
    const int TRIS  = GRID * GRID * 2;

    float positions[VERTS * 3];
    float normals[VERTS * 3];
    float uvs[VERTS * 2];
    uint32_t indices[TRIS * 3];

    /* Build indices (static). */
    int idx = 0;
    for (int y = 0; y < GRID; ++y) {
        for (int x = 0; x < GRID; ++x) {
            int tl = y * (GRID + 1) + x;
            int tr = tl + 1;
            int bl = (y + 1) * (GRID + 1) + x;
            int br = bl + 1;
            indices[idx++] = tl;
            indices[idx++] = bl;
            indices[idx++] = tr;
            indices[idx++] = tr;
            indices[idx++] = bl;
            indices[idx++] = br;
        }
    }

    for (int frame = 0; frame < 20; ++frame) {
        float t = (float)frame / 20.0f;

        /* Animate positions — sine-wave displacement on Y axis. */
        for (int y = 0; y <= GRID; ++y) {
            for (int x = 0; x <= GRID; ++x) {
                int i = y * (GRID + 1) + x;
                float fx = (float)x / (float)GRID;
                float fy = (float)y / (float)GRID;

                positions[i*3 + 0] = fx - 0.5f;
                positions[i*3 + 1] = sinf((fx + t) * 6.28318f) * 0.1f
                                   + cosf((fy + t) * 4.0f) * 0.05f;
                positions[i*3 + 2] = fy - 0.5f;

                normals[i*3 + 0] = 0.0f;
                normals[i*3 + 1] = 1.0f;
                normals[i*3 + 2] = 0.0f;

                uvs[i*2 + 0] = fx;
                uvs[i*2 + 1] = fy;
            }
        }

        gonodes_set_input_geometry_direct(gn, p, "host_geo_in",
                                    positions, normals, uvs, nullptr,
                                    VERTS, indices, TRIS * 3);
        gonodes_cook_frame(gn, 1.0 / 60.0);

        if (frame % 5 == 0) {
            const gonodes_geometry_data_t* geo =
                gonodes_get_output_geometry(gn, p, "sop_out");
            if (geo) {
                printf("  Frame %d: output has %d vertices\n", frame, geo->vertex_count);
            } else {
                double cook_ms = 0;
                int nodes = 0, fn = 0;
                gonodes_get_stats(gn, p, &cook_ms, &nodes, &fn);
                printf("  Frame %d: cook=%.2fms, nodes=%d\n", frame, cook_ms, nodes);
            }
        }
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Main                                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <project_path> <patch_file.gnpatch>\n", argv[0]);
        return 1;
    }
    const char* project_path = argv[1];
    const char* patch_file   = argv[2];

    printf("═══════════════════════════════════════\n");
    printf(" GONODES Geometry Host\n");
    printf("═══════════════════════════════════════\n\n");

    /* ── Create Instance (headless) ─────────────────────────────────── */

    gonodes_instance_t gn = gonodes_create(project_path, nullptr);
    if (!gn) {
        fprintf(stderr, "gonodes_create failed\n");
        return 1;
    }

    int major, minor, patch;
    gonodes_get_version(&major, &minor, &patch);
    printf("API version: %d.%d.%d\n", major, minor, patch);

    /* ── Load Patch ─────────────────────────────────────────────────── */

    printf("Loading patch: %s\n", patch_file);
    gonodes_patch_t p = gonodes_load_patch(gn, patch_file);
    if (!p) {
        fprintf(stderr, "Load failed: %s\n", gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        return 1;
    }

    /* Initial cook. */
    gonodes_cook_frame(gn, 0.0);

    /* ── Run Demos ──────────────────────────────────────────────────── */

    demo_push_geometry(gn, p);
    demo_read_geometry(gn, p);
    demo_texture_info(gn, p);
    demo_animated_geometry(gn, p);

    /* ── Cleanup ────────────────────────────────────────────────────── */

    printf("\n═══ Cleanup ═══\n");
    gonodes_destroy(gn);
    printf("Clean exit.\n");

    return 0;
}
