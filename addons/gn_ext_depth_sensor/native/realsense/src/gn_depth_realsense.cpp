#include "gn_depth_realsense.h"
#include <godot_cpp/variant/utility_functions.hpp>

extern std::unique_ptr<DepthSensorBackend> create_realsense_backend();

#define GN_DEPTH_CLASS GNDepthRealSense
#define GN_DEPTH_BACKEND_NAME "realsense"
#define GN_DEPTH_BACKEND_FACTORY create_realsense_backend

#include "depth_sensor_impl.h"
