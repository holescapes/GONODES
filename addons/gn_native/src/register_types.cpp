#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

// SOP processors — Phase 1
#include "sop/gn_native_particle.h"
#include "sop/gn_native_metaball.h"
#include "sop/gn_native_polyreduce.h"

// SOP processors — Phase 2
#include "sop/gn_native_isosurface.h"
#include "sop/gn_native_ray.h"
#include "sop/gn_native_facet.h"
#include "sop/gn_native_fuse.h"
#include "sop/gn_native_subdivide.h"
#include "sop/gn_native_copy.h"
#include "sop/gn_native_lsystem.h"
#include "sop/gn_native_spring.h"

// IMG processors — Phase 1
#include "img/gn_native_blur.h"
#include "img/gn_native_pixel_sort.h"
#include "img/gn_native_noise.h"

// IMG processors — Phase 2
#include "img/gn_native_edge_detect.h"

// CHOP processors — Phase 2
#include "chop/gn_native_smooth.h"

// CHOP processors — Phase 3
#include "chop/gn_native_noise_chop.h"
#include "chop/gn_native_wave_chop.h"
#include "chop/gn_native_math_chop.h"
#include "chop/gn_native_filter_chop.h"
#include "chop/gn_native_resample_chop.h"
#include "chop/gn_native_trail_chop.h"
#include "chop/gn_native_slope_chop.h"
#include "chop/gn_native_warp_chop.h"
#include "chop/gn_native_interpolate_chop.h"
#include "chop/gn_native_physics_chop.h"
#include "chop/gn_native_pattern_chop.h"
#include "chop/gn_native_audio_spectrum_chop.h"

// SOP processors — Phase 3
#include "sop/gn_native_noise_sop.h"
#include "sop/gn_native_mountain_sop.h"
#include "sop/gn_native_blend_sop.h"
#include "sop/gn_native_scatter_sop.h"
#include "sop/gn_native_sweep_sop.h"
#include "sop/gn_native_extrude_sop.h"
#include "sop/gn_native_bend_sop.h"
#include "sop/gn_native_taper_sop.h"
#include "sop/gn_native_twist_sop.h"
#include "sop/gn_native_lattice_sop.h"
#include "sop/gn_native_magnet_sop.h"
#include "sop/gn_native_polyloft_sop.h"
#include "sop/gn_native_skin_sop.h"

// TOP processors — Phase 3
#include "top/gn_native_optical_flow_top.h"
#include "top/gn_native_analyze_top.h"

using namespace godot;

void initialize_gn_native_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // SOP processors — Phase 1
    ClassDB::register_class<GNNativeParticle>();
    ClassDB::register_class<GNNativeMetaball>();
    ClassDB::register_class<GNNativePolyReduce>();

    // SOP processors — Phase 2
    ClassDB::register_class<GNNativeIsoSurface>();
    ClassDB::register_class<GNNativeRay>();
    ClassDB::register_class<GNNativeFacet>();
    ClassDB::register_class<GNNativeFuse>();
    ClassDB::register_class<GNNativeSubdivide>();
    ClassDB::register_class<GNNativeCopy>();
    ClassDB::register_class<GNNativeLSystem>();
    ClassDB::register_class<GNNativeSpring>();

    // IMG processors — Phase 1
    ClassDB::register_class<GNNativeBlur>();
    ClassDB::register_class<GNNativePixelSort>();
    ClassDB::register_class<GNNativeNoise>();

    // IMG processors — Phase 2
    ClassDB::register_class<GNNativeEdgeDetect>();

    // CHOP processors — Phase 2
    ClassDB::register_class<GNNativeSmooth>();

    // CHOP processors — Phase 3
    ClassDB::register_class<GNNativeNoiseChop>();
    ClassDB::register_class<GNNativeWaveChop>();
    ClassDB::register_class<GNNativeMathChop>();
    ClassDB::register_class<GNNativeFilterChop>();
    ClassDB::register_class<GNNativeResampleChop>();
    ClassDB::register_class<GNNativeTrailChop>();
    ClassDB::register_class<GNNativeSlopeChop>();
    ClassDB::register_class<GNNativeWarpChop>();
    ClassDB::register_class<GNNativeInterpolateChop>();
    ClassDB::register_class<GNNativePhysicsChop>();
    ClassDB::register_class<GNNativePatternChop>();
    ClassDB::register_class<GNNativeAudioSpectrumChop>();

    // SOP processors — Phase 3
    ClassDB::register_class<GNNativeNoiseSop>();
    ClassDB::register_class<GNNativeMountainSop>();
    ClassDB::register_class<GNNativeBlendSop>();
    ClassDB::register_class<GNNativeScatterSop>();
    ClassDB::register_class<GNNativeSweepSop>();
    ClassDB::register_class<GNNativeExtrudeSop>();
    ClassDB::register_class<GNNativeBendSop>();
    ClassDB::register_class<GNNativeTaperSop>();
    ClassDB::register_class<GNNativeTwistSop>();
    ClassDB::register_class<GNNativeLatticeSop>();
    ClassDB::register_class<GNNativeMagnetSop>();
    ClassDB::register_class<GNNativePolyLoftSop>();
    ClassDB::register_class<GNNativeSkinSop>();

    // TOP processors — Phase 3
    ClassDB::register_class<GNNativeOpticalFlowTop>();
    ClassDB::register_class<GNNativeAnalyzeTop>();
}

void uninitialize_gn_native_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT gn_native_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_gn_native_module);
    init_obj.register_terminator(uninitialize_gn_native_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
