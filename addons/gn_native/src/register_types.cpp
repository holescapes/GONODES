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
