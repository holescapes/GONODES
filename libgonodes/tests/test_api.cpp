/*
 * libgonodes API test suite.
 *
 * Unit-level tests for the public C API that do NOT require a running Godot
 * engine.  These verify argument validation, error codes, version queries,
 * struct layouts, and NULL-safety — everything that can be checked without
 * a live LibGodot instance.
 *
 * Build:
 *   cd libgonodes/build && cmake .. -DGONODES_BUILD_TESTS=ON && cmake --build . --target gonodes_tests
 *
 * Run:
 *   ./gonodes_tests
 *
 * Integration tests that boot LibGodot live in test_integration.cpp.
 */

#include <gonodes_host.h>

#include <cstdio>
#include <cstring>
#include <cstdlib>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Minimal test harness                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int g_total  = 0;
static int g_passed = 0;
static int g_failed = 0;

#define TEST(name)                                                \
    static void test_##name();                                    \
    static void run_##name() {                                    \
        g_total++;                                                \
        printf("  %-60s ", #name);                                \
        test_##name();                                            \
    }                                                             \
    static void test_##name()

#define ASSERT_EQ(a, b) do {                                      \
        if ((a) != (b)) {                                         \
            printf("FAIL  (line %d: %s != %s)\n", __LINE__, #a, #b); \
            g_failed++; return;                                   \
        }                                                         \
    } while(0)

#define ASSERT_NE(a, b) do {                                      \
        if ((a) == (b)) {                                         \
            printf("FAIL  (line %d: %s == %s)\n", __LINE__, #a, #b); \
            g_failed++; return;                                   \
        }                                                         \
    } while(0)

#define ASSERT_NULL(ptr) do {                                     \
        if ((ptr) != nullptr) {                                   \
            printf("FAIL  (line %d: %s not null)\n", __LINE__, #ptr); \
            g_failed++; return;                                   \
        }                                                         \
    } while(0)

#define ASSERT_NOT_NULL(ptr) do {                                 \
        if ((ptr) == nullptr) {                                   \
            printf("FAIL  (line %d: %s is null)\n", __LINE__, #ptr); \
            g_failed++; return;                                   \
        }                                                         \
    } while(0)

#define ASSERT_TRUE(cond) do {                                    \
        if (!(cond)) {                                            \
            printf("FAIL  (line %d: %s)\n", __LINE__, #cond);    \
            g_failed++; return;                                   \
        }                                                         \
    } while(0)

#define PASS() do { printf("OK\n"); g_passed++; } while(0)


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Version API                                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(version_returns_correct_values) {
    int major = -1, minor = -1, patch = -1;
    gonodes_get_version(&major, &minor, &patch);
    ASSERT_EQ(major, GONODES_API_VERSION_MAJOR);
    ASSERT_EQ(minor, GONODES_API_VERSION_MINOR);
    ASSERT_EQ(patch, GONODES_API_VERSION_PATCH);
    PASS();
}

TEST(version_accepts_null_pointers) {
    /* Should not crash when any output pointer is NULL. */
    gonodes_get_version(nullptr, nullptr, nullptr);

    int major = -1;
    gonodes_get_version(&major, nullptr, nullptr);
    ASSERT_EQ(major, GONODES_API_VERSION_MAJOR);
    PASS();
}

TEST(version_macros_are_consistent) {
    ASSERT_TRUE(GONODES_API_VERSION_MAJOR >= 1);
    ASSERT_TRUE(GONODES_API_VERSION_MINOR >= 0);
    ASSERT_TRUE(GONODES_API_VERSION_PATCH >= 0);
    PASS();
}

TEST(version_matches_cmake) {
    /* CMake passes EXPECTED_VERSION_{MAJOR,MINOR,PATCH} from versions.env.
     * This test verifies the header macros match the single source of truth. */
#ifdef EXPECTED_VERSION_MAJOR
    ASSERT_EQ(GONODES_API_VERSION_MAJOR, EXPECTED_VERSION_MAJOR);
    ASSERT_EQ(GONODES_API_VERSION_MINOR, EXPECTED_VERSION_MINOR);
    ASSERT_EQ(GONODES_API_VERSION_PATCH, EXPECTED_VERSION_PATCH);
#endif
    PASS();
}

TEST(version_runtime_matches_cmake) {
    /* Verify gonodes_get_version() returns values consistent with versions.env. */
    int major = -1, minor = -1, patch = -1;
    gonodes_get_version(&major, &minor, &patch);
#ifdef EXPECTED_VERSION_MAJOR
    ASSERT_EQ(major, EXPECTED_VERSION_MAJOR);
    ASSERT_EQ(minor, EXPECTED_VERSION_MINOR);
    ASSERT_EQ(patch, EXPECTED_VERSION_PATCH);
#endif
    PASS();
}

TEST(get_patch_count_null_handle) {
    int count = gonodes_get_patch_count(nullptr);
    ASSERT_EQ(count, 0);
    PASS();
}

TEST(get_patch_path_null_handle) {
    const char* path = gonodes_get_patch_path(nullptr, nullptr);
    ASSERT_NULL(path);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  NULL handle safety — every function should return a clean error           */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(create_null_project_path_returns_null) {
    gonodes_instance_t inst = gonodes_create(nullptr, nullptr);
    ASSERT_NULL(inst);
    PASS();
}

TEST(destroy_null_does_not_crash) {
    gonodes_destroy(nullptr);  /* Should be a no-op. */
    PASS();
}

TEST(load_patch_null_handle) {
    gonodes_patch_t p = gonodes_load_patch(nullptr, "test.gnpatch");
    ASSERT_NULL(p);
    PASS();
}

TEST(load_patch_null_path) {
    /* We can't create a real instance without LibGodot, so pass NULL handle.
     * The NULL handle check comes first, which is what we verify. */
    gonodes_patch_t p = gonodes_load_patch(nullptr, nullptr);
    ASSERT_NULL(p);
    PASS();
}

TEST(unload_patch_null_handle) {
    gonodes_unload_patch(nullptr, nullptr);  /* Should be a no-op. */
    PASS();
}

TEST(reload_patch_null_handle) {
    int err = gonodes_reload_patch(nullptr, nullptr);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_auto_reload_null_handle) {
    gonodes_set_auto_reload(nullptr, nullptr, 1, 0.5);  /* Should be a no-op. */
    PASS();
}

TEST(cook_frame_null_handle) {
    gonodes_cook_frame(nullptr, 0.016);  /* Should be a no-op. */
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Input injection — NULL handle safety                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(set_input_texture_null_handle) {
    int err = gonodes_set_input_texture(nullptr, nullptr, "node", 123, 100, 100, 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_chop_null_handle) {
    float samples[] = {1.0f};
    int err = gonodes_set_input_chop(nullptr, nullptr, "node", "ch", samples, 1);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_table_null_handle) {
    int err = gonodes_set_input_table(nullptr, nullptr, "node", "[]");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_parameter_null_handle) {
    int err = gonodes_set_parameter(nullptr, nullptr, "node", "param", "1.0");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_pixels_null_handle) {
    uint8_t pixels[4] = {255, 0, 0, 255};
    int err = gonodes_set_input_pixels(nullptr, nullptr, "node", pixels, 1, 1, 0, 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_geometry_null_handle) {
    float pos[] = {0, 0, 0};
    int err = gonodes_set_input_geometry(nullptr, nullptr, "node", pos, nullptr, nullptr, 1, nullptr, 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_volume_null_handle) {
    float voxels[] = {1.0f};
    int err = gonodes_set_input_volume(nullptr, nullptr, "node", voxels, 1, 1, 1, 1, "density");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_particles_null_handle) {
    float pos[] = {0, 0, 0};
    int err = gonodes_set_input_particles(nullptr, nullptr, "node", pos, nullptr, nullptr, nullptr, 1);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output reading — NULL handle safety                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(get_output_texture_null_handle) {
    int w, h;
    uint64_t tex = gonodes_get_output_texture(nullptr, nullptr, "node", &w, &h);
    ASSERT_EQ(tex, (uint64_t)0);
    PASS();
}

TEST(get_output_chop_null_handle) {
    float buf[16];
    int n = gonodes_get_output_chop(nullptr, nullptr, "node", "ch", buf, 16);
    ASSERT_TRUE(n < 0);
    PASS();
}

TEST(get_output_table_null_handle) {
    const char* json = gonodes_get_output_table(nullptr, nullptr, "node");
    ASSERT_NULL(json);
    PASS();
}

TEST(get_parameter_null_handle) {
    const char* val = gonodes_get_parameter(nullptr, nullptr, "node", "param");
    ASSERT_NULL(val);
    PASS();
}

TEST(get_output_geometry_null_handle) {
    const gonodes_geometry_data_t* geo = gonodes_get_output_geometry(nullptr, nullptr, "node");
    ASSERT_NULL(geo);
    PASS();
}

TEST(get_output_volume_null_handle) {
    const gonodes_volume_data_t* vol = gonodes_get_output_volume(nullptr, nullptr, "node");
    ASSERT_NULL(vol);
    PASS();
}

TEST(get_output_particles_null_handle) {
    const gonodes_particle_data_t* pop = gonodes_get_output_particles(nullptr, nullptr, "node");
    ASSERT_NULL(pop);
    PASS();
}

TEST(read_output_pixels_null_handle) {
    uint8_t buf[4];
    int w, h;
    int err = gonodes_read_output_pixels(nullptr, nullptr, "node", buf, 4, 0, &w, &h);
    ASSERT_TRUE(err < 0);
    PASS();
}

TEST(get_texture_info_null_handle) {
    gonodes_texture_info_t info;
    int err = gonodes_get_texture_info(nullptr, nullptr, "node", &info);
    ASSERT_TRUE(err < 0);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Introspection — NULL handle safety                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(list_nodes_null_handle) {
    const char* json = gonodes_list_nodes(nullptr, nullptr);
    ASSERT_NULL(json);
    PASS();
}

TEST(get_node_info_null_handle) {
    const char* json = gonodes_get_node_info(nullptr, nullptr, "node");
    ASSERT_NULL(json);
    PASS();
}

TEST(list_parameters_null_handle) {
    const char* json = gonodes_list_parameters(nullptr, nullptr, "node");
    ASSERT_NULL(json);
    PASS();
}

TEST(list_connections_null_handle) {
    const char* json = gonodes_list_connections(nullptr, nullptr);
    ASSERT_NULL(json);
    PASS();
}

TEST(get_host_io_null_handle) {
    const char* json = gonodes_get_host_io(nullptr, nullptr);
    /* v2 returns "{}" for invalid handle. */
    ASSERT_NOT_NULL(json);
    PASS();
}

TEST(get_stats_null_handle) {
    double cook_ms;
    int node_count, frame_number;
    gonodes_get_stats(nullptr, nullptr, &cook_ms, &node_count, &frame_number);
    /* Should be a no-op — just shouldn't crash. */
    PASS();
}

TEST(get_last_error_null_handle) {
    const char* err = gonodes_get_last_error(nullptr);
    /* v2 returns "Invalid handle" for NULL inst. */
    ASSERT_NOT_NULL(err);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callbacks — NULL handle safety                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(set_on_param_changed_null_handle) {
    gonodes_set_on_param_changed(nullptr, nullptr, nullptr);
    PASS();
}

TEST(set_log_callback_null_handle) {
    gonodes_set_log_callback(nullptr, nullptr, nullptr);
    PASS();
}

TEST(set_on_event_null_handle) {
    gonodes_set_on_event(nullptr, nullptr, nullptr);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Transport — NULL handle safety                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(set_transport_null_handle) {
    int err = gonodes_set_transport(nullptr, nullptr, GONODES_TRANSPORT_PLAY);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_transport_speed_null_handle) {
    int err = gonodes_set_transport_speed(nullptr, nullptr, 1.0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(transport_seek_null_handle) {
    int err = gonodes_transport_seek(nullptr, nullptr, 5.0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(get_transport_time_null_handle) {
    double t = gonodes_get_transport_time(nullptr, nullptr);
    ASSERT_EQ(t, 0.0);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Events — NULL handle safety                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(fire_event_null_handle) {
    int err = gonodes_fire_event(nullptr, nullptr, "beat", nullptr);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(send_midi_event_null_handle) {
    gonodes_midi_event_t evt = {0x90, 60, 127, 0, 0};
    int err = gonodes_send_midi_event(nullptr, nullptr, &evt);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(send_osc_message_null_handle) {
    int err = gonodes_send_osc_message(nullptr, nullptr, "/test", "[1.0]");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Dynamic graph editing — NULL handle safety                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(create_node_null_handle) {
    int err = gonodes_create_node(nullptr, nullptr, "node1", "NoiseTOP");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(delete_node_null_handle) {
    int err = gonodes_delete_node(nullptr, nullptr, "node1");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(connect_null_handle) {
    int err = gonodes_connect(nullptr, nullptr, "a", 0, "b", 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(disconnect_null_handle) {
    int err = gonodes_disconnect(nullptr, nullptr, "a", 0, "b", 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_output_resolution_null_handle) {
    int err = gonodes_set_output_resolution(nullptr, nullptr, "node", 1920, 1080);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Zero-copy — NULL handle safety                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(set_input_volume_gpu_null_handle) {
    int err = gonodes_set_input_volume_gpu(nullptr, nullptr, "node", 123, 64, 64, 64, 1, "density");
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(get_output_volume_gpu_null_handle) {
    gonodes_volume_gpu_handle_t info;
    int err = gonodes_get_output_volume_gpu(nullptr, nullptr, "node", &info);
    ASSERT_TRUE(err < 0);
    PASS();
}

TEST(set_input_particles_gpu_null_handle) {
    int err = gonodes_set_input_particles_gpu(nullptr, nullptr, "node", 123, 100, 64, 6400);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(get_output_particles_gpu_null_handle) {
    gonodes_particle_gpu_handle_t info;
    int err = gonodes_get_output_particles_gpu(nullptr, nullptr, "node", &info);
    ASSERT_TRUE(err < 0);
    PASS();
}

TEST(set_input_chop_direct_null_handle) {
    const char* names[] = {"ch1"};
    float data[] = {1.0f};
    const float* ptrs[] = {data};
    int counts[] = {1};
    int err = gonodes_set_input_chop_direct(nullptr, nullptr, "node", names, ptrs, counts, 1);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(get_output_chop_direct_null_handle) {
    gonodes_chop_data_t out;
    int err = gonodes_get_output_chop_direct(nullptr, nullptr, "node", &out);
    ASSERT_TRUE(err < 0);
    PASS();
}

TEST(set_input_table_direct_null_handle) {
    int err = gonodes_set_input_table_direct(nullptr, nullptr, "node", "[]", 2);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}

TEST(set_input_geometry_direct_null_handle) {
    float pos[] = {0, 0, 0};
    int err = gonodes_set_input_geometry_direct(nullptr, nullptr, "node", pos, nullptr, nullptr, nullptr, 1, nullptr, 0);
    ASSERT_EQ(err, GONODES_ERR_INVALID_HANDLE);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Struct layout / size checks                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(gpu_context_struct_has_correct_fields) {
    gonodes_gpu_context_t gpu = {0};
    gpu.graphics_api = GONODES_GFX_VULKAN;
    ASSERT_EQ(gpu.graphics_api, GONODES_GFX_VULKAN);
    ASSERT_NULL(gpu.vulkan_instance);
    ASSERT_NULL(gpu.metal_device);
    ASSERT_NULL(gpu.gl_context);
    PASS();
}

TEST(texture_info_struct_layout) {
    gonodes_texture_info_t info;
    memset(&info, 0, sizeof(info));
    info.width = 1920;
    info.height = 1080;
    info.format = GONODES_FORMAT_RGBA8;
    info.channels = 4;
    info.native_handle = 0xDEADBEEF;
    info.graphics_api = GONODES_GFX_VULKAN;
    ASSERT_EQ(info.width, 1920);
    ASSERT_EQ(info.height, 1080);
    ASSERT_EQ(info.channels, 4);
    ASSERT_EQ(info.native_handle, (uint64_t)0xDEADBEEF);
    PASS();
}

TEST(geometry_data_struct_layout) {
    gonodes_geometry_data_t geo;
    memset(&geo, 0, sizeof(geo));
    geo.vertex_count = 100;
    geo.index_count = 300;
    geo.primitive_type = 0;  /* triangles */
    ASSERT_EQ(geo.vertex_count, 100);
    ASSERT_EQ(geo.index_count, 300);
    ASSERT_NULL(geo.positions);
    PASS();
}

TEST(volume_data_struct_layout) {
    gonodes_volume_data_t vol;
    memset(&vol, 0, sizeof(vol));
    vol.width = 64;
    vol.height = 64;
    vol.depth = 64;
    vol.channels = 1;
    ASSERT_EQ(vol.width, 64);
    ASSERT_EQ(vol.depth, 64);
    ASSERT_NULL(vol.voxels);
    PASS();
}

TEST(particle_data_struct_layout) {
    gonodes_particle_data_t pop;
    memset(&pop, 0, sizeof(pop));
    pop.particle_count = 10000;
    ASSERT_EQ(pop.particle_count, 10000);
    ASSERT_NULL(pop.positions);
    ASSERT_NULL(pop.velocities);
    PASS();
}

TEST(particle_gpu_handle_stride) {
    gonodes_particle_gpu_handle_t gpu_pop;
    memset(&gpu_pop, 0, sizeof(gpu_pop));
    gpu_pop.stride = 64;  /* Standard layout: 4x vec4 = 64 bytes */
    ASSERT_EQ(gpu_pop.stride, 64);
    PASS();
}

TEST(midi_event_struct_layout) {
    gonodes_midi_event_t evt;
    evt.status = 0x90;   /* Note On */
    evt.data1 = 60;      /* Middle C */
    evt.data2 = 127;     /* Velocity */
    evt.channel = 0;
    evt.port = 0;
    ASSERT_EQ(evt.status, 0x90);
    ASSERT_EQ(evt.data1, 60);
    PASS();
}

TEST(chop_data_struct_layout) {
    gonodes_chop_data_t chop;
    memset(&chop, 0, sizeof(chop));
    chop.channel_count = 3;
    chop.sample_rate = 44100.0f;
    ASSERT_EQ(chop.channel_count, 3);
    ASSERT_TRUE(chop.sample_rate > 44000.0f);
    ASSERT_NULL(chop.channels);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Error code / enum value checks                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

TEST(error_codes_are_distinct) {
    ASSERT_NE(GONODES_OK, GONODES_ERR_INVALID_HANDLE);
    ASSERT_NE(GONODES_ERR_FILE_NOT_FOUND, GONODES_ERR_PARSE_ERROR);
    ASSERT_NE(GONODES_ERR_GPU_INIT_FAILED, GONODES_ERR_NODE_NOT_FOUND);
    ASSERT_NE(GONODES_ERR_PARAM_NOT_FOUND, GONODES_ERR_BUFFER_TOO_SMALL);
    ASSERT_NE(GONODES_ERR_NOT_LOADED, GONODES_ERR_MAX_PATCHES);
    ASSERT_NE(GONODES_ERR_UNSUPPORTED, GONODES_ERR_TYPE_MISMATCH);
    ASSERT_NE(GONODES_ERR_INTERNAL, GONODES_OK);
    PASS();
}

TEST(error_codes_are_negative) {
    ASSERT_EQ(GONODES_OK, 0);
    ASSERT_TRUE(GONODES_ERR_INVALID_HANDLE < 0);
    ASSERT_TRUE(GONODES_ERR_FILE_NOT_FOUND < 0);
    ASSERT_TRUE(GONODES_ERR_PARSE_ERROR < 0);
    ASSERT_TRUE(GONODES_ERR_INTERNAL < 0);
    PASS();
}

TEST(graphics_api_enum_values) {
    ASSERT_EQ(GONODES_GFX_AUTO, 0);
    ASSERT_EQ(GONODES_GFX_VULKAN, 1);
    ASSERT_EQ(GONODES_GFX_METAL, 2);
    ASSERT_EQ(GONODES_GFX_OPENGL, 3);
    ASSERT_EQ(GONODES_GFX_MOBILE, 4);
    PASS();
}

TEST(texture_format_enum_values) {
    ASSERT_EQ(GONODES_FORMAT_RGBA8, 0);
    ASSERT_EQ(GONODES_FORMAT_RGBA16F, 1);
    ASSERT_EQ(GONODES_FORMAT_RGBA32F, 2);
    ASSERT_EQ(GONODES_FORMAT_R8, 3);
    ASSERT_EQ(GONODES_FORMAT_RG8, 4);
    ASSERT_EQ(GONODES_FORMAT_BGRA8, 5);
    PASS();
}

TEST(transport_state_enum_values) {
    ASSERT_EQ(GONODES_TRANSPORT_PLAY, 0);
    ASSERT_EQ(GONODES_TRANSPORT_PAUSE, 1);
    ASSERT_EQ(GONODES_TRANSPORT_STOP, 2);
    PASS();
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Main                                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int main() {
    printf("\n═══ libgonodes API Tests ═══\n\n");

    /* Version */
    printf("[version]\n");
    run_version_returns_correct_values();
    run_version_accepts_null_pointers();
    run_version_macros_are_consistent();
    run_version_matches_cmake();
    run_version_runtime_matches_cmake();

    /* NULL handle safety */
    printf("\n[null_handle_lifecycle]\n");
    run_create_null_project_path_returns_null();
    run_destroy_null_does_not_crash();
    run_load_patch_null_handle();
    run_load_patch_null_path();
    run_unload_patch_null_handle();
    run_reload_patch_null_handle();
    run_set_auto_reload_null_handle();
    run_get_patch_count_null_handle();
    run_get_patch_path_null_handle();
    run_cook_frame_null_handle();

    printf("\n[null_handle_input]\n");
    run_set_input_texture_null_handle();
    run_set_input_chop_null_handle();
    run_set_input_table_null_handle();
    run_set_parameter_null_handle();
    run_set_input_pixels_null_handle();
    run_set_input_geometry_null_handle();
    run_set_input_volume_null_handle();
    run_set_input_particles_null_handle();

    printf("\n[null_handle_output]\n");
    run_get_output_texture_null_handle();
    run_get_output_chop_null_handle();
    run_get_output_table_null_handle();
    run_get_parameter_null_handle();
    run_get_output_geometry_null_handle();
    run_get_output_volume_null_handle();
    run_get_output_particles_null_handle();
    run_read_output_pixels_null_handle();
    run_get_texture_info_null_handle();

    printf("\n[null_handle_introspection]\n");
    run_list_nodes_null_handle();
    run_get_node_info_null_handle();
    run_list_parameters_null_handle();
    run_list_connections_null_handle();
    run_get_host_io_null_handle();
    run_get_stats_null_handle();
    run_get_last_error_null_handle();

    printf("\n[null_handle_callbacks]\n");
    run_set_on_param_changed_null_handle();
    run_set_log_callback_null_handle();
    run_set_on_event_null_handle();

    printf("\n[null_handle_transport]\n");
    run_set_transport_null_handle();
    run_set_transport_speed_null_handle();
    run_transport_seek_null_handle();
    run_get_transport_time_null_handle();

    printf("\n[null_handle_events]\n");
    run_fire_event_null_handle();
    run_send_midi_event_null_handle();
    run_send_osc_message_null_handle();

    printf("\n[null_handle_graph_editing]\n");
    run_create_node_null_handle();
    run_delete_node_null_handle();
    run_connect_null_handle();
    run_disconnect_null_handle();
    run_set_output_resolution_null_handle();

    printf("\n[null_handle_zero_copy_v1_2]\n");
    run_set_input_volume_gpu_null_handle();
    run_get_output_volume_gpu_null_handle();
    run_set_input_particles_gpu_null_handle();
    run_get_output_particles_gpu_null_handle();
    run_set_input_chop_direct_null_handle();
    run_get_output_chop_direct_null_handle();
    run_set_input_table_direct_null_handle();
    run_set_input_geometry_direct_null_handle();

    /* Struct layouts */
    printf("\n[struct_layouts]\n");
    run_gpu_context_struct_has_correct_fields();
    run_texture_info_struct_layout();
    run_geometry_data_struct_layout();
    run_volume_data_struct_layout();
    run_particle_data_struct_layout();
    run_particle_gpu_handle_stride();
    run_midi_event_struct_layout();
    run_chop_data_struct_layout();

    /* Enums */
    printf("\n[enums]\n");
    run_error_codes_are_distinct();
    run_error_codes_are_negative();
    run_graphics_api_enum_values();
    run_texture_format_enum_values();
    run_transport_state_enum_values();

    /* Summary */
    printf("\n═══════════════════════════════════════════════════\n");
    printf("  Total: %d  |  Passed: %d  |  Failed: %d\n", g_total, g_passed, g_failed);
    printf("═══════════════════════════════════════════════════\n\n");

    return g_failed > 0 ? 1 : 0;
}
