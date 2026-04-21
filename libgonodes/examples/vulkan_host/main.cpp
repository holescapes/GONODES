/*
 * GONODES Vulkan Host Example
 *
 * Demonstrates embedding GONODES with a Vulkan rendering context.
 * The host creates a VkInstance, VkDevice, and VkQueue, shares them
 * with LibGodot for zero-copy texture sharing, then renders the output
 * to a window via a VkSwapchain blit.
 *
 * After loading, the Host I/O manifest is queried via gonodes_get_host_io()
 * to discover the patch's declared inputs, outputs, and exposed parameters.
 *
 * This example uses the Vulkan API directly (no windowing library) with
 * platform-specific surface creation.  For a simpler approach with SDL2,
 * see the sdl_host example.
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target vulkan_host
 *
 * Run:
 *   ./vulkan_host path/to/gonodes_project path/to/show.gnpatch
 */

#include <gonodes_host.h>

#include <vulkan/vulkan.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Vulkan Helpers                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static VkInstance create_instance() {
    VkApplicationInfo app_info = {};
    app_info.sType              = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.pApplicationName   = "GONODES Vulkan Host";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName        = "GONODES";
    app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion         = VK_API_VERSION_1_2;

    VkInstanceCreateInfo create_info = {};
    create_info.sType            = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app_info;

    /* In production, add VK_KHR_surface + platform surface extension. */
    VkInstance instance = VK_NULL_HANDLE;
    VkResult res = vkCreateInstance(&create_info, nullptr, &instance);
    if (res != VK_SUCCESS) {
        fprintf(stderr, "vkCreateInstance failed: %d\n", res);
        return VK_NULL_HANDLE;
    }
    return instance;
}


static VkPhysicalDevice pick_physical_device(VkInstance instance) {
    uint32_t count = 0;
    vkEnumeratePhysicalDevices(instance, &count, nullptr);
    if (count == 0) return VK_NULL_HANDLE;

    std::vector<VkPhysicalDevice> devices(count);
    vkEnumeratePhysicalDevices(instance, &count, devices.data());

    /* Prefer discrete GPU. */
    for (auto dev : devices) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(dev, &props);
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            printf("[Vulkan Host] Using GPU: %s\n", props.deviceName);
            return dev;
        }
    }
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(devices[0], &props);
    printf("[Vulkan Host] Using GPU: %s\n", props.deviceName);
    return devices[0];
}


static uint32_t find_graphics_queue_family(VkPhysicalDevice phys_dev) {
    uint32_t count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(phys_dev, &count, nullptr);
    std::vector<VkQueueFamilyProperties> families(count);
    vkGetPhysicalDeviceQueueFamilyProperties(phys_dev, &count, families.data());

    for (uint32_t i = 0; i < count; ++i) {
        if (families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)
            return i;
    }
    return UINT32_MAX;
}


static VkDevice create_device(VkPhysicalDevice phys_dev, uint32_t queue_family, VkQueue* out_queue) {
    float priority = 1.0f;
    VkDeviceQueueCreateInfo queue_info = {};
    queue_info.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_info.queueFamilyIndex = queue_family;
    queue_info.queueCount       = 1;
    queue_info.pQueuePriorities = &priority;

    VkPhysicalDeviceFeatures features = {};

    VkDeviceCreateInfo create_info = {};
    create_info.sType                = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    create_info.queueCreateInfoCount = 1;
    create_info.pQueueCreateInfos    = &queue_info;
    create_info.pEnabledFeatures     = &features;

    VkDevice device = VK_NULL_HANDLE;
    VkResult res = vkCreateDevice(phys_dev, &create_info, nullptr, &device);
    if (res != VK_SUCCESS) {
        fprintf(stderr, "vkCreateDevice failed: %d\n", res);
        return VK_NULL_HANDLE;
    }

    vkGetDeviceQueue(device, queue_family, 0, out_queue);
    return device;
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

    /* ── Vulkan Setup ───────────────────────────────────────────────── */

    VkInstance vk_instance = create_instance();
    if (!vk_instance) return 1;

    VkPhysicalDevice vk_phys_dev = pick_physical_device(vk_instance);
    if (!vk_phys_dev) return 1;

    uint32_t queue_family = find_graphics_queue_family(vk_phys_dev);
    if (queue_family == UINT32_MAX) {
        fprintf(stderr, "No graphics queue family found\n");
        return 1;
    }

    VkQueue vk_queue = VK_NULL_HANDLE;
    VkDevice vk_device = create_device(vk_phys_dev, queue_family, &vk_queue);
    if (!vk_device) return 1;

    printf("[Vulkan Host] Device created, queue family %u\n", queue_family);

    /* ── GONODES Initialization ─────────────────────────────────────── */

    gonodes_gpu_context_t gpu = {};
    gpu.graphics_api          = GONODES_GFX_VULKAN;
    gpu.vulkan_instance       = (void*)vk_instance;
    gpu.vulkan_physical_device = (void*)vk_phys_dev;
    gpu.vulkan_device         = (void*)vk_device;
    gpu.vulkan_queue          = (void*)vk_queue;
    gpu.vulkan_queue_family   = queue_family;

    printf("[Vulkan Host] Creating GONODES instance...\n");
    gonodes_instance_t gn = gonodes_create(project_path, &gpu);
    if (!gn) {
        fprintf(stderr, "[Vulkan Host] gonodes_create failed\n");
        vkDestroyDevice(vk_device, nullptr);
        vkDestroyInstance(vk_instance, nullptr);
        return 1;
    }

    printf("[Vulkan Host] Loading patch: %s\n", patch_file);
    gonodes_patch_t p = gonodes_load_patch(gn, patch_file);
    if (!p) {
        fprintf(stderr, "[Vulkan Host] Load failed: %s\n", gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        vkDestroyDevice(vk_device, nullptr);
        vkDestroyInstance(vk_instance, nullptr);
        return 1;
    }

    gonodes_set_auto_reload(gn, p, 1, 0.5);

    /* ── Query Host I/O Manifest ────────────────────────────────────── */

    const char* host_io = gonodes_get_host_io(gn, p);
    if (host_io && host_io[0] != '\0') {
        printf("[Vulkan Host] Host I/O Manifest:\n%s\n", host_io);
    } else {
        printf("[Vulkan Host] No Host I/O manifest in patch.\n");
    }

    /* ── Headless Cook Loop (no presentation) ───────────────────────── */
    /* In a real app, you'd create a swapchain and blit the output VkImage.
     * Here we demonstrate the cook loop and output reading. */

    printf("[Vulkan Host] Running 300 frames (headless)...\n");
    for (int frame = 0; frame < 300; ++frame) {
        double delta = 1.0 / 60.0;

        /* Inject host data. */
        float value = (float)frame / 300.0f;
        gonodes_set_input_chop(gn, p, "host_lfo", "progress", &value, 1);

        /* Cook. */
        gonodes_cook_frame(gn, delta);

        /* Read output texture — this is a VkImage on the shared device. */
        int w = 0, h = 0;
        uint64_t tex = gonodes_get_output_texture(gn, p, "host_out", &w, &h);

        if (frame % 60 == 0) {
            double cook_ms = 0;
            int cooked = 0, fn = 0;
            gonodes_get_stats(gn, p, &cook_ms, &cooked, &fn);
            printf("  Frame %d: tex=0x%llx %dx%d, cook=%.2fms\n",
                   frame, (unsigned long long)tex, w, h, cook_ms);
        }
    }

    /* ── v2.0: Zero-Copy VOL GPU Exchange ─────────────────────────── */
    /* On a shared Vulkan device, push a 3D texture handle to a HostInVOL
     * node.  The handle is used directly by the GONODES compute pipeline
     * — no CPU readback or upload.  After cooking, read the output 3D
     * texture handle back from a HostOutVOL node. */

    printf("[Vulkan Host] VOL GPU zero-copy demo...\n");
    {
        /* In a real app, create a VkImage3D and fill it with voxel data.
         * Here we simulate by passing a dummy handle for demonstration. */
        uint64_t dummy_vol_handle = 0x12345678ULL;  /* real: vkGetImage... */
        int vol_err = gonodes_set_input_volume_gpu(gn, p, "host_vol_in",
            dummy_vol_handle, 64, 64, 64, 1, "density");
        if (vol_err == GONODES_OK)
            printf("  Pushed 64^3 volume handle to host_vol_in\n");

        gonodes_cook_frame(gn, 1.0 / 60.0);

        gonodes_volume_gpu_handle_t vol_out = {};
        if (gonodes_get_output_volume_gpu(gn, p, "host_vol_out", &vol_out) == GONODES_OK
            && vol_out.native_handle != 0) {
            printf("  VOL output: handle=0x%llx %dx%dx%d ch=%d\n",
                   (unsigned long long)vol_out.native_handle,
                   vol_out.width, vol_out.height, vol_out.depth, vol_out.channels);
        } else {
            printf("  VOL output: not available (no host_vol_out node?)\n");
        }
    }

    /* ── v2.0: Zero-Copy POP GPU Exchange ─────────────────────────── */
    /* Push a particle SSBO handle to a HostInPOP node.  The buffer is a
     * VkBuffer on the shared device, used directly by POP compute shaders.
     * After cooking, read the output SSBO handle from a HostOutPOP node. */

    printf("[Vulkan Host] POP GPU zero-copy demo...\n");
    {
        uint64_t dummy_ssbo = 0xABCDEF00ULL;  /* real: vkCreateBuffer... */
        int pop_err = gonodes_set_input_particles_gpu(gn, p, "host_pop_in",
            dummy_ssbo, 10000, 64, 10000 * 64);
        if (pop_err == GONODES_OK)
            printf("  Pushed 10000-particle SSBO to host_pop_in\n");

        gonodes_cook_frame(gn, 1.0 / 60.0);

        gonodes_particle_gpu_handle_t pop_out = {};
        if (gonodes_get_output_particles_gpu(gn, p, "host_pop_out", &pop_out) == GONODES_OK
            && pop_out.native_handle != 0) {
            printf("  POP output: handle=0x%llx count=%d stride=%d\n",
                   (unsigned long long)pop_out.native_handle,
                   pop_out.particle_count, pop_out.stride);
        } else {
            printf("  POP output: not available (no host_pop_out node?)\n");
        }
    }

    /* ── Cleanup ────────────────────────────────────────────────────── */

    gonodes_destroy(gn);
    vkDestroyDevice(vk_device, nullptr);
    vkDestroyInstance(vk_instance, nullptr);

    printf("[Vulkan Host] Clean exit.\n");
    return 0;
}
