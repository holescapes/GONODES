/*
 * GONODES Parameters Demo
 *
 * Demonstrates the full parameter and I/O injection API:
 *   • Setting float, int, bool, string, color, and vector parameters
 *   • Injecting CHOP channel data (multi-channel, multi-sample)
 *   • Injecting DAT table data (JSON arrays)
 *   • Reading output textures, CHOP channels, DAT tables
 *   • Introspection: listing nodes, parameters, connections
 *   • Registering a parameter change callback
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target params_demo
 *
 * Run:
 *   ./params_demo path/to/gonodes_project path/to/params_test.gnpatch
 */

#include <gonodes_host.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callback: Parameter Change Notification                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void on_param_changed(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name,
    const char* value_json,
    void* user_data
) {
    (void)inst;
    (void)user_data;
    printf("  [CALLBACK] %s.%s = %s\n", node_id, param_name, value_json);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Log Callback                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void on_log(int level, const char* category, const char* message, void* /*user_data*/) {
    const char* lvl[] = {"DBG", "INF", "WRN", "ERR"};
    printf("  [%s/%s] %s\n", lvl[level < 4 ? level : 3], category, message);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo Sections                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_introspection(gonodes_instance_t gn) {
    printf("\n═══ Introspection ═══\n");

    /* List all nodes. */
    const char* nodes_json = gonodes_list_nodes(gn);
    if (nodes_json)
        printf("Nodes: %s\n", nodes_json);

    /* List all connections. */
    const char* conns_json = gonodes_list_connections(gn);
    if (conns_json)
        printf("Connections: %s\n", conns_json);
}


static void demo_set_parameters(gonodes_instance_t gn) {
    printf("\n═══ Setting Parameters ═══\n");

    /* Float parameter. */
    printf("Setting noise1.scale = 8.0\n");
    gonodes_set_parameter(gn, "noise1", "scale", "8.0");

    /* Integer parameter. */
    printf("Setting noise1.seed = 42\n");
    gonodes_set_parameter(gn, "noise1", "seed", "42");

    /* Boolean parameter. */
    printf("Setting noise1.monochrome = false\n");
    gonodes_set_parameter(gn, "noise1", "monochrome", "false");

    /* String parameter. */
    printf("Setting text1.text = \"Hello from C API\"\n");
    gonodes_set_parameter(gn, "text1", "text", "\"Hello from C API\"");

    /* Color parameter (RGBA array). */
    printf("Setting constant1.color = [1.0, 0.3, 0.0, 1.0]\n");
    gonodes_set_parameter(gn, "constant1", "color", "[1.0, 0.3, 0.0, 1.0]");

    /* Vector2i parameter. */
    printf("Setting noise1.resolution = [1920, 1080]\n");
    gonodes_set_parameter(gn, "noise1", "resolution",
                          "{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}");

    /* Cook a frame to apply the parameters. */
    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_read_parameters(gonodes_instance_t gn) {
    printf("\n═══ Reading Parameters ═══\n");

    const char* val = gonodes_get_parameter(gn, "noise1", "scale");
    if (val) printf("noise1.scale = %s\n", val);

    val = gonodes_get_parameter(gn, "noise1", "monochrome");
    if (val) printf("noise1.monochrome = %s\n", val);

    val = gonodes_get_parameter(gn, "noise1", "resolution");
    if (val) printf("noise1.resolution = %s\n", val);
}


static void demo_chop_injection(gonodes_instance_t gn) {
    printf("\n═══ CHOP Injection ═══\n");

    /* Single-sample channels (like a ConstantCHOP from the host). */
    float tx = 1.5f, ty = -0.3f, tz = 0.0f;
    printf("Injecting host_chop: tx=%.2f, ty=%.2f, tz=%.2f\n", tx, ty, tz);
    gonodes_set_input_chop(gn, "host_chop", "tx", &tx, 1);
    gonodes_set_input_chop(gn, "host_chop", "ty", &ty, 1);
    gonodes_set_input_chop(gn, "host_chop", "tz", &tz, 1);

    /* Multi-sample channel (like a WaveCHOP from the host). */
    const int NUM_SAMPLES = 128;
    float waveform[NUM_SAMPLES];
    for (int i = 0; i < NUM_SAMPLES; ++i) {
        waveform[i] = sinf((float)i / (float)NUM_SAMPLES * 6.28318f);
    }
    printf("Injecting host_wave: %d samples of sine wave\n", NUM_SAMPLES);
    gonodes_set_input_chop(gn, "host_wave", "sine", waveform, NUM_SAMPLES);

    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_chop_reading(gonodes_instance_t gn) {
    printf("\n═══ CHOP Reading ═══\n");

    float buf[16];
    int count = gonodes_get_output_chop(gn, "host_out_chop", "result", buf, 16);
    if (count > 0) {
        printf("host_out_chop.result: %d samples — [", count);
        for (int i = 0; i < count && i < 5; ++i)
            printf("%.3f%s", buf[i], i < count - 1 ? ", " : "");
        if (count > 5) printf(", ...");
        printf("]\n");
    } else {
        printf("host_out_chop: no data (node not found or empty)\n");
    }
}


static void demo_dat_injection(gonodes_instance_t gn) {
    printf("\n═══ DAT Injection ═══\n");

    /* Table mode: 2D array of strings. */
    const char* table_json =
        "[[\"name\", \"value\", \"unit\"],"
        " [\"temperature\", \"23.5\", \"C\"],"
        " [\"humidity\", \"65\", \"%\"],"
        " [\"pressure\", \"1013.25\", \"hPa\"]]";
    printf("Injecting host_dat: 3x3 sensor table\n");
    gonodes_set_input_table(gn, "host_dat", table_json);

    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_dat_reading(gonodes_instance_t gn) {
    printf("\n═══ DAT Reading ═══\n");

    const char* table = gonodes_get_output_table(gn, "host_out_dat");
    if (table)
        printf("host_out_dat: %s\n", table);
    else
        printf("host_out_dat: no data\n");
}


static void demo_texture_output(gonodes_instance_t gn) {
    printf("\n═══ Texture Output ═══\n");

    int w = 0, h = 0;
    uint64_t tex = gonodes_get_output_texture(gn, "host_out_tex", &w, &h);
    if (tex != 0)
        printf("host_out_tex: handle=0x%llx, %dx%d\n", (unsigned long long)tex, w, h);
    else
        printf("host_out_tex: no texture (node not found or not cooked)\n");
}


static void demo_animated_loop(gonodes_instance_t gn) {
    printf("\n═══ Animated Cook Loop (60 frames) ═══\n");

    for (int frame = 0; frame < 60; ++frame) {
        double delta = 1.0 / 60.0;
        float t = (float)frame / 60.0f;

        /* Animate parameters over time. */
        char buf[64];
        snprintf(buf, sizeof(buf), "%.3f", 2.0 + t * 10.0);
        gonodes_set_parameter(gn, "noise1", "scale", buf);

        snprintf(buf, sizeof(buf), "%.3f", t);
        gonodes_set_parameter(gn, "noise1", "time_offset", buf);

        /* Inject evolving CHOP data. */
        float val = sinf(t * 6.28318f);
        gonodes_set_input_chop(gn, "host_lfo", "lfo", &val, 1);

        /* Cook. */
        gonodes_cook_frame(gn, delta);

        /* Sample stats every 20 frames. */
        if (frame % 20 == 0) {
            double cook_ms = 0;
            int cooked = 0, fn = 0;
            gonodes_get_stats(gn, &cook_ms, &cooked, &fn);
            printf("  Frame %d: cook=%.2fms, nodes=%d\n", frame, cook_ms, cooked);
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
    printf(" GONODES Parameters Demo\n");
    printf("═══════════════════════════════════════\n\n");

    /* ── Create Instance (headless — no GPU sharing) ────────────────── */

    printf("Creating GONODES instance (headless)...\n");
    gonodes_instance_t gn = gonodes_create(project_path, nullptr);
    if (!gn) {
        fprintf(stderr, "gonodes_create failed\n");
        return 1;
    }

    /* Register callbacks. */
    gonodes_set_on_param_changed(gn, on_param_changed, nullptr);
    gonodes_set_log_callback(gn, on_log, nullptr);

    /* Print version. */
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

    /* Initial cook to populate introspection data. */
    gonodes_cook_frame(gn, 0.0);

    /* ── Run All Demos ──────────────────────────────────────────────── */

    demo_introspection(gn);
    demo_set_parameters(gn);
    demo_read_parameters(gn);
    demo_chop_injection(gn);
    demo_chop_reading(gn);
    demo_dat_injection(gn);
    demo_dat_reading(gn);
    demo_texture_output(gn);
    demo_animated_loop(gn);

    /* ── Reload Test ────────────────────────────────────────────────── */

    printf("\n═══ Reload Test ═══\n");
    int reload_err = gonodes_reload_patch(gn);
    printf("Reload result: %d\n", reload_err);
    gonodes_cook_frame(gn, 0.0);

    /* ── Cleanup ────────────────────────────────────────────────────── */

    printf("\n═══ Cleanup ═══\n");
    gonodes_destroy(gn);
    printf("Clean exit.\n");

    return 0;
}
