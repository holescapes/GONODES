/*
 * GONODES Graph Edit Demo
 *
 * Demonstrates the v1.1.0 dynamic graph editing API (Gap 7):
 *   • Creating nodes at runtime
 *   • Wiring connections between nodes
 *   • Deleting nodes (auto-removes connections)
 *   • Building a full processing chain programmatically
 *   • Introspection after each mutation
 *
 * This capability goes BEYOND TouchEngine SDK (which only allows read-only
 * graph access) and matches VUO's dynamic composition modification.
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target graph_edit_demo
 *
 * Run:
 *   ./graph_edit_demo path/to/gonodes_project path/to/graph_edit_base.gnpatch
 */

#include <gonodes_host.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Helpers                                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void print_graph_state(gonodes_instance_t gn, const char* label) {
    printf("\n  [%s] Graph state:\n", label);

    const char* nodes = gonodes_list_nodes(gn);
    if (nodes) printf("    Nodes: %s\n", nodes);

    const char* conns = gonodes_list_connections(gn);
    if (conns) printf("    Connections: %s\n", conns);

    double cook_ms = 0;
    int node_count = 0, frame = 0;
    gonodes_get_stats(gn, &cook_ms, &node_count, &frame);
    printf("    Stats: %d nodes, %.2fms cook, frame %d\n",
           node_count, cook_ms, frame);
}

static int check(int err, const char* op, gonodes_instance_t gn) {
    if (err != GONODES_OK) {
        fprintf(stderr, "    FAILED %s: %d — %s\n", op, err, gonodes_get_last_error(gn));
        return 0;
    }
    printf("    OK: %s\n", op);
    return 1;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo 1: Add a blur node in the middle of an existing chain               */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_insert_node(gonodes_instance_t gn) {
    printf("\n═══ Demo 1: Insert Blur Node ═══\n");
    printf("  Starting with: noise1 → host_out\n");

    print_graph_state(gn, "BEFORE");

    /* Disconnect the existing wire. */
    check(gonodes_disconnect(gn, "noise1", 0, "host_out", 0),
          "disconnect noise1→host_out", gn);

    /* Create a BlurTOP. */
    check(gonodes_create_node(gn, "blur1", "BlurTOP"),
          "create BlurTOP as blur1", gn);

    /* Set blur parameters. */
    gonodes_set_parameter(gn, "blur1", "blur_size", "8.0");

    /* Wire: noise1 → blur1 → host_out. */
    check(gonodes_connect(gn, "noise1", 0, "blur1", 0),
          "connect noise1→blur1", gn);
    check(gonodes_connect(gn, "blur1", 0, "host_out", 0),
          "connect blur1→host_out", gn);

    /* Cook and verify. */
    gonodes_cook_frame(gn, 1.0 / 60.0);
    print_graph_state(gn, "AFTER INSERT");

    int w = 0, h = 0;
    uint64_t tex = gonodes_get_output_texture(gn, "host_out", &w, &h);
    printf("  Output texture: handle=0x%llx, %dx%d\n",
           (unsigned long long)tex, w, h);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo 2: Build a multi-node chain from scratch                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_build_chain(gonodes_instance_t gn) {
    printf("\n═══ Demo 2: Build Processing Chain ═══\n");

    /* Create additional nodes. */
    check(gonodes_create_node(gn, "level1", "LevelTOP"),
          "create LevelTOP as level1", gn);
    check(gonodes_create_node(gn, "hsv1", "HSVAdjustTOP"),
          "create HSVAdjustTOP as hsv1", gn);

    /* Set parameters. */
    gonodes_set_parameter(gn, "level1", "brightness", "1.2");
    gonodes_set_parameter(gn, "level1", "gamma", "0.8");
    gonodes_set_parameter(gn, "hsv1", "hue_offset", "0.3");
    gonodes_set_parameter(gn, "hsv1", "saturation", "1.5");

    /* Wire: noise1 → blur1 → level1 → hsv1 → host_out. */
    check(gonodes_disconnect(gn, "blur1", 0, "host_out", 0),
          "disconnect blur1→host_out", gn);
    check(gonodes_connect(gn, "blur1", 0, "level1", 0),
          "connect blur1→level1", gn);
    check(gonodes_connect(gn, "level1", 0, "hsv1", 0),
          "connect level1→hsv1", gn);
    check(gonodes_connect(gn, "hsv1", 0, "host_out", 0),
          "connect hsv1→host_out", gn);

    gonodes_cook_frame(gn, 1.0 / 60.0);
    print_graph_state(gn, "AFTER CHAIN BUILD");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo 3: Delete nodes (auto-removes connections)                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_delete_nodes(gonodes_instance_t gn) {
    printf("\n═══ Demo 3: Delete Nodes ═══\n");

    /* Delete blur1 and level1. */
    check(gonodes_delete_node(gn, "blur1"), "delete blur1", gn);
    check(gonodes_delete_node(gn, "level1"), "delete level1", gn);

    /* Rewire: noise1 → hsv1 directly. */
    check(gonodes_connect(gn, "noise1", 0, "hsv1", 0),
          "connect noise1→hsv1", gn);

    gonodes_cook_frame(gn, 1.0 / 60.0);
    print_graph_state(gn, "AFTER DELETE");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo 4: Animated parameter sweep on dynamically-created nodes            */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_animated_sweep(gonodes_instance_t gn) {
    printf("\n═══ Demo 4: Animated Sweep (30 frames) ═══\n");

    for (int frame = 0; frame < 30; ++frame) {
        float t = (float)frame / 30.0f;
        char buf[64];

        /* Sweep hue offset from 0 to 1. */
        snprintf(buf, sizeof(buf), "%.3f", t);
        gonodes_set_parameter(gn, "hsv1", "hue_offset", buf);

        /* Sweep noise scale. */
        snprintf(buf, sizeof(buf), "%.3f", 2.0f + t * 20.0f);
        gonodes_set_parameter(gn, "noise1", "scale", buf);

        gonodes_cook_frame(gn, 1.0 / 60.0);

        if (frame % 10 == 0) {
            double cook_ms = 0;
            int nodes = 0, fn = 0;
            gonodes_get_stats(gn, &cook_ms, &nodes, &fn);
            printf("  Frame %d: cook=%.2fms, nodes=%d, hue=%.2f\n",
                   frame, cook_ms, nodes, t);
        }
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo 5: Clean up all dynamically created nodes                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_cleanup_dynamic(gonodes_instance_t gn) {
    printf("\n═══ Demo 5: Cleanup Dynamic Nodes ═══\n");

    check(gonodes_delete_node(gn, "hsv1"), "delete hsv1", gn);

    /* Restore original wire. */
    check(gonodes_connect(gn, "noise1", 0, "host_out", 0),
          "connect noise1→host_out", gn);

    gonodes_cook_frame(gn, 1.0 / 60.0);
    print_graph_state(gn, "RESTORED ORIGINAL");
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
    printf(" GONODES Graph Edit Demo\n");
    printf("═══════════════════════════════════════\n\n");

    /* ── Create Instance ────────────────────────────────────────────── */

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
    int err = gonodes_load_patch(gn, patch_file);
    if (err != GONODES_OK) {
        fprintf(stderr, "Load failed (%d): %s\n", err, gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        return 1;
    }

    gonodes_cook_frame(gn, 0.0);

    /* ── Run Demos ──────────────────────────────────────────────────── */

    demo_insert_node(gn);
    demo_build_chain(gn);
    demo_delete_nodes(gn);
    demo_animated_sweep(gn);
    demo_cleanup_dynamic(gn);

    /* ── Cleanup ────────────────────────────────────────────────────── */

    printf("\n═══ Cleanup ═══\n");
    gonodes_destroy(gn);
    printf("Clean exit.\n");

    return 0;
}
