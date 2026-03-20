#include "register_types.h"
#include "gn_python_runtime.h"
#include "gn_python_processor.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void gn_python_init(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;

    ClassDB::register_class<gn::GNPythonRuntime>();
    ClassDB::register_class<gn::GNPythonProcessor>();
}

void gn_python_deinit(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    // GNPythonRuntime destructor calls Py_FinalizeEx()
}

extern "C" {

GDExtensionBool GDE_EXPORT gn_python_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    const GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization) {

    GDExtensionBinding::InitObject init_obj(p_get_proc_address,
                                             p_library, r_initialization);
    init_obj.register_initializer(gn_python_init);
    init_obj.register_terminator(gn_python_deinit);
    init_obj.set_minimum_library_initialization_level(
        MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}

} // extern "C"
