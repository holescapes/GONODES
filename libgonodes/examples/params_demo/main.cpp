/*
 * GONODES Parameters Demo
 *
 * Demonstrates the full parameter and I/O injection API:
 *   • Setting float, int, bool, string, color, and vector parameters
 *   • Injecting CHOP channel data (multi-channel, multi-sample)
 *   • Injecting DAT table data (JSON arrays)
 *   • Reading output textures, CHOP channels, DAT tables
 *   • Introspection: listing nodes, parameters, connections
 *   • Host I/O manifest: querying the patch interface contract
 *   • Registering a parameter change callback
 *   • v2.0: Transport control, event triggers, texture info, resolution override
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
    gonodes_patch_t patch,
    const char* node_id,
    const char* param_name,
    const char* value_json,
    void* user_data
) {
    (void)inst;
    (void)patch;
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

static void demo_introspection(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Introspection ═══\n");

    /* List all nodes. */
    const char* nodes_json = gonodes_list_nodes(gn, p);
    if (nodes_json)
        printf("Nodes: %s\n", nodes_json);

    /* List all connections. */
    const char* conns_json = gonodes_list_connections(gn, p);
    if (conns_json)
        printf("Connections: %s\n", conns_json);
}


static void demo_host_io(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Host I/O Manifest ═══\n");

    const char* io_json = gonodes_get_host_io(gn, p);
    if (io_json && io_json[0] != '\0' && strcmp(io_json, "{}") != 0) {
        printf("Manifest:\n%s\n", io_json);
        printf("\nThe host can use this JSON to auto-discover:\n");
        printf("  - Which texture/CHOP/DAT inputs the patch expects\n");
        printf("  - Which outputs the patch produces\n");
        printf("  - Which parameters are exposed for host control\n");
    } else {
        printf("No Host I/O manifest — patch has no bridge operators.\n");
    }
}


static void demo_set_parameters(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Setting Parameters ═══\n");

    /* Float parameter. */
    printf("Setting noise1.scale = 8.0\n");
    gonodes_set_parameter(gn, p, "noise1", "scale", "8.0");

    /* Integer parameter. */
    printf("Setting noise1.seed = 42\n");
    gonodes_set_parameter(gn, p, "noise1", "seed", "42");

    /* Boolean parameter. */
    printf("Setting noise1.monochrome = false\n");
    gonodes_set_parameter(gn, p, "noise1", "monochrome", "false");

    /* String parameter. */
    printf("Setting text1.text = \"Hello from C API\"\n");
    gonodes_set_parameter(gn, p, "text1", "text", "\"Hello from C API\"");

    /* Color parameter (RGBA array). */
    printf("Setting constant1.color = [1.0, 0.3, 0.0, 1.0]\n");
    gonodes_set_parameter(gn, p, "constant1", "color", "[1.0, 0.3, 0.0, 1.0]");

    /* Vector2i parameter. */
    printf("Setting noise1.resolution = [1920, 1080]\n");
    gonodes_set_parameter(gn, p, "noise1", "resolution",
                          "{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}");

    /* Cook a frame to apply the parameters. */
    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_read_parameters(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Reading Parameters ═══\n");

    const char* val = gonodes_get_parameter(gn, p, "noise1", "scale");
    if (val) printf("noise1.scale = %s\n", val);

    val = gonodes_get_parameter(gn, p, "noise1", "monochrome");
    if (val) printf("noise1.monochrome = %s\n", val);

    val = gonodes_get_parameter(gn, p, "noise1", "resolution");
    if (val) printf("noise1.resolution = %s\n", val);
}


static void demo_chop_injection(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ CHOP Injection ═══\n");

    /* Single-sample channels (like a ConstantCHOP from the host). */
    float tx = 1.5f, ty = -0.3f, tz = 0.0f;
    printf("Injecting host_chop: tx=%.2f, ty=%.2f, tz=%.2f\n", tx, ty, tz);
    gonodes_set_input_chop(gn, p, "host_chop", "tx", &tx, 1);
    gonodes_set_input_chop(gn, p, "host_chop", "ty", &ty, 1);
    gonodes_set_input_chop(gn, p, "host_chop", "tz", &tz, 1);

    /* Multi-sample channel (like a WaveCHOP from the host). */
    const int NUM_SAMPLES = 128;
    float waveform[NUM_SAMPLES];
    for (int i = 0; i < NUM_SAMPLES; ++i) {
        waveform[i] = sinf((float)i / (float)NUM_SAMPLES * 6.28318f);
    }
    printf("Injecting host_wave: %d samples of sine wave\n", NUM_SAMPLES);
    gonodes_set_input_chop(gn, p, "host_wave", "sine", waveform, NUM_SAMPLES);

    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_chop_reading(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ CHOP Reading ═══\n");

    float buf[16];
    int count = gonodes_get_output_chop(gn, p, "host_out_chop", "result", buf, 16);
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


static void demo_dat_injection(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ DAT Injection ═══\n");

    /* Table mode: 2D array of strings. */
    const char* table_json =
        "[[\"name\", \"value\", \"unit\"],"
        " [\"temperature\", \"23.5\", \"C\"],"
        " [\"humidity\", \"65\", \"%\"],"
        " [\"pressure\", \"1013.25\", \"hPa\"]]";
    printf("Injecting host_dat: 3x3 sensor table\n");
    gonodes_set_input_table(gn, p, "host_dat", table_json);

    gonodes_cook_frame(gn, 1.0 / 60.0);
}


static void demo_dat_reading(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ DAT Reading ═══\n");

    const char* table = gonodes_get_output_table(gn, p, "host_out_dat");
    if (table)
        printf("host_out_dat: %s\n", table);
    else
        printf("host_out_dat: no data\n");
}


static void demo_texture_output(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Texture Output ═══\n");

    int w = 0, h = 0;
    uint64_t tex = gonodes_get_output_texture(gn, p, "host_out_tex", &w, &h);
    if (tex != 0)
        printf("host_out_tex: handle=0x%llx, %dx%d\n", (unsigned long long)tex, w, h);
    else
        printf("host_out_tex: no texture (node not found or not cooked)\n");
}


static void demo_animated_loop(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Animated Cook Loop (60 frames) ═══\n");

    for (int frame = 0; frame < 60; ++frame) {
        double delta = 1.0 / 60.0;
        float t = (float)frame / 60.0f;

        /* Animate parameters over time. */
        char buf[64];
        snprintf(buf, sizeof(buf), "%.3f", 2.0 + t * 10.0);
        gonodes_set_parameter(gn, p, "noise1", "scale", buf);

        snprintf(buf, sizeof(buf), "%.3f", t);
        gonodes_set_parameter(gn, p, "noise1", "time_offset", buf);

        /* Inject evolving CHOP data. */
        float val = sinf(t * 6.28318f);
        gonodes_set_input_chop(gn, p, "host_lfo", "lfo", &val, 1);

        /* Cook. */
        gonodes_cook_frame(gn, delta);

        /* Sample stats every 20 frames. */
        if (frame % 20 == 0) {
            double cook_ms = 0;
            int cooked = 0, fn = 0;
            gonodes_get_stats(gn, p, &cook_ms, &cooked, &fn);
            printf("  Frame %d: cook=%.2fms, nodes=%d\n", frame, cook_ms, cooked);
        }
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v2.0 Demo: Transport Control                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_transport(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Transport Control (v2.0) ═══\n");

    double t = gonodes_get_transport_time(gn, p);
    printf("  Current time: %.3f s\n", t);

    gonodes_set_transport(gn, p, GONODES_TRANSPORT_PLAY);
    gonodes_set_transport_speed(gn, p, 1.0);
    printf("  Set PLAY, speed=1.0x\n");

    for (int i = 0; i < 10; ++i)
        gonodes_cook_frame(gn, 1.0 / 60.0);
    printf("  After 10 frames: %.3f s\n", gonodes_get_transport_time(gn, p));

    gonodes_set_transport(gn, p, GONODES_TRANSPORT_PAUSE);
    printf("  Set PAUSE\n");
    gonodes_cook_frame(gn, 1.0 / 60.0);
    printf("  After 1 paused frame: %.3f s (should be unchanged)\n",
           gonodes_get_transport_time(gn, p));

    gonodes_transport_seek(gn, p, 5.0);
    printf("  Seek to 5.0 s: %.3f s\n", gonodes_get_transport_time(gn, p));

    gonodes_set_transport(gn, p, GONODES_TRANSPORT_STOP);
    printf("  Set STOP: %.3f s\n", gonodes_get_transport_time(gn, p));
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v2.0 Demo: Event/Trigger System                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void on_event_demo(
    gonodes_instance_t /*inst*/, gonodes_patch_t /*patch*/,
    const char* name, const char* payload, void* /*user_data*/
) {
    printf("  [EVENT] %s", name);
    if (payload) printf(" — %s", payload);
    printf("\n");
}

static void demo_events(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Event/Trigger System (v2.0) ═══\n");

    gonodes_set_on_event(gn, on_event_demo, nullptr);
    printf("  Event callback registered.\n");

    int err = gonodes_fire_event(gn, p, "test_bang", "{\"data\": 42}");
    printf("  Fire 'test_bang': %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    err = gonodes_fire_event(gn, p, "pulse", nullptr);
    printf("  Fire 'pulse' (bare): %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    gonodes_set_on_event(gn, nullptr, nullptr);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v2.0 Demo: Texture Info Query                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_texture_info(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Texture Info Query (v2.0) ═══\n");

    gonodes_texture_info_t info;
    memset(&info, 0, sizeof(info));

    int err = gonodes_get_texture_info(gn, p, "host_out_tex", &info);
    if (err == GONODES_OK) {
        printf("  host_out_tex: %dx%d, format=%d, channels=%d\n",
               info.width, info.height, info.format, info.channels);
    } else {
        printf("  host_out_tex: not available (%d)\n", err);
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v2.0 Demo: Output Resolution Override                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_resolution(gonodes_instance_t gn, gonodes_patch_t p) {
    printf("\n═══ Resolution Override (v2.0) ═══\n");

    int w = 0, h = 0;
    gonodes_get_output_texture(gn, p, "host_out_tex", &w, &h);
    printf("  Default: %dx%d\n", w, h);

    gonodes_set_output_resolution(gn, p, "host_out_tex", 1920, 1080);
    gonodes_cook_frame(gn, 1.0 / 60.0);
    gonodes_get_output_texture(gn, p, "host_out_tex", &w, &h);
    printf("  After 1080p override: %dx%d\n", w, h);

    gonodes_set_output_resolution(gn, p, "host_out_tex", 0, 0);
    gonodes_cook_frame(gn, 1.0 / 60.0);
    gonodes_get_output_texture(gn, p, "host_out_tex", &w, &h);
    printf("  After revert: %dx%d\n", w, h);
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
    gonodes_patch_t p = gonodes_load_patch(gn, patch_file);
    if (!p) {
        fprintf(stderr, "Load failed: %s\n", gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        return 1;
    }

    /* Initial cook to populate introspection data. */
    gonodes_cook_frame(gn, 0.0);

    /* ── Run All Demos ──────────────────────────────────────────────── */

    demo_introspection(gn, p);
    demo_host_io(gn, p);
    demo_set_parameters(gn, p);
    demo_read_parameters(gn, p);
    demo_chop_injection(gn, p);
    demo_chop_reading(gn, p);
    demo_dat_injection(gn, p);
    demo_dat_reading(gn, p);
    demo_texture_output(gn, p);
    demo_animated_loop(gn, p);

    /* ── v2.0 Feature Demos ───────────────────────────────────────── */

    demo_transport(gn, p);
    demo_events(gn, p);
    demo_texture_info(gn, p);
    demo_resolution(gn, p);

    /* ── Reload Test ────────────────────────────────────────────────── */

    printf("\n═══ Reload Test ═══\n");
    int reload_err = gonodes_reload_patch(gn, p);
    printf("Reload result: %d\n", reload_err);
    gonodes_cook_frame(gn, 0.0);

    /* ── Cleanup ────────────────────────────────────────────────────── */

    printf("\n═══ Cleanup ═══\n");
    gonodes_destroy(gn);
    printf("Clean exit.\n");

    return 0;
}
