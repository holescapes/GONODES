#include "gn_depth_ultraleap.h"
#include <godot_cpp/variant/utility_functions.hpp>

extern std::unique_ptr<DepthSensorBackend> create_ultraleap_backend();

#define GN_DEPTH_CLASS GNDepthUltraleap
#define GN_DEPTH_BACKEND_NAME "ultraleap"
#define GN_DEPTH_BACKEND_FACTORY create_ultraleap_backend

#include "depth_sensor_impl.h"
