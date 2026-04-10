/*
 * GONODES MIDI/OSC Host Example
 *
 * Demonstrates the v1.1.0 protocol bridge APIs:
 *   • MIDI event injection (Gap 5)
 *   • OSC message routing (Gap 5)
 *   • Event/trigger system — fire and receive (Gap 8)
 *   • Timeline/transport control (Gap 6)
 *   • Output resolution override (Gap 10)
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target midi_osc_host
 *
 * Run:
 *   ./midi_osc_host path/to/gonodes_project path/to/midi_osc_demo.gnpatch
 */

#include <gonodes_host.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Event Callback                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void on_event(
    gonodes_instance_t inst,
    const char* event_name,
    const char* payload,
    void* user_data
) {
    (void)inst;
    (void)user_data;
    printf("  [EVENT RECEIVED] %s", event_name);
    if (payload) printf(" — %s", payload);
    printf("\n");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: MIDI Event Injection                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_midi(gonodes_instance_t gn) {
    printf("\n═══ MIDI Event Injection ═══\n");

    /* Note On — C4 (MIDI note 60), velocity 100, channel 0. */
    gonodes_midi_event_t note_on = {0x90, 60, 100, 0, 0};
    int err = gonodes_send_midi_event(gn, &note_on);
    printf("  Note On  (C4, vel=100, ch=0): %s\n",
           err == GONODES_OK ? "OK" : "failed");

    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* CC message — CC7 (volume), value 80. */
    gonodes_midi_event_t cc = {0xB0, 7, 80, 0, 0};
    err = gonodes_send_midi_event(gn, &cc);
    printf("  CC7 (volume=80, ch=0): %s\n",
           err == GONODES_OK ? "OK" : "failed");

    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* Note Off. */
    gonodes_midi_event_t note_off = {0x80, 60, 0, 0, 0};
    err = gonodes_send_midi_event(gn, &note_off);
    printf("  Note Off (C4, ch=0): %s\n",
           err == GONODES_OK ? "OK" : "failed");

    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* Multi-channel burst: notes across channels 0-3. */
    printf("  Sending 4-channel chord...\n");
    int notes[] = {60, 64, 67, 72};  /* C, E, G, C5 */
    for (int i = 0; i < 4; ++i) {
        gonodes_midi_event_t ev = {0x90, notes[i], 127, i, 0};
        gonodes_send_midi_event(gn, &ev);
    }
    gonodes_cook_frame(gn, 1.0 / 60.0);
    printf("  4-channel chord sent.\n");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: OSC Message Routing                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_osc(gonodes_instance_t gn) {
    printf("\n═══ OSC Message Routing ═══\n");

    /* Single float. */
    int err = gonodes_send_osc_message(gn, "/control/fader1", "[0.75]");
    printf("  /control/fader1 [0.75]: %s\n",
           err == GONODES_OK ? "OK" : "failed");

    /* Multiple args. */
    err = gonodes_send_osc_message(gn, "/effect/params", "[1, \"bloom\", 0.5, true]");
    printf("  /effect/params [1, \"bloom\", 0.5, true]: %s\n",
           err == GONODES_OK ? "OK" : "failed");

    /* No arguments (bang-style). */
    err = gonodes_send_osc_message(gn, "/cue/next", nullptr);
    printf("  /cue/next (no args): %s\n",
           err == GONODES_OK ? "OK" : "failed");

    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* Animated sweep: send 20 OSC values ramping up. */
    printf("  Sending 20-frame OSC sweep on /control/sweep...\n");
    for (int i = 0; i < 20; ++i) {
        char args[32];
        snprintf(args, sizeof(args), "[%.3f]", (float)i / 19.0f);
        gonodes_send_osc_message(gn, "/control/sweep", args);
        gonodes_cook_frame(gn, 1.0 / 60.0);
    }
    printf("  Sweep done.\n");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Event/Trigger System                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_events(gonodes_instance_t gn) {
    printf("\n═══ Event/Trigger System ═══\n");

    /* Register event callback. */
    gonodes_set_on_event(gn, on_event, nullptr);
    printf("  Event callback registered.\n");

    /* Fire named events. */
    int err = gonodes_fire_event(gn, "beat", "{\"bpm\": 128, \"bar\": 1}");
    printf("  Fire 'beat': %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    err = gonodes_fire_event(gn, "scene_change", "{\"scene\": \"intro\"}");
    printf("  Fire 'scene_change': %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* Bare trigger (no payload). */
    err = gonodes_fire_event(gn, "flash", nullptr);
    printf("  Fire 'flash' (bare trigger): %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    /* Rapid burst — 10 beat triggers. */
    printf("  Firing 10 rapid beat triggers...\n");
    for (int i = 0; i < 10; ++i) {
        char payload[64];
        snprintf(payload, sizeof(payload), "{\"bpm\": 128, \"beat\": %d}", i + 1);
        gonodes_fire_event(gn, "beat", payload);
        gonodes_cook_frame(gn, 1.0 / 120.0);
    }

    /* Unregister. */
    gonodes_set_on_event(gn, nullptr, nullptr);
    printf("  Event callback unregistered.\n");
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Transport Control                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_transport(gonodes_instance_t gn) {
    printf("\n═══ Transport Control ═══\n");

    /* Check initial time. */
    double t = gonodes_get_transport_time(gn);
    printf("  Initial time: %.3f s\n", t);

    /* Play at normal speed. */
    gonodes_set_transport(gn, GONODES_TRANSPORT_PLAY);
    gonodes_set_transport_speed(gn, 1.0);
    printf("  Transport: PLAY, speed=1.0x\n");

    for (int i = 0; i < 10; ++i) {
        gonodes_cook_frame(gn, 1.0 / 60.0);
    }
    printf("  After 10 frames: %.3f s\n", gonodes_get_transport_time(gn));

    /* Double speed. */
    gonodes_set_transport_speed(gn, 2.0);
    printf("  Transport: speed=2.0x\n");

    for (int i = 0; i < 10; ++i) {
        gonodes_cook_frame(gn, 1.0 / 60.0);
    }
    printf("  After 10 frames at 2x: %.3f s\n", gonodes_get_transport_time(gn));

    /* Pause. */
    gonodes_set_transport(gn, GONODES_TRANSPORT_PAUSE);
    printf("  Transport: PAUSE\n");
    for (int i = 0; i < 5; ++i) {
        gonodes_cook_frame(gn, 1.0 / 60.0);
    }
    printf("  After 5 paused frames: %.3f s (should be unchanged)\n",
           gonodes_get_transport_time(gn));

    /* Seek. */
    gonodes_transport_seek(gn, 30.0);
    printf("  Seeked to 30.0 s\n");
    printf("  Time after seek: %.3f s\n", gonodes_get_transport_time(gn));

    /* Resume play. */
    gonodes_set_transport(gn, GONODES_TRANSPORT_PLAY);
    gonodes_set_transport_speed(gn, 1.0);
    gonodes_cook_frame(gn, 1.0 / 60.0);
    printf("  Resumed, time: %.3f s\n", gonodes_get_transport_time(gn));

    /* Stop (resets to 0). */
    gonodes_set_transport(gn, GONODES_TRANSPORT_STOP);
    printf("  Transport: STOP\n");
    printf("  Time after stop: %.3f s\n", gonodes_get_transport_time(gn));
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Demo: Output Resolution Override                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void demo_resolution_override(gonodes_instance_t gn) {
    printf("\n═══ Output Resolution Override ═══\n");

    /* Read initial output size. */
    int w = 0, h = 0;
    gonodes_get_output_texture(gn, "host_out", &w, &h);
    printf("  Default resolution: %dx%d\n", w, h);

    /* Override to 4K. */
    int err = gonodes_set_output_resolution(gn, "host_out", 3840, 2160);
    printf("  Override to 3840x2160: %s\n", err == GONODES_OK ? "OK" : "failed");
    gonodes_cook_frame(gn, 1.0 / 60.0);

    gonodes_get_output_texture(gn, "host_out", &w, &h);
    printf("  After override: %dx%d\n", w, h);

    /* Override to 720p. */
    gonodes_set_output_resolution(gn, "host_out", 1280, 720);
    gonodes_cook_frame(gn, 1.0 / 60.0);
    gonodes_get_output_texture(gn, "host_out", &w, &h);
    printf("  After 720p override: %dx%d\n", w, h);

    /* Revert to patch default. */
    gonodes_set_output_resolution(gn, "host_out", 0, 0);
    gonodes_cook_frame(gn, 1.0 / 60.0);
    gonodes_get_output_texture(gn, "host_out", &w, &h);
    printf("  After revert to default: %dx%d\n", w, h);
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
    printf(" GONODES MIDI/OSC Host\n");
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

    demo_midi(gn);
    demo_osc(gn);
    demo_events(gn);
    demo_transport(gn);
    demo_resolution_override(gn);

    /* ── Cleanup ────────────────────────────────────────────────────── */

    printf("\n═══ Cleanup ═══\n");
    gonodes_destroy(gn);
    printf("Clean exit.\n");

    return 0;
}
